# Tasks — v0.9.0 重大升级

> 实现顺序：先数据模型与持久化（瓶颈），再两阶段管线，再 UI（供应商/模型/顺序 + 设置卡片化），
> 再备份，最后版本号与双端发布。无严格先决依赖的任务可并行。

## Task 1: 建立「供应商 → 模型」数据模型并迁移旧配置
- [ ] SubTask 1.1: 新增 `lib/models/ai_provider.dart`，定义 `AiProvider`（id、名称、baseUrl、apiKey、`List<AiModel> models`）与 `AiModel`（id、名称、modelId、multimodal、splitEnabled、splitOrder、solveEnabled、solveOrder），含 `toJson/fromJson/copyWith`、`isComplete`、唯一编号生成、`userModelName`（`编号 + 供应商名 + 模型名`）。
- [ ] SubTask 1.2: 新增默认供应商/模型模板（DeepSeek、通义千问 VL、NVIDIA NIM 等）。
- [ ] SubTask 1.3: `SettingsProvider` 改为持有 `List<AiProvider>` 并持久化到 `keyAiCombos`（沿用旧键，JSON 结构升级）；提供增/删/改供应商、增/删/改/排序/启停模型、（按供应商+模型序号）唯一编号重算、按阶段生成的调用链 `buildSplitChain()` / `buildSolveChain()`。
- [ ] SubTask 1.4: `load()` 时对旧 `AiCombo` JSON 做一次性迁移为单模型供应商；`AiCombo`、`buildModelChain()`、`availableCombos` 相关旧引用删除/替换，全仓编译通过。

## Task 2: 两阶段调用管线（拆图分割 → 读题解答）
- [ ] SubTask 2.1: `ai_service.dart` 新增拆图分割提示词（提取文字、图片理解转述、数学绘图转结构化文本、标记「需多模态」）；复用 `generateRaw`（多模态）。
- [ ] SubTask 2.2: `failover_manager.dart` 支持「阶段内按序 Failover」并支持两组（多模态已标记 / 非多模态未标记）跨供应商并行调用后合并结果。
- [ ] SubTask 2.3: `solve_provider.dart` 重构 `solve/retry/askDetailed` 流程为两阶段：拆图分割 → 答案库匹配（命中直出）→ 分类解题（已标记用多模态、未标记用非多模态、异供应商并行）。
- [ ] SubTask 2.4: 拆图分割全失败/无多模态模型时的整图回退路径保持可用；`_handleStreamEvent` 兼容新合并结果事件。

## Task 3: 模型组合配置 UI（供应商/模型 + 调用顺序）
- [ ] SubTask 3.1: 新增供应商编辑页（名称、Base URL、API Key、连通性测试、关联模型列表）。
- [ ] SubTask 3.2: 新增模型编辑页（模型 id、自定义名称、多模态开关）。
- [ ] SubTask 3.3: 新增「调用顺序」页：拆图分割（仅多模态）/ 读题解答两板块，拖动排序、点击启停，展示用户模型名。
- [ ] SubTask 3.4: 删除/替换旧 `combo_edit_screen.dart` 引用，组合配置入口跳转到新页面。

## Task 4: 设置页卡片化改版
- [ ] SubTask 4.1: 设置页每类设置改为可折叠卡片（折叠显示标题+摘要，点击展开）。
- [ ] SubTask 4.2: AI 模型组合卡片接入新供应商/模型/顺序配置入口；其余类目（解题/外观/账户/后端/存储/更新/故障码）并入对应卡片。

## Task 5: 本地备份（解题记录 + 知识点）
- [ ] SubTask 5.1: 在 `solve_record_dao.dart`、`knowledge_dao.dart` 增加全量 export 取数与 import 幂等 upsert 支持。
- [ ] SubTask 5.2: 新增备份导出/导入服务：序列化 JSON、`file_picker` 存取文件、格式校验。
- [ ] SubTask 5.3: 设置页「存储与缓存」卡片加入「导出备份 / 导入恢复」入口与结果反馈。

## Task 6: 版本号与双端发布
- [ ] SubTask 6.1: `pubspec.yaml` 版本号 → `0.9.0+27`；`settings_screen.dart` 角标/更新文案 → `v0.9.0`。
- [ ] SubTask 6.2: 构建 Android APK（仅 v2 签名，`apksigner` 校验）与 Windows EXE；推送 `main` + 合并 `feature/windows-support` 触发 Windows 构建；发布 v0.9.0 Release（≥1.0.0 判正式/预发布，按 AGENTS.md 规则），双端产物上传同一 tag。
- [ ] SubTask 6.3: 更新 `docs/BUILD.md` 记录本次构建发布过程。

# Task Dependencies
- [Task 1] 无依赖，先完成（数据模型是其他任务的瓶颈）。
- [Task 2] 依赖 [Task 1]（需要供应商/模型数据结构与调用链）。
- [Task 3] 依赖 [Task 1]（基于新模型做 UI），可与 [Task 2] 并行。
- [Task 4] 依赖 [Task 3]（组合配置入口）。
- [Task 5] 依赖 [Task 1]（数据 DAO）与 [Task 4]（入口），可与 [Task 2]/[Task 3] 并行。
- [Task 6] 依赖 [Task 1-5] 全部完成（含编译通过）。