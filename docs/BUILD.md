# BUILD.md — 思谛 STDeel 编译 / 打包 / 发布记录与指南

> 本文件由 AGENTS.md 规则驱动：**每次成功编译后，将一整套环境准备与编译过程
> （工具链/依赖/签名/构建/上传命令）写入本文，以备下次使用**，并随仓库同步 `main`。
> 最新一次成功的构建过程见底部「累计记录」。

## 一、环境准备（首次一次性）

### 1.1 Flutter SDK
- 本仓库 `.metadata` 记录的 Flutter revision：`4cf24164269a5ebf0c16a028a00727d0e77bbb05`（stable）。
- `pubspec.yaml` 要求 `flutter >= 3.35.0`，Dart SDK `>=3.5.0 <4.0.0`。
- 安装（无 Flutter 时）：
  ```bash
  cd /opt
  curl -L -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.1-stable.tar.xz
  tar -xf flutter.tar.xz -C /opt
  export PATH="/opt/flutter/bin:$PATH"
  flutter config --no-analytics
  ```

### 1.2 Android SDK
- `ANDROID_HOME=/opt/android`。
- 安装 cmdline-tools 后用 `sdkmanager` 安装：`platform-tools`、`platforms;android-<compileSdk>`、`build-tools;36.0.0`、所需 NDK。
- 接受许可：`yes | sdkmanager --licenses`。

### 1.3 Java / Gradle
- 本项目要求 JDK 17（`android/gradle.properties` 已固定 `org.gradle.java.home=.../java/17.0.2`）。
- Gradle 8.x（本机 8.14.5）。

### 1.4 网络（受限容器）
- 通过代理 `http://127.0.0.1:18080`（环境变量 `HTTP(S)_PROXY`；`android/gradle.properties` 也配置了 systemProp 代理）。
- 注意：`storage.googleapis.com` 大文件下载可能很慢（受容器限速）；如中断可用 `curl -C -` 续传。

## 二、构建与发布流程

```bash
scripts/build-release.sh              # 一键：环境→签名→构建→上传→回写本文
```

等价手动步骤：
```bash
# 1) 取签名文件（仅构建用，不并入 main）
git checkout feature/signing-config -- android/upload-keystore.jks android/key.properties

# 2) 在 android/app/build.gradle.kts 的 buildTypes.release 临时启用签名并构建
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter build apk --release

# 3) 产物改名为 app-<版本号>.apk 并上传
cp build/app/outputs/flutter-apk/app-release.apk app-<版本号>.apk
# 版本 >=1.0.0 且为 a.b.0 → Release；否则 Pre-Release
gh release create v<版本号> [--prerelease] --repo IFFCheckPass/STDeel-Android app-<版本号>.apk

# 4) 清理签名文件并恢复 build.gradle.kts，保持 main 干净
rm -f android/upload-keystore.jks android/key.properties
```

## 三、累计记录

### v0.5.1（✅ 已成功编译并发布）
- **工具链（本沙箱 / Linux x64）**：
  - Flutter **3.47.1**（stable，revision `6655482ec0`）/ Dart **3.13.1**
  - Gradle **9.3.1**（本仓库 wrapper 指定；AGP 9.1.0 需 Gradle 9）
  - AGP **9.1.0**、Kotlin **2.4.0**（`android/settings.gradle.kts` 内已固定）
  - JDK **17**（`android/gradle.properties` 固定 `org.gradle.java.home=.../java/17.0.2`）
  - Android SDK：compileSdk=36、minSdk=24、targetSdk=36、build-tools 36.0.0、**NDK 28.2.13676358**（Flutter 3.47 默认，来自 flutter_tools `gradle_utils.dart`）
- **关键：出国源极慢（~70-150KB/s），务必用国内镜像**：
  - Flutter SDK / 引擎产物：`FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter`
  - pub 依赖：`PUB_HOSTED_URL=https://pub.flutter-io.cn`
  - Android SDK 压缩包（dl.google.com）替换为：`https://mirrors.cloud.tencent.com/AndroidSDK/<archive>`
  - Gradle 发行包：`https://mirrors.cloud.tencent.com/gradle/gradle-9.3.1-bin.zip`
  - Maven 依赖：项目 `android/settings.gradle.kts` 已用阿里云 `maven.aliyun.com/repository/{google,central,gradle-plugin}`
- **Android SDK 安装关键点**：
  - `platform-tools`、`platforms;android-36`、`build-tools;36.0.0`、`ndk;28.2.13676358` 从 Tencent 直下 zip 解压到对应目录（不要去用 sdkmanager，它走 dl.google 慢）。
  - 版本与 zip 文件名映射见 Google `repository2-3.xml`（Tencent 也镜像该 xml）。
  - 用 `yes | sdkmanager --licenses` 接受许可。
- **耗时**：源码已就绪（任务1~5、6 已修），仅补编译；`flutter build apk --release` Gradle 阶段约 **756s**（首次含 AGP/Kotlin/原生 sqlite 编译）。产物 **app-release.apk 67.7MB**。
- **签名**：从 `feature/signing-config` 分支仅取 `upload-keystore.jks` + `key.properties` 到工作区（不并入 main），临时在 `app/build.gradle.kts` 启用 release 签名；构建后恢复、删除密钥文件。校验 SHA-256 `ed7379e8...`。
- **发布**：`gh release create v0.5.1 --prerelease`（0.5.1 < 1.0.0 → Pre-Release），产物 `app-0.5.1.apk`。
  - 链接：https://github.com/IFFCheckPass/STDeel-Android/releases/tag/v0.5.1

