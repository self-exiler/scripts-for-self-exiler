# .NET 项目打包规则

目录结构、产物命名、tag 驱动版本号、推 GitHub Release、测试拦截——与 SKILL.md 的通用规则一致，本文件只讲 .NET 特有部分。

## 1. build.ps1 要点（全部来自实战踩坑）

- **参数化**：`-Version`（必传）、`-Full`/`-SelfContained`、`-AOT`、`-R2R`、`-SkipPublish`（复用 publish 产物加速调试）。
- **显式写死 publish 参数**，不要依赖 `.pubxml`（常被 gitignore，隐式默认会漂移成坏包）：
  ```powershell
  dotnet publish $project -c Release --self-contained $sc -p:WindowsAppSDKSelfContained=$wasc -o $publishDir --nologo -v minimal
  if ($LASTEXITCODE -ne 0) { throw "dotnet publish 失败（退出码 $LASTEXITCODE）" }
  ```
- **版本号拆分**：
  ```powershell
  if (-not ($Version -match '^(\d+(?:\.\d+){0,3})')) { throw "无法解析数字主版本" }
  $msiVersion = $Matches[1]
  ```

## 2. WiX MSI

installer/ 下维护三个文件：

- `Product.wxs` — MSI 定义
- `Bundle.wxs` — Bundle 引导安装器（检测/下载依赖）
- `harvest.wxs` — 发布目录收割文件（构建时生成或手工维护）

要点：

- **WiX 稳定 GUID**：组件 GUID 由相对路径派生（同一份代码重复打包得到稳定 GUID），否则升级安装不会正确替换旧文件。`UpgradeCode` 一经发布**不得更改**，Bundle 的升级码与 MSI 的分开。
- **WiX v4 没有 Files 目录收割**（v5 才有），Heat 要额外装扩展；可自己扫描发布目录生成 harvest.wxs。
- **非自包含的依赖链路**：构建期把运行时安装包下载到 `cache/`、算 SHA1 和大小注入 Bundle.wxs；安装期由 Bundle 检测锚点（如注册表/文件存在性）决定是否下载执行。

## 3. Android（.NET APK 直出）

```powershell
dotnet publish src/AndroidApp/AndroidApp.csproj -c Release -f net10.0-android -p:AndroidPackageFormat=apk -o installer/output-android
# 签名：CI 中用 secrets 存 keystore（base64），步骤里解码并传
# -p:AndroidKeyStore=true -p:AndroidSigningKeyStore=... -p:AndroidSigningKeyPass / AndroidSigningStorePass
```

产物重命名为 `软件名-android-arm64-版本号.apk`。
