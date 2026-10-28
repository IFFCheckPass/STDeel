# 需求清单与实现核对（v0.9.9）

> 用途：汇总你给出过的全部有效需求，逐条核对当前代码实现情况，供你审核。
> 标记说明：✅ 已实现并核对通过 ｜ ⚠️ 部分实现/有偏差 ｜ ❓ 疑似被后续需求取代，待你确认
> 生成时间：v0.9.9 发版时。已作废项按你要求剔除，但涉及"前后冲突"的会单独列出请你裁决。

---

## A. 交互与体验

| # | 需求 | 状态 | 代码位置 / 说明 |
|---|------|------|----------------|
| A1 | 除专有名词/编程约定外，一律中文思考、中文输出 | ✅ | 全仓注释、UI 文案、故障提示均为中文 |
| A2 | 拍照/选图页：主图宽度或高度至少一个方向撑满屏幕（底图全屏自适应） | ✅ | `lib/screens/image_edit_screen.dart` `_fitLayout` 用 `math.max`（cover），并显式给未旋转尺寸，保证与 `_rotatedSize` 精确一致、无黑边 |
| A3 | 设置页整理：每个选项放入可点击卡片，点击展开，减少占屏 | ✅ | `lib/screens/settings_screen.dart` `_ExpCard`（折叠仅一行标题+摘要，点击展开） |

## B. AI 模型配置

| # | 需求 | 状态 | 代码位置 / 说明 |
|---|------|------|----------------|
| B1 | 按供应商配置模型：每供应商一个 Base URL、一个 API Key、多个模型；供应商可自定义名称 | ✅ | `lib/models/ai_provider.dart` `AiProvider`；`lib/screens/provider_edit_screen.dart` |
| B2 | 每个模型可自定义名称；模型唯一编号（供应商1的模型1 = `1-1`） | ✅ | `AiModel.name`；`userModelName()` 生成 `编号 + 供应商名 + 模型名`（如 `1-1 Deepseek V4.1Flash`） |
| B3 | 界面显示的模型名统一为「编号+供应商名+模型名」 | ✅ | 供应商编辑页与调用顺序页均用 `userModelName()` |
| B4 | 模型调用顺序：可拖动调整顺序、点击决定是否启用 | ✅ | `lib/screens/model_order_screen.dart` 拖动排序 + 开关；`SettingsProvider.reorderModels / toggleModelEnabled` |
| B5 | 调用顺序分「拆图分割」「读题解答」两个板块（拆图分割只排多模态） | ⛔ 已作废 | **用户决定：保留 v0.9.6 简化**——单一全局顺序列表（`model_order_screen.dart`）。本条不再执行 |
| B6 | 模型无法添加 / 保存后消失 | ✅ | v0.9.1 修复（本地 `_models` 列表统一落库）；v0.9.9 再加"保存失败显式提示" |
| B7 | 0.9.8 无法保存供应商 | ✅ | v0.9.9 修复，见 F 节（根因是 SharedPreferences 不落盘 + 插件失效，已迁至 SQLite） |

## C. 模型调用逻辑

| # | 需求 | 状态 | 代码位置 / 说明 |
|---|------|------|----------------|
| C1 | 两阶段调用：a. 拆图分割（多模态提取文字、图片理解转述、数学绘图转结构化文本；难转换题标记进入下一阶段）b. 读题解答（标记题优先多模态、无标记题优先非多模态省经费；异供应商则并行；命中答案库直出） | ⛔ 已作废 | **用户决定：保留 v0.9.6 的"整图直答"单阶段简化**。两阶段管线不再引入；命中答案库直出（C3）仍保留 |
| C2 | 所有 AI 都报"无法读到图片" | ✅ | v0.9.7 修复：恢复 v0.8 多模态优先排序 + `FailoverManager` 带图请求跳过纯文本模型 |
| C3 | 命中答案库直接出答案（不调 AI） | ✅ | `SolveProvider._matchFromLibrary` / `_finishMatch` 全命中直出 |
| C4 | 后台/切其他软件时 AI 继续思考，不截断回答 | ✅ | `lib/services/solve_wakelock.dart`（前台服务 + PARTIAL_WAKE_LOCK）+ `ai_service.dart` 断流重连/部分收尾 |

> C1 与 B5 相互关联：若确认要恢复两阶段，B5 的两板块也要一并恢复。**这两条是最需要你拍板的。**

## D. 数据与备份

