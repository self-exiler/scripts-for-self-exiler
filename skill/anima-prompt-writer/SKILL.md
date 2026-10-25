---
name: anima-prompt-writer
description: |
  根据小说或任意文本，使用任意大模型（如 DeepSeek V4 / d4pro）为 Anima（anima3 等）AI 绘图模型编写分镜绘图提示词的专业技法。
  本技能提供三步工作流（预设词 → 小说分镜拆分 → 角色形象一致性）与可复用模板；详细的模型提示词规范见 references/anima-spec.md，模板见 references/templates.md。
  当用户要求"写 anima 提示词""根据小说生成分镜""anima 分镜脚本""角色一致性提示词""d4pro 写提示词""anima3 提示词""生成绘图 prompt"时，应使用本技能。
agent_created: true
---
# Anima 分镜提示词写作技法

本技能让 AI 助手扮演"AI 绘图提示词助手"，读取用户的小说/文本，按分镜拆解出符合 Anima 模型规范的成品绘图提示词，并借助角色卡片保证跨分镜人物一致。

## 何时使用

- 用户希望为 Anima / anima3 模型生成绘图提示词。
- 用户提供小说、情节或角色设定，要求拆分分镜并产出 prompt。
- 用户需要稳定的角色形象一致性方案（角色卡片 / 上下文复用）。

## 核心工作流（三步）

### 步骤 1 · 预设词（Preset）

1. 准备固定的正向前缀与负向前缀，保存在对话上下文中（跨会话则写入本地文件），每次生图直接拼用。
2. 默认前缀（可直接使用，详见 references/anima-spec.md §推荐的前缀）：
   - 正向：`masterpiece, best quality, score_7, safe, `
   - 负向：`worst quality, low quality, score_1, score_2, score_3, artist name, text`
3. 按需用模板 A（references/templates.md）重新生成贴合用户偏好的前缀。

### 步骤 2 · 小说分镜拆分与提示词生成

1. 读取用户提供的小说/情节文本。
2. 按镜头/场景切分，为每个分镜写一段成品 prompt。
3. 严格遵守 references/anima-spec.md 的规范：小写标签、空格分隔、`@` 画师、质量/安全标签、权重写法 `(tag:1.x)`、标签顺序分区。
4. 保证**连续性**：上一分镜对主角的影响（服装撕裂、特定状态等）必须继承到后续分镜，不得丢失。
5. 成品 prompt 按此结构组织：
   - 先声明角色数量与组成（如 `2girls, 1boy`）；
   - 逐个角色描述其在画面中的**位置 + 形象 + 状态 + 动作**；
   - 说明角色**互动**；
   - 最后写**背景与环境**。
6. 使用模板 B（references/templates.md）构造请求，将角色卡片与小说文本填入占位符。
7. 按"输出格式约定"将每个分镜的英文 prompt 放入代码块、其后紧跟汉语对照返回给用户。

### 步骤 3 · 角色形象一致性构造（Character Card）

1. 读取原文中的人物设定段落。
2. 用模板 C（references/templates.md）让模型将其总结为一段 Anima 风格外貌卡片（小写标签、逗号分隔、含体型/发色/服饰/表情）。
3. 将卡片保存在对话上下文中（或写入本地 .txt 文件以便跨会话复用），在后续每个分镜生成时读取并引用，实现跨分镜一致。

## 输出格式约定

将分析结果与提示词返回给用户时，统一采用以下格式：

1. **英文提示词放入代码块**：将完整英文 prompt（含质量/安全标签与全部自然语言描述段）原样放在围栏代码块（` ``` `）中，保持 Anima 规范的大小写与标点，不做翻译。
2. **代码块后紧跟汉语（按次序，置于正文）**：代码块结束后，在代码块**之外**的正文中按 prompt 出现的先后顺序写出汉语说明，自然连贯地描述画面内容，不要采用"xx 对应 xx"的逐项罗列写法，也不要把汉语写进代码块。
3. **多分镜依次排列**：每个分镜按"英文代码块 + 汉语说明"成对出现，分镜之间用标题或空行分隔。
4. **前缀不翻译**：正/负向前缀只给英文代码块即可，其后不写汉语对照。

示例（分镜 prompt，完整英文入代码块，其后汉语为正文）：
```
score_9, score_8, score_7, masterpiece, best quality, highres, absurdres, sensitive, 1girl, solo, mature, milf

In the center of the image is 1girl, a beautiful mature woman with a full yet firm curvy figure. She wears red-soled high heels and glossy sheer black pantyhose that hug her slender long legs with a fine sheen; her wine-glass thighs are soft and springy, quivering slightly with each step. A pair of micro denim shorts leaves her plump white buttocks spilling over the hem, the wide hips swaying, fat butt cheeks overflowing the shorts with a deep gluteal cleft visible from behind.

On top she wears a sleeveless white shirt worn off one shoulder; her abundant huge breasts strain the fabric and pull the buttons taut as if about to pop, revealing a bottomless deep cleavage. Her waist is slim and easily spanned by a hand, a pretty navel and defined ab lines left bare. She wears long lace opera gloves on both arms.

She stands in the cabin of a first-class airplane, luxurious leather seats and soft warm cabin lighting around her, a window showing open sky beyond.
```
画面中央是一名身材丰满紧致的成熟女性，脚踩红底高跟、身着泛光泽的轻薄黑丝包裹细长小腿，酒杯腿柔软弹动；超短牛仔热裤让丰盈白嫩的臀肉从裤边溢出，宽胯轻摆，臀瓣饱胀、背影可见深邃臀沟。上身是半露香肩的无袖白衬衫，丰硕巨乳将衣料绷紧、扣子仿佛随时崩开，露出深不见底的乳沟；腰肢纤细、肚脐与马甲线裸露，双臂戴着长筒蕾丝手套。她立于飞机头等舱内，四周是奢华真皮座椅与温暖舱灯，舷窗外是开阔的天空。

示例（前缀，仅英文）：
```
masterpiece, best quality, score_9, score_8, score_7, highres, absurdres, sensitive,
```

## 详细参考（按需加载）

- `references/anima-spec.md` —— Anima 模型官方提示词规范全文（标签顺序、质量/时间/元/安全/画师标签、数据集标签、自然语言混排、已知局限）。生成任何 prompt 前先读此文件确认规范。
- `references/templates.md` —— 三套可复用模板（生成预设词 / 分镜生成 / 角色卡片）及多角色站位示范、主角卡片示例。

## 关键注意事项

- 标签小写、空格分隔；分数标签带下划线；画师名前加 `@`。
- 显式写明安全标签（`safe / sensitive / nsfw / explicit`），不要靠默认。
- 避免过短 prompt；分镜描述尽量具体，Anima 对短 prompt 易跑偏。
- base 模型务必加画师/质量标签，否则风格偏朴素。
- 上下文持久化是关键：预设词与角色卡片在每次生图时保持在上下文中（跨会话则存为本地文件），跨分镜一致性最高。
