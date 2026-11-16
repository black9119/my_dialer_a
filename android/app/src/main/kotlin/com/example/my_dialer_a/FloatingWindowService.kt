package com.example.my_dialer_a

import android.app.*
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Toast
import androidx.core.app.NotificationCompat

class FloatingWindowService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var floatingView: LinearLayout

    override fun onCreate() {
        super.onCreate()
        startForegroundServiceCompat()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        floatingView = createFloatingView()
        
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE
        val params = WindowManager.LayoutParams(WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT, layoutType, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT).apply { gravity = Gravity.TOP or Gravity.START; x = 100; y = 300 }
        
        try { windowManager.addView(floatingView, params) } catch (e: Exception) { Toast.makeText(this, "悬浮窗失败", Toast.LENGTH_SHORT).show() }
    }

    private fun createFloatingView(): LinearLayout {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xB3000000.toInt())
            setPadding(20, 20, 20, 20)
        }
        
        // 6个按钮（去掉了真实拨号）
        val buttons = listOf(
            "APP语音拨号" to "voip",
            "播放忙音" to "busy",
            "播放空号" to "empty",
            "播放正忙" to "user_busy",
            "静音控制" to "mute",
            "↩️ 返回拨号盘" to "RETURN"
        )

        for ((text, cmd) in buttons) {
            val btn = Button(this).apply {
                this.text = text
                if (cmd == "RETURN") setTextColor(android.graphics.Color.RED)
                setOnClickListener { 
                    if (cmd == "RETURN") {
                        val intent = Intent(this@FloatingWindowService, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP }
                        startActivity(intent)
                        stopSelf()
                    } else {
                        MainActivity.flutterChannel?.invokeMethod("onNativeCommand", cmd)
                        Toast.makeText(applicationContext, "发送: $text", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            layout.addView(btn)
        }
        return layout
    }

    private fun startForegroundServiceCompat() {
        val channelId = "dialer_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "悬浮窗服务", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, channelId).setContentTitle("A端运行中").setContentText("悬浮窗已启动").setSmallIcon(android.R.drawable.ic_menu_compass).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(1, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC) else startForeground(1, notification)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::floatingView.isInitialized) windowManager.removeView(floatingView)
    }
    override fun onBind(intent: Intent?): IBinder? = null
}