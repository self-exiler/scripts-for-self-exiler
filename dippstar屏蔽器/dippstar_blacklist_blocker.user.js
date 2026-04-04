// ==UserScript==
// @name         dippstar 黑名单屏蔽器
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  从黑名单页面提取用户并在论坛帖子列表中屏蔽这些用户
// @author       You
// @match        https://bbs.dippstar.com/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_xmlhttpRequest
// @grant        GM_registerMenuCommand
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

    // 执行屏蔽
    async function doBlock() {
        const users = await getBlacklistUsers();
        if (!users || users.length === 0) {
            console.log('[dippstar 屏蔽器] 黑名单为空');
            return 0;
        }

        const userIds = users.map(u => u.uid);
        let blockedCount = 0;

        // 屏蔽帖子列表中的作者 - 使用更精确的选择器
        const forumThreads = document.querySelectorAll('tbody[id^="normalthread_"]');
        forumThreads.forEach(thread => {
            // 只查找 cite 标签内的作者链接
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

    // 主屏蔽函数
    function blockUsersInForum() {
        doBlock();
    }

    // 注册菜单命令手动刷新黑名单
    GM_registerMenuCommand('🔄 刷新黑名单', async () => {
        console.log('[dippstar 屏蔽器] 手动刷新黑名单...');
        GM_setValue(BLACKLIST_KEY, null);
        const users = await fetchBlacklist();
        alert(`黑名单已刷新，共 ${users.length} 个用户`);
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
                doBlock();
            }, 500);
        }
    });

    // 开始监听
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
})();
