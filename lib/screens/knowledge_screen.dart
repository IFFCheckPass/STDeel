/// 知识点统计页 - 思谛 STDeel
///
/// - 雷达图展示各知识点掌握度
/// - 薄弱知识点高亮（错误率 > 50%）
/// - 点击知识点查看相关错题
/// - "举一反三"按钮：AI 生成同类变式题
library;

import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../models/knowledge_point.dart';
import '../providers/settings_provider.dart';
import '../providers/solve_provider.dart';
import '../services/ai_service.dart';
import '../widgets/glass.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  List<KnowledgePoint> _points = const [];
  bool _loading = true;
  // null 表示"全部学科"；否则按所选学科过滤
  String? _selectedSubject;
  // AI 一键整理是否进行中
  bool _organizing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = context.read<AppDatabase>();
    final rows = await db.knowledgeDao.getAll();
    if (!mounted) return;
    setState(() {
      _points = rows
          .map((r) => KnowledgePoint(
                name: r.knowledgePoint,
                subject: r.subject,
                correctCount: r.correctCount,
                wrongCount: r.wrongCount,
              ))
          .toList();
      _loading = false;
    });
  }

  /// 全部学科集合（用于顶部分学科筛选）
  List<String> get _subjects {
    final s = _points.map((p) => p.subject).where((e) => e.isNotEmpty).toSet();
    return s.toList()..sort();
  }

  /// 当前筛选后的知识点（"全部"则不过滤）
  List<KnowledgePoint> get _visible {
    final sel = _selectedSubject;
    if (sel == null || sel.isEmpty) return _points;
    return _points.where((p) => p.subject == sel).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_points.isEmpty) {
      return const Center(
        child: Text('暂无知识点数据，先去解题吧！'),
      );
    }
    final visible = _visible;
    final weak = visible.where((p) => p.isWeak).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('知识点掌握度雷达图',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '已按大类聚合展示，细分知识点见下方列表',
                  style: TextStyle(fontSize: 11, color: G.textFaint),
                ),
              ),
              _organizing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      onPressed: () => _aiOrganize(context, _points),
                      icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                      style: TextButton.styleFrom(foregroundColor: G.accent),
                      label: const Text('AI 整理'),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          // 学科筛选
          if (_subjects.isNotEmpty) ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _subjectChip(null, label: '全部'),
                  for (final s in _subjects) _subjectChip(s, label: s),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildRadarChart(context, visible),
          const SizedBox(height: 24),
          if (weak.isNotEmpty) ...[
            const Text('薄弱知识点',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: G.coral)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: weak
                  .map((p) => ActionChip(
                        label: Text('${p.name}（错误率 ${(p.errorRate * 100).toStringAsFixed(0)}%）'),
                        onPressed: () => _showRelatedWrong(context, p.name),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          const Text('所有知识点（长按可设置学科）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final p in visible) _buildPointRow(context, p),
        ],
      ),
    );
  }

  Widget _subjectChip(String? subject, {required String label}) {
    final selected = _selectedSubject == subject;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: G.accent.withOpacity(0.25),
        checkmarkColor: G.accentFg,
        labelStyle: TextStyle(
          color: selected ? G.accentFg : G.textSecondary,
          fontSize: 13,
        ),
        onSelected: (_) => setState(() => _selectedSubject = subject),
      ),
    );
  }

  Widget _buildRadarChart(BuildContext context, List<KnowledgePoint> source) {
    final cats = _aggregateCategories(source);
    final n = cats.length;
    if (n < 3) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: G.glassFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: G.glassBorder),
        ),
        child: const Text('至少需要 3 个知识点才能绘制雷达图'),
      );
    }
    final values = cats.map((c) => c.accuracy * 4).toList();
    return SizedBox(
      height: 240,
      child: RadarChart(RadarChartData(
        dataSets: [
          RadarDataSet(
            dataEntries: [for (final v in values) RadarEntry(value: v)],
            fillColor: G.accentDeep.withOpacity(0.3),
            borderColor: G.accent,
          )
        ],
        titleTextStyle: TextStyle(fontSize: 11, color: G.textSecondary),
        getTitle: (idx, angle) => RadarChartTitle(text: cats[idx % n].name),
        tickCount: 4,
        ticksTextStyle: TextStyle(fontSize: 9, color: G.textFaint),
        gridBorderData: BorderSide(color: G.glassBorder),
        radarBackgroundColor: Colors.transparent,
      )),
    );
  }

  /// 单个细分知识点的粗分类归属。
  ///
  /// 尽量从名字里剥离常见连词（与/和/及/、等），取更粗的"大类"；
  /// 无连词时整体作为一个大类。用于把雷达图从"逐点"收敛为"按大类"，
  /// 缓解细分小知识点过多导致看不清的问题。
  static const _boundaryChars = ['与', '和', '及', '、', '，', ',', '/', '·', '｜', '：', ':', '－'];

  String _categoryOf(String name) {
    final t = name.trim();
    if (t.isEmpty) return t;
    for (final ch in _boundaryChars) {
      final i = t.indexOf(ch);
      if (i > 0) {
        final seg = t.substring(0, i).trim();
        if (seg.isNotEmpty) return seg;
      }
    }
    return t;
  }

  /// 把知识点按大类聚合并截断（保留前 [maxAxes] 个大类，其余并入"其他"），
  /// 使雷达图可读，不再因细分点过多而杂乱。
  static const int _maxAxes = 8;

  List<_RadarCategory> _aggregateCategories(List<KnowledgePoint> points) {
    final merged = <String, _RadarCategory>{};
    for (final p in points) {
      final cat = _categoryOf(p.name);
      merged.putIfAbsent(cat, () => _RadarCategory(cat)).add(p);
    }
    var list = merged.values.toList()
      ..sort((a, b) => b.totalCount.compareTo(a.totalCount));
    if (list.length > _maxAxes) {
      final kept = list.sublist(0, _maxAxes - 1);
      final rest = list.sublist(_maxAxes - 1);
      final other = _RadarCategory('其他');
      for (final r in rest) {
        other.correctCount += r.correctCount;
        other.wrongCount += r.wrongCount;
      }
      list = [...kept, other];
    }
    return list;
  }

  /// AI 一键整理：把所有已有知识点批量交给 AI 归类到学科，
  /// 自动写入数据库，避免手动逐个分类存量内容。
  Future<void> _aiOrganize(
      BuildContext context, List<KnowledgePoint> points) async {
    if (_organizing) return;
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可整理的知识点')),
      );
      return;
    }
    final settings = context.read<SettingsProvider>();
    final models = settings.buildModelChain();
    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先到「设置 → AI 模型组合」配置可用模型')),
      );
      return;
    }
    setState(() => _organizing = true);
    final ai = context.read<AiService>();
    final names = points.map((p) => p.name).toList();
    final subjectPrompt =
        '你是一个学科知识整理助手。下面是用户在学习积累中的所有知识点标签。'
        '\n请把【每一个】知识点归类到最合适的学科。'
        '学科取值限定为：数学、语文、英语、物理、化学、生物、历史、地理、政治、其他；'
        '无法判断时用"未分类"。'
        '\n只返回 JSON，不得输出任何解释文字，格式如下：'
        '\n{"assignments":[{"point":"原始知识点名称","subject":"学科"}]}'
        '\nassignments 必须覆盖下面列出的每一个知识点，不要遗漏。'
        '\n\n知识点列表：\n${names.map((n) => '- $n').join('\n')}';
    try {
      final jsonText = await ai.generateRaw(
        model: models.first,
        userText: subjectPrompt,
        // 不传 temperature：让 API 使用自身默认值（同解题做法），
        // 避免部分模型只允许 temperature=1 时报 400。
        source: 'AI 调用 · 知识点整理',
      );
      // AI 调用可能长达 180s，期间用户可能已退出页面；
      // 先检查 mounted 再使用 context，避免在已卸载元素上 read 抛异常。
      if (!mounted) return;
      // 从返回文本中截取 JSON 对象；若带围栏/前导文字则由 _extractJsonObject 兜底。
      final jsonStr = _extractJsonObject(jsonText) ?? jsonText;
      final obj = jsonDecode(jsonStr);
      final assignments = (obj as Map)['assignments'] as List<dynamic>? ?? [];
      final db = context.read<AppDatabase>();
      final byName = {for (final p in points) p.name: p};
      var applied = 0;
      for (final a in assignments) {
        if (a is! Map) continue;
        final point = (a['point'] ?? '').toString().trim();
        final subject = (a['subject'] ?? '').toString().trim();
        if (point.isEmpty || subject.isEmpty) continue;
        final cur = byName[point];
        if (cur == null || cur.subject == subject) continue;
        await db.knowledgeDao.setSubject(point, subject);
        applied++;
      }
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(applied > 0 ? 'AI 整理完成，归类了 $applied 个知识点' : 'AI 整理完成，未发现需要调整的归类')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 整理失败：$e'), backgroundColor: G.coral),
      );
    } finally {
      if (mounted) setState(() => _organizing = false);
    }
  }

  /// 从 AI 返回文本中截取第一个 JSON 对象，容忍 markdown 围栏/说明文字。
  String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  Widget _buildPointRow(BuildContext context, KnowledgePoint p) {
    final color = p.isWeak ? G.coral : G.mint;
    return Card(
      color: G.glassFill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: G.glassBorder),
      ),
      child: ListTile(
        onLongPress: () => _manageSubject(context, p),
        title: Text(p.name),
        subtitle: Text(
            '正确 ${p.correctCount} · 错误 ${p.wrongCount} · 正确率 ${(p.accuracy * 100).toStringAsFixed(0)}%'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: G.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: G.accent.withOpacity(0.3)),
                  ),
                  child: Text(
                    p.subject,
                    style: const TextStyle(fontSize: 10, color: G.accent),
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: () => _generateVariant(context, p.name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withOpacity(0.2),
                    foregroundColor: color,
                    side: BorderSide(color: color.withOpacity(0.5)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('举一反三'),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _showRelatedWrong(context, p.name),
      ),
    );
  }

  /// 知识点的常用学科目录（便于快速归类）
  static const _subjectChoices = <String>[
    '未分类',
    '数学',
    '语文',
    '英语',
    '物理',
    '化学',
    '生物',
    '历史',
    '地理',
    '政治',
    '其他',
  ];

  /// 长按知识点 → 选择/修改学科归属（知识点管理分学科）
  Future<void> _manageSubject(BuildContext context, KnowledgePoint p) async {
    final db = context.read<AppDatabase>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '为「${p.name}」选择学科',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _subjectChoices)
                  ChoiceChip(
                    label: Text(s),
                    selected: p.subject == s,
                    selectedColor: G.accent.withOpacity(0.25),
                    onSelected: (_) => Navigator.pop(context, s),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, '未分类'),
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              label: const Text('设为未分类'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked.trim().isEmpty || !mounted) return;
    await db.knowledgeDao.setSubject(p.name, picked);
    await _refresh();
  }

  Future<void> _showRelatedWrong(BuildContext context, String kp) async {
    final db = context.read<AppDatabase>();
    final records =
        await db.solveRecordDao.getByFeedbackAny(const ['wrong', 'partial']);
    if (!context.mounted) return;
    final related =
        records.where((r) => r.knowledgePoints.contains('"$kp"')).toList();
    showModalBottomSheet(
      context: context,
      builder: (_) => SizedBox(
        height: 320,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('「$kp」相关错题',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (related.isEmpty)
              const Text('暂无错题')
            else
              for (final r in related)
                ListTile(
                  dense: true,
                  title: Text(r.questionText,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('答案：${r.answer}'),
                ),
          ],
        ),
      ),
    );
  }

  /// 举一反三：让 AI 生成同类变式题
  Future<void> _generateVariant(BuildContext context, String kp) async {
    final solve = context.read<SolveProvider>();
    final settings = context.read<SettingsProvider>();
    final models = settings.buildModelChain();
    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先到「设置 → AI 模型组合」配置可用模型')),
      );
      return;
    }
    await solve.askDetailed(
      questionId: 0,
      questionText:
          '请基于「$kp」这一知识点，生成 3 道难度递进的变式题，并给出答案与解析。',
      models: models,
      thinkTimeout: settings.thinkTimeout,
      // 生成的每道变式题都各自新建一条历史记录，不覆盖既有记录
      commitAll: true,
    );
    if (!context.mounted) return;
    if (solve.state.status == SolveStatus.done) {
      Navigator.of(context).pushNamed('/answer');
    }
  }
}

/// 雷达图用的大类聚合对象（汇总其下细分知识点的正确/错误次数）。
class _RadarCategory {
  _RadarCategory(this.name);

  final String name;
  int correctCount = 0;
  int wrongCount = 0;

  int get totalCount => correctCount + wrongCount;

  double get accuracy => totalCount == 0 ? 0 : correctCount / totalCount;

  void add(KnowledgePoint p) {
    correctCount += p.correctCount;
    wrongCount += p.wrongCount;
  }
}
