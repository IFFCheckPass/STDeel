# Tasks — v0.9.0 重大升级

> 实现顺序：先数据模型与持久化（瓶颈），再两阶段管线，再 UI（供应商/模型/顺序 + 设置卡片化），
> 再备份，最后版本号与双端发布。无严格先决依赖的任务可并行。

## Task 1: 建立「供应商 → 模型」数据模型并迁移旧配置
- [x] SubTask 1.1: 新增 `lib/models/ai_provider.dart`，定义 `AiProvider` / `AiModel`（含唯一编号与用户模型名）。
- [x] SubTask 1.2: 新增默认供应商/模型模板（DeepSeek、通义千问 VL、NVIDIA NIM 等）。
- [x] SubTask 1.3: `SettingsProvider` 持有 `List<AiProvider>` 并持久化；提供供应商/模型增删改、两阶段 `buildSplitChain()/buildSolveChainPlain()/buildSolveChainMultimodal()`。
- [x] SubTask 1.4: `load()` 迁移旧 `AiCombo` JSON 为单模型供应商；删除 `AiCombo`/`buildModelChain` 旧引用（保留 `buildModelChain` 兼容），全仓编译通过（`flutter analyze` 0 error、`flutter test` 全绿）。

## Task 2: 两阶段调用管线（拆图分割 → 读题解答）
- [x] SubTask 2.1: `ai_service.dart` 新增 `AiConfig.imageSplitPrompt` 拆图分割提示词；`generateRaw` 支持自定义 `systemPrompt`。
- [x] SubTask 2.2: `failover_manager.dart` 兼容阶段内按序 Failover；跨供应商并行用于 `_solveStageB`。
- [x] SubTask 2.3: `solve_provider.dart` 重构 `solve` 为两阶段：拆图(多模态)→答案库匹配(命中直出)→分类解题(已标记多模态 / 未标记非多模态、异供应商并行)；`retry/askDetailed` 沿用 `buildModelChain`。
- [x] SubTask 2.4: 拆图全失败/无多模态时整图回退路径保留 streaming；`_emitDone` 合并并行结果并落库通知。

## Task 3: 模型组合配置 UI（供应商/模型 + 调用顺序）
- [x] SubTask 3.1: 新增 `provider_config_screen.dart`（供应商列表/添加入口）、`provider_edit_screen.dart`（名称/Base URL/API Key/连通性/模型管理）。
- [x] SubTask 3.2: 新增 `model_edit_screen.dart`（model id/自定义名称/多模态开关/两阶段启用）。
- [x] SubTask 3.3: 新增 `model_order_screen.dart`：拆图分割（仅多模态）/读题解答两板块，拖动排序、点击启停，展示用户模型名。
- [x] SubTask 3.4: 删除旧 `combo_edit_screen.dart`，配置入口指向新页面。

## Task 4: 设置页卡片化改版
- [x] SubTask 4.1: 设置页每类设置改为可折叠卡片（`_ExpCard`，折叠显示标题+摘要，点击展开）。
- [x] SubTask 4.2: AI 模型组合卡片接入 `ProviderConfigScreen`；解题/外观/账户/后端/存储/更新/故障码并入对应卡片。

## Task 5: 本地备份（解题记录 + 知识点）
- [x] SubTask 5.1: `solve_record_dao.dart` 增加 `existsBySourceKey`/`insertFromBackup`；`knowledge_dao.dart` 增加 `importAbsolute`。
- [x] SubTask 5.2: 新增 `backup_service.dart`：导出/导入 JSON、`file_picker` 存取、格式校验、幂等去重。
- [x] SubTask 5.3: 设置页「存储与缓存」卡片加入「导出备份 / 导入恢复」入口与 SnackBar 反馈。

## Task 6: 版本号与双端发布
- [x] SubTask 6.1: `pubspec.yaml` 版本号 → `0.9.0+27`；`settings_screen.dart` 角标/更新文案 → `v0.9.0`。
- [ ] SubTask 6.2: 构建 Android APK（仅 v2 签名，`apksigner` 校验）与 Windows EXE；推送 `main` + 合并 `feature/windows-support` 触发 Windows 构建；发布 v0.9.0（按 AGENTS.md 规则），双端产物同一 tag。
- [ ] SubTask 6.3: 更新 `docs/BUILD.md` 记录本次构建发布过程。

## 追加：紧急照片编辑底图全屏适配（用户插入需求）
- [x] SubTask 7.1: `image_edit_screen.dart` 底图改为显式未旋转尺寸渲染，使 cover 缩放（`_fitScale/_fitOffset`）与 `_rotatedSize` 精确一致，保证底图始终撑满视口且旋转后不产生黑边/偏差。

# Task Dependencies
- [Task 1] 无依赖，先完成（数据模型是其他任务的瓶颈）。
- [Task 2] 依赖 [Task 1]。
- [Task 3] 依赖 [Task 1]，可与 [Task 2] 并行。
- [Task 4] 依赖 [Task 3]。
- [Task 5] 依赖 [Task 1] 与 [Task 4]，可与 [Task 2]/[Task 3] 并行。
- [Task 6] 依赖 [Task 1-5] 全部完成（含编译通过）。