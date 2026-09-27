/// 模型编辑页 - 思谛 STDeel
///
/// 编辑一个模型：API model id、自定义名称、是否多模态，以及其在
/// 「拆图分割 / 读题解答」两阶段的启用开关。并提供从供应商端点拉取模型列表、
/// 连通性测试。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../widgets/glass.dart';

class ModelEditScreen extends StatefulWidget {
  const ModelEditScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.initial,
    required this.isNew,
  });

  final String providerId;
  final String providerName;
  final AiModel initial;
  final bool isNew;

  @override
  State<ModelEditScreen> createState() => _ModelEditScreenState();
}

class _ModelEditScreenState extends State<ModelEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelCtrl;
  late bool _multimodal;
  bool _fetchingModels = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _modelCtrl = TextEditingController(text: widget.initial.modelId);
    _multimodal = widget.initial.multimodal;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  AiModel _buildModel() => AiModel(
        id: widget.initial.id,
        name: _nameCtrl.text.trim().isEmpty
            ? '未命名模型'
            : _nameCtrl.text.trim(),
        modelId: _modelCtrl.text.trim(),
        multimodal: _multimodal,
        splitEnabled: widget.initial.splitEnabled,
        splitOrder: widget.initial.splitOrder,
        solveEnabled: widget.initial.solveEnabled,
        solveOrder: widget.initial.solveOrder,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '添加模型' : '编辑模型'),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: '删除模型',
              icon: const Icon(Icons.delete_outline, color: G.coral),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSectionTitle('模型信息（${widget.providerName}）'),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '模型自定义名称',
                      hintText: '如：V4.1Flash、qwen-vl',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _modelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Model ID',
                      hintText: 'deepseek-chat（可手动输入）',
                      prefixIcon: Icon(Icons.smart_toy_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _fetchingModels ? null : _fetchModels,
                    icon: _fetchingModels
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined, size: 18),
                    label: Text(_fetchingModels ? '正在获取模型列表…' : '获取模型列表'),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _multimodal,
                    onChanged: (v) => setState(() => _multimodal = v),
                    title: const Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            color: G.accent, size: 18),
                        SizedBox(width: 10),
                        Text('支持多模态（视觉 / 图片识别）',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    subtitle: const Text(
                      '勾选后，拆图分割（图片文字/图形转结构化文本）会优先使用该模型。仅支持文字输入的模型请保持关闭。',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlassSectionTitle('两阶段启用'),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    value: widget.initial.splitEnabled && _multimodal,
                    onChanged: _multimodal
                        ? (v) => setState(() {
                              widget.initial.splitEnabled = v;
                            })
                        : null,
                    title: const Text('参与拆图分割',
                        style:
                            TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('仅多模态模型可参与拆图分割',
                        style: TextStyle(fontSize: 12)),
                  ),
                  SwitchListTile(
                    value: widget.initial.solveEnabled,
                    onChanged: (v) => setState(() {
                      widget.initial.solveEnabled = v;
                    }),
                    title: const Text('参与读题解答',
                        style:
                            TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('未标记题优先非多模态，标记题/回退用多模态',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlassPrimaryButton(
              icon: Icons.check_rounded,
              label: '保存模型',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchModels() async {
    final s = context.read<SettingsProvider>();
    final p = s.providers.firstWhere((p) => p.id == widget.providerId,
        orElse: () => throw StateError('供应商不存在'));
    if (p.baseUrl.trim().isEmpty) {
      showGlassSnackBar(context, '请先为供应商填写 Base URL', error: true);
      return;
    }
    setState(() => _fetchingModels = true);
    try {
      final ai = context.read<AiService>();
      final models = await ai.fetchModels(baseUrl: p.baseUrl, apiKey: p.apiKey);
      if (!mounted) return;
      if (models.isEmpty) {
        showGlassSnackBar(context, '该端点未返回任何模型', error: true);
        return;
      }
      final selected = await _showModelPicker(models);
      if (selected != null && selected.isNotEmpty) {
        _modelCtrl.text = selected;
        showGlassSnackBar(context, '已选择模型：$selected', success: true);
      }
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(context, '获取模型列表失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  Future<String?> _showModelPicker(List<String> models) {
    var keyword = '';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final filtered = models
              .where((m) => m.toLowerCase().contains(keyword.toLowerCase()))
              .toList();
          return SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('选择模型',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      Text('${models.length} 个模型',
                          style: TextStyle(fontSize: 12, color: G.textFaint)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '搜索模型…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setSheetState(() => keyword = v),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final m = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(m,
                            style: TextStyle(
                              fontSize: 13,
                              color: m == _modelCtrl.text
                                  ? G.accent
                                  : G.textPrimary,
                            )),
                        trailing: m == _modelCtrl.text
                            ? const Icon(Icons.check, color: G.accent, size: 18)
                            : null,
                        onTap: () => Navigator.pop(sheetCtx, m),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final model = _buildModel();
    if (model.modelId.isEmpty) {
      showGlassSnackBar(context, 'Model ID 不能为空', error: true);
      return;
    }
    final s = context.read<SettingsProvider>();
    await s.saveModel(widget.providerId, model);
    if (!mounted) return;
    showGlassSnackBar(context, '模型「${model.name}」已保存', success: true);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模型'),
        content: Text('确定删除模型「${widget.initial.name}」吗？'),
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
    if (confirmed != true) return;
    final s = context.read<SettingsProvider>();
    await s.deleteModel(widget.providerId, widget.initial.id);
    if (!mounted) return;
    showGlassSnackBar(context, '模型已删除', success: true);
    Navigator.of(context).pop();
  }
}