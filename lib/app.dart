/// 应用根组件 - 思谛 STDeel
///
/// 通过 MultiProvider 在启动时一次性注入所有服务与 Provider，
/// 服务依赖均为单例，不需要 ProxyProvider 的"依赖变更回放"语义。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/database.dart';
import 'providers/settings_provider.dart';
import 'providers/solve_provider.dart';
import 'screens/answer_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'services/ai_service.dart';
import 'services/backend_api.dart';
import 'services/document_split_service.dart';
import 'services/failover_manager.dart';
import 'services/fault_log_service.dart';
import 'services/image_cache_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'widgets/glass.dart';

class StdeelApp extends StatelessWidget {
  const StdeelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final themeMode = settings.loaded ? settings.themeMode : ThemeMode.system;
    return MaterialApp(
      title: '思谛',
      debugShowCheckedModeBanner: false,
      theme: G.theme(Brightness.light),
      darkTheme: G.theme(Brightness.dark),
      // 跟随系统，或由设置页手动选择白天/夜间
      themeMode: themeMode,
      builder: (context, child) {
        // 同步平台亮度到设计令牌；手动选择白天/夜间时强制覆盖。
        final platformBrightness =
            MediaQuery.maybeOf(context)?.platformBrightness ??
                Brightness.dark;
        G.brightness = themeMode == ThemeMode.dark
            ? Brightness.dark
            : themeMode == ThemeMode.light
                ? Brightness.light
                : platformBrightness;
        return GlassBackground(child: child);
      },
      home: const HomeScreen(),
      routes: {
        '/answer': (_) => const AnswerScreen(),
        '/history': (_) => const HistoryScreen(),
      },
    );
  }
}

/// 启动期注入依赖；服务之间通过构造函数装配好，
/// 子组件只读即可，避免 ProxyProvider 的复杂签名与潜在误用。
class AppProviders extends StatelessWidget {
  const AppProviders({
    super.key,
    required this.child,
    this.notificationService,
  });

  final Widget child;
  final NotificationService? notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>(create: (_) => AppDatabase.instance),
        Provider<FaultLogService>(
          create: (_) => FaultLogService.instance..load(),
        ),
        Provider<BackendApi>(create: (_) => BackendApi()),
        Provider<AiService>(create: (_) => AiService()),
        Provider<DocumentSplitService>(
          create: (ctx) =>
              DocumentSplitService(aiService: ctx.read<AiService>()),
        ),
        Provider<ImageCacheService>(
          create: (_) => ImageCacheService(),
        ),
        Provider<NotificationService>(
          // main() 已对注入实例 await init()；传入则复用，避免重复初始化。
          create: (_) => notificationService ?? NotificationService(),
        ),
        Provider<SyncService>(
          create: (ctx) => SyncService(
            database: ctx.read<AppDatabase>(),
            backendApi: ctx.read<BackendApi>(),
          ),
        ),
        Provider<FailoverManager>(
          create: (ctx) => FailoverManager(
            aiService: ctx.read<AiService>(),
            notificationService: ctx.read<NotificationService>(),
          ),
        ),
        ChangeNotifierProvider<SolveProvider>(
          create: (ctx) => SolveProvider(
            failoverManager: ctx.read<FailoverManager>(),
            syncService: ctx.read<SyncService>(),
            notificationService: ctx.read<NotificationService>(),
            database: ctx.read<AppDatabase>(),
            backendApi: ctx.read<BackendApi>(),
          ),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (ctx) =>
              SettingsProvider(backendApi: ctx.read<BackendApi>())..load(),
        ),
      ],
      child: child,
    );
  }
}
