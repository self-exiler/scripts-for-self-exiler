# 油猴脚本合集

本仓库包含两个 Tampermonkey/油猴 用户脚本，分别用于华住官网 Cookie 提取与 Dippstar 论坛黑名单屏蔽。

## 目录结构

- `华住官网抓取cookies/`
  - `hworld-cookie-copy.user.js`：华住官网 Cookie 提取器。
- `dippstar 屏蔽器/`
  - `dippstar_blacklist_blocker.user.js`：Dippstar 论坛黑名单屏蔽器。

## 脚本说明

### 1. 华住集团官网 Cookie 提取器

- 文件：`华住官网抓取cookies/hworld-cookie-copy.user.js`
- 作用：在 `hworld.com` 站点页面上注入一个“复制 Cookie”按钮，点击后将当前页面 Cookie 复制到剪贴板。
- 适用范围：`https://www.hworld.com/*`、`https://*.hworld.com/*`
- 主要功能：
  - 提取当前页面 `document.cookie`
  - 复制 Cookie 到剪贴板
  - 使用通知提示复制结果

### 2. Dippstar 黑名单屏蔽器

- 文件：`dippstar 屏蔽器/dippstar_blacklist_blocker.user.js`
- 作用：自动从 Dippstar 论坛黑名单页面获取用户列表，并在论坛帖子列表／回帖中屏蔽这些用户的内容。
- 适用范围：`https://bbs.dippstar.com/*`
- 主要功能：
  - 从黑名单页面提取 UID 和用户名
  - 缓存黑名单，减少请求频率
  - 隐藏帖子列表、回帖、动态中的黑名单用户内容
  - 在帖子详情页为每个用户添加“一键屏蔽”按钮
  - 提供菜单命令：刷新黑名单、查看黑名单

<a href="javascript:(function(d,s){s=d.createElement('script');s.src='https://raw.githubusercontent.com/self-exiler/tampermonkey-scripts-self-exiler/main/dippstar%20%E5%B1%8F%E8%94%BD%E5%99%A8/dippstar_blacklist_blocker.user.js';d.body.appendChild(s);})();">
  <button style="background-color:#4CAF50;border:none;color:white;padding:12px 24px;text-align:center;text-decoration:none;display:inline-block;font-size:16px;margin:4px 2px;cursor:pointer;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,0.2);transition:all 0.2s ease;">
    🚀 安装 dippstar 黑名单屏蔽器
  </button>
</a>

## 注意事项

- 使用脚本前请确认已登录目标站点。
- Dippstar 屏蔽器依赖黑名单页面抓取数据，若页面结构变更可能需要更新脚本。
- 脚本仅供个人使用，不保证对所有页面场景都完全兼容。

## 贡献

如需优化脚本功能或添加新脚本，可直接修改对应文件并提交 PR。
