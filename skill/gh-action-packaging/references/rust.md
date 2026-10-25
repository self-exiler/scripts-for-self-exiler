# Rust 项目打包规则

通用的目录结构（`installer/` 唯一构建入口）、产物命名 `软件名-操作系统-CPU平台-版本号.扩展名`、tag 驱动版本号、推 GitHub Release、测试拦截——与 SKILL.md 的通用规则完全一致。本文件只讲 Rust 特有部分。

## 1. "自包含"在 Rust 里的形态

Rust 产物天然不依赖目标机装任何运行时，但仍要问用户并确认链接形态：

- **MSVC（默认）**：`x86_64-pc-windows-msvc`，动态链接系统 CRT（vcruntime），目标机基本都有 VC++ Redistributable；体积小。
- **静态 CRT**：`-C target-feature=+crt-static`，CRT 内嵌进 exe，真正单文件免依赖（对应 .NET 的 self-contained 语义）。确认无 DLL 依赖冲突时优先推荐。
- **musl 全静态**（Linux 产物）：`x86_64-unknown-linux-musl`，零 glibc 版本地狱，任何 Linux 可跑；纯 Rust 项目好用，链 C 依赖（openssl 等）时要换 vendored 特性或 rusqlite bundled 等。

打包脚本里做成参数：`-StaticCrt`（Windows）、`-Musl`（Linux）。

## 2. 编译选项（做进 build.ps1 参数或 Cargo profile 分层）

在 `Cargo.toml` 里建 `[profile.release]` 基线，构建脚本不覆盖只透传 `--profile`：

```toml
[profile.release]
lto = "fat"        # 或 "thin"：编译更慢、运行更快/更小
codegen-units = 1  # 最佳优化；1 比 16 慢很多
strip = "symbols"  # 去符号表，体积可减一半以上
panic = "abort"    # 可选：不需要 unwind 时减体积（去掉则栈回溯没了）
opt-level = 3      # 体积敏感可换 "s"/"z"（性能下降）
```

与用户确认的映射关系（对标 .NET 的 AOT/R2R）：
- 极致优化 = `lto="fat"` + `codegen-units=1`（编译最慢）
- 平衡 = `lto="thin"` + `codegen-units=16`
- 必开 `strip = "symbols"`，否则 release 二进制动辄几十 MB 全是调试符号。

## 3. Windows MSI：cargo-wix

用 `cargo-wix`（内部就是 WiX toolset，与 .NET 端同一套 Product.wxs 语义）：

```powershell
# 装一次即可（CI 与本地都要）
cargo install cargo-wix
# 初始化一次，生成 wix\ 目录（main.wxs 等），之后手工维护、入 git
cargo wix init
# 打包（先自己 cargo build --release，或让它内部构建）
cargo wix --release -o installer/output/
```

要点：
- 产物默认名 `xxx-0.1.0-x86_64.msi`，打包后按命名规则重命名为 `软件名-windows-x64-版本号.msi`（版本号由 `-Version` 参数注入，`cargo wix` 读 Cargo.toml 的 version，可用 `-p:ProductVersion` 类参数或在脚本里改写）。
- MSI `ProductVersion` 只能是数字段，`0.4.1beta` 这类串要剥后缀（与 .NET 端同一规则）。
- `UpgradeCode` 由 cargo-wix 生成后**永不再改**；组件 GUID 默认按路径派生，升级替换语义同 .NET 端。
- 不用 cargo-wix 也可以：脚本里自己 `dotnet tool install wix` + 手写 Product.wxs + `wix build`，与 .NET 流程共用一套 wxs 经验。二选一，cargo-wix 更省事，手写 wxx 控制力更强（能做 Bundle 依赖检测）。

## 4. Android APK：cargo-ndk + Gradle 壳

Rust 库进 APK 的标准链路——Rust 编译成 `.so`，由 Android Gradle 项目打 APK：

```powershell
# 一次配置
rustup target add aarch64-linux-android armv7-linux-androideabi
cargo install cargo-ndk

# 编译 .so 到 jniLibs（Gradle 会打进 APK）
cargo ndk -t arm64-v8a -o ./android/app/src/main/jniLibs build --release

# 直出 APK（签名用 CI secrets 注入 keystore）
cd android && ./gradlew assembleRelease
# 或出 AAB：./gradlew bundleRelease
```

- 签名：keystore 以 base64 存 `secrets.ANDROID_KEYSTORE_BASE64`，CI 解码后由 `android/app/build.gradle` 的 `signingConfigs` 读取 `secrets` 环境变量。
- 产物重命名为 `软件名-android-arm64-版本号.apk`。
- 纯 Rust 命令行/无 GUI 的安卓目标不常见；GUI 类（如 Tauri、dioxus-mobile）走它们自己的 CLI，但产物命名和 Release 步骤仍遵守本 skill。

## 5. build.ps1 骨架差异（相对 .NET 版）

```powershell
param([string]$Version = '0.1.0', [switch]$StaticCrt, [switch]$Musl, [switch]$SkipBuild)

# 1. 构建
$rustflags = if ($StaticCrt) { '-Ctarget-feature=+crt-static' } else { $env:RUSTFLAGS }
$env:RUSTFLAGS = $rustflags
$target = if ($Musl) { 'x86_64-unknown-linux-musl' } else { 'x86_64-pc-windows-msvc' }
if (-not $SkipBuild) {
    cargo build --release --target $target --locked
    if ($LASTEXITCODE -ne 0) { throw "cargo build 失败（退出码 $LASTEXITCODE）" }
}
# 2. 收集产物
$exe = "target/$target/release/$appName.exe"
# 3. 打 MSI（cargo wix 或 wix build），4. 重命名为 软件名-windows-x64-$Version.msi
```

- `--locked` 必加：CI 里禁止 Cargo.lock 漂移。
- 跨平台出 Linux 产物在 Windows 上跑不了，需在 ubuntu job 或交叉工具链（`cross`）里做；见 release.yml 模板中"Android job 并行"注释，Linux job 同理按矩阵展开。
- 缓存：CI 中给 `~/.cargo`（registry/git）和 `target/` 配 `actions/cache` 或用 `Swatinem/rust-cache@v2`，否则每次全量重编。

## 6. 工作流差异清单（相对 .NET 模板）

- setup 步骤换：`dtolnay/rust-toolchain@stable`（或钉版本）+ 必要时 `rustup target add ...`；Windows MSI job 仍需 WiX（cargo-wix 自带或 dotnet tool wix）。
- 测试步骤：`cargo test --locked`（在构建前，失败中断发布）。
- `cargo install cargo-wix` 很慢（全量编译），CI 里考虑缓存 `~/.cargo/bin` 或改用手写 wxs + `dotnet tool install wix`（秒级）。
- 其余（版本号解析、upload-artifact、gh-release、fail_on_unmatched_files）与 .NET 模板完全相同。