### v0.5.1 re-build（✅ 增量重打包——单纯补打 de8e087 两处编译修复）
- 场景：`v0.5.1` 首次发布后，`main` 又新增 `de8e087`（修复知识点分学科两处编译错误 + 补文档）。本次**在不改版本号**的前提下基于当前 `main` 重新打包，`gh release upload v0.5.1 --clobber` 覆盖发布产物。
- 签名切换：在 `android/app/build.gradle.kts` 增加 `signingConfigs.release`（读 `android/key.properties`），`buildTypes.release.signingConfig` 改为按 `project.hasProperty("signingEnabled")` 选择；构建命令加 `-PsigningEnabled` 启用。**必须**在文件顶部 `import java.util.Properties`，否则 Kotlin 脚本 `Unresolved reference 'Properties'`。
- 构建：`flutter build apk --release -PsigningEnabled`，Gradle 阶段 **47.8s**（增量热缓存，非首次 756s）。产物 67.7MB。
- 校验：`apksigner verify --print-certs` → SHA-256 `ed7379e8...`（与首发一致）。`gh release upload v0.5.1 app-0.5.1.apk --clobber`。
- 收尾：`git checkout -- android/app/build.gradle.kts` 还原，删除 `android/upload-keystore.jks`、`android/key.properties`、`app-0.5.1.apk`，保持 `main` 干净。

### v0.5.5（✅ 已成功编译并发布）
- 版本：`pubspec.yaml version: 0.5.5+11`；`settings_screen.dart` 底部文案 `v0.5.5`。
- **关键新增依赖**：`file_picker ^8.0.0`（选 PDF/Word）、`pdfx ^2.11.0`（PDF 渲染为图片、docx 解压提取文本）、`archive ^3.6.0`。
- **⚠️ compileSdk 36 强制覆盖（本次新增的重要坑）**：
  - 报错：`:file_picker:checkReleaseAarMetadata` — `flutter_plugin_android_lifecycle` 要求依赖方 compileSdk>=36，而 `file_picker` 固定 `compileSdk 34`。
  - 直接用根 `android/build.gradle.kts` 的 `subprojects { afterEvaluate { ... compileSdk = 36 } }` 会抛 `Cannot run Project.afterEvaluate when the project is already evaluated`（Flutter Gradle 插件重入求值导致），且载入时 `plugins.withId` 的扩展配置会被插件自带 `android { compileSdk = 34 }` 覆盖。
  - **有效方案**：直接改 pub-cache 里插件源码：
    ```bash
    sed -i 's/compileSdk 34/compileSdk 36/' /root/.pub-cache/hosted/pub.flutter-io.cn/file_picker-8.3.7/android/build.gradle
    ```
    本次仅 `file_picker` 依赖 lifecycle 报了错；`flutter_local_notifications/pdfx/jni*` 虽也固定更低 SDK 但无该依赖，无需改。
- **构建**：`flutter build apk --release -PsigningEnabled`，Gradle 阶段 **115.7s**（增量）。产物 **app-release.apk 68.0MB**。
- **签名**：与 v0.5.1 相同证书，SHA-256 `ed7379e83486704322dba43361dde16c307fe64f8fdabdc7e437f70eb457f933`（`apksigner verify --print-certs`）。产物改名 `app-0.5.5.apk`。
- **代码同步**：先 `git push` 源码到 `main`（commit `8ff2471`），再 `gh release create v0.5.5 --prerelease app-0.5.5.apk`（0.5.5 < 1.0.0 → Pre-Release）。
  - 链接：https://github.com/IFFCheckPass/STDeel-Android/releases/tag/v0.5.5
- 收尾：删除 `android/upload-keystore.jks`、`android/key.properties`、`app-0.5.5.apk`，保持 `main` 干净。

### v0.6.0（✅ 已成功编译并发布）
- 版本：`pubspec.yaml version: 0.6.0+12`；`settings_screen.dart` 底部文案 `v0.6.0`。
- **功能**：对齐后端 `PUT /users/api-key` 批量契约（发送 `{user_id, api_keys:[{api_key,name,enabled}]}`，全量覆盖该用户所有 key）。
- **环境笔记（本沙箱重置后）**：
  - 工具链目录：`/opt/flutter`（3.47.1 stable）、`/opt/android`（compileSdk 36、build-tools 36.0.0、NDK 28.2.13676358）。JDK 17 位于 `/root/.local/share/mise/installs/java/17.0.2`。
  - 构建前必须显式设置环境变量（否则命中 mise shim 的 JDK25）：`export ANDROID_HOME=/opt/android; export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java17 2>/dev/null))))`，并用 miseshims 之外的 JDK17 `java`。本环境用：`export PATH=/opt/flutter/bin:/root/.local/share/mise/installs/java/17.0.2/bin:$PATH`，再 `unset _MISE_SESSION`。
