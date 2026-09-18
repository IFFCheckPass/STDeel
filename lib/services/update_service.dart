/// 应用内更新服务 - 思谛 STDeel
///
/// 从 GitHub Releases（`IFFCheckPass/STDeel`）拉取最新版本：
///  - 对比本地安装版本，判断是否有新版本
///  - 下载对应更新包并触发安装（Windows 为 .exe 安装器，Android 为 .apk，
///    原生 MethodChannel 触发系统安装器）
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'fault_log_service.dart';

/// GitHub 仓库（Release 源）
const String kUpdateRepoOwner = 'IFFCheckPass';
const String kUpdateRepoName = 'STDeel';

/// 拉取的远端版本信息
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.tagName,
    required this.url,
    required this.pkgUrl,
    required this.pkgSize,
    required this.notes,
    required this.publishedAt,
  });

  /// 远端版本号（不含 v 前缀）
  final String version;

  /// 如 v1.0.0
  final String tagName;

  /// Release 页面链接
  final String url;

  /// 更新包直链（Windows 为 .exe 安装器，Android 为 .apk）
  final String pkgUrl;

  /// 更新包大小（字节）
  final int pkgSize;

  /// Release 说明
  final String notes;

  final String publishedAt;

  bool get hasPkg => pkgUrl.isNotEmpty;

  String get humanPkgSize {
    if (pkgSize <= 0) return '';
    if (pkgSize < 1024 * 1024) return '${(pkgSize / 1024).toStringAsFixed(0)} KB';
    return '${(pkgSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  UpdateService({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  /// 下载专用客户端：与 API 检查客户端隔离。
  ///
  /// GitHub 发布资产会 302 到 CDN（release-assets.githubusercontent.com），
  /// 该 CDN 对浏览器类 UA 最宽容；API 专属的 `Accept: application/vnd.github+json`
  /// 对下载无意义且个别网络/中间设备可能对陌生头敏感，故下载不带它。
  /// 连接超时调短（10s），避免"连接被挂起"时长时间无反馈。
  late final Dio _downloadDio = _buildDownloadDio();

  static const MethodChannel _channel = MethodChannel('stdeel/updater');

  /// 构造带统一配置的 Dio：显式 User-Agent（GitHub 对默认/dio 的 UA 可能拒绝，403 的常见诱因）、
  /// 更长的连接/接收超时、主动跟随重定向。
  static Dio _buildDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'User-Agent': 'STDeel-Android/update-check',
        'Accept': 'application/vnd.github+json',
      },
    ));
    return dio;
  }

  /// 下载客户端：浏览器风格 UA + `Accept: */*`，跟随重定向，短连接超时。
  static Dio _buildDownloadDio() {
    return Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 2),
      sendTimeout: const Duration(seconds: 30),
      followRedirects: true,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        'Accept': '*/*',
      },
    ));
  }

  /// 读取当前安装版本号
  static Future<String> currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '0.0.0';
    }
  }

  /// 简单版本号比较：返回 1 / 0 / -1（a>b / 相等 / a<b）。
  /// 支持形如 `1.0.0`、`0.5.5` 的三段（忽略补丁后的 +build）。
  static int compareVersions(String a, String b) {
    String clean(String s) {
      final i = s.indexOf('+');
      return (i >= 0 ? s.substring(0, i) : s).trim().replaceFirst(RegExp(r'^v'), '');
    }

    final pa = clean(a).split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = clean(b).split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    return 0;
  }

  /// 拉取最新 Release 信息。失败抛异常（可读中文原因）。
  ///
  /// 说明：因版本号 < 1.0.0 发布为 Pre-Release，GitHub 的 `/releases/latest`
  /// 对"只有 pre-release"的仓库会返回 404。因此这里直接拉取 `/releases` 列表，
  /// 取第一项（GitHub 按创建时间倒序），即可拿到最新版本（含 pre-release）。
  Future<AppUpdateInfo> fetchLatest({
    bool includePrerelease = false,
  }) async {
    final listUrl =
        'https://api.github.com/repos/$kUpdateRepoOwner/$kUpdateRepoName/releases';
    try {
      final resp = await _dio.get<List<dynamic>>(
        listUrl,
        queryParameters: {'per_page': 20},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      final list = resp.data ?? const [];
      Map<String, dynamic>? chosen;
      for (final it in list) {
        if (it is! Map) continue;
        final draft = it['draft'] == true;
        final prerelease = it['prerelease'] == true;
        if (draft) continue;
        if (!includePrerelease && prerelease) continue;
        chosen = Map<String, dynamic>.from(it);
        break;
      }
      if (chosen == null) {
        throw '未找到任何已发布版本';
      }
      return _parseRelease(chosen);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final zh = _zhGithubMessage(code);
      FaultLogService.instance.record(
        source: 'GitHub 更新',
        code: code != null ? '$code' : '网络',
        summary: zh,
      );
      throw code == 404
          ? '检查更新失败：GitHub 未找到该仓库的发布（HTTP 404）'
          : code == 403
              ? '检查更新失败：GitHub 访问受限（HTTP 403，多为请求过于频繁被限流）'
              : code == 429
                  ? '检查更新失败：GitHub 触发限流（HTTP 429），请稍后再试'
                  : '检查更新失败：$zh';
    } catch (e) {
      throw '检查更新失败：$e';
    }
  }

  /// 把单个 release JSON 解析为 [AppUpdateInfo]
  AppUpdateInfo _parseRelease(Map<String, dynamic> r) {
    final tag = (r['tag_name'] ?? '').toString();
    final assets = (r['assets'] as List<dynamic>?) ?? const [];
    // Windows 桌面版匹配 .exe 安装器，其余平台匹配 .apk
    final ext = Platform.isWindows ? '.exe' : '.apk';
    String pkgUrl = '';
    int pkgSize = 0;
    for (final a in assets) {
      if (a is Map && (a['name'] ?? '').toString().toLowerCase().endsWith(ext)) {
        if (pkgUrl.isEmpty) {
          pkgUrl = (a['browser_download_url'] ?? '').toString();
          pkgSize = (a['size'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return AppUpdateInfo(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      tagName: tag,
      url: (r['html_url'] ?? '').toString(),
      pkgUrl: pkgUrl,
      pkgSize: pkgSize,
      notes: (r['body'] ?? '').toString(),
      publishedAt: (r['published_at'] ?? '').toString(),
    );
  }

  /// GitHub 常见 HTTP 状态码 → 中文说明
  String _zhGithubMessage(int? code) {
    switch (code) {
      case 403:
        return '访问被拒绝（HTTP 403）——通常为 GitHub API 未带 Token 触发限流，'
            '或所在网络对 api.github.com 有限制，请稍后再试';
      case 404:
        return '资源不存在（HTTP 404）——Release 版本或指定位被移除，'
            '或仓库不可见';
      case 429:
        return '爬取过于频繁（HTTP 429）——已触发限流，请稍后再试';
      case 500:
        return 'GitHub 服务器错误（HTTP 500）';
      case 502:
        return '网关错误（HTTP 502）';
      case 503:
        return '服务暂不可用（HTTP 503）';
      default:
        return code == null ? '网络连接失败，无法访问 GitHub' : 'GitHub 请求失败（HTTP $code）';
    }
  }

  /// 检查是否有可用更新。
  /// @return 有更新返回 [AppUpdateInfo]；无返回 null（抛错则说明无法检查）。
  ///
  /// 本项目版本号 < 1.0.0，一律发布为 Pre-Release（见 AGENTS.md 版本发布规则），
  /// 因此必须 `includePrerelease:true`，否则默认会跳过所有 pre-release，
  /// 导致"未发现任何已发布版本"的假阴性。
  Future<AppUpdateInfo?> checkForUpdate() async {
    final latest = await fetchLatest(includePrerelease: true);
    final current = await currentVersion();
    if (compareVersions(latest.version, current) <= 0) return null;
    return latest;
  }

  /// 下载更新包到本地（返回本地路径），带进度回调。
  /// Windows 下载 .exe 安装器到系统下载目录；Android 先下载到应用缓存目录，
  /// 随后由 [installPackage] 转存到系统公共「下载」目录（MediaStore）并拉起安装器。
  ///
  /// GitHub 发布 CDN 直连偶发"连接被挂起/中断"（表现为进度长时间停在 0%），
  /// 因此采用短连接超时（10s）+ 最多 3 次重试；取消则抛"已取消更新"。
  Future<String> downloadPackage(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    String? fileName,
  }) async {
    // Windows 直接落在系统下载目录（~/Downloads），便于检测与手动兜底安装
    final dir = Platform.isWindows
        ? (await getDownloadsDirectory()) ?? await getTemporaryDirectory()
        : await getTemporaryDirectory();
    final ext = Platform.isWindows ? '.exe' : '.apk';
    final name = fileName ??
        'stdeel_update_${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = p.join(dir.path, name);

    const maxAttempts = 3;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        await Future<void>.delayed(Duration(seconds: 2 * (attempt - 1)));
      }
      try {
        await _downloadDio.download(
          url,
          dest,
          onReceiveProgress: (received, total) =>
              onProgress?.call(received, total),
          cancelToken: cancelToken,
        );
        if (!File(dest).existsSync()) {
          throw '下载失败：未生成 ${Platform.isWindows ? '安装器' : '更新包'} 文件';
        }
        return dest;
      } on DioException catch (e) {
        if (cancelToken?.isCancelled ?? false) {
          throw '已取消更新';
        }
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }

    final err = lastError;
    final msg = err is DioException ? _zhDownloadMessage(err) : '$err';
    FaultLogService.instance.record(
      source: 'GitHub 更新下载',
      code: err is DioException ? '${err.type.name}' : '未知',
      summary: msg,
    );
    throw '更新包下载失败：$msg';
  }

  String _zhDownloadMessage(DioException e) {
    final code = e.response?.statusCode;
    if (code == 403) return '下载被拒绝（HTTP 403），多为下载地址被限流或网络限制';
    if (code == 404) return '下载地址不存在（HTTP 404），版本包可能已被移除';
    if (code == 429) return '下载触发限流（HTTP 429），请稍后再试';
    if (e.type == DioExceptionType.connectionError) return '网络连接中断，请检查网络后重试';
    if (e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionTimeout) {
      return '下载超时';
    }
    return code != null ? 'HTTP $code' : (e.message ?? '未知错误');
  }

  /// 触发安装（Android）。
  ///
  /// 流程：
  ///  1. 通过原生 MethodChannel 把更新包**转存到系统公共「下载」目录**
  ///     （Android 10+ 走 MediaStore，9- 直接写公共下载目录），
  ///     用户可在文件管理器/下载应用里随时找到，系统「清除缓存」不会误删，
  ///     自动安装失败时也方便手动兜底；
  ///  2. 删除缓存目录中的临时下载，避免反复更新积累废弃安装包；
  ///  3. 用系统安装器（ACTION_VIEW + FileProvider/MediaStore content URI）唤起安装。
  ///
  /// 返回保存到下载目录的文件名（供 UI 提示落盘位置）；Windows 直接启动 .exe。
  Future<String?> installPackage(String path, {String? fileName}) async {
    if (Platform.isWindows) {
      try {
        await Process.start(path, const [], mode: ProcessStartMode.detached);
        return p.basename(path);
      } catch (e) {
        throw '启动安装器失败：$e';
      }
    }
    final name = fileName ??
        'stdeel_update_${DateTime.now().millisecondsSinceEpoch}.apk';
    Map<dynamic, dynamic> pub;
    try {
      pub = (await _channel.invokeMethod<Map<dynamic, dynamic>>(
            'publishToDownloads',
            {'sourcePath': path, 'fileName': name},
          )) ??
          const <dynamic, dynamic>{};
    } on PlatformException catch (e) {
      throw '保存更新包失败：${e.message ?? e.code}';
    }
    // 清理缓存目录中的临时下载，防止存储膨胀
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    final uri = (pub['uri'] ?? '').toString();
    final filePath = (pub['path'] ?? '').toString();
    try {
      await _channel.invokeMethod<void>(
        'installPackage',
        {'uri': uri, 'path': filePath},
      );
    } on PlatformException catch (e) {
      throw '安装失败：${e.message ?? e.code}';
    }
    return (pub['fileName'] ?? name).toString();
  }
}