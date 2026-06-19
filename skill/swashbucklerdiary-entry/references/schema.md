# SwashbucklerDiary 数据库实际结构

SQLite 文件：`SwashbucklerDiary.db3`

---

## DiaryModel（日记主表）

| 列名 | 类型 | 说明 |
|------|------|------|
| `Id` | TEXT (GUID) | 主键，格式 `xxxxxxxx-xxxx-...`，无大括号 |
| `CreateTime` | TEXT | `2026-01-15 23:08:29.235` |
| `UpdateTime` | TEXT | 同上 |
| `Title` | TEXT | 可为 NULL |
| `Content` | TEXT | Markdown，实际无长度限制 |
| `Mood` | TEXT | 可为 NULL，如 `😊` / `开心` |
| `Weather` | TEXT | 可为 NULL，如 `☀️` / `晴` |
| `Location` | TEXT | 可为 NULL |
| `Top` | INTEGER | 0/1 |
| `Private` | INTEGER | 0/1（新增列，默认 0）|
| `Template` | INTEGER | 0/1 |

---

## TagModel（标签表）

| 列名 | 类型 | 说明 |
|------|------|------|
| `Id` | TEXT (GUID) | 主键 |
| `CreateTime` | TEXT | |
| `UpdateTime` | TEXT | |
| `Name` | TEXT | 标签名，如 `工作` |

---

## DiaryTagModel（日记-标签关联表）

| 列名 | 类型 | 说明 |
|------|------|------|
| `Id` | TEXT (GUID) | 主键 |
| `CreateTime` | TEXT | |
| `UpdateTime` | TEXT | |
| `DiaryId` | TEXT | 外键 → DiaryModel.Id |
| `TagId` | TEXT | 外键 → TagModel.Id |

---

## 插入顺序

1. 若标签不存在 → 插入 `TagModel`
2. 插入 `DiaryModel`（生成新 GUID 作为 Id）
3. 若有关联标签 → 插入 `DiaryTagModel`

---

## 时间格式

`CreateTime` / `UpdateTime` 格式：
```
YYYY-MM-DD HH:MM:SS.mmm
```
例：`2026-06-19 10:25:00.123`

Python 生成方式：
```python
from datetime import datetime
now = datetime.now()
ts = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{now.microsecond // 1000:03d}"
```

---

## Id 生成

使用 Python `uuid.uuid4()`，输出格式即为所需格式：
```python
import uuid
new_id = str(uuid.uuid4())  # "35fc2701-06ae-4b30-..."
```