- **⚠️ Gradle daemon 锁（新坑）**：
  - 报错：`Timeout waiting to lock journal cache (/root/.gradle/caches/journal-1). Owner PID <残留>`。
  - 原因：上次构建留下的残留 Gradle/Java 进程（旧 PID）未退出，占用 journal 锁。构建命令 `flutter build apk --release -PsigningEnabled` 使用 `| tail` 时会先启动 daemon，若上轮进程未清，daemon 间会互锁。
  - 处理：`ps aux | grep -iE 'gradle|GradleDaemon'` 找到残留 PID，`kill -9 <pid>` 全部清掉；Gradle daemon 对锁超时约 1 分钟后报错。清理后重建即可。
- **⚠️ 旧 KGP 插件与 Gradle 9.3.1 不兼容（本次新增的重要坑）**：
  - 报错：`:app:compileReleaseJavaWithJavac` — `GeneratedPluginRegistrant.java:49 cannot find symbol class PackageInfoPlugin`。
  - 原因：App 用 AGP 9.1.0/ Kotlin 2.4.0/ Gradle 9.3.1（Flutter 3.47 模板）；而插件 `package_info_plus` 8.3.1 内置 `kotlin-gradle-plugin:1.7.22` + AGP 8.3.1，KGP 1.7.22 在 Gradle 9 下编译 Kotlin 不产出 class（其 AAR 存在但 `classes=0`），导致 registrant 引用的类缺失。同批 `pdfx` 用 KGP 1.9.23 可正常编译。
  - 修复：把 pub-cache 插件 build.gradle 的 Kotlin/AGP 提到与 pdfx 一致（已验证能在 Gradle 9 下编译）：
    ```bash
    sed -i "s/kotlin_version = '1.7.22'/kotlin_version = '1.9.23'/" $P/package_info_plus-8.3.1/android/build.gradle
    sed -i "s#com.android.tools.build:gradle:8.3.1#com.android.tools.build:gradle:8.5.2#" $P/package_info_plus-8.3.1/android/build.gradle
    ```
    本环境 pub-cache 在 `/root/.pub-cache/hosted/pub.dev/`（以 `.dart_tool/package_config.json` 的 rootUri 为准）。
  - file_picker 的 compileSdk：本次路径是 `pub.dev` 副本（v0.5.5 记的是 `pub.flutter-io.cn`），同样 `sed -i 's/compileSdk 34/compileSdk 36/' .../file_picker-8.3.7/android/build.gradle`。
- **构建**：`flutter build apk --release -PsigningEnabled`，增量 Gradle 阶段约 **68s**（前两次因锁/KGP/file_picker 先后失败，清理更正后续传成功）。产物 **app-release.apk 68.3MB**。
- **签名**：从 `feature/signing-config` 取 `upload-keystore.jks`+`key.properties`（不并入 main）；`apksigner verify --print-certs` SHA-256 `ed7379e8...`（与历史一致）。产物改名 `app-0.6.0.apk`。
- **发布**：先 `git push` 到 `main`（commit `1e16c5b`），再 `gh release create v0.6.0 --prerelease app-0.6.0.apk`（0.6.0 < 1.0.0 → Pre-Release）。
  - 链接：https://github.com/IFFCheckPass/STDeel-Android/releases/tag/v0.6.0
- 收尾：删除 `android/upload-keystore.jks`、`android/key.properties`、`/tmp/app-0.6.0.apk`，保持 `main` 干净。

### v0.6.1（✅ 已成功编译并发布）
- 版本：`pubspec.yaml version: 0.6.1+13`；`settings_screen.dart` 底部文案 `v0.6.1`。
- **功能**：解题（`AiService.callModelStream`→`_runStream`）请求体**不再发送 `temperature`**，且不固定 `top_p`/`n`/`presence_penalty`，全部由 AI API 端默认决定。删除未用的 `AiConfig.retryTemperature`。`generateRaw`（文档拆分，非解题）与 `testConnection`（连通性 ping）保持各自固定参数不变。
  - 改动点：`lib/services/ai_service.dart`（删 temperature 参数+字段）、`lib/config/ai_config.dart`（删 retryTemperature）。
- **环境重建成套记录（本沙箱 /opt 被清空后的完整恢复）**：
  - Flutter 3.47.1：腾讯云镜像下载 `https://mirrors.cloud.tencent.com/flutter/.../flutter_linux_3.47.1-stable.tar.xz`（约 1.5GB，比 storage.googleapis.com 快非常多），解压到 `/opt/flutter`，并 `git config --global --add safe.directory /opt/flutter` 消除 dubious ownership 报错。
  - Android SDK：从 `https://mirrors.cloud.tencent.com/AndroidSDK/` 下载 platform-36、build-tools、platform-tools、NDK r28c、cmake 各 zip 解压到 `/opt/android/{platforms,build-tools,platform-tools,ndk,cmake}`。注意 build-tools zip 内层多一层 `android-16/`、NDK zip 内层 `android-ndk-r28c/`。
  - 依赖：`export FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter; export PUB_HOSTED_URL=https://pub.flutter-io.cn`；本项目本次 pub-cache 落在 `/root/.pub-cache/hosted/pub.flutter-io.cn/`。
