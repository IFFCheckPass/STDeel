# Checklist — v0.9.0 重大升级

## 数据模型与迁移
- [x] `AiProvider` / `AiModel` 数据模型（含唯一编号与用户模型名）实现符合 Spec
- [x] 旧 `AiCombo` JSON 能自动迁移为单模型供应商，不丢原配置
- [x] `SettingsProvider` 以供应商层级持久化，`buildSplitChain()` / `buildSolveChainPlain()` / `buildSolveChainMultimodal()` 正确生成两阶段调用链
- [x] 全仓编译通过（`flutter analyze` 0 error、`flutter test` 全绿），无残留 `AiCombo`/`buildModelChain` 旧引用

## 两阶段调用管线
- [x] 拆图分割阶段用多模态模型提取题目、标记「需多模态」，结果可作为读题解答输入
- [x] 读题解答：命中答案库直接出答案（不调 AI）
- [x] 已标记题优先多模态解题，未标记题优先非多模态解题（成本优先，`_solveStageB` 分组）
- [x] 多模态与非多模态来自不同供应商时并行发送并合并结果（`_streamSolveGroup` + `_emitDone`）
- [x] 拆图全失败/无多模态模型时的整图回退路径可用（保留 streaming）

## 组合配置 UI
- [x] 供应商编辑页（名称/Base URL/API Key/连通性/模型列表）可用
- [x] 模型编辑页（model id/自定义名称/多模态开关/两阶段启用）可用
- [x] 调用顺序页：拆图分割（仅多模态）/读题解答两板块，可拖动排序、点击启停、展示用户模型名
- [x] 旧组合配置页引用已移除，入口指向新页面

## 设置页卡片化
- [x] 每类设置均为可折叠卡片，折叠显示标题+摘要，点击展开
- [x] AI 模型组合卡片接入新配置入口

## 本地备份
- [x] 导出生成含解题记录+知识点的 JSON 文件，提示保存路径
- [x] 导入恢复/合并进本地数据库，重复导入去重不产生重复记录
- [x] 导入格式非法时给出明确错误提示，不破坏现有数据

## 版本与发布
- [x] `pubspec.yaml` 版本 0.9.0+27，设置页角标/更新文案为 v0.9.0
- [ ] APK 构建成功且 `apksigner verify` 仅 v2、证书 CN=STDeel（SHA-256 与基准一致）
- [ ] Windows EXE 构建上传同 tag；v0.9.0（≥1.0.0 判正式/预发布）双端产物符合 AGENTS.md
- [ ] `docs/BUILD.md` 记录本次构建发布过程

## 紧急：照片编辑底图全屏适配
- [x] 底图改为显式未旋转尺寸渲染，cover 缩放（`_fitScale/_fitOffset`）与 `_rotatedSize` 精确一致，旋转后无黑边/偏差、始终撑满视口