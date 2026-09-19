/// 设置页 - 思谛 STDeel
///
/// - AI 模型组合管理（多组合、拖动排序、启用开关）
/// - think 检测超时阈值
/// - 后端 URL 配置 + 连通性测试
/// - 手动同步
/// 所有保存/测试操作均有 SnackBar 反馈。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/ai_combo.dart';
import '../providers/settings_provider.dart';
import '../services/backend_api.dart';
import '../services/fault_log_service.dart';
import '../services/image_cache_service.dart';
import '../services/sync_service.dart';
import '../services/update_service.dart';
import '../widgets/glass.dart';
import 'combo_edit_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _usernameCtrl;
  bool _initialized = false;
  // 首次异步加载完成后只回填一次输入框，避免与用户正在输入冲突。
  bool _didInitialSync = false;
  // 故障码记录是否展开显示全部（默认仅显示两条）
  bool _faultLogExpanded = false;
  // 图片缓存统计
  ImageCacheStats? _cacheStats;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // 先建空控制器，等 SettingsProvider.load() 完成后统一回填，
      // 修复"重启后用户名已绑定但文本框为空 / 内网 URL 被默认公网地址覆盖"
      // 的加载竞态（didChangeDependencies 会随 provider notify 再次触发）。
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

  /// 读取图片缓存占用（用于展示 + 清除后刷新）
  Future<void> _loadCacheStats() async {
    final stats = await context.read<ImageCacheService>().stats();
    if (!mounted) return;
    setState(() => _cacheStats = stats);
  }

  /// 清除题目图片缓存
  Future<void> _clearImageCache() async {
    final img = context.read<ImageCacheService>();
    final count = await img.clearAll().onError((_, __) => 0);
    await _loadCacheStats();
    if (!mounted) return;
    showGlassSnackBar(context, '已清除图片缓存（$count 张）', success: true);
  }

  /// 检查并提示更新（从 GitHub Releases 拉取）
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

  /// 展示"发现新版本"对话框；确认后下载并调用系统安装器
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

  /// 下载更新包并触发安装。
  ///
  /// 修复"下载永远卡在 0%"：旧实现先 `await showDialog`（进度对话框），
  /// 而该对话框只有"取消"能关闭 → 下载代码在对话框关闭前永远不会执行，
  /// 进度只能停在 0%。现在下载与对话框**并行启动**：打开对话框的瞬间即开始
  /// 下载，进度实时回填；完成/失败后对话框自动关闭，用户也可随时取消
  /// （CancelToken 真正中止下载）。
  Future<void> _startUpdate(AppUpdateInfo info) async {
    if (info.pkgUrl.isEmpty) {
      if (!mounted) return;
      showGlassSnackBar(context, '该版本未附带更新包', error: true);
      return;
    }
    final update = UpdateService();
    final cancelToken = CancelToken();
    // null=下载中；true=成功；false=失败
    final progress = ValueNotifier<double>(0);
    final done = ValueNotifier<bool?>(null);
    final errorMsg = ValueNotifier<String?>(null);
    // 更新包保存到系统下载目录后的文件名（用于提示手动兜底）
    final savedName = ValueNotifier<String?>(null);
    final pkgName = 'STDeel_${info.tagName}.apk';

    // 立即启动下载（与对话框并行，进度实时回填）
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
        if (cancelToken.isCancelled) return; // 用户取消，静默退出
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
          // 下载完成/失败：下一帧自动关闭对话框
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
                        Text(
                          '${(p * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : Text(
                    v == true
                        ? '更新包已保存到系统「下载」目录'
                            '（下载/${savedName.value ?? pkgName}），即将拉起安装器。\n'
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
    // 仅在 didChangeDependencies 中初始化；若在首次构建前即被 dispose（极端情况下），
    // 跳过释放以免抛 LateInitializationError。
    if (_initialized) {
      _urlCtrl.dispose();
      _usernameCtrl.dispose();
    }
    super.dispose();
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
          GlassSectionTitle('AI 模型组合', trailing: Text(
            '${s.availableCombos.length}/${s.combos.length} 可用',
            style: TextStyle(fontSize: 12, color: G.textSecondary),
          )),
          GlassCard(
            padding: const EdgeInsets.all(12),
            fillColor: G.glassFill.withOpacity(0.5),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: G.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '解题时按顺序自动尝试启用的组合，超时或失败将自动切换下一个。长按卡片可拖动排序。',
                    style: TextStyle(fontSize: 12, color: G.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (s.combos.isEmpty)
            GlassCard(
              child: Column(
                children: [
                  Icon(Icons.cloud_off, color: G.textFaint, size: 40),
                  const SizedBox(height: 8),
                  Text('暂无组合，点击下方按钮添加', style: TextStyle(color: G.textSecondary)),
                  TextButton(
                    onPressed: _addCombo,
                    child: const Text('添加组合'),
                  ),
                ],
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: s.combos.length,
              onReorder: (oldIndex, newIndex) =>
                  s.moveCombo(oldIndex, newIndex),
              itemBuilder: (context, i) {
                final combo = s.combos[i];
                return _ComboTile(
                  key: ValueKey('combo-${combo.id}'),
                  index: i,
                  combo: combo,
                  onTap: () => _editCombo(combo),
                );
              },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addCombo,
            icon: const Icon(Icons.add),
            label: const Text('添加组合'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          const SizedBox(height: 28),

          // ===== think 超时 =====
          GlassSectionTitle('解题设置'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: G.accent, size: 18),
                    const SizedBox(width: 10),
                    const Text('Think 检测超时', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: G.accentDeep.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${s.thinkTimeout} 秒',
                        style: TextStyle(
                          color: G.accentFg,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
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
                  onChangeEnd: (v) =>
                      showGlassSnackBar(context, '已保存：超时 ${v.round()} 秒', success: true),
                ),
                Text(
                  '模型在此时长内未输出任何内容（含思考与回答）时，自动切换下一组合。API 响应慢可适当调大。',
                  style: TextStyle(fontSize: 12, color: G.textFaint, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ===== 外观（日/夜） =====
          GlassSectionTitle('外观'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.contrast_rounded, color: G.accent, size: 18),
                    const SizedBox(width: 10),
                    const Text('主题模式', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(
                      s.themeMode == ThemeMode.system
                          ? Icons.brightness_auto
                          : Icons.palette_outlined,
                      color: G.accent,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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

          const SizedBox(height: 28),

          // ===== 账号绑定 =====
          GlassSectionTitle('账户'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: G.accent, size: 18),
                    const SizedBox(width: 10),
                    const Text('用户名', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (s.username != null && s.username!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: G.mint.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: G.mint.withOpacity(0.4)),
                        ),
                        child: const Text('已绑定', style: TextStyle(fontSize: 10, color: G.mint)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    hintText: '例如：张三 / student01',
                    prefixIcon: Icon(Icons.badge_outlined),
                    helperText: '设置用户名并绑定账号后，多设备用同一用户名即可共享同一份数据',
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
            ),
          ),

          const SizedBox(height: 28),

          // ===== 后端与数据 =====
          GlassSectionTitle('后端与数据'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 公网 / 内网 通道切换
                Row(
                  children: [
                    const Icon(Icons.public, color: G.accent, size: 18),
                    const SizedBox(width: 10),
                    const Text('后端通道', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 12),
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
                  onSelectionChanged: (sel) =>
                      _selectChannel(context, s, sel.first),
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
                    helperText: '内网支持 http 协议与端口号，如 http://192.168.1.10:8000/api/v1',
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    '示例：\n'
                    '  · 公网：https://api.stdeel.com/api/v1\n'
                    '  · 内网：http://192.168.x.x:8000/api/v1（同网段直连调试）\n'
                    '保存时自动补全协议、去掉尾部斜杠，路径前缀与端口号原样保留。',
                    style: TextStyle(fontSize: 11, color: G.textFaint, height: 1.5),
                  ),
                ),
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
            ),
          ),
          const SizedBox(height: 12),

          // ===== 存储与缓存 =====
          GlassSectionTitle('存储与缓存'),
          GlassCard(
            child: Column(
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
                  '解题时拍摄/选用的图片会临时缓存在本地（供重答、疑问时读取完整题干选项与图表），超过 15 天自动清理。',
                  style: TextStyle(fontSize: 12, color: G.textFaint, height: 1.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _clearImageCache,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('清除图片缓存'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ===== 关于 / 更新 =====
          GlassSectionTitle('关于 / 更新'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.system_update_alt,
                        color: G.accent, size: 18),
                    const SizedBox(width: 10),
                    const Text('应用内更新',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      '版本 v0.7.7',
                      style: TextStyle(fontSize: 12, color: G.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
            ),
          ),

          const SizedBox(height: 12),

          // ===== 故障码记录 =====
          GlassSectionTitle('故障码记录'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bug_report_outlined,
                        color: G.coral, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'AI 调用、GitHub 更新、后端同步等环节出错时自动记录诊断信息。'
                        '列表展示中文概要；点击单条可查看原始返回信息，'
                        '一键复制（含原始返回）便于反馈定位。',
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Consumer<FaultLogService>(
                  builder: (context, logService, _) {
                    final logs = logService.logs;
                    if (logs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: Text(
                          '暂无故障记录',
                          style: TextStyle(
                              fontSize: 12, color: G.textFaint),
                        ),
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
                            Divider(height: 1, color: G.glassBorder.withOpacity(0.4)),
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
                                    style: TextStyle(
                                        fontSize: 12, color: G.accent),
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
                const SizedBox(height: 12),
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
            ),
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              '思谛 STDeel · v0.7.7',
              style: TextStyle(fontSize: 11, color: G.textFaint),
            ),
          ),
        ],
      ),
    );
  }

  /// 绑定 / 同步：设置用户名 → 后端按 username 找或创建用户 → 上传 AI API Key
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
      // 上传本机 AI API Key 到账号（跨端同步），与后端契约对齐：
      // {user_id, api_keys:[{api_key,name,enabled}]}
      final keys = <Map<String, dynamic>>[];
      for (final c in s.combos) {
        if (c.isComplete && c.apiKey.trim().isNotEmpty) {
          keys.add({
            'api_key': c.apiKey.trim(),
            'name': c.name,
            'enabled': c.enabled,
          });
        }
      }
      final api = context.read<BackendApi>();
      final okKey = await api.syncUserApiKeys(keys);
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

  /// 切换公网/内网通道时，把输入框内容切到对应通道的已保存 URL
  void _selectChannel(BuildContext context, SettingsProvider s, bool usePublic) {
    if (s.usePublicBackend == usePublic) return;
    s.setUsePublicBackend(usePublic);
    final target = usePublic ? s.backendUrlPublic : s.backendUrlIntranet;
    _urlCtrl.value = TextEditingValue(
      text: target.isEmpty ? '' : target,
      selection: TextSelection.collapsed(offset: target.length),
    );
  }

  Future<void> _saveUrl(BuildContext context, SettingsProvider s) async {
    // 允许清空：公网地址可为空（仅用内网），内网/公网均可留空回退另一通道
    final raw = _urlCtrl.text.trim();
    final url = raw.isEmpty ? '' : normalizeBaseUrl(raw);
    _urlCtrl.value = TextEditingValue(
      text: url,
      selection: TextSelection.collapsed(offset: url.length),
    );
    if (s.usePublicBackend) {
      await s.setBackendUrlPublic(url);
      showGlassSnackBar(
        context,
        url.isEmpty ? '已清空公网后端 URL（可仅用内网）' : '公网后端 URL 已保存',
        success: true,
      );
    } else {
      await s.setBackendUrlIntranet(url);
      showGlassSnackBar(
        context,
        url.isEmpty ? '已清空内网后端 URL' : '内网后端 URL 已保存',
        success: true,
      );
    }
  }

  Future<void> _ping(BuildContext context, SettingsProvider s) async {
    showGlassSnackBar(context, '正在测试连通性…');
    await s.ping();
    if (!mounted) return;
    if (s.pingOk) {
      showGlassSnackBar(context, '后端连接成功', success: true);
    } else {
      showGlassSnackBar(context, '后端连接失败，请检查 URL 与网络', error: true);
    }
  }

  Future<void> _manualSync(BuildContext context) async {
    final sync = context.read<SyncService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 双向同步：先上传本地未同步记录，再下拉后端缺失记录
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

  Future<void> _addCombo() async {
    final preset = await _pickPreset();
    if (preset == null) return;
    await Navigator.of(context).push<AiCombo>(
      MaterialPageRoute(
        builder: (_) => ComboEditScreen(
          initial: AiCombo(
            id: 'combo-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
            name: preset['name'] as String,
            baseUrl: preset['baseUrl'] as String,
            apiKey: '',
            modelId: preset['modelId'] as String,
          ),
          isNew: true,
        ),
      ),
    );
  }

  Future<void> _editCombo(AiCombo combo) async {
    await Navigator.of(context).push<AiCombo>(
      MaterialPageRoute(
        builder: (_) => ComboEditScreen(initial: combo, isNew: false),
      ),
    );
  }

  /// 选择预置模板或空白
  Future<Map<String, String>?> _pickPreset() {
    const presets = <Map<String, String>>[
      {'name': 'DeepSeek', 'baseUrl': 'https://api.deepseek.com/v1', 'modelId': 'deepseek-chat'},
      {'name': '通义千问 VL', 'baseUrl': 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'modelId': 'qwen-vl-plus'},
      {'name': 'NVIDIA NIM', 'baseUrl': 'https://integrate.api.nvidia.com/v1', 'modelId': 'qwen/qwen2.5-vl-72b-instruct'},
      {'name': '智谱 GLM', 'baseUrl': 'https://open.bigmodel.cn/api/paas/v4', 'modelId': 'glm-4v-plus'},
      {'name': '硅基流动', 'baseUrl': 'https://api.siliconflow.cn/v1', 'modelId': 'Qwen/Qwen2.5-VL-72B-Instruct'},
      {'name': '自定义', 'baseUrl': '', 'modelId': ''},
    ];
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('选择预置组合（API Key 均需自行填写）',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            for (final p in presets)
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(
                  p['name'] == '自定义' ? Icons.edit_note : Icons.bolt,
                  color: G.accent,
                ),
                title: Text(p['name']!),
                subtitle: p['baseUrl']!.isEmpty ? null : Text(
                  p['baseUrl']!,
                  style: TextStyle(fontSize: 12, color: G.textFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
  }

  /// 复制全部故障码记录到剪贴板，便于用户反馈定位问题
  Future<void> _copyFaultLogs() async {
    final logs = context.read<FaultLogService>().logs;
    if (logs.isEmpty) {
      showGlassSnackBar(context, '暂无故障码记录可复制', error: true);
      return;
    }
    final header = '思谛 STDeel 故障码记录（${DateTime.now().toLocal()}）';
    final body = logs.map((l) => l.toClipboardText()).join('\n');
    final text = '$header\n$body';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showGlassSnackBar(context, '已复制 ${logs.length} 条故障码记录', success: true);
  }

  /// 清空全部故障码记录
  Future<void> _clearFaultLogs() async {
    await context.read<FaultLogService>().clear();
    if (!mounted) return;
    showGlassSnackBar(context, '已清空故障码记录', success: true);
  }
}

/// 单条故障码记录卡片；点击后弹窗展示原始故障返回信息
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
              child: Text(
                '${log.code}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: G.coral,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[${log.source}] ${log.timeText}',
                    style: TextStyle(fontSize: 11, color: G.textFaint),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.summary,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.open_in_full_rounded,
                  size: 14, color: G.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// 屏幕中间弹出单条故障详情（含原始故障返回信息），可一键复制
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
              SelectableText(
                log.detail,
                style: const TextStyle(fontSize: 12.5, height: 1.6),
              ),
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

/// 组合卡片（可拖动排序）
class _ComboTile extends StatelessWidget {
  const _ComboTile({
    super.key,
    required this.index,
    required this.combo,
    required this.onTap,
  });

  final int index;
  final AiCombo combo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final ready = combo.enabled && combo.isComplete;

    return Padding(
      // ReorderableListView 不处理 item 间距，用 padding 模拟
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        radius: 18,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                // 拖动手柄
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drag_indicator, color: G.textFaint, size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                // 序号 + 状态
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ready
                        ? G.primaryGradient
                        : null,
                    color: ready ? null : G.glassFillStrong,
                    border: ready ? null : Border.all(color: G.glassBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: ready ? Colors.white : G.textFaint,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 名称 + 详情
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              combo.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (combo.multimodal) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: G.mint.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: G.mint.withOpacity(0.4)),
                              ),
                              child: const Text(
                                '多模态',
                                style: TextStyle(fontSize: 9, color: G.mint),
                              ),
                            ),
                          ],
                          if (!combo.isComplete) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: G.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: G.amber.withOpacity(0.4)),
                              ),
                              child: const Text(
                                '待完善',
                                style: TextStyle(fontSize: 9, color: G.amber),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        combo.modelId.isEmpty ? '未设置模型' : combo.modelId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: G.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: combo.enabled,
                  onChanged: (v) => s.toggleCombo(combo.id, v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
