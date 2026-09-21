package com.stdeel.steel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * 解题前台服务 - 思谛 STDeel
 *
 * 修复「应用放入后台 / 打开其他软件后 AI 流式回答必断」的 t0 级问题：
 *  - Android（尤其荣耀/鸿蒙等国产 ROM）对后台应用执行激进冻结（App Freeze /
 *    App Standby），进程被挂起后正在进行的 AI 流式连接被系统切断；
 *  - 本服务在解题期间以前台服务形式运行 + 持有 PARTIAL_WAKE_LOCK，
 *    将应用进程提升为「前台」优先级，系统不会冻结进程或挂起网络，
 *    保证 AI 流在后台继续正常输出；
 *  - 解题结束（成功/失败/取消）后由 Dart 侧调用 stop 停止服务并释放唤醒锁。
 */
class SolveForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "stdeel_solve"
        private const val NOTIFICATION_ID = 1001

        private var wakeLock: PowerManager.WakeLock? = null

        /** 启动前台服务（幂等：已在运行时不做任何事）。 */
        fun start(context: Context, title: String, text: String) {
            val intent = Intent(context, SolveForegroundService::class.java)
                .putExtra("title", title)
                .putExtra("text", text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** 停止前台服务（幂等：未运行时忽略）。
         *  用 stopService 而非 startService：解题结束时应用可能已在后台，
         *  Android 8+ 禁止后台 startService 会抛 IllegalStateException；
         *  stopService 从后台调用无限制，且会触发 onDestroy 释放唤醒锁。 */
        fun stop(context: Context) {
            val intent = Intent(context, SolveForegroundService::class.java)
            context.stopService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title")?.takeIf { it.isNotBlank() }
            ?: "思谛正在解题"
        val text = intent?.getStringExtra("text")?.takeIf { it.isNotBlank() }
            ?: "AI 正在后台思考，请稍候…"
        acquireWakeLock()
        startAsForeground(title, text)
        return START_STICKY
    }

    /** 持有 PARTIAL_WAKE_LOCK：即使屏幕熄灭 / 应用后台，CPU 保持唤醒，网络不挂起。 */
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "stdeel:solve")
        lock.setReferenceCounted(false)
        lock.acquire()
        wakeLock = lock
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    /** 以低打扰通知启动前台服务（channel 低重要性，不弹出打扰）。 */
    private fun startAsForeground(title: String, text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "后台解题",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "AI 后台解题时显示，避免系统冻结进程"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }

        // 点击通知回到应用
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification: Notification =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                Notification.Builder(this)
            }.setContentTitle(title)
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_popup_sync)
                .setOngoing(true)
                .setContentIntent(pi)
                .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }
}
