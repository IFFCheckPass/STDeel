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
                resolver.openOutputStream(uri)?.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                } ?: throw Exception("无法写入下载目录")
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