- **⚠️ compileSdk 统一到 36（本沙箱重建后一次到位）**：
  - 腾讯镜像没有基础 `platforms;android-34`（只有 ext 包，不含 android.jar），所以不能靠安装 34/35，而是把插件 compileSdk 统一抬到 36。受影响插件：`flutter_local_notifications`(34)、`package_info_plus`(34)、`pdfx`(35)、`sqlite3_flutter_libs`(35)、`jni`(1.0.0 & 1.0.3, 35)、`jni_flutter`(1.0.1 & 1.0.3, 35)、`file_picker`(34)。均在各自 `android/build.gradle` 用 `sed` 改到 36。
  - KGP 补丁同 v0.6.0（package_info_plus 1.7.22→1.9.23、AGP 8.3.1→8.5.2，否则类不产出）。
  - **License hash 必需正确**：`/opt/android/licenses/android-sdk-license` 必须写标准 hash（`24333f8a...` + `850de8a1`，每行一个），否则 Gradle 报 `License for package not accepted` 并尝试联网装缺失 platform。
- **⚠️ 打包 OOM（新/复发）**：`gradle.properties` 的 `-Xmx1280m` 在整链编译时堆不足，产生 `java_pid*.hprof`。改为 `-Xmx2048m -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=128m`（仍保留 `-XX:-UseContainerSupport` 规避 JDK17 cgroup NPE）后成功。报错前先 `rm -f android/java_pid*.hprof`。
- **构建**：`flutter build apk --release -PsigningEnabled`，Gradle 阶段 **120.8s**（含原生编译缓存重建）。产物 **app-release.apk 68.3MB**。
- **签名**：`apksigner verify --print-certs` → STDeel，SHA-256 `ed7379e8...`（与历史一致）。产物改名 `app-0.6.1.apk`。
- **发布**：先 `git push` 到 `main`（commit `3933a67`），再 `gh release create v0.6.1 --prerelease app-0.6.1.apk`（0.6.1 < 1.0.0 → Pre-Release）。
  - 链接：https://github.com/IFFCheckPass/STDeel-Android/releases/tag/v0.6.1
- 收尾：删除 `/tmp/app-0.6.1.apk`，保持 `main` 干净。

### v0.6.2（✅ 已成功编译并发布）
- 版本：`pubspec.yaml version: 0.6.2+14`；`settings_screen.dart` 底部文案 `v0.6.2`。
- **功能**：
  1. **故障码记录**（新文件 `lib/services/fault_log_service.dart`）：AI 调用 / GitHub 更新 / 更新下载等故障时自动记录「来源、时间、HTTP 状态码、中文概要」，SharedPreferences 持久化（上限 50 条），`ChangeNotifier` 供 UI 刷新。
  2. 设置页新增「故障码记录」玻璃卡片：查看最近 8 条、一键复制全部、清空记录（`_FaultLogTile` / `_copyFaultLogs` / `_clearFaultLogs`）。
  3. 故障码提示统一为中文：`ai_service.dart` 新增 `_zhHttpMessage`、`update_service.dart` 新增 `_zhGithubMessage` / `_zhDownloadMessage`，屏蔽英文原返回。
  4. **修复 GitHub 更新 403/404**：改用 `/releases` 列表接口（替代 `/releases/latest`，后者对"仅有 pre-release"的仓库返回 404）+ 显式 `User-Agent`（修复 403/限流）。
  5. `app.dart` 注入 `Provider<FaultLogService>`。
- **⚠️ 网络受限容器（本沙箱）关键修复：`dl.google.com` TLS 握手失败不可达**：
  - 项目原 `android/settings.gradle.kts`、`android/build.gradle.kts` 的 `google()`/`mavenCentral()` 回退会去连 dl.google.com → 报 `Could not get resource 'https://dl.google.com/...gradle-8.5.2.pom' ... Remote host terminated the handshake`。
  - 处理：根 `settings.gradle.kts`/`build.gradle.kts` **删除 `google()` 与 `mavenCentral()` 回退**，仅保留 `maven.aliyun.com/repository/{google,central,gradle-plugin}` + `gradlePluginPortal()`；并对 pub-cache 里 10 个插件的 `android/build.gradle` 用 `sed` 把 `google()`→`maven { url 'https://maven.aliyun.com/repository/google' }`、`mavenCentral()`→`.../central`（涉及 file_picker、flutter_local_notifications、google_mobile_ads、jni、jni_flutter、package_info_plus、pdfx、sqlite3_flutter_libs）。
