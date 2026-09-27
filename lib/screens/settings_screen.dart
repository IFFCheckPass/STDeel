/// 设置页 - 思谛 STDeel（v0.9.0 卡片化）
///
/// 每类设置收纳为「可点击展开」的卡片，折叠时仅显示一行标题与关键摘要，
/// 减少屏幕空间占用。点击标题展开全部配置。
///
/// 各类目：AI 模型组合、解题设置、外观、账户、后端与数据、存储与缓存、关于/更新、故障码记录。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../models/ai_provider.dart' show normalizeBaseUrl;
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import '../services/backend_api.dart';
import '../services/fault_log_service.dart';
import '../services/image_cache_service.dart';
import '../services/sync_service.dart';
import '../services/update_service.dart';
import '../widgets/glass.dart';
import 'provider_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _usernameCtrl;
  bool _initialized = false;
  bool _didInitialSync = false;
  bool _faultLogExpanded = false;
  ImageCacheStats? _cacheStats;

  // 卡片展开状态（默认：存储与缓存折叠，其余折叠）
  final Set<String> _expanded = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _urlCtrl = TextEditingController();
      _usernameCtrl = TextEditingController();
      _initialized = true;
      _loadCacheStats();
    }
    final s = context.read<SettingsProvider>();
    if (s.loaded && !_didInitialSync) {
      _didInitialSync = true;
      _urlCtrl.text = s.backendUrl;
      _usernameCtrl.text = s.username ?? '';
    }
  }

  Future<void> _loadCacheStats() async {
    final stats = await context.read<ImageCacheService>().stats();
    if (!mounted) return;
    setState(() => _cacheStats = stats);
  }

  Future<void> _clearImageCache() async {
    final img = context.read<ImageCacheService>();
    final count = await img.clearAll().onError((_, __) => 0);
    await _loadCacheStats();
    if (!mounted) return;
    showGlassSnackBar(context, '已清除图片缓存（$count 张）', success: true);
  }

  Future<void> _checkUpdate() async {
    showGlassSnackBar(context, '正在检查更新…');
    try {
      final info = await UpdateService().checkForUpdate();
      if (!mounted) return;
      if (info == null) {
        showGlassSnackBar(context, '已是最新版本', success: true);
        return;
      }
      final current = await UpdateService.currentVersion();
      if (!mounted) return;
      _showUpdateDialog(info, current);
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(context, '检查更新失败：$e', error: true);
    }
  }

  void _showUpdateDialog(AppUpdateInfo info, String currentVersion) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('发现新版本 ${info.tagName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前版本：$currentVersion\n'
                '新版本：${info.version}\n'
                '${info.pkgUrl.isEmpty ? '' : '包体：${info.humanPkgSize}'}',
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              if (info.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('更新内容：',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(info.notes.trim(),
                    style: const TextStyle(fontSize: 13, height: 1.6)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('暂不更新'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startUpdate(info);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _startUpdate(AppUpdateInfo info) async {
    if (info.pkgUrl.isEmpty) {
      if (!mounted) return;
      showGlassSnackBar(context, '该版本未附带更新包', error: true);
      return;
    }
    final update = UpdateService();
    final cancelToken = CancelToken();
    final progress = ValueNotifier<double>(0);
    final done = ValueNotifier<bool?>(null);
    final errorMsg = ValueNotifier<String?>(null);
    final savedName = ValueNotifier<String?>(null);
    final pkgName = 'STDeel_${info.tagName}.apk';

    unawaited(() async {
      try {
        final path = await update.downloadPackage(
          info.pkgUrl,
          onProgress: (received, total) =>
              progress.value = total > 0 ? received / total : 0,
          cancelToken: cancelToken,
          fileName: pkgName,
          expectedSize: info.pkgSize,
        );
        final name = await update.installPackage(path, fileName: pkgName);
        savedName.value = name;
        done.value = true;
      } catch (e) {
        if (cancelToken.isCancelled) return;
        errorMsg.value = '$e';
        done.value = false;
      }
    }());

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<bool?>(
        valueListenable: done,
        builder: (ctx, v, _) {
          if (v != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) Navigator.pop(ctx, v);
            });
          }
          final error = errorMsg.value;
          return AlertDialog(
            title: Text(
              v == null
                  ? '正在下载更新…'
                  : (v == true ? '下载完成' : '下载失败'),
            ),
            content: v == null
                ? ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (ctx, p, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(value: p > 0 ? p : null),
                        const SizedBox(height: 10),
                        Text('${(p * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )
                : Text(
                    v == true
                        ? '更新包已保存到系统「下载」目录（下载/${savedName.value ?? pkgName}），即将拉起安装器。'
                            '若未自动安装，可在文件管理器中找到该文件手动安装。'
                        : '更新失败：$error',
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
            actions: [
              if (v == null)
                TextButton(
                  onPressed: () {
                    cancelToken.cancel();
                    Navigator.pop(ctx, false);
                  },
                  child: const Text('取消'),
                )
              else
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, v),
                  child: const Text('确定'),
                ),
            ],
          );
        },
      ),
    );

    final err = errorMsg.value;
    progress.dispose();
    done.dispose();
    errorMsg.dispose();
    savedName.dispose();

    if (!mounted) return;
    if (ok == true) {
      showGlassSnackBar(
        context,
        '已拉起系统安装器，请按提示完成安装。更新包保存在「下载」目录'
        '（${savedName.value ?? pkgName}），若未自动安装可在文件管理器中手动打开。',
        success: true,
      );
    } else if (ok == false) {
      showGlassSnackBar(
        context,
        err == null ? '已取消更新' : '更新失败：$err',
        error: err != null,
      );
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _urlCtrl.dispose();
      _usernameCtrl.dispose();
    }
    super.dispose();
  }

  void _toggle(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== AI 模型组合 =====
          _ExpCard(
            title: 'AI 模型组合',
            summary:
                '${s.availableModelCount} 个模型可用 · 点击配置供应商与调用顺序',
            icon: Icons.auto_awesome,
            expanded: _expanded.contains('ai'),
            onToggle: () => _toggle('ai'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '供应商化配置模型：每个供应商含 Base URL / API Key / 多个模型，'
                  '模型以「编号 + 供应商名 + 模型名」展示；可独立配置「拆图分割 / 读题解答」两阶段的顺序与启用。',
                  style: TextStyle(
                      fontSize: 12, color: G.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ProviderConfigScreen()),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('配置 AI 模型组合'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ===== 解题设置 =====
          _ExpCard(
            title: '解题设置',
            summary: 'Think 检测超时 ${s.thinkTimeout} 秒',
            icon: Icons.timer_outlined,
            expanded: _expanded.contains('solve'),
            onToggle: () => _toggle('solve'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Think 检测超时',
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: G.accentDeep.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${s.thinkTimeout} 秒',
                          style: TextStyle(
                              color: G.accentFg,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  ],
                ),
                Slider(
                  value: s.thinkTimeout.clamp(5, 120).toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  activeColor: G.accent,
                  onChanged: (v) => s.setThinkTimeout(v.round()),
                  onChangeEnd: (v) => showGlassSnackBar(
                      context, '已保存：超时 ${v.round()} 秒', success: true),
                ),
                Text(
                  '模型在此时长内未输出任何内容（含思考与回答）时，自动切换下一模型。',
                  style: TextStyle(fontSize: 12, color: G.textFaint, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ===== 外观 =====
          _ExpCard(
            title: '外观',
            summary: s.themeMode == ThemeMode.system
                ? '跟随系统'
                : (s.themeMode == ThemeMode.light ? '日间' : '夜间'),
            icon: Icons.contrast_rounded,
            expanded: _expanded.contains('theme'),
            onToggle: () => _toggle('theme'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('日间'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('跟随系统'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('夜间'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (sel) => s.setThemeMode(sel.first),
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '日间模式采用浅色玻璃卡片；也可自动跟随系统深浅色。',
                  style: TextStyle(fontSize: 12, color: G.textFaint, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ===== 账户 =====
          _ExpCard(
            title: '账户',
            summary: s.username != null && s.username!.isNotEmpty
                ? s.username!
                : '未绑定',
            icon: Icons.person_outline,
            expanded: _expanded.contains('account'),
            onToggle: () => _toggle('account'),
            child: _buildAccount(context, s),
          ),

          const SizedBox(height: 12),

          // ===== 后端与数据 =====
          _ExpCard(
            title: '后端与数据',
            summary: s.usePublicBackend ? '公网通道' : '内网通道',
            icon: Icons.public,
            expanded: _expanded.contains('backend'),
            onToggle: () => _toggle('backend'),
            child: _buildBackend(context, s),
          ),

          const SizedBox(height: 12),

          // ===== 存储与缓存 =====
          _ExpCard(
            title: '存储与缓存',
            summary: _cacheStats == null
                ? '图片缓存 …'
                : '图片缓存 ${_cacheStats!.humanSize} · 本地备份',
            icon: Icons.photo_library_outlined,
            expanded: _expanded.contains('storage'),
            onToggle: () => _toggle('storage'),
            child: _buildStorage(context),
          ),

          const SizedBox(height: 12),

          // ===== 关于 / 更新 =====
          _ExpCard(
            title: '关于 / 更新',
            summary: '版本 v0.9.0',
            icon: Icons.system_update_alt,
            expanded: _expanded.contains('about'),
            onToggle: () => _toggle('about'),
            child: _buildAbout(context),
          ),

          const SizedBox(height: 12),

          // ===== 故障码记录 =====
          _ExpCard(
            title: '故障码记录',
            summary: '诊断信息',
            icon: Icons.bug_report_outlined,
            expanded: _expanded.contains('fault'),
            onToggle: () => _toggle('fault'),
            child: _buildFaultLog(context),
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              '思谛 STDeel · v0.9.0',
              style: TextStyle(fontSize: 11, color: G.textFaint),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 各卡片内容 ----------

  Widget _buildAccount(BuildContext context, SettingsProvider s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _usernameCtrl,
          decoration: const InputDecoration(
            hintText: '例如：张三 / student01',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _saveUsername(context, s),
          icon: const Icon(Icons.link, size: 18),
          label: const Text('绑定 / 同步'),
        ),
        const SizedBox(height: 8),
        Text(
          '绑定后会把本机已配置的 AI API Key 一并上传到该账号，换设备登录后自动拉回。',
          style: TextStyle(fontSize: 11, color: G.textFaint, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildBackend(BuildContext context, SettingsProvider s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              label: Text('公网'),
              icon: Icon(Icons.cloud_outlined),
            ),
            ButtonSegment(
              value: false,
              label: Text('内网'),
              icon: Icon(Icons.router_outlined),
            ),
          ],
          selected: {s.usePublicBackend},
          onSelectionChanged: (sel) => _selectChannel(context, s, sel.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _urlCtrl,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: s.usePublicBackend ? '公网 API URL' : '内网 API URL',
            hintText: s.usePublicBackend
                ? 'https://api.stdeel.com/api/v1'
                : 'http://192.168.1.10:8000/api/v1',
            prefixIcon: Icon(
              s.usePublicBackend ? Icons.public : Icons.apartment,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _saveUrl(context, s),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('保存 URL'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: s.pinging ? null : () => _ping(context, s),
                icon: s.pinging
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: const Text('连通性测试'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: G.glassBorder.withOpacity(0.5)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _manualSync(context),
          icon: const Icon(Icons.sync, size: 18),
          label: const Text('手动同步解题记录（双向）'),
        ),
      ],
    );
  }

  Widget _buildStorage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined,
                color: G.accent, size: 18),
            const SizedBox(width: 10),
            const Text('题目图片缓存',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              _cacheStats == null
                  ? '…'
                  : '${_cacheStats!.count} 张 / ${_cacheStats!.humanSize}',
              style: TextStyle(fontSize: 12, color: G.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '解题时拍摄/选用的图片会临时缓存在本地（供重答、疑问时读取完整题干），超过 15 天自动清理。',
          style: TextStyle(fontSize: 12, color: G.textFaint, height: 1.5),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _clearImageCache,
          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
          label: const Text('清除图片缓存'),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.backup_outlined, color: G.accent, size: 18),
            const SizedBox(width: 10),
            const Text('本地备份',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '将解题记录与知识点掌握度导出为 JSON 文件（离线保存、跨设备迁移），或从备份文件导入恢复。导入会合并且不产生重复记录。',
          style: TextStyle(fontSize: 12, color: G.textFaint, height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportBackup,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('导出备份'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importBackup,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('导入恢复'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAbout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '从 GitHub 拉取最新 Release，检查到新版本后自动下载更新包并拉起系统安装器。',
          style: TextStyle(fontSize: 12, color: G.textFaint, height: 1.5),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _checkUpdate,
          icon: const Icon(Icons.system_update_outlined, size: 18),
          label: const Text('检查更新'),
        ),
      ],
    );
  }

  Widget _buildFaultLog(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Consumer<FaultLogService>(
          builder: (context, logService, _) {
            final logs = logService.logs;
            if (logs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('暂无故障记录',
                    style: TextStyle(fontSize: 12, color: G.textFaint)),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final log in logs
                    .take(_faultLogExpanded ? logs.length : 2)) ...[
                  _FaultLogTile(log: log),
                  if (log !=
                      logs
                          .take(_faultLogExpanded ? logs.length : 2)
                          .last)
                    Divider(
                        height: 1,
                        color: G.glassBorder.withOpacity(0.4)),
                ],
                if (logs.length > 2)
                  InkWell(
                    onTap: () => setState(
                        () => _faultLogExpanded = !_faultLogExpanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _faultLogExpanded
                                ? '收起'
                                : '展开全部（共 ${logs.length} 条）',
                            style:
                                TextStyle(fontSize: 12, color: G.accent),
                          ),
                          Icon(
                            _faultLogExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: G.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyFaultLogs,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('复制全部'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearFaultLogs,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('清空记录'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- 处理函数 ----------

  Future<void> _saveUsername(BuildContext context, SettingsProvider s) async {
    final name = _usernameCtrl.text.trim();
    if (name.isEmpty) {
      showGlassSnackBar(context, '请输入用户名', error: true);
      return;
    }
    showGlassSnackBar(context, '正在绑定账号…');
    final ok = await s.setUsername(name);
    if (!mounted) return;
    if (ok) {
      showGlassSnackBar(context, '账号绑定成功', success: true);
      final api = context.read<BackendApi>();
      final okKey = await api.syncUserApiKeys(const []);
      if (mounted && !okKey) {
        showGlassSnackBar(
          context,
          '用户名已绑定，但 API Key 同步失败（可稍后重试）',
          error: true,
        );
      }
    } else {
      showGlassSnackBar(
        context,
        '后端绑定未成功（后端未适配或网络异常），用户名已保存在本机',
        error: true,
      );
    }
  }

  void _selectChannel(
      BuildContext context, SettingsProvider s, bool usePublic) {
    if (s.usePublicBackend == usePublic) return;
    s.setUsePublicBackend(usePublic);
    final target = usePublic ? s.backendUrlPublic : s.backendUrlIntranet;
    _urlCtrl.value = TextEditingValue(
      text: target.isEmpty ? '' : target,
      selection: TextSelection.collapsed(offset: target.length),
    );
  }

  Future<void> _saveUrl(BuildContext context, SettingsProvider s) async {
    final raw = _urlCtrl.text.trim();
    final url = raw.isEmpty ? '' : normalizeBaseUrl(raw);
    _urlCtrl.value = TextEditingValue(
      text: url,
      selection: TextSelection.collapsed(offset: url.length),
    );
    if (s.usePublicBackend) {
      await s.setBackendUrlPublic(url);
      showGlassSnackBar(context,
          url.isEmpty ? '已清空公网后端 URL（可仅用内网）' : '公网后端 URL 已保存',
          success: true);
    } else {
      await s.setBackendUrlIntranet(url);
      showGlassSnackBar(
          context, url.isEmpty ? '已清空内网后端 URL' : '内网后端 URL 已保存',
          success: true);
    }
  }

  Future<void> _ping(BuildContext context, SettingsProvider s) async {
    showGlassSnackBar(context, '正在测试连通性…');
    await s.ping();
    if (!mounted) return;
    if (s.pingOk) {
      showGlassSnackBar(context, '后端连接成功', success: true);
    } else {
      showGlassSnackBar(
          context, '后端连接失败，请检查 URL 与网络', error: true);
    }
  }

  Future<void> _manualSync(BuildContext context) async {
    final sync = context.read<SyncService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await sync.syncAll();
      final msg = result.hasFailure
          ? '同步完成：上传成功 ${result.uploaded} 条、失败 ${result.uploadFailed} 条，回写 ${result.pulled} 条'
          : '同步成功：上传 ${result.uploaded} 条，回写 ${result.pulled} 条';
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: result.hasFailure ? G.coral : G.mint,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('同步失败：$e')));
    }
  }

  Future<void> _exportBackup() async {
    final service = BackupService(db: AppDatabase.instance);
    try {
      showGlassSnackBar(context, '正在导出…');
      final path = await service.exportBackup();
      if (!mounted) return;
      showGlassSnackBar(context, '备份已导出：$path', success: true);
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(context, '导出失败：$e', error: true);
    }
  }

  Future<void> _importBackup() async {
    final service = BackupService(db: AppDatabase.instance);
    try {
      showGlassSnackBar(context, '正在导入…');
      final r = await service.importBackup();
      if (!mounted) return;
      showGlassSnackBar(
        context,
        '导入完成：解题记录 ${r.solve} 条、知识点 ${r.knowledge} 条',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(context, '导入失败：$e', error: true);
    }
  }

  Future<void> _copyFaultLogs() async {
    final logs = context.read<FaultLogService>().logs;
    if (logs.isEmpty) {
      showGlassSnackBar(context, '暂无故障码记录可复制', error: true);
      return;
    }
    final header = '思谛 STDeel 故障码记录（${DateTime.now().toLocal()}）';
    final body = logs.map((l) => l.toClipboardText()).join('\n');
    await Clipboard.setData(ClipboardData(text: '$header\n$body'));
    if (!mounted) return;
    showGlassSnackBar(context, '已复制 ${logs.length} 条故障码记录', success: true);
  }

  Future<void> _clearFaultLogs() async {
    await context.read<FaultLogService>().clear();
    if (!mounted) return;
    showGlassSnackBar(context, '已清空故障码记录', success: true);
  }
}

/// 可折叠设置卡片
class _ExpCard extends StatelessWidget {
  const _ExpCard({
    required this.title,
    required this.summary,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final String summary;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题行（点击切换展开/折叠）
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(icon, color: G.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    Expanded(
                      child: Text(summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12, color: G.textSecondary)),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: G.textFaint,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// 单条故障码记录卡片
class _FaultLogTile extends StatelessWidget {
  const _FaultLogTile({super.key, required this.log});

  final FaultLog log;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showFaultLogDetail(context, log),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: G.coral.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${log.code}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: G.coral,
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('[${log.source}] ${log.timeText}',
                      style:
                          TextStyle(fontSize: 11, color: G.textFaint)),
                  const SizedBox(height: 2),
                  Text(log.summary,
                      style: const TextStyle(fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_full_rounded,
                size: 14, color: G.textFaint),
          ],
        ),
      ),
    );
  }
}

void _showFaultLogDetail(BuildContext context, FaultLog log) {
  final full = log.toClipboardText();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('[${log.source}] HTTP ${log.code}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('时间：${log.timeText}',
                style: TextStyle(fontSize: 12, color: G.textFaint)),
            const SizedBox(height: 8),
            Text('概要：${log.summary}',
                style: const TextStyle(fontSize: 13, height: 1.5)),
            if (log.detail.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('原始返回信息：',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              SelectableText(log.detail,
                  style: const TextStyle(fontSize: 12.5, height: 1.6)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: full));
            Navigator.pop(ctx);
            showGlassSnackBar(context, '已复制本条故障详情', success: true);
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('复制本条'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}