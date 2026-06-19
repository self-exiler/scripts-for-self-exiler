// ==UserScript==
// @name         知乎清空关注问题
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  批量取消关注知乎上的所有关注问题
// @author       opencode
// @match        https://www.zhihu.com/*
// @grant        GM_xmlhttpRequest
// @connect      www.zhihu.com
// ==/UserScript==

(function() {
    'use strict';

    const CONFIG = {
        API_BASE: 'https://www.zhihu.com/api/v4',
        DELAY_BETWEEN_REQUESTS: 1500,
        LIMIT_PER_REQUEST: 20
    };

    let isRunning = false;
    let processedCount = 0;
    let totalCount = 0;

    function createUI() {
        const container = document.createElement('div');
        container.id = 'zhihu-unfollow-panel';
        container.innerHTML = `
            <div style="
                position: fixed;
                top: 100px;
                right: 20px;
                width: 320px;
                background: #fff;
                border: 1px solid #e0e0e0;
                border-radius: 8px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.15);
                z-index: 9999;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                padding: 16px;
            ">
                <h3 style="margin: 0 0 12px 0; color: #333; font-size: 16px;">知乎清空关注问题</h3>
                <div id="zhihu-unfollow-status" style="margin-bottom: 12px; color: #666; font-size: 14px;">
                    点击开始按钮执行批量取消关注
                </div>
                <div id="zhihu-unfollow-progress" style="
                    display: none;
                    margin-bottom: 12px;
                    padding: 8px;
                    background: #f5f5f5;
                    border-radius: 4px;
                    font-size: 13px;
                    color: #333;
                ">
                    <div>进度: <span id="zhihu-progress-text">0/0</span></div>
                    <div style="
                        height: 4px;
                        background: #e0e0e0;
                        border-radius: 2px;
                        margin-top: 8px;
                        overflow: hidden;
                    ">
                        <div id="zhihu-progress-bar" style="
                            height: 100%;
                            background: #1772f6;
                            width: 0%;
                            transition: width 0.3s;
                        "></div>
                    </div>
                </div>
                <div style="display: flex; gap: 8px;">
                    <button id="zhihu-unfollow-start" style="
                        flex: 1;
                        padding: 8px 16px;
                        background: #1772f6;
                        color: #fff;
                        border: none;
                        border-radius: 4px;
                        cursor: pointer;
                        font-size: 14px;
                    ">开始</button>
                    <button id="zhihu-unfollow-stop" style="
                        flex: 1;
                        padding: 8px 16px;
                        background: #f5f5f5;
                        color: #333;
                        border: 1px solid #e0e0e0;
                        border-radius: 4px;
                        cursor: pointer;
                        font-size: 14px;
                    ">停止</button>
                </div>
                <button id="zhihu-unfollow-close" style="
                    position: absolute;
                    top: 8px;
                    right: 8px;
                    background: none;
                    border: none;
                    font-size: 18px;
                    cursor: pointer;
                    color: #999;
                ">&times;</button>
            </div>
        `;
        document.body.appendChild(container);

        document.getElementById('zhihu-unfollow-start').addEventListener('click', startUnfollow);
        document.getElementById('zhihu-unfollow-stop').addEventListener('click', stopUnfollow);
        document.getElementById('zhihu-unfollow-close').addEventListener('click', () => container.remove());
    }

    function updateStatus(message) {
        const statusEl = document.getElementById('zhihu-unfollow-status');
        if (statusEl) statusEl.textContent = message;
    }

    function updateProgress(current, total) {
        const progressEl = document.getElementById('zhihu-unfollow-progress');
        const progressText = document.getElementById('zhihu-progress-text');
        const progressBar = document.getElementById('zhihu-progress-bar');
        if (progressEl) progressEl.style.display = 'block';
        if (progressText) progressText.textContent = `${current}/${total}`;
        if (progressBar) progressBar.style.width = `${(current / total) * 100}%`;
    }

    function apiRequest(method, url) {
        return new Promise((resolve, reject) => {
            GM_xmlhttpRequest({
                method: method,
                url: url,
                headers: {
                    'x-requested-with': 'fetch',
                },
                onload: function(response) {
                    if (response.status >= 200 && response.status < 300) {
                        if (response.status === 204 || !response.responseText) {
                            resolve({});
                        } else {
                            try {
                                resolve(JSON.parse(response.responseText));
                            } catch (e) {
                                resolve({});
                            }
                        }
                    } else {
                        reject(new Error(`API Error: ${response.status}`));
                    }
                },
                onerror: function(error) {
                    reject(error);
                }
            });
        });
    }

    async function getUsername() {
        const response = await apiRequest('GET', `${CONFIG.API_BASE}/me`);
        return response.url_token;
    }

    async function getFollowedQuestions(username, offset = 0) {
        const url = `${CONFIG.API_BASE}/members/${username}/following-questions?include=data[*].created,answer_count,follower_count,author&offset=${offset}&limit=${CONFIG.LIMIT_PER_REQUEST}`;
        return await apiRequest('GET', url);
    }

    async function unfollowQuestion(questionId) {
        const url = `${CONFIG.API_BASE}/questions/${questionId}/followers`;
        return await apiRequest('DELETE', url);
    }

    async function startUnfollow() {
        if (isRunning) return;

        isRunning = true;
        processedCount = 0;
        updateStatus('正在获取用户信息...');

        try {
            const username = await getUsername();
            if (!username) throw new Error('无法获取用户名');
            updateStatus('正在获取关注问题列表...');

            let allQuestions = [];
            let offset = 0;
            let hasMore = true;

            while (hasMore) {
                const response = await getFollowedQuestions(username, offset);
                if (response.data && response.data.length > 0) {
                    allQuestions = allQuestions.concat(response.data);
                    offset += response.data.length;
                    hasMore = !response.paging?.is_end;
                    updateStatus(`已获取 ${allQuestions.length} 个关注问题...`);
                } else {
                    hasMore = false;
                }
                await new Promise(resolve => setTimeout(resolve, 500));
            }

            totalCount = allQuestions.length;
            if (totalCount === 0) {
                updateStatus('没有关注的问题');
                isRunning = false;
                return;
            }

            updateStatus(`共找到 ${totalCount} 个关注问题，开始取消关注...`);
            updateProgress(0, totalCount);

            for (const question of allQuestions) {
                if (!isRunning) break;

                try {
                    await unfollowQuestion(question.id);
                    processedCount++;
                    updateProgress(processedCount, totalCount);
                    updateStatus(`[${processedCount}/${totalCount}] ${question.title?.substring(0, 30) || question.id}`);
                } catch (error) {
                    console.error(`取消关注失败: ${question.id}`, error);
                    updateStatus(`失败: ${question.title?.substring(0, 30) || question.id}`);
                }

                await new Promise(resolve => setTimeout(resolve, CONFIG.DELAY_BETWEEN_REQUESTS));
            }

            updateStatus(isRunning ? `完成！已取消关注 ${processedCount} 个问题` : `已停止，完成 ${processedCount}/${totalCount}`);
        } catch (error) {
            updateStatus(`错误: ${error.message}`);
        } finally {
            isRunning = false;
        }
    }

    function stopUnfollow() {
        isRunning = false;
        updateStatus('正在停止...');
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', createUI);
    } else {
        createUI();
    }
})();
