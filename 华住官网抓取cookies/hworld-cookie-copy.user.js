// ==UserScript==
// @name         华住集团官网 Cookie 提取器
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  提取 hworld.com 网站的 cookie 并复制到剪贴板（点击按钮触发）
// @author       User
// @match        https://www.hworld.com/*
// @match        https://*.hworld.com/*
// @grant        GM_setClipboard
// @grant        GM_notification
// @run-at       document-idle
// ==/UserScript==

(function() {
    'use strict';

    function copyCookiesToClipboard() {
        try {
            const cookies = document.cookie;
            
            if (!cookies || cookies === '') {
                GM_notification({
                    text: '未找到任何 Cookie',
                    title: '华住 Cookie 提取器',
                    timeout: 3000
                });
                return;
            }

            GM_setClipboard(cookies);
            
            GM_notification({
                text: 'Cookie 已成功复制到剪贴板！\n\n' + cookies.substring(0, 100) + (cookies.length > 100 ? '...' : ''),
                title: '华住 Cookie 提取器',
                timeout: 5000
            });

            console.log('[华住 Cookie 提取器] Cookie 已复制:', cookies);
        } catch (error) {
            console.error('[华住 Cookie 提取器] 复制失败:', error);
            GM_notification({
                text: '复制失败：' + error.message,
                title: '华住 Cookie 提取器',
                timeout: 3000
            });
        }
    }

    function createButton() {
        const button = document.createElement('button');
        button.textContent = '📋 复制 Cookie';
        button.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 999999;
            padding: 12px 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: bold;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
            transition: all 0.3s ease;
        `;

        button.onmouseover = () => {
            button.style.transform = 'translateY(-2px)';
            button.style.boxShadow = '0 6px 20px rgba(0, 0, 0, 0.3)';
        };

        button.onmouseout = () => {
            button.style.transform = 'translateY(0)';
            button.style.boxShadow = '0 4px 15px rgba(0, 0, 0, 0.2)';
        };

        button.onclick = (e) => {
            e.preventDefault();
            e.stopPropagation();
            copyCookiesToClipboard();
        };

        document.body.appendChild(button);
        console.log('[华住 Cookie 提取器] 按钮已创建');
    }

    setTimeout(() => {
        createButton();
    }, 1000);

})();
