# AGENTS.md — 思谛 STDeel 项目代理指令

> 本文件为持久化记忆文件。所有 AI 编码代理在任何会话/任何模式下都必须遵守以下规则。
> 本文件应随仓库保存并同步到 `main`，作为不可撤销的项目约束。

## 数据完整性强制规则（T0 级，不可协商）

> 背景：v0.9.x 期间出现过"覆盖安装后模型配置/账号绑定丢失、导入报错但实际成功"
> 的 T0 级事故。用户数据（解题记录、知识点、模型 API 配置、账号绑定）是本应用
> 最高优先级资产，任何代码改动都不得以任何形式破坏其完整性。

### 持久化结构稳定性
- **SharedPreferences key、drift 表结构、数据库文件名一经发布即为契约**：
  严禁改名、迁移存储位置、变更序列化格式；确需变更时必须同时提供对全部历史
  格式的读取兼容 + 自动迁移，并写入 `docs/BUILD.md`。
- drift `schemaVersion` 递增时**必须**在 `onUpgrade` 提供完整迁移链，严禁任何
  路径出现 drop/recreate 表。
- `SettingsProvider.load()` 对无法识别的配置 JSON **绝不静默重置为默认模板**：
  必须先尝试 salvage（从任意结构抠出数据），失败则把原文留底
  （`ai_combos_json_corrupt`）后才降级，且仅内存降级、不覆盖原值。
- 任何覆盖写入关键 key（如 `ai_combos_json`）之前**必须**先把旧值留底
  （`ai_combos_json_prev`）。

### 启动强制核查（每次启动必须执行）
- 每次启动必须运行 `DataIntegrityService.run()`（挂在 `SettingsProvider.load()`
  尾部）：① 快照关键数据（模型配置/username/device_id/user_id）到
  `integrity_snapshot_json`（旧快照转 prev）；② 核查 SQLite 各表可读与行数、
  模型配置可解析非空、账号绑定一致性；③ 自愈——username 存在但 user_id 缺失时
  自动按 username 重绑云端账号（找回云端记录归属）。
- 核查结果必须写入 FaultLog 并在设置页「存储与缓存」卡片可见。

### 备份与恢复（用户救命稻草，必须最稳）
- 备份格式 v3 必须包含：解题记录 + 知识点 + **AI 模型 API 配置（含 Key）** +
  **账号绑定用户名**。后续新增任何用户数据（如答案库）必须同步纳入备份。
- 导入原则：**AI 配置恢复最优先**；**逐条容错**（单条失败计入明细，严禁笼统
  抛错让用户看到"导入失败"但实际已写入一半）；**宽容格式**（v1/v2/v3 及缺
  type 标记的已知结构均兼容；不强制文件扩展名；容忍 BOM）。
- 导入后必须自动恢复账号绑定（setUsername + 按 username 重绑 user_id），
  使云端记录随账号自动找回。

### 版本升级数据安全
- 每次发版前必须自测：老版本数据 + 覆盖安装 → 启动核查通过、数据无丢失。
- 涉及持久化的改动，发布说明中必须注明"数据兼容性"结论。

## 强制执行约束（不可协商，无论如何均不得违反）

### 签名分支禁止合并 / 禁止 PR
- 分支 **`feature/signing-config`** 仅用于留存统一签名的必要文件：
  - `android/upload-keystore.jks`（签名证书）
  - `android/key.properties`（密钥口令，含敏感信息）
- **严禁**将该分支合并到 `main` 或任何其他分支，合并命令一律不得执行。
- **严禁**以任何形式对该分支发起、创建或合并 Pull Request / Merge Request，也不得把它作为目标分支或源分支参与任何合并。
- 该分支上的文件带有 `.gitignore` 忽略 + 敏感口令，合并会污染主分支并泄露密钥凭证。
- 无论后续需求如何表述（如"统一签名""解决安装失败""同步签名"），只要涉及把该分支并入主分支或提 PR，一律拒绝并提醒用户此约束。

### Windows 适配分支隔离 / 禁止合并
- 分支 **`feature/windows-support`** 专门用于 Windows 桌面版适配开发：
  - `windows/` 平台工程文件（runner、CMake、资源）、Windows 专属构建脚本（`docs/BUILD-win.md` 所述）、Windows 适配代码。
- **严禁**将该分支合并到 `main` 或任何其他分支，合并命令一律不得执行。
- **严禁**以任何形式对该分支发起、创建或合并 Pull Request / Merge Request，也不得把它作为目标分支或源分支参与任何合并。
- Windows 适配代码如需进入 `main`，只能由用户明确指示后，由用户决定合并方式；代理不得自行执行任何合并。
- 该分支的日常提交可直接 push 到 `feature/windows-support`（不是 `main`）。

## 代码同步与版本发布规则（GitHub）

### 代码同步（自执行，无需用户提醒）
- **每次更改代码后，必须自行将最新代码提交并推送到 `main`**（先 `git push` 该 commit）。
- **每次构建 APK 后，必须自行上传产物到 GitHub** 并按下方版本规则发布。
- 若推送因凭据未配置而失败，应自行执行 `gh auth setup-git` 后再推送。

### 编译环境自愈（自执行，禁止打断用户）
- 遇到编译问题或环境缺失（Flutter / Dart / Android SDK 等）时，**完全自主完成**环境配置、签名统一与打包签名工作：
  - 自行安装 / 定位 Flutter SDK 与 Android SDK，补齐缺失的依赖与平台产物。
  - 签名统一引用 `feature/signing-config` 分支留存的 `upload-keystore.jks` 与 `key.properties`（只用于本地构建，**不得**把密钥文件或该分支并入 `main`，遵守上方签名分支约束）。
