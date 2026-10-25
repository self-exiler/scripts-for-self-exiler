#!/usr/bin/env python3
"""
match_mood_weather.py — Match user input to predefined mood and weather options.

Usage:
    python match_mood_weather.py --mood "开心"
    python match_mood_weather.py --weather "晴天"
    python match_mood_weather.py --mood "开心" --weather "晴天"
"""

import argparse
from difflib import get_close_matches


# 心情选项：英文键 -> (中文值, 匹配关键词列表)
MOOD_OPTIONS = {
    "happy": ("开心", ["开心", "快乐", "高兴", "愉快", "喜悦"]),
    "sad": ("伤心", ["伤心", "难过", "悲伤", "痛苦"]),
    "angry": ("生气", ["生气", "愤怒", "恼火", "气恼"]),
    "excited": ("激动", ["激动", "兴奋", "激动人心"]),
    "neutral": ("无感", ["无感", "平静", "一般", "普通"]),
    "confused": ("困惑", ["困惑", "迷茫", "不解"]),
    "cool": ("得意", ["得意", "骄傲", "自豪"]),
    "cry": ("哭泣", ["哭泣", "流泪", "哭"]),
    "dead": ("难受", ["难受", "痛苦", "难受"]),
    "devil": ("嘿嘿", ["嘿嘿", "坏笑", "调皮"]),
    "frown": ("担忧", ["担忧", "担心", "焦虑"]),
    "kiss": ("亲亲", ["亲亲", "亲吻", "爱"]),
    "lol": ("大笑", ["大笑", "哈哈", "爆笑"]),
    "poop": ("糟糕", ["糟糕", "倒霉", "烦"]),
    "sick": ("病了", ["病了", "不舒服", "生病"]),
    "tongue": ("好吃", ["好吃", "美味", "馋"]),
    "wink": ("眨眼", ["眨眼", "调皮"]),
}


# 天气选项：英文键 -> (中文值, 匹配关键词列表)
WEATHER_OPTIONS = {
    "sunny": ("晴", ["晴", "晴天", "阳光", "晴朗"]),
    "sunny-off": ("阴", ["阴", "阴天", "多云"]),
    "cloudy": ("多云", ["多云", "阴天"]),
    "rainy": ("雨", ["雨", "下雨", "雨天"]),
    "lightning-rainy": ("雷阵雨", ["雷阵雨", "雷雨"]),
    "pouring": ("倾盆大雨", ["倾盆大雨", "暴雨"]),
    "sleet": ("雨夹雪", ["雨夹雪", "雨雪"]),
    "snow": ("雪", ["雪", "下雪", "雪天"]),
    "fog": ("雾", ["雾", "大雾", "雾天"]),
    "hazy": ("薄雾", ["薄雾", "朦胧"]),
    "dust": ("沙尘暴", ["沙尘暴", "沙尘"]),
    "windy": ("风", ["风", "刮风", "大风"]),
    "lightning": ("闪电", ["闪电", "雷电"]),
    "hail": ("冰雹", ["冰雹", "雹子"]),
    "hurricane": ("飓风", ["飓风", "台风"]),
    "tornado": ("龙卷风", ["龙卷风"]),
    "ultraviolet": ("紫外线", ["紫外线", "强光"]),
}


def match_option(user_input: str, options: dict) -> str | None:
    """
    根据用户输入匹配最接近的选项。

    Args:
        user_input: 用户输入的关键词
        options: 选项字典 {英文键: (中文值, 匹配关键词列表)}

    Returns:
        匹配到的英文键，如果没有匹配则返回 None
    """
    if not user_input:
        return None

    user_input = user_input.strip().lower()

    # 1. 精确匹配：检查是否直接匹配某个关键词
    for key, (zh_name, keywords) in options.items():
        if user_input in [kw.lower() for kw in keywords]:
            return key
        if user_input == zh_name.lower():
            return key
        if user_input == key.lower():
            return key

    # 2. 模糊匹配：使用 difflib 找到最接近的匹配
    all_keywords = []
    for key, (zh_name, keywords) in options.items():
        all_keywords.extend(keywords)
        all_keywords.append(zh_name)
        all_keywords.append(key)

    matches = get_close_matches(user_input, all_keywords, n=1, cutoff=0.6)
    if matches:
        matched_keyword = matches[0]
        # 找到对应的英文键
        for key, (zh_name, keywords) in options.items():
            if matched_keyword in keywords or matched_keyword == zh_name or matched_keyword == key:
                return key

    return None


def main():
    parser = argparse.ArgumentParser(description="Match user input to mood/weather options")
    parser.add_argument("--mood", help="User input for mood")
    parser.add_argument("--weather", help="User input for weather")
    args = parser.parse_args()

    if args.mood:
        matched_mood = match_option(args.mood, MOOD_OPTIONS)
        if matched_mood:
            zh_name = MOOD_OPTIONS[matched_mood][0]
            print(f"Mood: {matched_mood} ({zh_name})")
        else:
            print(f"Mood: No match found for '{args.mood}'")
            print("Available moods:")
            for key, (zh_name, _) in MOOD_OPTIONS.items():
                print(f"  - {key}: {zh_name}")

    if args.weather:
        matched_weather = match_option(args.weather, WEATHER_OPTIONS)
        if matched_weather:
            zh_name = WEATHER_OPTIONS[matched_weather][0]
            print(f"Weather: {matched_weather} ({zh_name})")
        else:
            print(f"Weather: No match found for '{args.weather}'")
            print("Available weathers:")
            for key, (zh_name, _) in WEATHER_OPTIONS.items():
                print(f"  - {key}: {zh_name}")


if __name__ == "__main__":
    main()
