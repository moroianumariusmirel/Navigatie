package com.trailpulse.trailpulse

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.trailpulse/download_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownloadForeground" -> {
                    val title = call.argument<String>("title") ?: "Downloading Offline Map"
                    val progress = call.argument<Int>("progress") ?: 0
                    val text = call.argument<String>("text") ?: "Transferring map data..."
                    DownloadForegroundService.startService(applicationContext, title, progress, text)
                    result.success(true)
                }
                "updateDownloadProgress" -> {
                    val title = call.argument<String>("title") ?: "Downloading Offline Map"
                    val progress = call.argument<Int>("progress") ?: 0
                    val text = call.argument<String>("text") ?: "Transferring map data..."
                    DownloadForegroundService.updateProgress(applicationContext, title, progress, text)
                    result.success(true)
                }
                "stopDownloadForeground" -> {
                    DownloadForegroundService.stopService(applicationContext)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