- **无需、也不得通知用户请求决策**；直接继续推进编译、签名、打包。
- 打包好的 APK 按前述产物命名规则（`app-<版本号>.apk`）与版本发布规则（Release / Pre-Release 判定）**自主上传到 GitHub Releases**。
- **每次成功编译后，将一整套环境准备与编译过程（工具链安装/依赖/签名/构建/上传命令）写入 `docs/BUILD.md`**，以备下次使用；该文档随仓库提交同步到 `main`。
- Windows 桌面版构建流程单独记录于 **`docs/BUILD-win.md`**（随 Windows 分支维护）；Windows 构建产物命名 `stdeel-setup-<版本号>.exe`，上传到同一版本 tag 的 GitHub Release（Release/Pre-Release 判定与 APK 一致）。
- **双端同步发布（强制，不可协商）**：
  - **每次版本更新发布，必须同时产出 Android APK（`app-<版本号>.apk`）与 Windows 安装器（`stdeel-setup-<版本号>.exe`）双端产物，并上传到同一版本 tag 的 GitHub Release**，不允许只发布单端。
  - 流程：APK 由本仓库 `main` 直接构建发布；exe 由 `build-windows` GitHub Actions 在 `feature/windows-support` 分支（合并最新 `main` 后）自动构建并 `gh release upload v<版本号> --clobber` 上传。
  - 因此**每次改代码发布时，除提交推送 `main` 外，必须将 `main` 合并同步到 `feature/windows-support` 并 push 触发 Windows 构建**，然后确认该版本 tag 下 APK 与 exe 均已就位。

### APK 签名方案强制规则（不可协商）
- **Android APK 签名方案必须固定为「仅 v2」（`enableV1Signing = false; enableV2Signing = true; enableV3Signing = false`）**，与 0.7.4 完全一致，见 `android/app/build.gradle.kts`。
- **严禁开启 v1 / v3 签名**：实测荣耀 30（HarmonyOS 4.2）对 v1+v2+v3 全签名 APK 报"没有证书"无法安装（0.7.6/0.7.7 曾因此安装失败），而仅 v2 签名的 **0.7.4 为绝对可用基准**（0.7.5 曾两次发布且其中一次含全模型调用失败回归，不作可靠参照）。
- 发布前必须用 `apksigner verify --print-certs`（或等价工具）确认产物：**只含 v2 签名块**、证书为 `CN=STDeel`（SHA256 `ED:73:79:E8:34:86:70:43:22:DB:A4:33:61:DD:E1:6C:30:7F:E6:4F:8F:DA:BD:C7:E4:37:F7:0E:B4:57:F9:33`）。若产物含 `META-INF/*.RSA`（v1）或 v3 签名块，必须修复配置后重新构建。
- 同时严禁以下操作（历史教训，已造成用户安装失败）：
  - 严禁以"兼容性更好"为由开启 v1+v2+v3 全签名——方向与实测相反；
  - 严禁不校验签名方案就直接覆盖已发布 Release 的 APK 资产。

### 版本发布规则（GitHub Release / Pre-Release）
- 版本号由 `pubspec.yaml` 的 `version` 决定，同步更新 `lib/screens/settings_screen.dart` 底部角标文案。
- tag 格式沿用 `v<版本号>`（如 `v0.5.0`）。
- 版本号按 `主.次.补丁` 三段划分：
  - **大版本（主版，x.0.0）**：如 `1.0.0`、`2.0.0`
  - **中版本（次版，a.b.0）**：如 `1.1.0`、`0.5.0`
  - **小版本（补丁版，a.b.c，c≠0）**：如 `1.0.1`、`0.4.1`
- **版本号更新规则（按用户表述判定版本级别）**：
  - 若无特别说明，"按规则命名"即为**小版本更新**，在 `a.b.c` 的版本号结构中往 **c 位**数字加一；
  - 若用户特别指明**中版本更新**，即往 **b 位** +1，结果为 `a.（b+1）.0`；
  - 若用户指明**大版本更新**，即往 **a 位**数字加一。
- **版本号强制递增（不可协商）**：
  - **每次更新（含 bug 修复、小改动）必须至少递增一个小/中/大版本号**，默认按上文规则递增**小版本**（c 位 +1）；中版本/大版本更新必须在更新说明中提前明确说明。
  - **严禁不更改版本号进行更新/发布**——版本号不递增会导致内建更新无法识别到新版本（`compareVersions` 判定为无更新），用户永远收不到修复。
- **发布类型判定（前置条件：版本号必须 ≥ 1.0.0 才可能为正式版 Release）**：
  - 只有在**版本号 ≥ 1.0.0** 且符合**大版本（x.0.0）或中版本（a.b.0）**时，才发布为正式版 **Release**。
  - 其余情况一律发布为 **Pre-Release**，包括：
    - 所有 **< 1.0.0** 的版本（无论 0.x.0 或 0.x.y，如 `0.4.1`、`0.5.0`、`0.4.999`）——即使其中/末位为 0，也因未达 1.0.0 均为 pre-release；
    - **≥ 1.0.0** 的**小版本（a.b.c，c≠0）**（如 `1.0.1`）。
- 发布动作：
  - Release 使用 `gh release create <tag>`（不加 `--prerelease`）。
  - Pre-Release 使用 `gh release create <tag> --prerelease`。
- APK 产物命名建议沿用 `app-<版本号>.apk` 的形式上传到对应 tag。