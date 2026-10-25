# SwashbucklerDiary Entry Skill 使用示例

## 完整工作流程示例

### 场景 1：用户发送包含心情和天气的日记

**用户输入**：
```
今天天气很好，心情特别开心。完成了项目的重要功能，感觉很有成就感。
```

**解析过程**：
1. 提取内容："今天天气很好，心情特别开心。完成了项目的重要功能，感觉很有成就感。"
2. 匹配心情：
   ```bash
   python scripts/match_mood_weather.py --mood "开心"
   # 输出: Mood: happy (开心)
   ```
3. 匹配天气：
   ```bash
   python scripts/match_mood_weather.py --weather "很好"
   # 输出: Weather: sunny (晴)  # 模糊匹配
   ```
4. 与用户确认：
   ```
   解析结果：
   - 内容：今天天气很好，心情特别开心。完成了项目的重要功能，感觉很有成就感。
   - 心情：开心 (happy)
   - 天气：晴 (sunny)
   - 日期：今天
   - 标签：无

   确认写入？(y/n)
   ```

**写入数据库**：
```bash
python scripts/insert_diary.py \
  --db-path "C:\Users\dioha\AppData\Local\Packages\36234Yu-Core.12598F3457A93_n5xthzrt7j3t2\LocalState\SwashbucklerDiary.db3" \
  --content "今天天气很好，心情特别开心。完成了项目的重要功能，感觉很有成就感。" \
  --mood "happy" \
  --weather "sunny"
```

---

### 场景 2：用户心情无法匹配

**用户输入**：
```
今天感觉有点郁闷，工作遇到了一些困难。
```

**解析过程**：
1. 提取内容："今天感觉有点郁闷，工作遇到了一些困难。"
2. 匹配心情：
   ```bash
   python scripts/match_mood_weather.py --mood "郁闷"
   # 输出: Mood: No match found for '郁闷'
   # 输出: Available moods:
   #   - happy: 开心
   #   - sad: 伤心
   #   - angry: 生气
   #   ...
   ```

**询问用户**：
```
无法匹配心情"郁闷"，请从以下选项中选择：
1. 开心 (happy)
2. 伤心 (sad)
3. 生气 (angry)
4. 激动 (excited)
5. 无感 (neutral)
6. 困惑 (confused)
7. 得意 (cool)
8. 哭泣 (cry)
9. 难受 (dead)
10. 嘿嘿 (devil)
11. 担忧 (frown)
12. 亲亲 (kiss)
13. 大笑 (lol)
14. 糟糕 (poop)
15. 病了 (sick)
16. 好吃 (tongue)
17. 眨眼 (wink)

请输入选项编号或英文键：
```

**用户选择**：`frown`（担忧）

**继续写入**：
```bash
python scripts/insert_diary.py \
  --db-path "..." \
  --content "今天感觉有点郁闷，工作遇到了一些困难。" \
  --mood "frown"
```

---

### 场景 3：包含日期、标签、位置

**用户输入**：
```
昨天去北京出差，遇到了老朋友，一起吃了顿饭。#出差 #朋友
```

**解析过程**：
1. 提取内容："昨天去北京出差，遇到了老朋友，一起吃了顿饭。"
2. 日期：昨天（自动计算为 2026-06-19）
3. 位置：北京
4. 标签：出差、朋友
5. 心情和天气：未提及，留空

**与用户确认**：
```
解析结果：
- 内容：昨天去北京出差，遇到了老朋友，一起吃了顿饭。
- 日期：2026-06-19
- 位置：北京
- 标签：出差, 朋友
- 心情：无
- 天气：无

确认写入？(y/n)
```

**写入数据库**：
```bash
python scripts/insert_diary.py \
  --db-path "..." \
  --content "昨天去北京出差，遇到了老朋友，一起吃了顿饭。" \
  --date "2026-06-19" \
  --location "北京" \
  --tags "出差,朋友"
```

---

## 关键要点

1. **心情和天气必须匹配**：
   - 不能直接使用用户输入的中文或自定义值
   - 必须使用 `match_mood_weather.py` 匹配到英文键值
   - 如果无法匹配，询问用户从选项列表中选择

2. **匹配顺序**：
   - 先尝试精确匹配（关键词、中文值、英文键）
   - 再尝试模糊匹配（相似度 ≥ 0.6）
   - 都失败则询问用户

3. **写入数据库时使用英文键值**：
   - `--mood happy`（不是 `--mood 开心` 或 `--mood 😊`）
   - `--weather sunny`（不是 `--weather 晴` 或 `--weather ☀️`）

4. **其他字段保持灵活**：
   - 内容、位置、标签可以自由输入
   - 标签不存在时会自动创建
