#!/usr/bin/env python3
"""
insert_diary.py — Insert a diary entry into SwashbucklerDiary SQLite DB.

Usage:
    python insert_diary.py \
        --db-path "C:/path/to/SwashbucklerDiary.db3" \
        --content "Today I ..." \
        --date "2026-06-16" \
        --title "Day title" \
        --mood "😊" \
        --weather "☀️" \
        --location "Beijing" \
        --tags "work,life"

All fields except --db-path and --content are optional.
If --date is provided, CreateTime uses that date + current time; otherwise uses current datetime.
"""

import argparse
import sqlite3
import uuid
from datetime import datetime, date as date_type


def now_str(date_override: str | None = None) -> str:
    """Return timestamp string formatted as 'YYYY-MM-DD HH:MM:SS.mmm'.
    If date_override is specified (e.g. '2026-06-16'), use that date + current time."""
    now = datetime.now()
    if date_override:
        try:
            d = date_type.fromisoformat(date_override)
            now = datetime.combine(d, now.time())
        except ValueError:
            pass
    return now.strftime("%Y-%m-%d %H:%M:%S.") + f"{now.microsecond // 1000:03d}"


def new_id() -> str:
    """Return a new GUID string matching SqlSugar uniqueidentifier format."""
    return str(uuid.uuid4())


def ensure_tags(conn: sqlite3.Connection, tag_names: list[str], ts: str) -> list[str]:
    """Ensure tags exist in TagModel; return list of tag Id values."""
    ids = []
    for name in tag_names:
        row = conn.execute(
            "SELECT Id FROM TagModel WHERE Name = ?", (name,)
        ).fetchone()
        if row:
            ids.append(row[0])
        else:
            tid = new_id()
            conn.execute(
                "INSERT INTO TagModel (Id, CreateTime, UpdateTime, Name) VALUES (?, ?, ?, ?)",
                (tid, ts, ts, name),
            )
            ids.append(tid)
    return ids


def insert_diary(
    db_path: str,
    content: str,
    date_str: str | None = None,
    title: str | None = None,
    mood: str | None = None,
    weather: str | None = None,
    location: str | None = None,
    tags: list[str] | None = None,
    top: bool = False,
    private: bool = False,
    template: bool = False,
) -> str:
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    ts = now_str(date_str)
    diary_id = new_id()

    conn.execute(
        """INSERT INTO DiaryModel
           (Id, CreateTime, UpdateTime, Title, Content, Mood, Weather, Location, Top, Private, Template)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            diary_id,
            ts,
            ts,
            title,
            content,
            mood,
            weather,
            location,
            1 if top else 0,
            1 if private else 0,
            1 if template else 0,
        ),
    )

    if tags:
        tag_ids = ensure_tags(conn, tags, ts)
        for tid in tag_ids:
            conn.execute(
                """INSERT INTO DiaryTagModel (Id, CreateTime, UpdateTime, DiaryId, TagId)
                   VALUES (?, ?, ?, ?, ?)""",
                (new_id(), ts, ts, diary_id, tid),
            )

    conn.commit()
    conn.close()
    return diary_id


def main():
    parser = argparse.ArgumentParser(description="Insert a diary entry into SwashbucklerDiary DB")
    parser.add_argument("--db-path", required=True, help="Path to SwashbucklerDiary.db3")
    parser.add_argument("--content", required=True, help="Diary content (Markdown supported)")
    parser.add_argument("--date", default=None, help="Diary date in YYYY-MM-DD format (optional, default today)")
    parser.add_argument("--title", default=None, help="Diary title (optional, default NULL)")
    parser.add_argument("--mood", default=None, help="Mood string, e.g. 😊")
    parser.add_argument("--weather", default=None, help="Weather string, e.g. ☀️")
    parser.add_argument("--location", default=None, help="Location string")
    parser.add_argument("--tags", default="", help="Comma-separated tag names, e.g. work,life")
    parser.add_argument("--top", action="store_true", help="Pin entry to top")
    parser.add_argument("--private", action="store_true", help="Mark as private")
    parser.add_argument("--template", action="store_true", help="Save as template")
    args = parser.parse_args()

    tags = [t.strip() for t in args.tags.split(",") if t.strip()] if args.tags else []

    diary_id = insert_diary(
        db_path=args.db_path,
        content=args.content,
        date_str=args.date,
        title=args.title,
        mood=args.mood,
        weather=args.weather,
        location=args.location,
        tags=tags,
        top=args.top,
        private=args.private,
        template=args.template,
    )
    print(f"[OK] Diary inserted successfully. ID: {diary_id}")


if __name__ == "__main__":
    main()
