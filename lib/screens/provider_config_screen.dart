/// AI 模型组合配置页（v0.9.0 供应商化）
///
/// 以「供应商」为维度管理模型：每个供应商含名称、Base URL、API Key 与多个模型。
/// 支持：
///  - 新增/删除供应商
///  - 进入供应商编辑页管理其模型
///  - 进入「调用顺序」页配置拆图分割 / 读题解答两阶段的顺序与启用
/// 界面统一以「用户模型名」（编号 + 供应商名 + 模型名）展示模型。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass.dart';
import 'model_order_screen.dart';
import 'provider_edit_screen.dart';

class ProviderConfigScreen extends StatelessWidget {
  const ProviderConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 模型组合')),
      body: Consumer<SettingsProvider>(
        builder: (context, s, _) {
          if (s.providers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, color: G.textFaint, size: 44),
                  const SizedBox(height: 12),
                  Text('暂无供应商，点击下方按钮添加',
                      style: TextStyle(color: G.textSecondary)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _addProvider(context, s),
                    icon: const Icon(Icons.add),
                    label: const Text('添加供应商'),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(12),
                fillColor: G.glassFill.withOpacity(0.5),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: G.accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '按供应商配置模型。每个模型以「编号 + 供应商名 + 模型名」展示（如 1-1 Deepseek V4.1Flash）。',
                        style:
                            TextStyle(fontSize: 12, color: G.textSecondary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 调用顺序入口
              GlassCard(
                child: ListTile(
                  leading: const Icon(Icons.swap_vert, color: G.accent),
                  title: const Text('模型调用顺序',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('配置「拆图分割 / 读题解答」两阶段的模型顺序与启用',
                      style: TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: G.textFaint),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ModelOrderScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < s.providers.length; i++) ...[
                _ProviderTile(index: i, provider: s.providers[i]),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _addProvider(context, s),
                icon: const Icon(Icons.add),
                label: const Text('添加供应商'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addProvider(BuildContext context, SettingsProvider s) async {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderEditScreen(
          initial: AiProvider(
            id: 'p-$ts',
            name: '新供应商',
            baseUrl: '',
            apiKey: '',
            models: <AiModel>[],
          ),
          isNew: true,
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.index, required this.provider});

  final int index;
  final AiProvider provider;

  @override
  Widget build(BuildContext context) {
    final s = context.read<SettingsProvider>();
    final modelCount = provider.models.length;
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ProviderEditScreen(initial: provider, isNew: false),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: G.primaryGradient,
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      provider.models.isEmpty
                          ? '尚未添加模型'
                          : '${modelCount} 个模型 · 点击管理',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: G.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!provider.isComplete)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: G.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: G.amber.withOpacity(0.4)),
                  ),
                  child: const Text('待完善',
                      style: TextStyle(fontSize: 9, color: G.amber)),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: G.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}