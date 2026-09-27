/// 模型调用顺序页 - 思谛 STDeel
///
/// 把每个「用户模型名」（编号 + 供应商名 + 模型名）排列在
/// 「拆图分割 / 读题解答」两个板块下：
///  - 拆图分割板块仅列出多模态模型；
///  - 用户可拖动调整板块内顺序（即调用顺序），点击切换该阶段启用；
///  - 该页只对「已被理解为最终调用顺序」进行跨供应商的整体排序。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass.dart';

class ModelOrderScreen extends StatefulWidget {
  const ModelOrderScreen({super.key});

  @override
  State<ModelOrderScreen> createState() => _ModelOrderScreenState();
}

class _ModelOrderScreenState extends State<ModelOrderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模型调用顺序')),
      body: Consumer<SettingsProvider>(
        builder: (context, s, _) {
          // 拆图分割：全部多模态模型（按 splitOrder 排序）
          final splitList = _collectForSplit(s);
          // 读题解答：全部启用的读题模型（按 solveOrder 排序）
          final solveList = _collectForSolve(s);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(12),
                fillColor: G.glassFill.withOpacity(0.5),
                child: Text(
                  '拖动调整模型在该阶段的调用顺序，点击启用/停用。'
                  '拆图分割只用多模态模型；读题解答未标记题优先非多模态（省经费），标记题/回退用多模态。',
                  style: TextStyle(
                      fontSize: 12, color: G.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              _StageSection(
                title: '拆图分割',
                subtitle: '仅多模态模型',
                icon: Icons.image_search_outlined,
                items: splitList,
                stage: 'split',
                trailingOf: (e) => e.$1.splitEnabled,
                nameOf: (e) => e.$3,
                onToggle: (p, m) => s.toggleStage(p.id, m.id, 'split'),
                onReorder: (p, m, oi, ni) =>
                    s.reorderStage(p.id, m.id, 'split', oi, ni),
                onSelect: (p, m) {},
              ),
              const SizedBox(height: 16),
              _StageSection(
                title: '读题解答',
                subtitle: '非多模态优先，多模态兜底',
                icon: Icons.psychology_outlined,
                items: solveList,
                stage: 'solve',
                trailingOf: (e) => e.$1.solveEnabled,
                nameOf: (e) => e.$3,
                onToggle: (p, m) => s.toggleStage(p.id, m.id, 'solve'),
                onReorder: (p, m, oi, ni) =>
                    s.reorderStage(p.id, m.id, 'solve', oi, ni),
                onSelect: (p, m) {},
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  /// 拆图分割：收集所有多模态模型，按 (splitOrder, 供应商序号, 模型序号) 稳定排序。
  List<(AiModel, AiProvider, String)> _collectForSplit(
      SettingsProvider s) {
    final list = <(AiModel, AiProvider, String)>[];
    for (final p in s.providers) {
      for (final m in p.models) {
        if (m.multimodal) {
          list.add((m, p, userModelName(s.providers, p, m)));
        }
      }
    }
    list.sort((a, b) {
      final c = a.$1.splitOrder.compareTo(b.$1.splitOrder);
      if (c != 0) return c;
      return a.$2.name.compareTo(b.$2.name);
    });
    return list;
  }

  /// 读题解答：收集所有启用读题阶段的模型，按 (solveOrder, 供应商序号, 模型序号) 稳定排序。
  List<(AiModel, AiProvider, String)> _collectForSolve(
      SettingsProvider s) {
    final list = <(AiModel, AiProvider, String)>[];
    for (final p in s.providers) {
      for (final m in p.models) {
        if (m.solveEnabled) {
          list.add((m, p, userModelName(s.providers, p, m)));
        }
      }
    }
    list.sort((a, b) {
      final c = a.$1.solveOrder.compareTo(b.$1.solveOrder);
      if (c != 0) return c;
      return a.$2.name.compareTo(b.$2.name);
    });
    return list;
  }
}

/// 一个阶段的排序板块（拖动排序 + 点击启停）
class _StageSection extends StatelessWidget {
  const _StageSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.stage,
    required this.trailingOf,
    required this.nameOf,
    required this.onToggle,
    required this.onReorder,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<(AiModel, AiProvider, String)> items;
  final String stage;
  final bool Function((AiModel, AiProvider, String)) trailingOf;
  final String Function((AiModel, AiProvider, String)) nameOf;
  final void Function(AiProvider, AiModel) onToggle;
  final void Function(AiProvider, AiModel, int, int) onReorder;
  final void Function(AiProvider, AiModel) onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: G.accent, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(subtitle,
                    style:
                        TextStyle(fontSize: 11, color: G.textFaint)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('暂无模型',
                    style: TextStyle(color: G.textFaint, fontSize: 12)),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: (oi, ni) {
                if (ni > oi) ni -= 1;
                final e = items[oi];
                onReorder(e.$2, e.$1, oi, ni);
              },
              itemBuilder: (context, i) {
                final e = items[i];
                final enabled = trailingOf(e);
                final provider = e.$2;
                return Padding(
                  key: ValueKey('$stage-${provider.id}-${e.$1.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    radius: 14,
                    fillColor: enabled
                        ? G.glassFill.withOpacity(0.6)
                        : G.glassFill.withOpacity(0.25),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.drag_indicator,
                                color: G.textFaint, size: 20),
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: enabled ? G.accentDeep : G.glassFillStrong,
                          ),
                          alignment: Alignment.center,
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  color: enabled
                                      ? Colors.white
                                      : G.textFaint,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            nameOf(e),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: enabled
                                  ? G.textPrimary
                                  : G.textFaint,
                            ),
                          ),
                        ),
                        Switch(
                          value: enabled,
                          onChanged: (v) => onToggle(provider, e.$1),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}