package com.stdeel.steel

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        // 相册选择请求码（避开 image_picker 使用的 2342/2343 等区间）
        private const val GALLERY_REQUEST = 4201
    }

    /// 相册选择进行中的 Dart 回调（ACTION_PICK 异步返回结果）
    private var galleryResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stdeel/updater",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // 应用内更新：把更新包转存到系统公共「下载」目录
                "publishToDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath") ?: ""
                    val fileName = call.argument<String>("fileName") ?: ""
                    publishToDownloads(this, sourcePath, fileName, result)
                }
                // 应用内更新：用 FileProvider / MediaStore content URI 拉起系统安装器
                "installPackage" -> {
                    val uri = call.argument<String>("uri") ?: ""
                    val path = call.argument<String>("path") ?: ""
                    installPackage(this, uri, path, result)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stdeel/solve_service",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // 后台解题：启动前台服务（防国产 ROM 冻结进程 + CPU 唤醒锁防 Doze 断网）
                "start" -> {
                    val title = call.argument<String>("title") ?: "思谛正在解题"
                    val text = call.argument<String>("text") ?: "AI 正在后台思考，请稍候…"
                    SolveForegroundService.start(this, title, text)
                    result.success(true)
                }
                // 解题结束：停止前台服务并释放唤醒锁
                "stop" -> {
                    SolveForegroundService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stdeel/gallery",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // 从相册选图：用 ACTION_PICK 恒定拉起系统「相册」选择界面。
                // （image_picker 高版本在无 Android Photo Picker 的设备上会退化
                //  为 ACTION_GET_CONTENT → 打开的是文件选择器，非相册。）
                "pick" -> {
                    if (galleryResult != null) {
                        result.error("BUSY", "相册选择正在进行中", null)
                        return@setMethodCallHandler
                    }
                    galleryResult = result
                    val intent = Intent(Intent.ACTION_PICK).apply {
                        setDataAndType(
                            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                            "image/*",
                        )
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    try {
                        startActivityForResult(intent, GALLERY_REQUEST)
                    } catch (e: Exception) {
                        galleryResult = null
                        result.error("NO_GALLERY", e.message ?: "无法打开相册", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != GALLERY_REQUEST) return
        val cb = galleryResult ?: return
        galleryResult = null
        // 用户取消或未返回内容：success(null)，Dart 侧静默结束
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            cb.success(null)
            return
        }
        try {
            val uri = data.data!!
            val mime = contentResolver.getType(uri) ?: "image/jpeg"
            val ext = when (mime) {
                "image/png" -> "png"
                "image/webp" -> "webp"
                "image/gif" -> "gif"
                "image/heic", "image/heif" -> "heic"
                else -> "jpg"
            }
            // ACTION_PICK 返回的是临时授权的 content:// URI，必须立即拷贝到应用缓存，
            // 否则授权在 Activity 结束后失效
            val dest = File(cacheDir, "gallery_${System.currentTimeMillis()}.$ext")
            contentResolver.openInputStream(uri)?.use { input ->
                dest.outputStream().use { input.copyTo(it) }
            } ?: throw Exception("无法读取相册图片")
            if (dest.length() <= 0) {
                dest.delete()
                throw Exception("相册图片为空")
            }
            cb.success(dest.absolutePath)
        } catch (e: Exception) {
            cb.error("COPY_FAILED", e.message ?: "读取相册图片失败", null)
        }
    }

    /**
     * 把更新包发布到系统公共「下载」目录：
     *  - Android 10+（Q）：通过 MediaStore.Downloads 写入，无需任何存储权限，
     *    文件进入系统下载索引，用户可在「下载」应用/文件管理器直接看到，
     *    系统「清除缓存」不会删除，自动安装失败可手动兜底；
     *  - Android 9-：直接写 Environment.DIRECTORY_DOWNLOADS（清单已声明
     *    WRITE_EXTERNAL_STORAGE，maxSdkVersion=28）。
     * 返回 {"uri", "path", "fileName"}：uri 优先（content://，安装直接用），
     * 低版本返回 path 供 FileProvider 生成授权 URI。
     */
    private fun publishToDownloads(
        activity: Activity,
        sourcePath: String,
        fileName: String,
        result: MethodChannel.Result,
    ) {
        try {
            val src = File(sourcePath)
            if (!src.exists()) {
                result.error("PUBLISH_FAILED", "更新包源文件不存在：$sourcePath", null)
                return
            }
            val safeName = fileName.ifBlank {
                "stdeel_update_${System.currentTimeMillis()}.apk"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, safeName)
                    put(MediaStore.Downloads.MIME_TYPE, "application/vnd.android.package-archive")
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val resolver = activity.contentResolver
                val uri = resolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values,
                ) ?: throw Exception("无法在下载目录创建条目")
                val srcLen = src.length()
                resolver.openOutputStream(uri)?.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                } ?: throw Exception("无法写入下载目录")
                // 完整性校验：转存结果必须与源文件大小一致，防止截断导致
                // 安装器报"没有证书/解析失败"
                val copiedLen = resolver.openAssetFileDescriptor(uri, "r")?.length ?: -1L
                if (copiedLen != srcLen) {
                    resolver.delete(uri, null, null)
                    throw Exception("更新包转存不完整（$copiedLen/$srcLen 字节），已清理")
                }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                result.success(
                    mapOf(
                        "uri" to uri.toString(),
                        "path" to "",
                        "fileName" to safeName,
                    ),
                )
            } else {
                val dir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS,
                )
                if (!dir.exists()) dir.mkdirs()
                val dest = File(dir, safeName)
                src.copyTo(dest, overwrite = true)
                if (dest.length() != src.length()) {
                    dest.delete()
                    throw Exception("更新包转存不完整（${dest.length()}/${src.length()} 字节），已清理")
                }
                result.success(
                    mapOf(
                        "uri" to "",
                        "path" to dest.absolutePath,
                        "fileName" to safeName,
                    ),
                )
            }
        } catch (e: Exception) {
            result.error("PUBLISH_FAILED", e.message ?: "发布到下载目录失败", null)
        }
    }

    private fun installPackage(
        activity: Activity,
        uriString: String,
        path: String,
        result: MethodChannel.Result,
    ) {
        try {
            val uri: Uri = if (uriString.isNotBlank()) {
                // MediaStore content URI（Android 10+）：直接授予系统安装器读权限
                Uri.parse(uriString)
            } else {
                val file = File(path)
                if (!file.exists()) {
                    result.error("INSTALL_FAILED", "APK 文件不存在：$path", null)
                    return
                }
                // Android 9-：FileProvider 暴露公共下载目录中的 APK
                FileProvider.getUriForFile(
                    activity,
                    activity.packageName + ".fileprovider",
                    file,
                )
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                // 部分国产 ROM 需要此标识才会弹安装确认
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
            }
            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message, null)
        }
    }
}
