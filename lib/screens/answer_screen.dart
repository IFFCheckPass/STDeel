/// 答案展示页 - 思谛 STDeel（核心页面）
///
/// 整页可上下滚动；每道题一个 AnswerCard：
///   - 左侧 4 个按钮（竖向）：重答 / 疑问 / 错误 / 正确
///   - 右侧：题目 + 知识点标签 + 答案 + 解答过程（LaTeX）
///
/// 进入方式：
///   1. 从首页拍照后 push（携带 [imagePath]）→ initState 自动触发 solve，
///      就地展示流式思维链与答案，避免用户困在主页无反馈。
///   2. 从历史记录页 push（不携带 imagePath）→ 直接展示 SolveProvider.state 中
///      的当前结果，或从 drift 加载指定 recordId 的历史记录。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/solve_result.dart';
import '../providers/settings_provider.dart';
import '../providers/solve_provider.dart';
import '../widgets/answer_card.dart';
import '../widgets/glass.dart';
import '../widgets/thinking_indicator.dart';

class AnswerScreen extends StatefulWidget {
  const AnswerScreen({super.key, this.imagePath});

  /// 非空时进入即触发一轮 solve（流式展示思维链 + 答案）。
  final String? imagePath;

  @override
  State<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends State<AnswerScreen> {
  /// 流式期间自动滚动到底部
  final _scrollCtrl = ScrollController();
  bool _solvingTriggered = false;
  /// 多候选卷次弹窗防重入
  bool _paperDialogShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      // 等首帧渲染完毕再触发，让流式 UI 先就位
      WidgetsBinding.instance.addPostFrameCallback((_) => _startSolving());
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// 进入页面后触发一轮 solve；触发一次即可，重答/疑问走 AnswerCard 内部按钮
  Future<void> _startSolving() async {
    if (!mounted || _solvingTriggered) return;
    _solvingTriggered = true;
    final settings = context.read<SettingsProvider>();
    final solve = context.read<SolveProvider>();
    final splitModels = settings.buildSplitChain();
    final plainModels = settings.buildSolveChainPlain();
    final multimodalModels = settings.buildSolveChainMultimodal();
    if (splitModels.isEmpty &&
        plainModels.isEmpty &&
        multimodalModels.isEmpty) {
      showGlassSnackBar(
        context,
        '请先到「设置 → AI 模型组合」配置供应商与模型',
        error: true,
      );
      return;
    }
    // 不 await：流式事件经 SolveProvider.notifyListeners 自动驱动 UI，
    // 这里仅 fire 一次即可。
    solve.solve(
      imagePath: widget.imagePath!,
      splitModels: splitModels,
      plainModels: plainModels,
      multimodalModels: multimodalModels,
      thinkTimeout: settings.thinkTimeout,
    );
  }

  void _maybeAutoScroll() {
    if (!_scrollCtrl.hasClients) return;
    // 仅当用户本就贴近底部时才跟随滚动，避免上滑阅读时被持续强制拉回。
    final pos = _scrollCtrl.position;
    if (pos.maxScrollExtent - pos.pixels > 80) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final solve = context.watch<SolveProvider>();
    final state = solve.state;

    // 多套答案册候选：等待用户选择当前卷次（弹窗一次）
    if (solve.hasPaperChoice && !_paperDialogShown) {
      _paperDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showPaperChoice(solve);
      });
    }

