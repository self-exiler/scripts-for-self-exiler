---
name: gh-action-packaging
description: 用 GitHub Actions 打包并发布桌面/移动应用安装包的技能，支持 .NET、Rust 与 Android 项目。PC 端用 WiX 生成 MSI（Windows），安卓端直出 APK；构建脚本放项目 installer/ 目录，工作流只调脚本；产物命名为 软件名-操作系统-CPU平台-版本号.扩展名；推 v* 标签触发并自动附到 GitHub Release，测试失败则中断发布。当用户要"打包"、"出安装包"、"发 Release"、"加 CI 发布流水线"或提到 WiX/MSI/APK/自包含/AOT/R2R/LTO/musl/cargo-wix/cargo-ndk 打包时使用本技能。
---

# GitHub Action 打包发布技能

为 .NET / Rust / Android 等项目搭建"本地与云端同源"的打包发布管线。核心经验来自 ComfyuiLauncher 项目：**构建唯一入口是一个仓库内脚本，GitHub Actions 只负责装环境 + 调脚本 + 传产物**，绝不在工作流 YAML 里复述构建步骤——否则本地和云端行为漂移，出坏包。

## 参考文件

按技术栈选读，动手前必读对应那份：

- .NET 项目（含 .NET Android）：读 [references/dotnet.md](references/dotnet.md)
- Rust 项目：读 [references/rust.md](references/rust.md)
- CI 工作流模板：[assets/release.yml](assets/release.yml)（tag 触发 + 手动触发 + Release 附件的完整骨架，两套技术栈通用）

## 0. 开工前必须问用户的事

动手前用 AskUserQuestion 或直接询问，把决策权交给用户：

1. **是否自包含依赖**（必问，含义随技术栈不同）：
   - .NET：自包含（self-contained）= 运行时全部内嵌，包大、离线可装；框架依赖 = 包小，安装时按需下载运行时。详见 references/dotnet.md。
   - Rust：默认产物就是自包含的；仅当链接了 CRT/GTK 等系统库时才需要确认链接形态（见 references/rust.md）。
   - 可以两种形态都出（推荐：默认出瘦身包，加开关出全量包，如 `-Full`），让用户自行选择。
2. **编译方式**（必问，逐项确认）：
   - .NET：AOT（快、小，有反射不兼容风险需先验证）/ R2R（折中）/ 默认 JIT（最稳）。做成构建脚本参数（如 `-AOT`、`-R2R`），不要写死。
   - Rust：release profile 的 `lto`、`strip`、`codegen-units` 等，同样做成参数或 profile 分层（见 references/rust.md）。
3. 其他：应用名、Manufacturer、目标平台（x64/arm64）、是否带测试项目、安卓端签名密钥是否已配置。

## 1. 项目目录结构

打包工具脚本固定放在项目的 `installer/` 目录（安卓端可放 `android/` 或并入 installer）：

```
项目根/
├── src/                      # 源码
├── test/                     # 测试项目（有则必须进流水线）
├── installer/                # 打包工具脚本目录（全部入 git，除 output/）
│   ├── build.ps1             # 唯一构建入口（本地与 CI 共用）
│   ├── cache/                # 构建期下载的依赖缓存（.gitignore）
│   ├── publish/              # 构建中间产物（.gitignore）
│   └── output/               # 最终安装包（.gitignore）
└── .github/workflows/release.yml
```

WiX 定义文件（Product.wxs、Bundle.wxs、harvest.wxs）也放 installer/，见对应技术栈参考文件。

## 2. 通用规则（与技术栈无关）

- **产物命名**（固定规则）：
  ```
  软件名-操作系统-CPU平台-版本号.扩展名
  例：SongYueLauncher-windows-x64-0.4.1beta.msi
      SongYueLauncher-windows-x64-0.4.1beta.exe   （Bundle）
      SongYueLauncher-android-arm64-v1.2.0.apk
  ```
- **版本号拆分**：文件名用完整版本串（如 `0.4.1beta`），MSI 的 ProductVersion 只能取数字段（Windows Installer 限制），脚本里剥出数字主版本。
- **测试拦截**：仓库有测试代码就必须在构建前插测试步骤（.NET：`dotnet test`；Rust：`cargo test --locked`），非零退出码中断发布；没有测试则不加该步骤，不要空跑。
- **CI 语义**（模板见 [assets/release.yml](assets/release.yml)）：
  - push `v*` 标签 → 测试 → 构建 → 创建 GitHub Release 附安装包，版本号取 tag 去 `v` 前缀。
  - workflow_dispatch（带 version 输入）→ 仅构建 + 上传 Actions 产物，**不建 Release**，用于验证管线。
  - `permissions: contents: write`；动作用当前大版本（checkout@v7、setup-dotnet@v6、upload-artifact@v7、softprops/action-gh-release@v3，以最新为准）。
  - `if-no-files-found: error` 和 `fail_on_unmatched_files: true` 都要开——产物缺失必须当场炸掉，不能静默出空 Release。
  - artifact 的 name 也遵循 `软件名-OS-平台-版本号` 命名。
  - 签名类 secrets（Android keystore、代码签名证书）通过 `secrets.*` 注入解码到临时文件，不要提交仓库。

## 3. 落地清单

按顺序执行：

1. 问清用户：自包含与否、编译方式、应用名/平台。
2. 建 `installer/` 目录，写 `build.ps1`（含版本号解析、显式构建参数、产物命名规则），细节按技术栈读对应参考文件。
3. 本地跑通：`./installer/build.ps1 -Version 0.0.1`，检查 output 产物名与行为。
4. 写 `.github/workflows/release.yml`（用 [assets/release.yml](assets/release.yml) 模板改），有测试就插测试步骤。
5. 加 `.gitignore`（installer/output、publish、cache）。
6. 推 `v0.1.0` 标签验证端到端：Actions 绿 → Release 附正确命名的安装包。
