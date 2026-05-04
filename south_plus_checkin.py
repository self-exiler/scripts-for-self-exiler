#!/usr/bin/env python3
"""
south-plus.net 论坛签到脚本 (青龙面板版)

原脚本基于QD框架，此版本适配青龙面板。

使用方法:
  1. 在青龙面板中添加环境变量 SOUTH_PLUS_COOKIE
  2. 值填写论坛的完整 Cookie 字符串
  3. 创建定时任务，推荐每天 9:00 运行

抓取Cookie方法:
  1. 用Chrome/Firefox打开 https://www.south-plus.net/ 并登录
  2. F12 -> 网络(Network) -> 刷新页面 -> 点击任意请求
  3. 在请求头(Request Headers)中找到 Cookie 字段，复制全部内容
  4. 粘贴到青龙面板环境变量 SOUTH_PLUS_COOKIE 的值中

定时规则:
  cron: 0 9 * * *
"""

import re
import os
import time
import sys

try:
    import requests
except ImportError:
    print("【错误】缺少 requests 库，请在青龙面板依赖管理中安装 requests")
    sys.exit(1)

# ============================================================
# 配置 - 从环境变量读取
# ============================================================
COOKIE = os.environ.get("SOUTH_PLUS_COOKIE", "")
if not COOKIE:
    print("【错误】未设置环境变量 SOUTH_PLUS_COOKIE")
    print("请在青龙面板 -> 环境变量 -> 添加 SOUTH_PLUS_COOKIE")
    sys.exit(1)

BASE_URL = "https://www.south-plus.net"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"


def create_session():
    """创建带 cookie 的 requests 会话"""
    session = requests.Session()
    session.headers.update({
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Connection": "keep-alive",
    })
    # 解析并设置 cookie
    for item in COOKIE.split(";"):
        item = item.strip()
        if "=" in item:
            key, value = item.split("=", 1)
            session.cookies.set(key.strip(), value.strip(), domain=".south-plus.net")
    return session


def main():
    TOTAL_STEPS = 7
    print("=" * 50)
    print("  south-plus.net 签到脚本")
    print("=" * 50)
    print()

    session = create_session()

    # ----------------------------------------------------------
    # 第1步: Cookie登录检查
    # ----------------------------------------------------------
    print(f"─── 第 1/{TOTAL_STEPS} 步: Cookie 登录验证 ───")
    try:
        resp = session.get(f"{BASE_URL}/plugin.php?H_name-tasks.html=", timeout=30)
        resp.encoding = "gbk"
        html = resp.text

        # 检查登录状态
        if "您没有登录" in html or "您还没有登录" in html:
            print("  [失败] Cookie 无效或已过期，请更新 SOUTH_PLUS_COOKIE")
            print("  提示: 重新登录后从浏览器F12中复制最新的Cookie")
            sys.exit(1)

        # 尝试提取用户名
        user_match = re.search(r'会员[：:]\s*([^<]+)', html)
        if user_match:
            print(f"  [成功] 已登录: {user_match.group(1).strip()}")
        else:
            # 其他用户名显示模式
            user_match = re.search(r'欢迎[：:]?\s*([^<]+)', html)
            if user_match:
                print(f"  [成功] 已登录: {user_match.group(1).strip()}")
            else:
                print("  [成功] Cookie 有效")

        # 提取 verify token
        verify = "6e09b5cc"
        vm = re.search(r'verify=([a-f0-9]+)', html)
        if vm:
            verify = vm.group(1)
        print(f"  [信息] 使用 verify token: {verify}")

    except requests.RequestException as e:
        print(f"  [失败] 网络请求异常: {e}")
        sys.exit(1)

    # ----------------------------------------------------------
    # 第2步: 获取时间戳
    # ----------------------------------------------------------
    print(f"─── 第 2/{TOTAL_STEPS} 步: 获取时间戳 ───")
    nowtime = int(time.time())
    print(f"  [成功] 当前时间戳: {nowtime}")

    # ----------------------------------------------------------
    # 第3-6步: 任务操作 (统一错误处理)
    # ----------------------------------------------------------
    tasks = [
        ("第 3/7 步", "申请周常任务", "job", "14"),
        ("第 4/7 步", "申请日常任务", "job", "15"),
        ("第 5/7 步", "完成周常任务", "job2", "14"),
        ("第 6/7 步", "完成日常任务", "job2", "15"),
    ]

    for step_label, task_name, action, cid in tasks:
        print(f"─── {step_label}: {task_name} (cid={cid}) ───")
        try:
            params = {
                "H_name": "tasks",
                "action": "ajax",
                "actions": action,
                "cid": cid,
                "nowtime": str(nowtime),
                "verify": verify,
            }
            resp = session.get(
                f"{BASE_URL}/plugin.php",
                params=params,
                headers={"Referer": f"{BASE_URL}/plugin.php?H_name-tasks.html"},
                timeout=30,
            )
            resp.encoding = "gbk"
            content = resp.text.strip()

            # 提取 CDATA 中的内容(ajax响应格式)
            cdata_match = re.search(r'<!\[CDATA\[(.+?)\]\]>', content, re.DOTALL)
            if cdata_match:
                content = cdata_match.group(1).strip()

            if "您还没有登录" in content or "不能使用此功能" in content:
                print(f"  [失败] 未登录，跳过")
            elif "success" in content.lower():
                print(f"  [成功] 操作成功")
            elif "已经申请" in content:
                print(f"  [成功] 已申请过，无需重复")
            elif "领取" in content:
                # 可能包含确认信息
                print(f"  [成功] {content[:100]}")
            else:
                print(f"  [信息] {content[:150]}")

        except requests.RequestException as e:
            print(f"  [失败] 请求异常: {e}")

    # ----------------------------------------------------------
    # 第7步: 获取积分
    # ----------------------------------------------------------
    print(f"─── 第 7/{TOTAL_STEPS} 步: 获取积分 ───")
    try:
        resp = session.get(f"{BASE_URL}/userpay.php", timeout=30)
        resp.encoding = "gbk"
        html = resp.text

        if "您没有登录" in html or "您还没有登录" in html:
            print("  [失败] 未登录，无法获取积分")
        else:
            sp_match = re.search(r'SP币[：:]\s*<[^>]+>\s*([\d,.-]+)', html)
            if not sp_match:
                sp_match = re.search(r'SP币[：:]\s*([\d,.-]+)', html)
            if sp_match:
                print(f"  [成功] 当前 SP币: {sp_match.group(1).strip()}")
            else:
                # 查找 SP 相关文本
                idx = html.find("SP")
                if idx > 0:
                    print(f"  [信息] {html[idx:idx+80].strip()}")
                else:
                    print("  [成功] 积分页面访问正常")
    except requests.RequestException as e:
        print(f"  [失败] 请求异常: {e}")

    print()
    print("=" * 50)
    print("  签到流程执行完毕")
    print("=" * 50)


if __name__ == "__main__":
    main()
