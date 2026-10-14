/// 模型编辑页 - 思谛 STDeel
///
/// 编辑一个模型：API model id、自定义名称。可从供应商端点拉取模型列表并即时
/// 连通性测试。
///
/// v0.9.6 起移除「多模态开关 / 拆图分割-读题解答两阶段启用」：解题一律整图
/// 直发模型（多模态直答），模型不再区分多模态属性，启停统一在「模型调用顺序」页。
///
/// 本页 **不直接写入** SettingsProvider（避免未保存的新供应商找不到而抛异常），
/// 而是通过 `Navigator.pop` 把编辑结果 `({AiModel? model, bool deleted})` 返回给
/// 供应商编辑页，由供应商页在「保存供应商」时一并落库。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart' show AiModel;
import '../services/ai_service.dart';
import '../widgets/glass.dart';

/// 模型编辑结果
typedef ModelEditOutcome = ({AiModel? model, bool deleted});

class ModelEditScreen extends StatefulWidget {
  const ModelEditScreen({
    super.key,
    required this.providerName,
    required this.baseUrl,
    required this.apiKey,
    required this.initial,
    required this.isNew,
  });

  final String providerName;
  final String baseUrl;
  final String apiKey;
  final AiModel initial;
  final bool isNew;

  @override
  State<ModelEditScreen> createState() => _ModelEditScreenState();
}

class _ModelEditScreenState extends State<ModelEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelCtrl;
  bool _fetchingModels = false;
  bool _testing = false;
  ({bool ok, int latencyMs, String message})? _testResult;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _modelCtrl = TextEditingController(text: widget.initial.modelId);
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
        // v0.9.6 起所有模型统一按多模态直答处理，不再区分
        multimodal: true,
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
                  const SizedBox(height: 12),
                  // 连通性测试：针对当前正在编辑的这个模型即时验证
                  FilledButton.icon(
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_testResult!.ok ? G.mint : G.coral)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_testResult!.ok ? G.mint : G.coral)
                              .withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _testResult!.ok
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: _testResult!.ok ? G.mint : G.coral,
                            size: 18,
                          ),
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
                    ),
                  ],
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
    if (widget.baseUrl.trim().isEmpty) {
      showGlassSnackBar(context, '请先为供应商填写 Base URL', error: true);
      return;
    }
    setState(() => _fetchingModels = true);
    try {
      final ai = context.read<AiService>();
      final models =
          await ai.fetchModels(baseUrl: widget.baseUrl, apiKey: widget.apiKey);
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

  /// 连通性测试：用当前输入的 Model ID（允许未保存）即时验证该模型可达性
  Future<void> _testConnection() async {
    final modelId = _modelCtrl.text.trim();
    if (widget.baseUrl.trim().isEmpty) {
      showGlassSnackBar(context, '请先为供应商填写 Base URL', error: true);
      return;
    }
    if (modelId.isEmpty) {
      showGlassSnackBar(context, '请先填写 Model ID', error: true);
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final ai = context.read<AiService>();
      final result = await ai.testConnection(
        baseUrl: widget.baseUrl,
        apiKey: widget.apiKey,
        modelId: modelId,
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

  void _save() {
    final model = _buildModel();
    if (model.modelId.isEmpty) {
      showGlassSnackBar(context, 'Model ID 不能为空', error: true);
      return;
    }
    Navigator.of(context).pop<ModelEditOutcome>(
      (model: model, deleted: false),
    );
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
    Navigator.of(context).pop<ModelEditOutcome>(
      (model: null, deleted: true),
    );
  }
}