- **环境重建（/opt 又被清空**，与 v0.6.1 相同）：Flutter 3.47.1（腾讯镜像 `/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.1-stable.tar.xz`，约 1.5GB）装到 `/opt/flutter`，需 `git config --global --add safe.directory /opt/flutter`；Android SDK 各组件 zip 从 `https://mirrors.cloud.tencent.com/AndroidSDK/` 下载并解压到 `/opt/android`（platform-36_r02.zip→platforms/android-36、build-tools_r36_linux.zip→build-tools/36.0.0、platform-tools 注意 zip 内层多套一层需拍平、NDK r28c→ndk/28.2.13676358、cmake-3.22.1 内层为扁平需要放进版本目录）。license 文件写标准 hash；JDK17 在 `/root/.local/share/mise/installs/java/17.0.2`。
- **构建**：`flutter build apk --release -PsigningEnabled`，首跑 Gradle 下载依赖约 3m20s（网络错误后被镜像修复），再跑因修复 Dart 类型错误重跑约 **466.8s**。产物 **app-release.apk 68.4MB**。
- **⚠️ Dart 编译错误（本次新增）**：`update_service.dart` 拉取 `/releases` 列表时 `it` 是 `Map<dynamic,dynamic>`，赋给 `Map<String,dynamic>? chosen` 报类型错；改为 `chosen = Map<String, dynamic>.from(it)` 修复。
- **签名**：`apksigner verify --print-certs` → STDeel，SHA-256 `ed7379e8...`（与历史一致）。产物改名 `app-0.6.2.apk`。
- **发布**：先 `git push` 到 `main`（commit `7b49239`），再 `gh release create v0.6.2 --prerelease ... /tmp/app-0.6.2.apk`（0.6.2 < 1.0.0 → Pre-Release）。产物 SHA-256 `c43e59ae...`。
  - 链接：https://github.com/IFFCheckPass/STDeel-Android/releases/tag/v0.6.2
- 收尾：删除 `android/upload-keystore.jks`、`android/key.properties`、`/tmp/app-0.6.2.apk`，保持 `main` 干净。

### v0.7.0（✅ 已成功编译并发布）
- 版本：`pubspec.yaml version: 0.7.0+17`；`settings_screen.dart` 底部文案与更新卡片均 `v0.7.0`。
- **功能**：
  1. **答案库"卷次+题号"认领**（schema v7：新增 `answer_papers` 表，`answer_library` 加 `paper_id`/`question_no`，无题干条目 question_text/hash 允许为空）——解决教辅/往年卷子答案只有题号无题干的匹配问题；导入答案册时弹窗命名卷次，按"卷次+题号"入库。
  2. **解题流程优化**（`solve_provider.dart`）：轻量拆题 → 卷次识别/逐题匹配 → 未命中才调用 AI 解题，减少 token 消耗。
  3. **数据同步修复**（B1-B4）：上传解析后端 id 写回 `remoteId`（`backend_api.uploadSolveRecord`/`solve_record_dao.setRemoteId`）、反馈与删除改用 `remoteId`、下拉同步反馈缺省值处理。
  4. **重答不再整图重发**：`_solveText` 新增 `attachImage` 参数，`retry` 传 `attachImage:false`。
  5. **知识点雷达图聚合 + AI 整理**（`knowledge_screen.dart`）。
  6. **当次解题题号 vs 内部序号**：`solve_result.dart` 新增 `sessionNo`。
  7. **故障码 429 带模型组合信息**（`ai_service.dart`/`failover_manager.dart`）。
- **环境/构建备注（本沙箱）**：
  - 本次 `/opt/android` 仅有 platforms 35/36，Gradle 自动在线安装 platform-34（revision 3）完成编译。
  - **⚠️ file_picker compileSdk 34 不匹配**：报 `:file_picker:checkReleaseAarMetadata — flutter_plugin_android_lifecycle 要求依赖方 compileSdk>=36`。根 build.gradle.kts 的 `subprojects` 强制方案无效（`Cannot run afterEvaluate when already evaluated` / 插件自带 `compileSdk 34` 会覆盖），**有效方案仍是直接改 pub-cache 插件源码**：
    ```bash
    sed -i 's/compileSdk 34/compileSdk 36/' /root/.pub-cache/hosted/pub.dev/file_picker-8.3.7/android/build.gradle
    ```
- **构建**：`flutter build apk --release -PsigningEnabled`，两次失败（file_picker compileSdk）后第三次 Gradle 阶段约 **197.6s** 成功。产物 **app-release.apk 68.6MB**。
- **签名**：`feature/signing-config` 取 `upload-keystore.jks`+`key.properties`（不并入 main）。产物改名 `app-0.7.0.apk`，SHA-256 `9e3c4eed6a281e7f80a2cfa2069424bace0ee4f35377e3164b70f19cdec4b9ad`。
- **发布**：`gh release create v0.7.0 --prerelease ... app-0.7.0.apk`（0.7.0 < 1.0.0 → Pre-Release）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.0
- 收尾：删除 `android/upload-keystore.jks`、`android/key.properties`、`app-0.7.0.apk`，保持 `main` 干净。

### v0.7.1（✅ 已成功编译并发布，小版本更新：0.7.0 → c 位 +1）
- **版本**：`pubspec.yaml version: 0.7.1+18`；`settings_screen.dart` 底部文案与更新卡片均 `v0.7.1`。
- **本次功能**：
  1. 内置字体 `assets/fonts/HarmonyOS_Sans_SC_Medium.ttf`（HarmonyOS Sans SC Medium，开源免费商用），`pubspec.yaml` 注册 + `glass.dart` 主题 `fontFamily`，安卓 / Windows 双端统一（桌面端 Flutter 同样从 assets 加载字体）。
  2. Windows 窗口标题 `windows/runner/main.cpp` 改 `\u601D\u8C16`（思谛）；应用图标用安卓端 `assets/icon/app_icon.png` 重新生成多尺寸 `app_icon.ico`（PIL，16~256px）。
  3. 更新语义清理：`update_service.dart`/`settings_screen.dart`/`MainActivity.kt` 的 apk 字段与方法统一为 `pkg`/`installPackage`（MethodChannel 方法名同步改 `installPackage`，双端必须一致）。