| # | 需求 | 状态 | 代码位置 / 说明 |
|---|------|------|----------------|
| D1 | 本地备份解题记录 + 知识点，可导入导出 | ✅ | `lib/services/backup_service.dart`（导出/导入 JSON；`file_picker` 存取） |
| D2 | 必须支持模型 API 配置信息的备份 | ✅ | 备份含 `ai_providers`（供应商名/Base URL/API Key/模型全量）；导出 v3 |
| D3 | 备份需含账号绑定 | ✅ | 备份 v3 新增 `username`；导入后自动 `setUsername` 并重绑云端 user_id |
| D4 | 导入"报错但实际成功" | ✅ | 导入重构：AI 配置恢复最优先、**逐条容错**（失败进警告明细弹窗）、宽容格式（v1/v2/v3、缺 type、裸数组、BOM、任意扩展名） |
| D5 | 导入备份不兼容（旧备份导入失败） | ✅ | 同上宽容格式兼容；旧版(v1)无 AI 配置会明确提示需手动补填 |
| D6 | 每次启动强制核查数据完整性 | ✅ | `lib/services/data_integrity_service.dart`，挂在 `SettingsProvider.load()` 尾部每次启动必跑；结果入故障记录 + 设置页「存储与缓存」可见 |
| D7 | 保证从 0.9.6 及以前版本迁移不再丢数据 | ✅ | v0.9.9 关键设置迁入 SQLite；首次启动自动从旧 SharedPreferences 一次性迁移全部 key；drift schema v7→v8 仅建表不重建 |
| D8 | 模型配置/账号绑定 大退后丢失 | ✅ | 根因=SharedPreferences 不保证落盘 + 插件 API 失效；v0.9.9 全部迁至 SQLite（写入后回读校验） |
| D9 | 覆盖安装丢信息 | ✅ | 同上；prefs 不再承载关键数据，且 SQLite 落盘有保证 |
| D10 | 数据完整性要求写进 AGENTS.md | ✅ | `AGENTS.md` 新增「数据完整性强制规则（T0 级，不可协商）」：关键数据禁 SharedPreferences、启动强制核查、备份必含模型配置与账号、覆盖前留底、schema 迁移链、发版前覆盖安装自测 |

## E. 发布与工程约束（AGENTS.md 既定）

| # | 需求 | 状态 | 说明 |
|---|------|------|------|
| E1 | 版本号每次必须递增，按 `主.次.补丁` 规则 | ✅ | 0.7.9→0.9.0→…→0.9.9，逐版递增 |
| E2 | <1.0.0 一律 Pre-Release | ✅ | v0.9.9 用 `gh release create --prerelease` |
| E3 | 每次发布必须双端：APK + Windows EXE，同一 tag | ✅ | `app-0.9.9.apk` + `stdeel-setup-0.9.9.exe` |
| E4 | APK 签名仅 v2，证书 CN=STDeel | ✅ | 每版 `apksigner verify` 校验（v1=false/v2=true/v3=false） |
| E5 | 每次改代码后推送 main；并同步 `feature/windows-support` 触发 EXE 构建 | ✅ | 每版均执行 |
| E6 | 签名分支 / Windows 分支严禁合并入 main 或提 PR | ✅ | 仅按约束取签名文件本地构建，不合并分支 |

---

## F. 本次（v0.9.9）修复的"无法保存供应商"根因

排查结论（三个症状同源）：

1. **SharedPreferences 官方明确"不保证写入落盘、不得用于关键数据"**，而此前模型配置、账号绑定、后端设置全部存在 prefs；
2. 你截图中的 `java.lang.NoSuchMethodError: ...SharedPreferencesApi$Registrar.getAll(...)` 说明**该插件在真机 release 包中整体调用失败** —— 于是 prefs 读写全废：保存＝没写进去（表现为"无法保存供应商"），大退后读不到（表现为"配置全丢"）。
3. 而历史记录存在 SQLite 中，故始终完好 —— 与"历史记录还在、API 信息没了"的现象完全吻合。

修复：

- 新增 drift `app_settings` 键值表（schema v8）+ `KeyValueStore`，**全部关键设置迁至 SQLite**，写入后**回读校验**，失败即抛错让 UI 提示（不再静默）；
- `BackendApi`、`FaultLogService` 全部改走 `KeyValueStore`；
- 首次启动自动从旧 SharedPreferences **一次性迁移全部 key**（老用户数据不丢）；
- 启动 `main()` 即初始化存储，确保任何读取前已就绪；
- 「保存供应商」增加失败提示与空模型提醒。

---

## G. 冲突项裁决结果（已定）

- **C1（两阶段调用）** 与 **B5（两板块顺序）**：用户已确认——**保留 v0.9.6 的简化**（整图直答单阶段 + 单一全局顺序列表）。
  两条需求**正式作废**，后续不再列入清单、不再实现。

## H. 版本号规则（已写入 AGENTS.md，确认并固化）

- 补丁位（c）为十进制数字、按数值递增，**严禁进位到 b 位**：
  `0.9.9 → 0.9.10 → 0.9.11 → 0.9.12 …`（`0.9.10` 仍属**小版本**，不是 `0.10.0`、更不是 `1.0.0`）。
- 版本号 < 1.0.0 期间一律 **Pre-Release**（`0.9.10`、`0.9.11` 同样）。
- 仅当用户**明确指明**中版本/大版本更新时，才允许 b / a 位变化。

## I. v0.9.10 新增需求

| # | 需求 | 状态 | 代码位置 / 说明 |
|---|------|------|----------------|
| I1 | AI 输出的 Markdown/LaTeX（`\frac`、`\sqrt` 等）必须可正常阅读 | ✅ | 新增 `lib/widgets/markdown_latex.dart`：Markdown 块级/行内 + LaTeX → Unicode（`3/4`、`√(5)`、`x²`、`≤`），`LatexRenderer` 委托渲染，纯 Dart 无崩溃 |
| I2 | 增加「部分错误」选项（橙色） | ✅ | `AnswerCard` 第 5 个按钮（橙 `#FF9F43`）；`SolveProvider.markPartial()`；历史页同步；知识点按半掌握（correct+1/wrong+1）；错题复习含 partial |
| I3 | 大题含多个小题时由 AI 拆成独立条目 | ✅ | `AiConfig.systemPrompt` 要求 (1)(2)(3)/①②③ 拆分，每小题独立 content/answer/solution/knowledge_points；LaTeX 统一标准写法 |
