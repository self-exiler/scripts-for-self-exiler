# 实用工具集

自用脚本与工具合集，按用途分目录存放。

---

## 篡改猴脚本

使用前请确认已登录目标站点

| 脚本                   | 文件                                                   | 说明                                                       | 安装                                                                                                                                                                                                                                                                                                                                        |
| ---------------------- | ------------------------------------------------------ | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 华住官网 Cookie 提取器 | `华住官网抓取cookies/hworld-cookie-copy.user.js`     | 在 hworld.com 注入"复制 Cookie"按钮，一键复制到剪贴板      | [![Install](https://img.shields.io/badge/Install-Tampermonkey-339933?logo=tampermonkey&style=for-the-badge)](https://raw.githubusercontent.com/self-exiler/scripts-for-self-exiler/main/%E7%AF%A1%E6%94%B9%E7%8C%B4%E8%84%9A%E6%9C%AC/%E5%8D%8E%E4%BD%8F%E5%AE%98%E7%BD%91%E6%8A%93%E5%8F%96cookies/hworld-cookie-copy.user.js)                  |
| 知乎清空关注问题       | `知乎清空关注问题/zhihu-unfollow-questions.user.js`  | 批量取消关注知乎上的所有关注问题，支持进度显示和暂停       | [![Install](https://img.shields.io/badge/Install-Tampermonkey-339933?logo=tampermonkey&style=for-the-badge)](https://raw.githubusercontent.com/self-exiler/scripts-for-self-exiler/main/%E7%AF%A1%E6%94%B9%E7%8C%B4%E8%84%9A%E6%9C%AC/%E7%9F%A5%E4%B9%8E%E6%B8%85%E7%A9%BA%E5%85%B3%E6%B3%A8%E9%97%AE%E9%A2%98/zhihu-unfollow-questions.user.js) |
| Dippstar 黑名单屏蔽器  | `dippstar 屏蔽器/dippstar_blacklist_blocker.user.js` | 从黑名单页面获取列表，自动屏蔽 Dippstar 论坛指定用户的内容 | [![Install](https://img.shields.io/badge/Install-Tampermonkey-339933?logo=tampermonkey&style=for-the-badge)](https://raw.githubusercontent.com/self-exiler/scripts-for-self-exiler/main/%E7%AF%A1%E6%94%B9%E7%8C%B4%E8%84%9A%E6%9C%AC/dippstar%20%E5%B1%8F%E8%94%BD%E5%99%A8/dippstar_blacklist_blocker.user.js)                                 |

## 青龙面板脚本

青龙脚本需在面板中配置 cron 触发和 Cookie 环境变量

| 脚本         | 文件                      | 说明                                 | 安装                                                                                                                                                                                                                                                                       |
| ------------ | ------------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ikuuu 签到   | `ikuuu_checkin.py`      | ikuuu 面板自动签到，需要抓取 Cookie  | [![Raw](https://img.shields.io/badge/Raw-%E2%AC%87%EF%B8%8F%20%E6%9F%A5%E7%9C%8B-222?style=for-the-badge&logo=python)](https://raw.githubusercontent.com/self-exiler/scripts-for-self-exiler/main/%E9%9D%92%E9%BE%99%E9%9D%A2%E6%9D%BF%E8%84%9A%E6%9C%AC/ikuuu_checkin.py)      |
| 南+ 论坛签到 | `south_plus_checkin.py` | 南+论坛每日自动签到，需要抓取 Cookie | [![Raw](https://img.shields.io/badge/Raw-%E2%AC%87%EF%B8%8F%20%E6%9F%A5%E7%9C%8B-222?style=for-the-badge&logo=python)](https://raw.githubusercontent.com/self-exiler/scripts-for-self-exiler/main/%E9%9D%92%E9%BE%99%E9%9D%A2%E6%9D%BF%E8%84%9A%E6%9C%AC/south_plus_checkin.py) |

## Python脚本

### B站 Yuki_114514 资源解压工具

- 文件：`B站Yuki_114514资源解压工具/decompress.py`
- 作用：一键解压 B 站 UP 主 Yuki_114514 发布的 MMD 视频资源
- 解压链路：`.lz4` → `.xz` → `.mp4`
- 基于 PySide6 构建的图形界面，支持拖拽文件、并行解压、进度显示
- 依赖：Python 3.8+、PySide6、lz4
- 解压工具需提前安装 Python 依赖：`pip install PySide6 lz4`

## AI 技能

- `skill/swashbucklerdiary-entry/` — 将用户输入的日常记录写入侠客日记 (SwashbucklerDiary) SQLite 数据库

## 注意事项

- 使用前请确认已登录目标站点
- 青龙脚本需在面板中配置 cron 触发和 Cookie 环境变量
- 解压工具需提前安装 Python 依赖：`pip install PySide6 lz4`
- 脚本仅供个人学习使用
