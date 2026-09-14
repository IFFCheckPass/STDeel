# BUILD-win.md — 思谛 STDeel Windows 桌面版构建 / 打包 / 发布记录与指南

> 本文件由 AGENTS.md 规则驱动：Windows 桌面版构建流程单独记录于此，随 `feature/windows-support` 分支维护（分支禁止合并 `main`）。
> 所有泛用类规则（版本号、Release/Pre-Release 判定、产物命名、代码同步）与 Android 版一致，见 `docs/BUILD.md` 与根 `AGENTS.md`。
> 最新一次成功的构建过程见底部「累计记录」。

## 一、平台差异说明（Windows 适配点）

本项目为拍照识题 + AI 解题移动应用，Windows 桌面版在 `feature/windows-support` 分支做了最小适配：

| 模块 | Android 行为 | Windows 行为 |
| --- | --- | --- |
| 首页「拍照识题」 | 调起系统相机 | 改为「选择图片文件」，走文件选择器（`image_picker` Windows 实现） |
| 本地通知（`notification_service.dart`） | `flutter_local_notifications` 推送 | **无 Windows 实现**，`Platform.isWindows` 时初始化/展示全部跳过 |
| 应用内更新（`update_service.dart`） | 下载 APK + MethodChannel 拉起系统安装器 | 匹配 `.exe` 资产，下载后 `Process.start` 启动安装器 |
| 竖屏锁定（`main.dart`） | `setPreferredOrientations` | Windows 跳过 |

## 二、构建方式（关键：Linux 无法原生构建 Windows）

`flutter build windows` 需要 **Windows 工具链（Visual Studio + MSVC + Windows SDK）**，Linux 沙箱无法交叉编译。
因此 Windows 版采用 **GitHub Actions windows-latest runner** 构建，workflow 已入库：
- 文件：`.github/workflows/build-windows.yml`
- 触发：push 到 `feature/windows-support`，或手动 `workflow_dispatch`
- 流程：安装 Flutter 3.47.1 → `flutter pub get` → `flutter build windows --release` → Inno Setup 打包安装器 → 上传 artifact → **自动发布到同版本 GitHub Release**（`gh release upload --clobber`，自 v0.7.5 起）

手动触发：
```bash
gh workflow run build-windows.yml --repo IFFCheckPass/STDeel --ref feature/windows-support
# 查看状态
gh run list --repo IFFCheckPass/STDeel --workflow build-windows.yml
```

## 三、安装器打包（Inno Setup）

- 脚本：`scripts/windows_installer.iss`
- 产物：`build/windows/installer/stdeel-setup-<版本号>.exe`
- 关键点：
  - **Release 目录必须用绝对路径传入**（`/DReleaseDir=...`），.iss 内相对路径 `..\..\build\...` 在 Actions 上会解析失败报 "No files found"。
  - 语言文件：只保留 `compiler:Default.isl`（choco 版 Inno Setup 不带 `ChineseSimplified.isl`，引用会编译失败）。
  - 版本号从 `pubspec.yaml` 读取，经 `/DMyAppVersion` 传入。

```powershell
$ver = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
$rel = (Resolve-Path build\windows\x64\runner\Release).Path
iscc /DMyAppVersion=$ver "/DReleaseDir=$rel" scripts/windows_installer.iss
```

## 四、发布到 GitHub Releases

```bash
# 安装器与 APK 上传到同一版本 tag；0.7.0 < 1.0.0 → Pre-Release
gh release upload v<版本号> --repo IFFCheckPass/STDeel stdeel-setup-<版本号>.exe
```

## 五、累计记录

