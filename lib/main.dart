/// 应用入口 - 思谛 STDeel
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/key_value_store.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 关键设置存储初始化（SQLite）+ 一次性迁移旧 SharedPreferences 数据，
  // 必须在任何设置读取之前完成（数据完整性关键，见 AGENTS.md）。
  await KeyValueStore.instance.ensureReady();

  // 锁竖屏（拍照/解题场景）——仅移动端有效
  if (!Platform.isWindows) {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }

  // 初始化本地通知（Failover / 解题完成 / 失败推送）
  // 唯一实例：await init() 后注入 AppProviders 复用，避免双重初始化。
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    AppProviders(
      notificationService: notificationService,
      child: const StdeelApp(),
    ),
  );
}
