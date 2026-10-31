/// 解题历史记录页 - 思谛 STDeel
///
/// 从 drift [SolveRecords] 表读取所有历史记录，按时间倒序列出。
/// 每条卡片默认折叠（题干 + 模型 + 时间 + 反馈标记），点击展开
/// 答案 / 解答过程 / 知识点。反馈按钮就地更新 drift 并同步后端。
///
/// 这是用户在手机上查看历史拍题解题记录的入口。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../providers/settings_provider.dart';
import '../providers/solve_provider.dart';
import '../services/backend_api.dart';
import '../services/sync_service.dart';
import '../widgets/glass.dart';
import '../widgets/latex_renderer.dart';
import '../widgets/markdown_latex.dart' show latexToUnicode;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Future<List<SolveRecordEntity>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppDatabase>().solveRecordDao.getAll();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = context.read<AppDatabase>().solveRecordDao.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('解题历史'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<SolveRecordEntity>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '读取历史记录失败：\n${snapshot.error}',
                  style: const TextStyle(color: G.coral, height: 1.5),
                ),
              ),
            );
          }
          final list = snapshot.data ?? const <SolveRecordEntity>[];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: G.textFaint),
                  const SizedBox(height: 12),
                  Text('还没有解题记录', style: TextStyle(color: G.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    '拍照解题后，记录会自动保存到这里',
                    style: TextStyle(fontSize: 12, color: G.textFaint),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _HistoryCard(
                record: list[i],
                onChanged: _refresh,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({required this.record, required this.onChanged});

  final SolveRecordEntity record;
  final VoidCallback onChanged;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _expanded = false;

  List<String> get _knowledgePoints {
    try {
      final l = jsonDecode(widget.record.knowledgePoints);
      if (l is List) return l.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  /// 按题目状态返回标记（颜色 / 图标 / 文案）：
  /// correct=绿(正确) / partial=橙(部分错误) / wrong=红(错误) / retry=蓝(重答)
  /// / detail=黄(疑问) / 其余中性(解题)
  (Color, IconData, String) _statusStyle(String action, String feedback) {
    if (feedback == 'correct') {
      return (G.mint, Icons.check_circle_rounded, '正确');
    }
    if (feedback == 'partial') {
      return (const Color(0xFFFF9F43), Icons.remove_circle_rounded, '部分错误');
    }
    if (feedback == 'wrong') {
      return (G.coral, Icons.cancel_rounded, '错误');
    }
    switch (action) {
      case 'retry':
        return (G.accent, Icons.refresh_rounded, '重答');
      case 'detail':
        return (G.amber, Icons.help_outline_rounded, '疑问');
      case 'solve':
      default:
        return (G.textFaint, Icons.auto_awesome_rounded, '解题');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    // 四色状态标记：正确=绿 / 错误=红 / 疑问(解答)=黄 / 重答=蓝 / 其余(初始解题)=中性
    final (Color fbColor, IconData fbIcon, String statusLabel) =
        _statusStyle(r.actionType, r.userFeedback);

    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 18,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(fbIcon, size: 18, color: fbColor),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: fbColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 展开时按 Markdown + LaTeX 渲染（历史页此前用纯文本，
                        // 导致 \(...\)、\mathbf 等公式原样显示）；折叠时只显示
                        // 两行纯文本摘要，避免卡片高度失控。
                        if (_expanded)
                          LatexRenderer(
                            text: r.questionText.isEmpty
                                ? '（空题干）'
                                : r.questionText,
                            isBlock: false,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: G.textPrimary,
                            ),
                          )
                        else
                          Text(
                            r.questionText.isEmpty
                                ? '（空题干）'
                                : latexToUnicode(r.questionText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: G.textPrimary,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (r.aiModel.isNotEmpty) ...[
                              Flexible(
                                child: Text(
                                  r.aiModel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: G.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _formatTime(r.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: G.textFaint,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _delete,
                              behavior: HitTestBehavior.opaque,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: G.coral,
                                ),
                              ),
                            ),
                            Icon(
                              _expanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: G.textFaint,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                if (r.answer.isNotEmpty) ...[
                  _buildSection('答案', r.answer, color: G.mint),
                  const SizedBox(height: 8),
                ],
                if (r.solution.isNotEmpty) ...[
                  _buildSection('解答', r.solution),
                  const SizedBox(height: 8),
                ],
                if (_knowledgePoints.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final kp in _knowledgePoints)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: G.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: G.accent.withOpacity(0.3)),
                          ),
                          child: Text(
                            kp,
                            style: const TextStyle(
                                fontSize: 11, color: G.accent),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    if (r.latencyMs > 0)
                      _meta('耗时 ${(r.latencyMs / 1000).toStringAsFixed(1)}s'),
                    if (r.tokensUsed > 0) ...[
                      const SizedBox(width: 10),
                      _meta('${r.tokensUsed} tokens'),
                    ],
                    const Spacer(),
                    if (r.synced)
                      _meta('已同步', color: G.textFaint)
                    else
                      _meta('待同步', color: G.amber),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _actionBtn(
                        label: '重答',
                        color: G.accent,
                        icon: Icons.refresh_rounded,
                        onPressed: () => _retryOrDetail(actionType: 'retry'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionBtn(
                        label: '疑问',
                        color: G.amber,
                        icon: Icons.help_outline_rounded,
                        onPressed: () => _retryOrDetail(actionType: 'detail'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionBtn(
                        label: '部分',
                        color: const Color(0xFFFF9F43),
                        icon: Icons.remove_circle_outline_rounded,
                        onPressed: () => _markFeedback('partial'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionBtn(
                        label: '错误',
                        color: G.coral,
                        icon: Icons.close_rounded,
                        onPressed: () => _markFeedback('wrong'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: G.mint,
                          minimumSize:
                              const Size.fromHeight(38),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('正确'),
                        onPressed: () => _markFeedback('correct'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 四个颜色统一的反馈/动作按钮（样式贴近解题页 AnswerCard）
  Widget _actionBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        minimumSize: const Size.fromHeight(38),
        backgroundColor: color.withOpacity(0.08),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  /// 重答 / 疑问：复用 Solver 的纯文本题解，就地覆盖历史记录并跳转到解题页查看
  ///
  /// 关键：**先**导航到解题页 /answer，**再**触发重答/疑问（不等待其完成），
  /// 让用户在解题页实时看到 AI 思考与作答进程，而不是等完成后才跳转。
  Future<void> _retryOrDetail({required String actionType}) async {
    final r = widget.record;
    final solve = context.read<SolveProvider>();
    final settings = context.read<SettingsProvider>();
    final models = settings.buildModelChain();
    if (models.isEmpty) {
      showGlassSnackBar(
        context,
        '请先到「设置 → AI 模型组合」填写 API Key 并启用组合',
        error: true,
      );
      return;
    }
    final questionText = r.questionText.isEmpty ? '（请补充题干）' : r.questionText;
    showGlassSnackBar(
      context,
      actionType == 'retry' ? '正在重答…' : '正在生成分步解答…',
    );
    // 立即进入解题页（导航先发），answer 页 watch SolveProvider 展示流式思维链
    final nav = Navigator.of(context).pushNamed('/answer');
    // 触发重答/疑问（fire，不阻塞导航，让流式事件驱动 answer 页 UI）
    // 携带原图缓存路径，保证重答/解答时题干选项与图表完整。
    if (actionType == 'retry') {
      solve.retry(
        questionId: r.id,
        questionText: questionText,
        models: models,
        thinkTimeout: settings.thinkTimeout,
        imagePath: r.imagePath,
      );
    } else {
      solve.askDetailed(
        questionId: r.id,
        questionText: questionText,
        models: models,
        thinkTimeout: settings.thinkTimeout,
        imagePath: r.imagePath,
      );
    }
    await nav;
    if (!mounted) return;
    widget.onChanged();
  }

  Widget _buildSection(String label, String body, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color ?? G.textFaint,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        LatexRenderer(
          text: body,
          isBlock: false,
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
      ],
    );
  }

  Widget _meta(String text, {Color? color}) => Text(
        text,
        style: TextStyle(fontSize: 10, color: color ?? G.textFaint),
      );

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  /// 删除该条记录：确认后先同步删除服务器记录，再删本地 drift。
  Future<void> _delete() async {
    final r = widget.record;
    final preview = r.questionText.isEmpty
        ? '（空题干）'
        : (r.questionText.length > 30
            ? '${r.questionText.substring(0, 30)}…'
            : r.questionText);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该记录'),
        content: Text(
          '确定删除这条解题记录吗？本地与服务器将同步删除，不可恢复。\n\n题干：$preview',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: G.coral,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = context.read<AppDatabase>();
    final api = context.read<BackendApi>();
    // 先删服务器（若已有后端主键），再删本地，避免"服务器残留 + 本地消失"。
    final remoteId = r.remoteId ?? 0;
    final remoteOk = await api.deleteSolveRecord(remoteId);
    if (!remoteOk && remoteId > 0) {
      // 服务器删除失败：把 remoteId 记入待删除队列，下次同步时重试删除，
      // 并确保下拉回写时跳过该主键——否则本地已删、服务器又回写，等于删不掉。
      await db.pendingDeleteDao.add(remoteId);
    }
    await db.solveRecordDao.deleteById(r.id);
    if (!mounted) return;
    showGlassSnackBar(
      context,
      remoteOk ? '已删除该记录' : '已删除本地记录（服务器删除未成功，已记录待下次同步重试）',
      success: remoteOk,
      error: !remoteOk,
    );
    widget.onChanged();
  }

  /// 就地更新反馈（写 drift + 累计知识点 + 异步同步后端）
  Future<void> _markFeedback(String feedback) async {
    final r = widget.record;
    final db = context.read<AppDatabase>();
    final sync = context.read<SyncService>();
    await db.solveRecordDao.updateFeedback(r.id, feedback);
    final kps = _knowledgePoints;
    final isCorrect = feedback == 'correct';
    final isPartial = feedback == 'partial';
    for (final kp in kps) {
      await db.knowledgeDao.upsert(
        knowledgePoint: kp,
        subject: r.subject,
        // 部分错误按「半掌握」计：correct +1、wrong +1
        deltaCorrect: (isCorrect || isPartial) ? 1 : 0,
        deltaWrong: (isCorrect || isPartial) ? (isPartial ? 1 : 0) : 1,
      );
    }
    // 异步上传至后端（失败静默，等下次手动同步重试）
    sync.uploadFeedback(r.id, feedback);
    if (!mounted) return;
    showGlassSnackBar(
      context,
      isCorrect
          ? '已标记正确，知识点统计已更新'
          : (isPartial ? '已标记部分错误，知识点按半掌握统计' : '已标记错误，薄弱知识点已记录'),
      success: true,
    );
    widget.onChanged();
  }
}
