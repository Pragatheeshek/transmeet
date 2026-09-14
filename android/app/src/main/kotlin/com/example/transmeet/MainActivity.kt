package com.example.transmeet

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.transmeet/foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCall" -> {
                    val title = call.argument<String>("title") ?: "TransMeet"
                    val text = call.argument<String>("text") ?: "Meeting in progress"
                    val intent = Intent(this, MeetingForegroundService::class.java).apply {
                        action = MeetingForegroundService.ACTION_START_CALL
                        putExtra(MeetingForegroundService.EXTRA_TITLE, title)
                        putExtra(MeetingForegroundService.EXTRA_TEXT, text)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "startScreenShare" -> {
                    val intent = Intent(this, MeetingForegroundService::class.java).apply {
                        action = MeetingForegroundService.ACTION_START_SCREEN_SHARE
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopScreenShare" -> {
                    val intent = Intent(this, MeetingForegroundService::class.java).apply {
                        action = MeetingForegroundService.ACTION_STOP_SCREEN_SHARE
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    val intent = Intent(this, MeetingForegroundService::class.java).apply {
                        action = MeetingForegroundService.ACTION_STOP_SERVICE
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