- **环境/构建备注（本沙箱 /opt 全新，SDK 重建）**：
  - Flutter 3.47.1 位于 `/opt/flutter`（已存在）；Android SDK 需自装：cmdline-tools + `platforms;android-36` + `build-tools;36.0.0` + `platform-tools`，Gradle 会按需自动安装 platform-34/35 与 NDK 28.2.13676358、CMake（license 需预先 `yes | sdkmanager --licenses`）。
  - `ANDROID_HOME=/opt/android-sdk`；`android/gradle.properties` 已配 JDK17（`org.gradle.java.home`）与受限容器参数（daemon=false、workers.max=1、kotlin in-process）。
  - **⚠️ 首次构建 Gradle daemon 被杀（OOM）**：容器仅 ~6G 内存无 swap，首跑下载依赖 + 自动装 SDK 平台时 daemon 消失（`Gradle build daemon disappeared`）。处理：`pkill -9 -f GradleDaemon` 清残留，二次构建（依赖已缓存）即成功。
  - **⚠️ file_picker compileSdk 34 不匹配**（老坑复现）：报 `:file_picker:checkReleaseAarMetadata — flutter_plugin_android_lifecycle 要求依赖方 compileSdk>=36`。修复同前：直接改 pub-cache 插件源码（两处都改，pub.dev 与 pub.flutter-io.cn 副本）：
    ```bash
    sed -i 's/compileSdk 34/compileSdk 36/' /root/.pub-cache/hosted/pub.dev/file_picker-8.3.7/android/build.gradle
    sed -i 's/compileSdk 34/compileSdk 36/' /root/.pub-cache/hosted/pub.flutter-io.cn/file_picker-8.3.7/android/build.gradle
    ```
- **构建**：`flutter build apk --release -PsigningEnabled`，前两次失败（OOM / file_picker）后第三次 Gradle 阶段约 **209.6s**。产物 **app-release.apk 74.2MB**（内置字体 +8MB）。
- **签名**：`feature/signing-config`（`git fetch origin feature/signing-config` + `git checkout FETCH_HEAD -- android/upload-keystore.jks android/key.properties`，不并入 main）。`apksigner verify --print-certs` → CN=STDeel（与历史一致）。
- **发布**：先 `git push` 源码到 `main`，再 `gh release create v0.7.1 --prerelease` 并上传 `app-0.7.1.apk` 与 Windows 安装器 `stdeel-setup-0.7.1.exe`（0.7.1 < 1.0.0 → Pre-Release，双端同一 tag）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.1
- 收尾：删除 `android/upload-keystore.jks`、`android/key.properties`、`/tmp/app-0.7.1.apk`，保持 `main` 干净（旧提交 b943b3d 曾误提交过 jks/key.properties，本次随 docs 提交一并从 main 树删除）。

### v0.7.2（✅ 已成功编译并发布，小版本更新：0.7.1 → c 位 +1）
- **版本**：`pubspec.yaml version: 0.7.2+19`；`settings_screen.dart` 底部文案 `v0.7.2`。
- **本次修复/功能**：
  1. **应用内更新"下载永远卡在 0%"（核心 bug）**：`settings_screen.dart` 的 `_startUpdate` 旧实现先 `await showDialog`（进度对话框只有"取消"能关闭）再执行下载 → **下载代码永远不执行**，进度恒为 0%。重构为：打开对话框的瞬间即后台启动下载（进度实时回填），完成/失败后对话框自动关闭，取消用 `CancelToken` 真正中止。
  2. **下载链路加固**（`update_service.dart`）：下载改用独立客户端（浏览器 UA、`Accept: */*`、无 GitHub API 专属头）、连接超时 10s + `receiveTimeout` 2min + 最多 3 次重试；GitHub 发布资产 302 到 CDN（release-assets.githubusercontent.com）直连偶发挂起，重试显著提升成功率（沙箱实测：三套下载策略经可达网络均 2-3s 下完 74MB）。
  3. **大屏侧边导航**（`home_screen.dart`）：宽度 ≥720dp（平板 / Windows 窗口）时底部 `NavigationBar` 改为左侧 `NavigationRail`（含 Logo leading），小屏保持底部导航；APK 与 EXE 同一代码生效。
- **构建**：`flutter build apk --release -PsigningEnabled`，Gradle 阶段约 **144.6s**（增量热缓存）。产物 **app-release.apk 74.3MB**。
- **签名**：`feature/signing-config` 取 jks/key.properties（不并入 main）；`apksigner verify --print-certs` → CN=STDeel，SHA-256 `ed7379e8...`（与历史一致）。产物改名 `app-0.7.2.apk`。
- **发布**：先 `git push` 源码到 `main`（commit `dd58f16`），Windows 分支 push 触发 Actions 构建安装器；`gh release create v0.7.2 --prerelease` 并上传 `app-0.7.2.apk` + `stdeel-setup-0.7.2.exe`（0.7.2 < 1.0.0 → Pre-Release，双端同一 tag）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.2
- 收尾：删除 `android/upload-keystore.jks`、`android/key.properties`、`/tmp/app-0.7.2.apk`，保持 `main` 干净。

