/// 模型调用顺序页 - 思谛 STDeel
///
/// v0.9.6 起移除「拆图分割 / 读题解答」两阶段板块：解题直接整图交多模态模型，
/// 本页收敛为单一「模型调用顺序」列表——
///  - 列出全部供应商下的全部模型（含停用的，便于重新开启）；
///  - 拖动调整调用顺序（跨供应商全局排序），点击开关切换是否参与解题。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass.dart';

class ModelOrderScreen extends StatelessWidget {
  const ModelOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模型调用顺序')),
      body: Consumer<SettingsProvider>(
        builder: (context, s, _) {
          // 收集全部供应商下的全部模型（含停用的），按 (solveOrder, 供应商名) 排序
          final items = <(AiProvider, AiModel, String)>[];
          for (final p in s.providers) {
            for (final m in p.models) {
              items.add((p, m, userModelName(s.providers, p, m)));
            }
          }
          items.sort((a, b) {
            final c = a.$2.solveOrder.compareTo(b.$2.solveOrder);
            if (c != 0) return c;
            return a.$1.name.compareTo(b.$1.name);
          });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(12),
                fillColor: G.glassFill.withOpacity(0.5),
                child: Text(
                  '解题时按此顺序逐个调用模型（失败/超时自动切换下一个）。'
                  '拖动调整顺序，点击开关决定是否参与解题；停用的模型仍显示在列表中，可随时重新开启。',
                  style: TextStyle(
                      fontSize: 12, color: G.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_list_numbered,
                            color: G.accent, size: 20),
                        const SizedBox(width: 8),
                        Text('模型调用顺序',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${items.length} 个模型',
                              style: TextStyle(
                                  fontSize: 11, color: G.textFaint)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('暂无模型，请先在供应商中添加',
                              style: TextStyle(
                                  color: G.textFaint, fontSize: 12)),
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
                          s.reorderModels(oi, ni);
                        },
                        itemBuilder: (context, i) {
                          final e = items[i];
                          final enabled = e.$2.solveEnabled;
                          return Padding(
                            key: ValueKey('${e.$1.id}-${e.$2.id}'),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: Icon(Icons.drag_indicator,
                                          color: G.textFaint, size: 20),
                                    ),
                                  ),
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: enabled
                                          ? G.accentDeep
                                          : G.glassFillStrong,
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
                                      e.$3,
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
                                    onChanged: (v) => s.toggleModelEnabled(
                                        e.$1.id, e.$2.id),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
