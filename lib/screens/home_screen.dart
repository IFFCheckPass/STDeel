/// 主页 - 思谛 STDeel
///
/// 液态玻璃设计：大按钮（拍照识题 / 从相册选择）
/// 底部导航：首页 / 知识点统计 / 答案库 / 设置
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/solve_provider.dart';
import '../services/image_cache_service.dart';
import '../services/sync_service.dart';
import '../widgets/glass.dart';
import '../widgets/thinking_indicator.dart';
import 'answer_library_screen.dart';
import 'answer_screen.dart';
import 'image_edit_screen.dart';
import 'knowledge_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _picker = ImagePicker();

  static const _titles = ['思谛', '知识点统计', '标准答案库', '设置'];

  @override
  void initState() {
    super.initState();
    // 启动期后台维护：清理超过 15 天的题目图片缓存 + 重试"本地已删、后端待删"
    // 的记录删除。fire-and-forget，不阻塞 UI。
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupMaintenance());
  }

  Future<void> _runStartupMaintenance() async {
    // 先取服务引用，避免 await 之后跨异步间隙使用 context
    final imgCache = context.read<ImageCacheService>();
    final sync = context.read<SyncService>();
    try {
      await imgCache.cleanupExpired();
    } catch (_) {}
    try {
      await sync.flushPendingDeletes();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildHomePage(context),
      const KnowledgeScreen(),
      const AnswerLibraryScreen(),
      const SettingsScreen(),
    ];

    // 大屏（平板 / Windows 桌面窗口较宽）时功能栏置于左侧，小屏保持底部导航
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final appBar = AppBar(title: Text(_titles[_index]));
        final body = IndexedStack(index: _index, children: pages);

        if (useRail) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Icon(Icons.menu_book_rounded,
                        color: G.accent, size: 26),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('首页'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: Text('知识点'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.library_books_outlined),
                      selectedIcon: Icon(Icons.library_books),
                      label: Text('答案库'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('设置'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: '知识点',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books),
                label: '答案库',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomePage(BuildContext context) {
    final solve = context.watch<SolveProvider>();
    final state = solve.state;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isWide ? 720 : double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // 品牌 Logo
                    GlassCard(
                      padding: const EdgeInsets.all(28),
                      radius: 28,
                      glowColor: G.accentDeep,
                      child: Column(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: G.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: G.accentDeep.withOpacity(0.5),
                                  blurRadius: 28,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '思谛',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              color: G.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '拍照识题 · AI 解题 · 多模型自动切换',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: G.textSecondary,
                                  letterSpacing: 1,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    GlassPrimaryButton(
                      icon: Icons.camera_alt_rounded,
                      label: Platform.isWindows ? '选择图片文件' : '拍照识题',
                      onPressed: () =>
                          _pickImage(context, fromCamera: !Platform.isWindows),
                    ),
                    const SizedBox(height: 12),
                    GlassPrimaryButton(
                      icon: Icons.photo_library_outlined,
                      label: '从相册选择',
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.06),
                        ],
                      ),
                      borderColor: G.glassBorder,
                      onPressed: () => _pickImage(context, fromCamera: false),
                    ),
                    const SizedBox(height: 12),
                    GlassPrimaryButton(
                      icon: Icons.history,
                      label: '历史记录',
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.06),
                        ],
                      ),
                      borderColor: G.glassBorder,
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/history'),
                    ),
                    const SizedBox(height: 28),
                    if (state.status == SolveStatus.thinking ||
                        state.status == SolveStatus.answering) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () =>
                            Navigator.of(context).pushNamed('/answer'),
                        child: Tooltip(
                          message: '点击查看解题进程',
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              ThinkingIndicator(
                                isAnswering:
                                    state.status == SolveStatus.answering,
                                modelName: state.currentModel.isEmpty
                                    ? null
                                    : state.currentModel,
                                notice: state.notice,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.touch_app_outlined,
                                      size: 12, color: G.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '点击查看解题进程',
                                    style: TextStyle(
                                        fontSize: 11, color: G.accent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (state.status == SolveStatus.done &&
                        state.result != null)
                      _buildResultSummary(context, state.result!)
                    else if (state.status == SolveStatus.error)
                      GlassCard(
                        fillColor: G.coral.withOpacity(0.08),
                        borderColor: G.coral.withOpacity(0.35),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: G.coral, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '解题失败：${state.error ?? '未知错误'}',
                                style: const TextStyle(
                                    color: G.coral, height: 1.5, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultSummary(BuildContext context, dynamic result) {
    return GlassCard(
      fillColor: G.mint.withOpacity(0.08),
      borderColor: G.mint.withOpacity(0.35),
      glowColor: G.mint,
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: G.mint, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '共识别 ${result.questions.length} 道题，'
              '耗时 ${(result.latencyMs / 1000).toStringAsFixed(1)}s'
              '（${result.aiModel}）',
              style: const TextStyle(color: G.mint, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/answer'),
            child: const Text('查看'),
          ),
        ],
      ),
    );
  }

  /// 原生相册通道（Android）：ACTION_PICK 恒定拉起系统「相册」选择界面。
  /// image_picker 0.8.13+ 在无 Android Photo Picker 的设备（荣耀/HarmonyOS 等）
  /// 会退化为 ACTION_GET_CONTENT → 打开的是文件选择器，因此相册走原生通道。
  static const MethodChannel _galleryChannel = MethodChannel('stdeel/gallery');

  Future<void> _pickImage(
    BuildContext context, {
    required bool fromCamera,
  }) async {
    // Android 相册：优先原生 ACTION_PICK（保持相册选择界面），失败回退 image_picker
    if (!fromCamera && Platform.isAndroid) {
      try {
        final path = await _galleryChannel.invokeMethod<String>('pick');
        if (path == null || path.isEmpty) return; // 用户取消，静默结束
        await _openEditor(context, path);
        return;
      } on PlatformException {
        // 原生通道不可用（如 ROM 限制）：回退 image_picker
      } on MissingPluginException {
        // 通道未注册：回退 image_picker
      }
    }
    // 直接调起系统相机/相册（不再经 CameraScreen 中间页，避免可见残留）。
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;
      showGlassSnackBar(context, '打开相机/相册失败', error: true);
      return;
    }
    if (file == null || !mounted) return;
    await _openEditor(context, file.path);
  }

  /// 选图完成后：先进入编辑页（裁切/旋转），编辑完再进入 AnswerScreen 触发解题
  Future<void> _openEditor(BuildContext context, String imagePath) async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ImageEditScreen(imagePath: imagePath),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnswerScreen(imagePath: picked),
      ),
    );
  }
}
