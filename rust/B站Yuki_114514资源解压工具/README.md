# B站Yuki_114514资源解压工具 v3.0 (Rust + WinUI 3)

Python/PySide6 版 [`python/B站Yuki_114514资源解压工具`](../../python/B站Yuki_114514资源解压工具/decompress.py) 的 Rust 重写版。
基于微软官方 [`windows-reactor`](https://crates.io/crates/windows-reactor)（WinUI 3 的 Rust 绑定，MVU 模式）。

解压流程: `.lz4` → `.xz` → `.mp4`

## 功能

- 拖拽或选择多个 `.lz4` 文件，支持追加、逐行移除、清空
- 多线程并行解压（1–16 线程可调），按字节量加权计算总进度
- 可选删除源文件（`.lz4`）和过渡文件（`.xz`）
- 实时进度条、逐文件状态、滚动日志
- 目标 mp4 已存在时自动跳过；失败时清理残留文件
- 纯 Rust 解码：`lz4_flex`（LZ4 frame）+ `lzma-rust2`（XZ），无 C 依赖

## 构建与运行

```text
cargo run --release
```

产物：`target/release/yuki-decompressor.exe`（约 2.7 MB）。

### 前置条件

- Rust (MSVC toolchain)
- **Windows App SDK 运行时**（默认为框架依赖部署）：从
  [Microsoft Learn](https://learn.microsoft.com/windows/apps/windows-app-sdk/downloads) 安装
  "Windows App Runtime Redistributable (x64)"。缺失时程序启动即失败。
- 若本机已能运行其他 WinUI 3 应用则无需额外安装。

### 自包含部署（可选）

如需发布给未安装运行时的机器，添加自包含构建：

1. `cargo add --build windows-reactor-setup@0.100`
2. 创建 `build.rs`：

   ```rust
   fn main() {
       windows_reactor_setup::as_self_contained();
   }
   ```

3. 正常 `cargo build --release`，将输出目录中所有运行时 DLL/目录与 exe 一起打包。

## 依赖说明

| 依赖 | 用途 |
| --- | --- |
| `windows-reactor 0.100` | WinUI 3 Rust 绑定（声明式 MVU） |
| `windows-pickers`（vendored） | 系统"打开文件"对话框 |
| `lz4_flex` | LZ4 frame 流式解码 |
| `lzma-rust2` | XZ 流式解码（纯 Rust） |

### 为什么 vendor 了 windows-pickers？

截至 2026-10：

- crates.io 上 `windows-pickers` 仅发布过 0.0.0 占位版本，`0.100.0` 尚未发布；
- 国内镜像 rsproxy 同样没有收录；
- 其 Reactor 集成 API（`request_multiple`）依赖未发布的 reactor master 功能。

因此本目录 `vendor/windows-pickers/` 取自
[microsoft/windows-rs](https://github.com/microsoft/windows-rs) master 快照，
并做了两处适配以匹配已发布的 `windows-core`/`windows-reactor` 0.100.0：

1. `src/bindings.rs`：补齐 `create_instance`（0.100.0 的 windows-core 尚未提供）；
2. 文件对话框改用 `show_multiple_for_hwnd` 裸 API，属主 HWND 通过
   `GetActiveWindow()`/`GetForegroundWindow()` 在 UI 线程获取（reactor 0.100.0
   未暴露 `run_window`/窗口句柄）。

待 crates.io 正式发布 `windows-pickers 0.100+` 后可移除 vendor 目录，改回：

```toml
windows-pickers = { version = "0.100", default-features = false }
```

## 与 Python 版的差异

- 确认弹窗改为两段式确认按钮（reactor 0.100.0 暂无 ContentDialog 结果回调）
- 总进度按字节量加权（Python 版按文件数均分）
- 解压失败会删除残留的 mp4 文件，避免下次被当作已存在而跳过
