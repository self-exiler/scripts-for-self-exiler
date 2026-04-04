// ==UserScript==
// @name         dippstar 黑名单屏蔽器
// @namespace    http://tampermonkey.net/
// @version      1.3
// @description  从黑名单页面提取用户并在论坛帖子列表中屏蔽这些用户（支持一键添加黑名单按钮）
// @author       You
// @match        https://bbs.dippstar.com/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_xmlhttpRequest
// @grant        GM_registerMenuCommand
// @grant        GM_notification
// @connect      bbs.dippstar.com
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    const BLACKLIST_KEY = 'dippstar_blacklist_users';
    const BLACKLIST_PAGE_URL = 'https://bbs.dippstar.com/home.php?mod=space&do=friend&view=blacklist';

    // 从 href 中提取用户 ID
    function extractUserId(href) {
        if (!href) return null;
        const patterns = [
            /space-uid-(\d+)\.html/,
            /uid=(\d+)/,
            /space\.php\?uid=(\d+)/
        ];
        for (const pattern of patterns) {
            const match = href.match(pattern);
            if (match && match[1]) return match[1];
        }
        return null;
    }

    // 获取 formhash
    function getFormhash() {
        const formhashInput = document.querySelector('input[name="formhash"]');
        if (formhashInput) {
            return formhashInput.value;
        }
        const urlMatch = document.body.innerHTML.match(/formhash=([a-f0-9]+)/);
        if (urlMatch && urlMatch[1]) {
            return urlMatch[1];
        }
        return null;
    }

    // 从黑名单页面提取用户 ID 列表
    async function fetchBlacklist() {
        return new Promise((resolve) => {
            GM_xmlhttpRequest({
                method: 'GET',
                url: BLACKLIST_PAGE_URL,
                onload: function(response) {
                    try {
                        const parser = new DOMParser();
                        const doc = parser.parseFromString(response.responseText, 'text/html');
                        const blacklistUsers = [];

                        // 查找所有黑名单用户链接
                        const deleteLinks = doc.querySelectorAll('a[href*="op=blacklist&subop=delete&uid="]');
                        deleteLinks.forEach(link => {
                            const href = link.getAttribute('href');
                            const uid = extractUserId(href);
                            if (uid) {
                                blacklistUsers.push({
                                    uid: uid,
                                    username: link.textContent.trim()
                                });
                            }
                        });

                        console.log('[dippstar 屏蔽器] 获取到黑名单用户:', blacklistUsers);
                        resolve(blacklistUsers);
                    } catch (error) {
                        console.error('[dippstar 屏蔽器] 解析黑名单失败:', error);
                        resolve([]);
                    }
                },
                onerror: function(error) {
                    console.error('[dippstar 屏蔽器] 获取黑名单失败:', error);
                    resolve([]);
                }
            });
        });
    }

    // 获取缓存的黑名单或重新获取
    async function getBlacklistUsers() {
        const cached = GM_getValue(BLACKLIST_KEY);
        const now = Date.now();

        // 如果有缓存且未超过 5 分钟，直接使用缓存
        if (cached && (now - cached.timestamp) < 5 * 60 * 1000) {
            console.log('[dippstar 屏蔽器] 使用缓存的黑名单');
            return cached.users;
        }

        // 重新获取黑名单
        console.log('[dippstar 屏蔽器] 正在获取最新黑名单...');
        const users = await fetchBlacklist();
        GM_setValue(BLACKLIST_KEY, {
            users: users,
            timestamp: now
        });
        return users;
    }

    // 添加到黑名单
    async function addToBlacklist(username) {
        const formhash = getFormhash();
        if (!formhash) {
            return { success: false, message: '无法获取 formhash' };
        }

        return new Promise((resolve) => {
            GM_xmlhttpRequest({
                method: 'POST',
                url: 'https://bbs.dippstar.com/home.php?mod=spacecp&ac=friend&op=blacklist&start=',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                },
                data: `username=${encodeURIComponent(username)}&formhash=${formhash}&blacklistsubmit=true`,
                onload: function(response) {
                    try {
                        const parser = new DOMParser();
                        const doc = parser.parseFromString(response.responseText, 'text/html');
                        
                        // 检查是否添加成功
                        const successMsg = doc.querySelector('.ntc_win') || 
                                         doc.querySelector('.alert_success') ||
                                         doc.querySelector('.w');
                        
                        if (successMsg && (successMsg.textContent.includes('成功') || successMsg.textContent.includes('添加'))) {
                            console.log('[dippstar 屏蔽器] 成功添加用户到黑名单:', username);
                            resolve({ success: true, message: '添加成功' });
                        } else if (response.responseText.includes('添加到黑名单成功') || 
                                   response.responseText.includes('操作成功') ||
                                   response.responseText.includes('黑名单除名')) {
                            console.log('[dippstar 屏蔽器] 成功添加用户到黑名单:', username);
                            resolve({ success: true, message: '添加成功' });
                        } else {
                            const errorMsg = doc.querySelector('.alert_error')?.textContent || 
                                           doc.querySelector('.w')?.textContent || 
                                           '添加失败';
                            console.error('[dippstar 屏蔽器] 添加失败:', errorMsg);
                            resolve({ success: false, message: errorMsg.trim() });
                        }
                    } catch (error) {
                        console.error('[dippstar 屏蔽器] 解析响应失败:', error);
                        resolve({ success: false, message: '解析响应失败' });
                    }
                },
                onerror: function(error) {
                    console.error('[dippstar 屏蔽器] 添加黑名单失败:', error);
                    resolve({ success: false, message: '网络错误' });
                }
            });
        });
    }

    // 执行屏蔽
    async function doBlock() {
        const users = await getBlacklistUsers();
        if (!users || users.length === 0) {
            console.log('[dippstar 屏蔽器] 黑名单为空');
            return 0;
        }

        const userIds = users.map(u => u.uid);
        let blockedCount = 0;

        // 屏蔽帖子列表中的作者
        const forumThreads = document.querySelectorAll('tbody[id^="normalthread_"]');
        forumThreads.forEach(thread => {
            const authorLinks = thread.querySelectorAll('cite a[href*="space-uid-"]');
            authorLinks.forEach(authorLink => {
                const href = authorLink.getAttribute('href');
                const uid = extractUserId(href);
                if (uid && userIds.includes(uid) && thread.style.display !== 'none') {
                    thread.style.display = 'none';
                    thread.setAttribute('data-blocked-by', 'dippstar_blacklist');
                    blockedCount++;
                    console.log('[dippstar 屏蔽器] 已屏蔽帖子:', authorLink.textContent);
                }
            });
        });

        // 屏蔽帖子详情页中的回复
        const posts = document.querySelectorAll('div[id^="post_"]');
        posts.forEach(post => {
            const authorLinks = post.querySelectorAll('.authi a[href*="space-uid-"], cite a[href*="space-uid-"]');
            authorLinks.forEach(authorLink => {
                const href = authorLink.getAttribute('href');
                const uid = extractUserId(href);
                if (uid && userIds.includes(uid) && post.style.display !== 'none') {
                    post.style.display = 'none';
                    post.setAttribute('data-blocked-by', 'dippstar_blacklist');
                    blockedCount++;
                    console.log('[dippstar 屏蔽器] 已屏蔽回复:', authorLink.textContent);
                }
            });
        });

        // 屏蔽动态/家园中的内容
        const feedItems = document.querySelectorAll('ul#feed li, .feed li');
        feedItems.forEach(item => {
            const authorLinks = item.querySelectorAll('a[href*="space-uid-"]');
            authorLinks.forEach(authorLink => {
                const href = authorLink.getAttribute('href');
                const uid = extractUserId(href);
                if (uid && userIds.includes(uid) && item.style.display !== 'none') {
                    item.style.display = 'none';
                    item.setAttribute('data-blocked-by', 'dippstar_blacklist');
                    blockedCount++;
                }
            });
        });

        if (blockedCount > 0) {
            console.log(`[dippstar 屏蔽器] 本次共屏蔽 ${blockedCount} 条内容`);
        }
        return blockedCount;
    }

    // 创建一键屏蔽按钮
    function createBlockButton(uid, username) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'dippstar-block-btn';
        btn.innerHTML = '🚫 屏蔽';
        btn.title = `将 ${username} 添加到黑名单`;
        btn.style.cssText = `
            padding: 4px 8px;
            font-size: 12px;
            color: #fff;
            background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
            border: none;
            border-radius: 4px;
            cursor: pointer;
            margin-left: 6px;
            transition: all 0.2s ease;
            box-shadow: 0 2px 4px rgba(239, 68, 68, 0.3);
            white-space: nowrap;
        `;

        btn.onmouseover = () => {
            btn.style.transform = 'scale(1.05)';
            btn.style.boxShadow = '0 3px 8px rgba(239, 68, 68, 0.4)';
        };

        btn.onmouseout = () => {
            btn.style.transform = 'scale(1)';
            btn.style.boxShadow = '0 2px 4px rgba(239, 68, 68, 0.3)';
        };

        btn.onclick = async (e) => {
            e.preventDefault();
            e.stopPropagation();

            // 检查是否已在黑名单中
            const users = await getBlacklistUsers();
            const userIds = users.map(u => u.uid);
            
            if (userIds.includes(uid)) {
                GM_notification({
                    text: `${username} 已在黑名单中`,
                    title: 'dippstar 屏蔽器',
                    timeout: 3000
                });
                return;
            }

            // 禁用按钮防止重复点击
            btn.disabled = true;
            btn.textContent = '⏳ 添加中...';
            btn.style.opacity = '0.7';

            try {
                const result = await addToBlacklist(username);
                
                if (result.success) {
                    btn.textContent = '✅ 已屏蔽';
                    btn.style.background = 'linear-gradient(135deg, #10b981 0%, #059669 100%)';
                    
                    GM_notification({
                        text: `已将 ${username} 添加到黑名单`,
                        title: 'dippstar 屏蔽器',
                        timeout: 3000
                    });

                    // 刷新缓存的黑名单
                    GM_setValue(BLACKLIST_KEY, null);
                    
                    // 立即屏蔽该用户的内容
                    setTimeout(() => doBlock(), 500);
                } else {
                    btn.textContent = '🚫 屏蔽';
                    btn.style.background = 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)';
                    btn.disabled = false;
                    
                    GM_notification({
                        text: `添加失败：${result.message}`,
                        title: 'dippstar 屏蔽器',
                        timeout: 3000
                    });
                }
            } catch (error) {
                console.error('[dippstar 屏蔽器] 添加黑名单异常:', error);
                btn.textContent = '❌ 失败';
                btn.disabled = false;
            }
        };

        return btn;
    }

    // 在头像旁添加屏蔽按钮（仅帖子详情页）
    function addBlockButtons() {
        // 帖子详情页 - 头像区域（.authi 或 .avatar_area）
        const postAvatars = document.querySelectorAll('div[id^="post_"] .authi, div[id^="post_"] .avatar_area');
        postAvatars.forEach(container => {
            // 查找用户链接
            const userLink = container.querySelector('a[href*="space-uid-"]');
            if (!userLink) return;

            // 检查是否已添加按钮
            if (container.querySelector('.dippstar-block-btn')) return;

            const uid = extractUserId(userLink.getAttribute('href'));
            const username = userLink.textContent.trim() || '该用户';

            if (uid) {
                const btn = createBlockButton(uid, username);
                container.appendChild(btn);
            }
        });
    }

    // 主屏蔽函数
    function blockUsersInForum() {
        doBlock();
        addBlockButtons();
    }

    // 注册菜单命令手动刷新黑名单
    GM_registerMenuCommand('🔄 刷新黑名单', async () => {
        console.log('[dippstar 屏蔽器] 手动刷新黑名单...');
        GM_setValue(BLACKLIST_KEY, null);
        const users = await fetchBlacklist();
        GM_notification({
            text: `黑名单已刷新，共 ${users.length} 个用户`,
            title: 'dippstar 屏蔽器',
            timeout: 3000
        });
        location.reload();
    });

    // 显示黑名单信息
    GM_registerMenuCommand('📋 查看黑名单', () => {
        const cached = GM_getValue(BLACKLIST_KEY);
        if (cached && cached.users) {
            const userList = cached.users.map(u => `${u.username} (UID: ${u.uid})`).join('\n');
            alert(`黑名单用户列表:\n\n${userList}`);
        } else {
            alert('黑名单为空或未加载');
        }
    });

    // 页面加载完成后执行
    if (document.readyState === 'complete') {
        blockUsersInForum();
    } else {
        window.addEventListener('load', blockUsersInForum);
    }

    // 监听 DOM 变化，处理 AJAX 加载的内容
    const observer = new MutationObserver((mutations) => {
        let hasNewContent = false;
        mutations.forEach((mutation) => {
            if (mutation.addedNodes.length > 0) {
                hasNewContent = true;
            }
        });
        if (hasNewContent) {
            // 延迟执行，避免频繁调用
            clearTimeout(window._blockTimeout);
            window._blockTimeout = setTimeout(() => {
                blockUsersInForum();
            }, 500);
        }
    });

    // 开始监听
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
})();