### v0.7.3（✅ 已成功编译并发布，小版本更新：0.7.2 → c 位 +1）
- **版本**：`pubspec.yaml version: 0.7.3+20`；`settings_screen.dart` 底部文案 `v0.7.3`。
- **本次修复/功能**（对应 App 端故障码：知识点分类时报 `HTTP 400 temperature only 1 is allow`）：
  1. **知识点 AI 整理 temperature 修复**：`ai_service.dart` 的 `generateRaw` 的 `temperature` 改为可选参数（`double? temperature`，`null` 时不发送该字段，由 API 使用默认值，同解题流式做法）；`knowledge_screen.dart` 的 `_aiOrganize` 调用不再传 temperature，避免部分推理模型只允许 `temperature=1` 时报 400。
  2. **故障码记录增强**（`fault_log_service.dart` / `settings_screen.dart` / `ai_service.dart`）：
     - `FaultLog` 新增 `detail` 字段：保存**原始故障返回信息**（API 英文原文 + 模型组合上下文），`toClipboardText()` 复制时输出「单行概要 + 详细：原始信息」，`toJson/fromJson` 同步持久化。
     - 设置页故障码列表点击单条 → 屏幕中间 `AlertDialog` 弹窗显示原始返回信息（`SelectableText` 可选中），提供「复制本条」（复制完整原始信息）与「关闭」。
     - 故障码来源细化到具体功能界面：`AI 调用 · 解题`、`AI 调用 · 知识点整理`、`AI 调用 · 拆题识别`、`AI 调用 · 答案库文档拆分`、`AI 调用 · 获取模型列表`、`AI 调用 · 连通性测试`。
     - 新增 `_zhApiError`：把 API 返回的常见英文错误翻译成中文概要（temperature 不支持、额度不足、API Key 无效、限流、上下文超长、模型不存在、内容被拦截、服务器内部错误等），原文保留在 detail 中。
  3. **同步解题记录补发四色状态**（`sync_service.dart` / `solve_record_dao.dart`，win 端最先出现、安卓同样受影响）：
     - `flushUnsynced` 上行补发 `action_type`（solve/retry/detail/correct/wrong），此前疑问(detail)/重答(retry) 状态在同步时丢失，只发了 `user_feedback`（none/correct/wrong）。
     - 下行 `pullSolveRecords` 兼容 `action_type`/`status`/`user_feedback` 字段名回写本地（`upsertFromBackend` 新增 `actionType` 参数），保留四色标记与反馈状态。
  4. **Windows 端修复**（仅 `feature/windows-support` 分支，见 `docs/BUILD-win.md`）：窗口标题 Unicode 修正（思谖→思谛）、安装器中文化、安装器图标。
- **构建**：`flutter build apk --release -PsigningEnabled`，Gradle 阶段约 **80.6s**（增量热缓存）。产物 **app-release.apk 74.3MB**。
- **签名**：`feature/signing-config` 取 jks/key.properties（不并入 main）；产物改名 `app-0.7.3.apk`。
- **发布**：先 `git push` 源码到 `main`（commit `9494696`，含同步状态修复；角标同步 `efcf1ac`），Windows 分支 push 触发 Actions 构建安装器；`gh release create v0.7.3 --prerelease` 并覆盖上传 `app-0.7.3.apk`（--clobber）+ `stdeel-setup-0.7.3.exe`（0.7.3 < 1.0.0 → Pre-Release，双端同一 tag）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.3
- 收尾：删除 `android/upload-keystore.jks`、`android/key.properties`、`/tmp/app-0.7.3.apk`，保持 `main` 干净。

### v0.6.3（✅ 已成功编译并发布）
- 版本：用户指定为小版本修复，回退到 `pubspec.yaml version: 0.6.3+17`；`settings_screen.dart` 底部文案与更新卡片均 `v0.6.3`。
- **修复应用内更新"未发现任何已发布版本" bug**（`update_service.dart`）：
  - 根因：`checkForUpdate`→`fetchLatest()` 默认 `includePrerelease:false`，会跳过所有 pre-release；而本项目版本号 < 1.0.0 一律发布为 Pre-Release，故更新检查永远选不中任何版本 → 抛"未找到任何已发布版本"。
  - 修复：`checkForUpdate()` 改为 `fetchLatest(includePrerelease: true)`，命中最新 pre-release。
- **构建**：`flutter build apk --release -PsigningEnabled`，Gradle 阶段约 **142.6s**（增量热缓存）。产物 **app-release.apk 68.4MB**。
- **签名**：`feature/signing-config`（已 fetch 远端分支）取 `upload-keystore.jks`+`key.properties`（不并入 main）。产物改名 `app-0.6.3.apk`，SHA-256 `f101ac9c...`。
- **发布**：先 `git push` 源码到 `main`，再 `gh release create v0.6.3 --prerelease app-0.6.3.apk`（0.6.3 < 1.0.0 → Pre-Release）。
- 收尾：删除 `android/upload-keystore.jks`、`android/key.properties`、`app-0.6.3.apk`，保持 `main` 干净。

