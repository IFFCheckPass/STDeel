/// 供应商编辑页 - 思谛 STDeel
///
/// 管理一个供应商：名称、Base URL、API Key、关联模型列表、连通性测试。
/// 模型在本页的本地列表 `_models` 中维护（添加/编辑/删除均先改本地），
/// 点击「保存供应商」时把整个供应商（含全部模型）一次性写入 [SettingsProvider]，
/// 从而避免「未保存的新供应商找不到」以及「同引用清空」两类模型丢失 bug。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../widgets/glass.dart';
import 'model_edit_screen.dart';

class ProviderEditScreen extends StatefulWidget {
  const ProviderEditScreen({
    super.key,
    required this.initial,
    required this.isNew,
  });

  final AiProvider initial;
  final bool isNew;

  @override
  State<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

class _ProviderEditScreenState extends State<ProviderEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;

  /// 本地维护的模型列表（编辑中）；保存供应商时随 provider 一并落库。
  late List<AiModel> _models;

  bool _obscureKey = true;
  bool _testing = false;
  ({bool ok, int latencyMs, String message})? _testResult;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _urlCtrl = TextEditingController(text: widget.initial.baseUrl);
    _keyCtrl = TextEditingController(text: widget.initial.apiKey);
    _models = List.of(widget.initial.models);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  String get _providerName =>
      _nameCtrl.text.trim().isEmpty ? '未命名供应商' : _nameCtrl.text.trim();

  AiProvider _buildProvider() => AiProvider(
        id: widget.initial.id,
        name: _providerName,
        baseUrl: normalizeBaseUrl(_urlCtrl.text),
        apiKey: _keyCtrl.text.trim(),
        models: List.of(_models),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.read<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '添加供应商' : '编辑供应商'),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: '删除供应商',
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
            GlassSectionTitle('供应商信息'),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '供应商名称',
                      hintText: '如：DeepSeek、通义千问',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.deepseek.com/v1',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyCtrl,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check, size: 18),
                    label: Text(_testing ? '测试中…' : '测试连通性'),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    _testResultCard(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlassSectionTitle('模型（${_models.length} 个）'),
            if (_models.isEmpty)
              GlassCard(
                child: Column(
                  children: [
                    Icon(Icons.smart_toy_outlined,
                        color: G.textFaint, size: 36),
                    const SizedBox(height: 8),
                    Text('尚未添加模型',
                        style: TextStyle(color: G.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _addModel,
                      icon: const Icon(Icons.add),
                      label: const Text('添加模型'),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_models.length, (i) {
                final m = _models[i];
                return GlassCard(
                  child: ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: m.multimodal ? G.mint : G.accentDeep,
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    title: Text(
                      userModelName(s.providers, _buildProvider(), m),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      m.multimodal ? '多模态' : '非多模态',
                      style: TextStyle(fontSize: 11, color: G.textSecondary),
                    ),
                    trailing: Icon(Icons.edit_outlined,
                        color: G.textFaint, size: 18),
                    onTap: () => _editModel(m),
                  ),
                );
              }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addModel,
              icon: const Icon(Icons.add),
              label: const Text('添加模型'),
            ),
            const SizedBox(height: 24),
            GlassPrimaryButton(
              icon: Icons.check_rounded,
              label: '保存供应商',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _testResultCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (_testResult!.ok ? G.mint : G.coral).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (_testResult!.ok ? G.mint : G.coral).withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_testResult!.ok ? Icons.check_circle : Icons.cancel,
              color: _testResult!.ok ? G.mint : G.coral, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _testResult!.message,
              style: TextStyle(
                fontSize: 13,
                color: _testResult!.ok ? G.mint : G.coral,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addModel() async {
    if (_urlCtrl.text.trim().isEmpty) {
      showGlassSnackBar(context, '请先填写 Base URL', error: true);
      return;
    }
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final out = await Navigator.of(context).push<ModelEditOutcome>(
      MaterialPageRoute(
        builder: (_) => ModelEditScreen(
          providerName: _providerName,
          baseUrl: normalizeBaseUrl(_urlCtrl.text),
          apiKey: _keyCtrl.text.trim(),
          initial: AiModel(
            id: 'm-$ts',
            name: '新模型',
            modelId: '',
            multimodal: false,
            solveEnabled: true,
            solveOrder: _models.length,
          ),
          isNew: true,
        ),
      ),
    );
    if (!mounted || out == null) return;
    if (out.deleted) return; // 新建即删除，忽略
    final m = out.model;
    if (m != null) {
      setState(() => _models.add(m));
    }
  }

  Future<void> _editModel(AiModel model) async {
    final out = await Navigator.of(context).push<ModelEditOutcome>(
      MaterialPageRoute(
        builder: (_) => ModelEditScreen(
          providerName: _providerName,
          baseUrl: normalizeBaseUrl(_urlCtrl.text),
          apiKey: _keyCtrl.text.trim(),
          initial: model,
          isNew: false,
        ),
      ),
    );
    if (!mounted || out == null) return;
    if (out.deleted) {
      setState(() => _models.removeWhere((m) => m.id == model.id));
      return;
    }
    final m = out.model;
    if (m != null) {
      setState(() {
        final i = _models.indexWhere((x) => x.id == model.id);
        if (i >= 0) {
          _models[i] = m;
        } else {
          _models.add(m);
        }
      });
    }
  }

  Future<void> _testConnection() async {
    final p = _buildProvider();
    if (p.baseUrl.isEmpty) {
      showGlassSnackBar(context, '请先填写 Base URL', error: true);
      return;
    }
    if (p.models.isEmpty) {
      showGlassSnackBar(context, '请先至少添加一个模型再测试', error: true);
      return;
    }
    final m = p.models.first;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final ai = context.read<AiService>();
      final result = await ai.testConnection(
        baseUrl: p.baseUrl,
        apiKey: p.apiKey,
        modelId: m.modelId,
      );
      if (!mounted) return;
      setState(() => _testResult = result);
      showGlassSnackBar(
        context,
        result.ok ? result.message : '测试失败：${result.message}',
        success: result.ok,
        error: !result.ok,
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final provider = _buildProvider();
    if (provider.baseUrl.isEmpty) {
      showGlassSnackBar(context, 'Base URL 不能为空', error: true);
      return;
    }
    final s = context.read<SettingsProvider>();
    await s.saveProvider(provider);
    if (!mounted) return;
    showGlassSnackBar(context, '供应商「${provider.name}」已保存', success: true);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final p = widget.initial;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除供应商'),
        content: Text('确定删除「${p.name}」及其全部模型吗？该操作不可撤销。'),
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
    await s.deleteProvider(p.id);
    if (!mounted) return;
    showGlassSnackBar(context, '供应商「${p.name}」已删除', success: true);
    Navigator.of(context).pop();
  }
}