### v0.7.0（✅ 已成功构建并发布 Windows 安装器）
- **版本**：`pubspec.yaml version: 0.7.0+17`（与 Android 版一致）。
- **功能**：Windows 桌面版适配（通知/更新/选图/竖屏平台处理）+ GitHub Actions 构建链 + Inno Setup 安装器。
- **工具链**：GitHub Actions `windows-latest`（自带 VS2022/MSVC）、Flutter 3.47.1 stable（`subosito/flutter-action`）、Inno Setup 6.7.1（choco）。
- **构建**：首次 `flutter build windows --release` 约 115-151s（含插件原生编译）。产物 `build\windows\x64\runner\Release\`（stdeel.exe + dartjni.dll + flutter_windows.dll + data/ + flutter_assets/）。
- **安装器**：`stdeel-setup-0.7.0.exe`，15.4MB（lzma2 压缩）。
- **踩坑记录**：
  1. `.iss` 用相对路径 `..\..\build\windows\x64\runner\Release\*` → Inno Setup 报 "No files found matching ... scripts\..\..\build\..."（相对 .iss 目录解析混乱）。**修复：绝对路径 `/DReleaseDir=` 传入**。
  2. `[Languages]` 引用 `ChineseSimplified.isl` → choco 安装的 Inno Setup 无该文件，编译失败。**修复：仅保留默认英文**。
  3. `workflow_dispatch` 触发被 token 权限拒绝（HTTP 403），但 **push 到分支会自动触发**，无需手动 dispatch。
- **发布**：`gh release upload v0.7.0 stdeel-setup-0.7.0.exe`（与 `app-0.7.0.apk` 同一 Pre-Release）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.0
- **收尾**：Windows 产物上传后删除本地下载副本（`win_artifact/`），保持工作区干净。

### v0.7.1（✅ 已成功构建并发布 Windows 安装器）
- **版本**：`pubspec.yaml version: 0.7.1+18`（与 Android 版一致）。
- **本次功能**：
  1. 窗口标题 `windows/runner/main.cpp`：`window.Create(L"stdeel", ...)` → `L"\u601D\u8C16"`（思谛，用 Unicode 转义避免源码编码问题）。
  2. 应用图标：用安卓端 `assets/icon/app_icon.png`（1024×1024）经 Python PIL 重新生成多尺寸 `windows/runner/resources/app_icon.ico`（16/24/32/48/64/128/256），替换 Flutter 默认图标；Runner.rc 引用路径不变。
  3. 字体：内置 HarmonyOS Sans SC Medium 于 `assets/fonts/`，`pubspec.yaml` 注册 + 主题 `fontFamily`，Windows 端 Flutter 同样从 assets 加载，与安卓一致。
- **构建**：push 到 `feature/windows-support` 自动触发 `build-windows` workflow，约 **4m59s** 成功（Flutter 3.47.1 windows-latest）。
- **安装器**：`stdeel-setup-0.7.1.exe`，20.4MB（含字体 assets，比 0.7.0 的 15.4MB 大）。
- **下载产物**（artifact → 本地 → 上传 Release）：
  - `gh run download <run-id> -n stdeel-windows-installer -D <dir>`（代理环境下可能很慢）；
  - 备选（更快）：`gh api repos/.../actions/artifacts/<id>/zip` 配合 `curl -L -H "Authorization: Bearer $(gh auth token)"` 直接下载 zip。
- **发布**：`gh release upload v0.7.1 stdeel-setup-0.7.1.exe`（与 `app-0.7.1.apk` 同一 Pre-Release；0.7.1 < 1.0.0 → Pre-Release）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.1
- **收尾**：删除本地下载副本，保持工作区干净。

### v0.7.2（✅ 已成功构建并发布 Windows 安装器）
- **版本**：`pubspec.yaml version: 0.7.2+19`（与 Android 版一致）。
- **本次功能**：
  1. **大屏侧边导航**（`home_screen.dart`）：窗口宽度 ≥720dp 时底部 `NavigationBar` 改为左侧 `NavigationRail`（默认窗口 1280×720 即触发），与平板 APK 同一代码。
  2. **应用内更新下载修复**（`settings_screen.dart` + `update_service.dart`）：下载与进度对话框并行启动（旧逻辑下载从未开始，恒 0%）；下载客户端独立化（浏览器 UA）+ 短超时重试，Windows 端 `.exe` 安装器下载更稳。
- **构建**：push 到 `feature/windows-support` 自动触发 `build-windows` workflow（run 34682802415），约 **5m** 成功。
- **安装器**：`stdeel-setup-0.7.2.exe`，20.4MB。
- **发布**：`gh release upload v0.7.2 stdeel-setup-0.7.2.exe`（与 `app-0.7.2.apk` 同一 Pre-Release）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.2
- **收尾**：删除本地下载副本，保持工作区干净。

### v0.7.3（✅ 已成功构建并发布 Windows 安装器，含用户报告的紧急修正）
- **版本**：`pubspec.yaml version: 0.7.3+20`（与 Android 版一致）。
- **本次功能/修复**：
  1. **窗口标题 Unicode 修正**（`windows/runner/main.cpp`）：`L"\u601D\u8C16"`（误为"思谖"）→ `L"\u601D\u8C1B"`（正确"思谛"）。谛 = U+8C1B，此前写错成 U+8C16（谖）。
  2. **安装器图标**（`scripts/windows_installer.iss`）：新增 `SetupIconFile={#SetupIcon}`，workflow 以绝对路径传入 `windows\runner\resources\app_icon.ico`（与 App 图标一致），替换 Inno Setup 默认图标。App 图标资源本身早已正确（Runner.rc `IDI_APP_ICON` + `win32_window.cpp` LoadIcon）。
  3. **安装器中文化**：新增 `scripts/languages/ChineseSimplified.isl`（Inno Setup 官方仓库 `Files/Languages/ChineseSimplified.isl`，417 行，6.5.0+）；`[Languages]` 从 `compiler:Default.isl`（英文）改为 `chinesesimplified`（绝对路径传入）。注意 choco 版 Inno Setup 不随包提供中文 isl，故随仓库维护。
  4. **同步补发四色状态**（`lib/services/sync_service.dart` + `solve_record_dao.dart`，双端共享）：上行补发 `action_type`（solve/retry/detail/correct/wrong），疑问(detail)/重答(retry) 状态此前丢失；下行兼容 `action_type`/`status`/`user_feedback` 回写。
- **构建**：push 到 `feature/windows-support`（commit `0ccf7a6`）自动触发 `build-windows` workflow（run 34685069774），约 **4m26s** 成功；iscc 编译 10.8s，`Parsing [Languages] section` 中文段解析通过。
- **安装器**：`stdeel-setup-0.7.3.exe`，20.6MB。
- **发布**：`gh release upload v0.7.3 stdeel-setup-0.7.3.exe --clobber`（与 `app-0.7.3.apk` 同一 Pre-Release）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.3
- **收尾**：删除本地下载副本，保持工作区干净。

### v0.7.4（✅ 已成功构建并发布 Windows 安装器）
- **版本**：`pubspec.yaml version: 0.7.4+21`（与 Android 版一致）。
- **本次功能/修复**（commit `840b53d`，由 main 同步）：
  1. **图标圆角统一 20%**：`flutter_launcher_icons` 重新生成 Android 各 mipmap 图标，与 Windows 端一致。
  2. 5 处 bug 修复（同步/答案库/异步 context/错误解析）。
- **构建**：push 到 `feature/windows-support` 自动触发 `build-windows`（run 34705638699），约 **4m49s** 成功。
- **安装器**：`stdeel-setup-0.7.4.exe`，与 `app-0.7.4.apk` 同一 Pre-Release。
- **发布**：`gh release upload v0.7.4 stdeel-setup-0.7.4.exe --clobber`。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.4
- **收尾**：删除本地下载副本，保持工作区干净。

### v0.7.5（✅ 已成功构建并发布 Windows 安装器，含自动发布流程）
- **版本**：`pubspec.yaml version: 0.7.5+22`（与 Android 版一致）。
- **本次修复**（merge `main` → `feature/windows-support`，commit `316cbce`）：
  1. **[t0] 后台/锁屏时 AI 流被切断（unknown）**：新增 `lib/services/solve_wakelock.dart`（引用计数唤醒锁，`wakelock_plus`），`failover_manager.dart` 解题期间持有唤醒锁，防止 Doze/App Standby 挂起网络。
  2. **[t0] 同模型自动重连**：`ai_service.dart` 重构 `_runStream`，网络被系统挂起导致流中断且未输出内容时自动重连一次。
  3. **[unknown 日志细化]**：`_dioErrorText` default 分支记录异常类型/底层 error/请求 URL/堆栈到 FaultLogService（debug log）。
- **CI 变更**：workflow 新增「发布安装器到 GitHub Release」步骤（`gh release upload --clobber`），push 构建成功后自动上传到同版本 tag，不再依赖人工下载 artifact 再上传。
- **构建**：push `4c0a5e0`（CI 变更）触发 `build-windows`（run 34862062201），约 **5m** 成功，安装器已自动发布到 v0.7.5。
- **安装器**：`stdeel-setup-0.7.5.exe`，与 `app-0.7.5.apk` 同一 Pre-Release（0.7.5 < 1.0.0 → Pre-Release）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.5
- **收尾**：本次无需本地下载副本（Actions 直接发布）。
