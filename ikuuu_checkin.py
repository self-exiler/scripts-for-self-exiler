#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""iKuuu VPN 每日签到脚本 - 青龙面板"""

import os
import sys
from datetime import datetime
import requests

BASE_URL = 'https://ikuuu.win'
COOKIE = os.getenv('IKUUU_COOKIE', '')

def log(level, msg):
    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    icons = {'info': 'ℹ️', 'ok': '✅', 'warn': '⚠️', 'err': '❌'}
    print(f'[iKuuu] [{ts}] {icons[level]} {msg}')

def checkin():
    if not COOKIE:
        log('err', '未设置IKUUU_COOKIE环境变量')
        return False
    
    session = requests.Session()
    session.headers.update({
        'Cookie': COOKIE,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    })
    
    try:
        log('info', '检查登录状态...')
        r = session.get(f'{BASE_URL}/user', timeout=10)
        if r.status_code != 200:
            log('err', f'未登录 (状态码: {r.status_code})')
            return False
        log('ok', '登录状态正常')
        
        log('info', '开始签到...')
        r = session.post(f'{BASE_URL}/user/checkin', timeout=10, json={})
        
        try:
            data = r.json()
        except:
            data = {}
        
        if r.status_code == 200 and (data.get('ret') == 0 or data.get('ret') == 1):
            log('ok', f'签到成功! {data.get("msg", "")}')
            return True
        
        log('warn', f'签到响应: {data}')
        return False
    
    except Exception as e:
        log('err', str(e))
        return False

if __name__ == '__main__':
    print('=' * 40)
    print('iKuuu 每日签到')
    print('=' * 40)
    sys.exit(0 if checkin() else 1)
