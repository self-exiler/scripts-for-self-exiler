---
name: swashbucklerdiary-entry
description: Write daily records into SwashbucklerDiary SQLite DB. Trigger when user sends journal text or asks to save to diary or write to xiake journal.
agent_created: true
---
# SwashbucklerDiary Entry Skill

将用户发送的日常记录解析后写入侠客日记 SQLite 数据库。

## 数据库路径

Windows 本机默认路径（已确认）：

```
C:\Users\dioha\AppData\Local\Packages\36234Yu-Core.12598F3457A93_n5xthzrt7j3t2\LocalState\SwashbucklerDiary.db3
```

将此路径存入记忆，后续无需重复询问。

## 工作流程

1. **接收输入** — 用户发送自由文本（可能隐含心情/天气/标签）
2. **解析字段** — 提取结构化字段（见下方解析规则）
3. **与用户确认** — 展示解析结果，请用户确认或修改
4. **写入数据库** — 执行 `scripts/insert_diary.py`

## 字段解析规则

| 字段         | 规则                                                      |
| ------------ | --------------------------------------------------------- |
| `Date`     | 若消息提及日期则使用该日期，否则为当日                     |
| `Title`    | 默认留空（NULL），除非用户特别指定标题                     |
| `Content`  | 正文主体（支持 Markdown）                                 |
| `Mood`     | 从语气推断（开心/平静/难过等）或询问用户                  |
| `Weather`  | 从上下文推断或留 NULL                                     |
| `Location` | 从上下文推断或留 NULL                                     |
| `Tags`     | 提取话题标签（#work）或关键词；不存在则新建               |
| `Top`      | 默认 `False`；用户明确要求置顶才设 `True`             |
| `Private`  | 默认 `False`                                            |

## 写入脚本

使用 `scripts/insert_diary.py`，用法：

```bash
python scripts/insert_diary.py \
  --db-path "在数据库路径内写好的db3文件路径" \
  --content "正文内容" \
  --date "2026-06-16" \
  --title "标题" \
  --mood "😊" \
  --weather "☀️" \
  --location "北京" \
  --tags "工作,生活"
```

除 `--db-path` 和 `--content` 外均为可选参数。
若指定 `--date`，则 `CreateTime` 使用该日期 + 当前时间；否则使用当前日期时间。
脚本自动处理：UUID 生成、`CreateTime`/`UpdateTime` 格式化、标签不存在时自动新建、写入 `DiaryTagModel` 关联表。

## 数据库结构参考

完整表结构见 `references/schema.md`。