    // 流式期间增量到达 → 滚到底部
    if (state.status == SolveStatus.thinking ||
        state.status == SolveStatus.answering) {
      _maybeAutoScroll();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('解题结果'),
        actions: [
          IconButton(
            tooltip: '历史记录',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).pushNamed('/history'),
          ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  /// 多候选卷次弹窗：用户选择当前卷次后继续认领，取消则回退 AI 解题
  Future<void> _showPaperChoice(SolveProvider solve) async {
    final papers = solve.pendingPapers ?? const [];
    if (papers.isEmpty) {
      _paperDialogShown = false;
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('选择当前卷次',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              '检测到多套答案册都包含本页题号，请选择当前正在做的卷子；'
              '选错卷子可能导致答案不匹配',
              style: TextStyle(fontSize: 12, color: G.textFaint, height: 1.5),
            ),
            const SizedBox(height: 12),
            for (final p in papers)
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.auto_stories_outlined,
                    color: G.accent),
                title: Text(p.name),
                subtitle: const Text('题号已匹配',
                    style: TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(ctx, p.id),
              ),
            const Divider(),
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, null),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('不使用答案库，直接 AI 解题'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (picked != null) {
      await solve.resumeWithPaper(picked);
    } else {
      await solve.cancelPaperChoice();
    }
    _paperDialogShown = false;
  }

  Widget _buildBody(BuildContext context, SolveUiState state) {
    if (state.status == SolveStatus.thinking ||
        state.status == SolveStatus.answering) {
      return _buildStreaming(context, state);
    }
    if (state.status == SolveStatus.error) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            fillColor: G.coral.withOpacity(0.08),
            borderColor: G.coral.withOpacity(0.35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: G.coral),
                const SizedBox(height: 12),
                Text(
                  state.error ?? '未知错误',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: G.coral, height: 1.6),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final result = state.result;
    if (result == null || result.questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: G.textFaint),
            const SizedBox(height: 12),
            Text('暂无解题结果', style: TextStyle(color: G.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('查看历史记录'),
              onPressed: () => Navigator.of(context).pushNamed('/history'),
            ),
          ],
        ),
      );
    }
    return _buildResults(context, result.questions, state.currentModel);
  }

  Widget _buildStreaming(BuildContext context, SolveUiState state) {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThinkingIndicator(
            isAnswering: state.status == SolveStatus.answering,
            modelName: state.currentModel.isEmpty
                ? null
                : state.currentModel,
            notice: state.notice,
          ),
          const SizedBox(height: 12),
          if (state.status == SolveStatus.thinking &&
              state.reasoningText.isNotEmpty)
            GlassCard(
              fillColor: G.accent.withOpacity(0.06),
              borderColor: G.accent.withOpacity(0.25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.psychology_rounded,
                          size: 14, color: G.accent),
                      SizedBox(width: 6),
                      Text(
                        '思维链',
                        style: TextStyle(
                          fontSize: 12,
                          color: G.accent,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    state.reasoningText,
                    style: TextStyle(
                      fontSize: 13,
                      color: G.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          if (state.status == SolveStatus.answering &&
              state.answerText.isNotEmpty)
            GlassCard(
              fillColor: G.mint.withOpacity(0.06),
              borderColor: G.mint.withOpacity(0.25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.chat_bubble_rounded,
                          size: 14, color: G.mint),
                      SizedBox(width: 6),
                      Text(
                        '回答',
                        style: TextStyle(
                          fontSize: 12,
                          color: G.mint,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    state.answerText,
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    List<QuestionResult> questions,
    String modelName,
  ) {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final q in questions)
            AnswerCard(
              question: q,
              modelName: modelName,
              feedback: 'none',
              onRetry: () => _onRetry(context, q),
              onAskDetailed: () => _onAskDetailed(context, q),
              onMarkCorrect: () => _onMarkCorrect(context, q),
              onMarkWrong: () => _onMarkWrong(context, q),
            ),
        ],
      ),
    );
  }

  /// 重答/疑问前检查模型链
  bool _ensureModels(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    if (settings.buildModelChain().isEmpty) {
      showGlassSnackBar(
        context,
        '请先到「设置 → AI 模型组合」填写 API Key 并启用组合',
        error: true,
      );
      return false;
    }
    return true;
  }

  Future<void> _onRetry(BuildContext context, QuestionResult q) async {
    if (!_ensureModels(context)) return;
    final solve = context.read<SolveProvider>();
    final settings = context.read<SettingsProvider>();
    showGlassSnackBar(context, '正在重答…');
    await solve.retry(
      questionId: q.id,
      questionText: q.content,
      models: settings.buildModelChain(),
      thinkTimeout: settings.thinkTimeout,
      // 从首次进入本页的图片取回原图，重答时题干选项/图表不丢失
      imagePath: widget.imagePath,
      sessionNoOverride: q.sessionNo,
    );
  }

  Future<void> _onAskDetailed(BuildContext context, QuestionResult q) async {
    if (!_ensureModels(context)) return;
    final solve = context.read<SolveProvider>();
    final settings = context.read<SettingsProvider>();
    showGlassSnackBar(context, '正在生成分步解答…');
    await solve.askDetailed(
      questionId: q.id,
      questionText: q.content,
      models: settings.buildModelChain(),
      thinkTimeout: settings.thinkTimeout,
      imagePath: widget.imagePath,
      sessionNoOverride: q.sessionNo,
    );
  }

  Future<void> _onMarkCorrect(BuildContext context, QuestionResult q) async {
    final solve = context.read<SolveProvider>();
    await solve.markCorrect(
      questionId: q.id,
      knowledgePoints: q.knowledgePoints,
      subject: q.subject,
    );
    if (!context.mounted) return;
    showGlassSnackBar(context, '已标记正确，知识点统计已更新', success: true);
  }

  Future<void> _onMarkWrong(BuildContext context, QuestionResult q) async {
    final solve = context.read<SolveProvider>();
    await solve.markWrong(
      questionId: q.id,
      knowledgePoints: q.knowledgePoints,
      subject: q.subject,
    );
    if (!context.mounted) return;
    showGlassSnackBar(context, '已标记错误，薄弱知识点已记录', success: true);
  }
}
