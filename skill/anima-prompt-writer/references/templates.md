# Anima 分镜提示词模板（可直接复用）

> 以下三段可直接复制，替换 `【】` 中的占位内容后发给模型（可保存在对话上下文或本地文件，按需引用）。生成时若需规范细节，参见 `references/anima-spec.md`。

## 模板 A · 生成预设词（正/负向前缀）
```
你是一名 AI 绘图提示词专家，熟悉 Anima（anima3）模型的提示词规范。
请基于以下规则为我生成一套固定的正向前缀与负向前缀：
- 标签小写、空格分隔；分数标签带下划线（score_9 等）
- 画师名前加 @
- 使用质量标签（masterpiece / best quality / score_9...）与安全标签（safe / sensitive / nsfw / explicit）
- 标签顺序：[质量/元/年份/安全] [人数] [角色] [系列] [画师] [通用]

我的默认偏好：【写实度/画风/分级 safe 或 nsfw 等】。
请直接输出两段：正向前缀、负向前缀，并简要说明每个标签的作用。
```

## 模板 B · 小说分镜拆分与提示词生成
```
你是一名 AI 绘图提示词高手。请帮我把下面提供的小说情节按分镜划分，并为每个分镜写出对应的 Anima 模型绘图 prompt。

规则：
1. 女主角固定为下面的【角色名】，其形象沿用已提供的角色卡片。
2. 小说各场景是连续的：上一个分镜对主角造成的影响（如服装撕裂、特定状态）必须继承到后续分镜，不要丢失。
3. 每个分镜的 prompt 结构：先声明角色数量与组成 → 逐个描述角色的位置/形象/状态/动作 → 角色互动 → 背景环境。
4. 遵循 Anima 标签规范：小写标签、@画师、质量与安全标签、权重用 (tag:1.x)。
5. 保证画面详细、可出图，避免过短 prompt。
6. 输出格式：每个分镜先给一段英文 prompt 代码块（保持原样、不翻译），紧接在代码块后按 prompt 先后顺序写出汉语说明，自然连贯、不用"xx 对应 xx"的写法；正/负向前缀只给英文、不翻译。

【角色卡片（来自对话上下文或本地文件）】
【小说情节文本】
```

## 模板 C · 角色形象一致性卡片
```
请把下面这段原文中的人物【角色名】的外貌与特征总结为一段 Anima 风格的提示词卡片（小写标签、逗号分隔、含体型/发色/服饰/表情等），便于我在后续所有分镜中复用，保证人物一致。

【原文人物设定段落】
```

## 多角色站位示范（成品 prompt 结构参考）
```
@eiichiro oda, score_9, score_8, score_7, high resolution, highres, absurdres, masterpiece, 2girls, 1boy, general, official art

On the left of the image is 1girl, she is short with medium breast with blue hair in twintails wearing a white tailcoat jacket over pink button up ruffle shirt and baggy purple pants with silver wingtip shoes. She is standing grinning in a kawaii pose and peace sign with her arm around the neck of 1boy.

In the middle of the image is 1boy, a shirtless muscular man with a bald head and blonde mustache wearing red briefs, yellow kneepads, and red boots. He is blushing and shy, looking down touching his hands together.

In the foreground of the image, sitting on the ground, is 1girl, she is skinny and tall with long black hair wearing orange gi with blue undershirt and blue wristbands and orange pants with blue boots with yellow trim. She is sitting leaning forward smiling and winking.

They are on a bright beach with a blue sky and white wispy clouds
```

## 主角外貌卡片示例（魔法女王西默尼丝）
```
1girl, solo, white hair, long hair, loose hair, ornate crown, red shoulder straps, bare shoulders, red eyes, phoenix eyes, smirk, fair skin, shiny skin, high-leg bodysuit, see-through chest mesh, deep cleavage, black and red corset, fishnet side cutouts, red waist drape, gold trim, red lace panties, black lace trim, red thighhighs, red high heel over-the-knee boots, long red gloves, large breasts, wide hips, curvy
```
