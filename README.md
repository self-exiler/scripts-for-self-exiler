# 脚本合集

本仓库包含为自用篡改猴和其他脚本工具仓库。

## 脚本说明

### 1. 华住集团官网 Cookie 提取器

- 文件：`华住官网抓取cookies/hworld-cookie-copy.user.js`
- 作用：在 `hworld.com` 站点页面上注入一个“复制 Cookie”按钮，点击后将当前页面 Cookie 复制到剪贴板。
- 适用范围：`https://www.hworld.com/*`、`https://*.hworld.com/*`
- 主要功能：
  - 提取当前页面 `document.cookie`
  - 复制 Cookie 到剪贴板
  - 使用通知提示复制结果

[![Install on Tampermonkey](https://img.shields.io/badge/Install-Tampermonkey-339933?logo=tampermonkey&style=for-the-badge)](https://github.com/self-exiler/tampermonkey-scripts-self-exiler/raw/refs/heads/main/%E5%8D%8E%E4%BD%8F%E5%AE%98%E7%BD%91%E6%8A%93%E5%8F%96cookies/hworld-cookie-copy.user.js)

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

[![Install on Tampermonkey](https://img.shields.io/badge/Install-Tampermonkey-339933?logo=tampermonkey&style=for-the-badge)](https://raw.githubusercontent.com/self-exiler/tampermonkey-scripts-self-exiler/main/dippstar%20%E5%B1%8F%E8%94%BD%E5%99%A8/dippstar_blacklist_blocker.user.js)

### 3.B站Yuki_114514资源解压工具

* 文件：B站Yuki_114514资源解压工具.ps1
* 作用：这个作者（Yuki_114514）给的MMD视频资源（见每个评论区网盘），保存规律为：lz4不用改格式直接解压，解压出来的文件要结尾加.xz，也是压缩包，xz解压出来的加.mp4。写了一个powershell脚本一键解压。
* 主要功能：通过内联.net framework的winform，实现了一个GUI，用于一键解压，需要开放ps1脚本权限，以及安装了bandzip。

## 注意事项

- 使用脚本前请确认已登录目标站点。
- Dippstar 屏蔽器依赖黑名单页面抓取数据，若页面结构变更可能需要更新脚本。
- 脚本仅供个人使用，不保证对所有页面场景都完全兼容。

## 贡献

如需优化脚本功能或添加新脚本，可直接修改对应文件并提交 PR。