### 卷次匹配功能开发（✅ 环境重建 + build_runner 生成通过，未打包 APK）
- **环境重建（本沙箱 /opt 又被清空，仅需 Dart 侧，未装 Android SDK）**：
  - Flutter 3.47.1：**正确镜像 URL**（注意 BUILD.md v0.6.1 记录的路径有误，缺一层 `flutter/`）：
    `https://mirrors.cloud.tencent.com/flutter/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.1-stable.tar.xz`（约 1.5GB）
    备用：`https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.1-stable.tar.xz`。
  - 解压到 `/opt/flutter` 后需 `git config --global --add safe.directory /opt/flutter`。
- **仅 Dart 侧流程**（数据库 schema 改动时必跑）：
  ```bash
  export PATH=/opt/flutter/bin:$PATH
  export PUB_HOSTED_URL=https://pub.flutter-io.cn
  export FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter
  cd /workspace && flutter pub get
  dart run build_runner build --delete-conflicting-outputs   # 生成 database.g.dart / daos/*.g.dart
  flutter analyze    # 0 error / 0 warning
  flutter test       # 全部通过
  ```
  - 注意：Flutter 3.47 下 `--delete-conflicting-outputs` 已被忽略（仅警告，不影响生成）。
- **功能**：答案库支持"卷次+题号"认领（schema v7：新增 `answer_papers` 表，`answer_library` 加 `paper_id`/`question_no`，无题干条目 question_text/hash 允许为空）；解题侧"拆题→答案库匹配→未命中才走 AI"。

### v0.7.4（✅ 已成功编译并发布，小版本更新：0.7.3 → c 位 +1）
- **版本**：`pubspec.yaml version: 0.7.4+21`；`settings_screen.dart` 底部文案 `v0.7.4`。
- **本次功能/修复**：
  1. **应用图标圆角统一**：调研主流软件（微信/QQ/B站/网易云音乐/钉钉/Photoshop/DaVinci Resolve 等）图标圆角实践，确定 **20% 圆弧圆角**（Android 安全值区间、iOS squircle 兼容、主流 App 常见值）。用 PIL 脚本从母版 `assets/icon/app_icon.png` 批量生成：Android 各密度 legacy 图标（mipmap-*）、Windows 多尺寸 `app_icon.ico`（16/24/32/48/64/128/256px，手动构造 ICO 头，避免 PIL 多帧保存只落首帧的坑），四角透明处理。
  2. **数据同步修复**（`sync_service.dart`）：
     - 上传未拿到后端 id 时不再标记已同步（避免反馈/删除功能因本地 id 与后端不一致而失效）。
     - 下拉回写时同步 `action_type` 与 `user_feedback` 双写（`correct/wrong` 判定兼容旧字段），确保错题查询准确。
  3. **答案库命中记录**（`solve_provider.dart`）：插入时直接标记 `synced=true`，避免被误上传到后端。
  4. **异步 context 安全**（`knowledge_screen.dart`）：AI 调用（最长 180s）返回后先 `if (!mounted) return` 再使用 context，修复页面退出后崩溃。
  5. **AI 错误信息提取**（`ai_service.dart`）：兼容 `{error: string}` 与 `{message: string}` 两种错误响应形状，提升故障定位能力。
  6. **file_picker 升级至 10.3.10**（修复 compileSdk 36 构建失败）：
     - 根因：旧版 `file_picker 8.3.7` 写死 `compileSdk 34`，而 `flutter_plugin_android_lifecycle` 新版要求依赖方 compileSdk≥36，`checkReleaseAarMetadata` 校验失败。
     - 历史方案（sed 改 pub-cache 插件源码）本次不再需要：10.3.10 改为 `compileSdk flutter.compileSdkVersion`，跟随 Flutter 默认 36。
- **构建**：`flutter build apk --release -PsigningEnabled`，Gradle 阶段约 **397.4s**（依赖变更后全量重编）。产物 **app-release.apk 74.4MB**。
- **签名**：`feature/signing-config` 分支取 `upload-keystore.jks`+`key.properties`（不并入 main）；`apksigner verify --print-certs` → CN=STDeel，SHA-256 `ed7379e83486704322dba43361dde16c307fe64f8fdabdc7e437f70eb457f933`（与历史一致）。产物改名 `app-0.7.4.apk`。
- **发布**：先 `git push` 源码到 `main`（commit `3f6b003` 图标+bug 修复、`0fc9d9f` file_picker 升级），Windows 分支 Actions 构建安装器 `stdeel-setup-0.7.4.exe`；`gh release create v0.7.4 --prerelease` 并上传 `app-0.7.4.apk` + `stdeel-setup-0.7.4.exe`（0.7.4 < 1.0.0 → Pre-Release，双端同一 tag）。
  - 链接：https://github.com/IFFCheckPass/STDeel/releases/tag/v0.7.4
- 收尾：删除 `android/upload-keystore.jks`、`android/key.properties`、`app-0.7.4.apk`，保持 `main` 干净。