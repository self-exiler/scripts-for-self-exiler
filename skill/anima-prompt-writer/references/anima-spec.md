# Anima 模型提示词规范（官方说明中文译）

> 适用模型：Anima / anima3 等。本文件为写 prompt 的硬性基础，标签名保留英文原词，解释用中文。

## 训练基础
模型在三类数据上训练：**Danbooru 风格标签**、**自然语言描述（caption）**，以及**标签与自然语言的混合**。两种写法都有效，也可混用。

## 标签书写规则
- 标签用小写，词与词之间用空格而不是下划线。
- 唯一例外是分数标签（score tags），它们带下划线，例如 `score_7`。
- 当某个标签在 Danbooru 和 Gelbooru 写法不同，优先用 Gelbooru 版本。
- 提示词权重可用，但需要的权重比 SDXL 通常情况更高。例：`(chibi:2)`。

## 推荐的前缀
- 正向前缀：`masterpiece, best quality, score_7, safe, `
- 负向前缀：`worst quality, low quality, score_1, score_2, score_3, artist name`

## 标签顺序（Tag Order）
按以下分区从左到右排列，每个分区内标签顺序随意：
```
[质量/元/年份/安全标签] [1girl / 1boy / 1other 等] [角色 character] [系列 series] [画师 artist] [通用标签 general tags]
```

## 质量标签（Quality Tags）
- 人工评分类：`masterpiece, best quality, good quality, normal quality, low quality, worst quality`
- PonyV7 美学模型类：`score_9, score_8, ... , score_1`
- 两者可任选其一、同时用、或都不用，组合都成立。

## 时间标签（Time Period Tags）
- 具体年份：`year 2025, year 2024, ...`
- 时期：`newest, recent, mid, early, old`

## 元标签（Meta Tags）
`highres, absurdres, anime screenshot, jpeg artifacts, official art` 等。

## 安全标签（Safety Tags）
`safe, sensitive, nsfw, explicit` —— 放在正向/负向提示词里控制输出分级。需要哪一级就显式写明，不要留空靠默认。

## 画师标签（Artist Tags）
- 画师名前必须加 `@`，例如 `@big chungus`。
- `@` 不能省略，省略后风格影响非常弱。

## 完整标签示例
```
year 2025, newest, normal quality, score_5, highres, safe, 1girl, oomuro sakurako, yuru yuri, @nnn yryr, smile, brown hair, hat, solo, fur-trimmed gloves, open mouth, long hair, gift box, fang, skirt, red gloves, blunt bangs, gloves, one eye closed, shirt, brown eyes, santa costume, red hat, skin fang, twitter username, white background, holding bag, fur trim, simple background, brown skirt, bag, gift bag, looking at viewer, santa hat, ;d, red shirt, box, gift, fur-trimmed headwear, holding, red capelet, holding box, capelet
```

## 标签丢弃（Tag Dropout）
模型训练时做了随机标签丢弃，不需要把每个相关标签都列全，缺一两个也能出图。

## 数据集标签（Dataset Tags）
为提升风格与内容多样性，模型额外用了两个非动漫数据集：LAION-POP（ye-pop 版）和 DeviantArt（均已过滤照片）。它们的 caption 以"数据集标签"开头，独占第一行并换行；第二行可选，写图片 alt-text（ye-pop）或作品标题（DeviantArt）。

- ye-pop 示例：
```
ye-pop
For Sale: Others by Arun Prem
Abstract, oil painting of three faceless, blue-skinned figures. Left: white, draped figure; center: yellow-shirted, dark-haired figure; right: red-veiled, dark-haired figure carrying another. Bold, textured colors, minimalist style.
```
- deviantart 示例：
```
deviantart
Flame
Digital painting of a fiery dragon with glowing yellow eyes, black horns, and a long, sinuous tail, perched on a glowing, molten rock formation. The background is a gradient of dark purple to orange.
```

## 自然语言提示技巧（Natural Language）
- 角色名、系列名遵循标准英文大小写（如 `Fern`, `Sousou no Frieren`）。
- 纯自然语言时越描述越好，至少 2 句话；过短容易出意外结果。
- 标签与自然语言可任意顺序混排。
- 质量/画师标签可放在自然语言 prompt 开头：`masterpiece, best quality, @big chungus. An anime girl with medium-length blonde hair is...`
- 先点名角色，再描述其基本外貌：`Digital artwork of Fern from Sousou no Frieren, with long purple hair and purple eyes, wearing a black coat over a white dress with puffy sleeves...`
- 多角色场景尤其重要——只列名字不描述外貌，模型会混乱。

## 已知局限（Limitations）
- 不擅长写实：设计取向聚焦动漫 / 插画 / 美术风格。
- 可能产出不想要的内容，尤其当 prompt 过短或缺少细节。规避：用合适的安全标签 + 写足够详细的 prompt。
- 文字渲染弱：一般能做单词、偶尔短句，长段文字基本失败。
- base 版本是真正的 base 模型，没在精选数据集上做美学微调，默认风格朴素中性——不用画师/质量标签时尤其明显。
