package app.shelfy.collector

import android.app.backup.BackupManager
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import app.shelfy.collector.widget.OnDisplayWidgetProvider

class MainActivity : FlutterActivity() {
    private val channelName = "app.shelfy.collector/on_display_widget"
    private val androidBackupChannelName = "app.shelfy.collector/android_backup"
    private var channel: MethodChannel? = null
    private var pendingNavigation: String? = null
    private var dartNavigationReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeWidgetIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> {
                        val payloads = call.argument<String>("payloads") ?: "[]"
                        OnDisplayWidgetProvider.savePayloadsAndUpdate(this, payloads)
                        result.success(null)
                    }
                    "initialNavigation" -> {
                        dartNavigationReady = true
                        val target = pendingNavigation
                        pendingNavigation = null
                        result.success(target)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            androidBackupChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "dataChanged" -> {
                    try {
                        BackupManager(this).dataChanged()
                        result.success(null)
                    } catch (e: Exception) {
                        Log.w(TAG, "BackupManager.dataChanged failed", e)
                        result.error("backup", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeWidgetIntent(intent)
    }

    private fun consumeWidgetIntent(intent: Intent?) {
        val target = navigationTarget(intent) ?: return
        intent?.removeExtra(EXTRA_WIDGET_NAVIGATION)
        if (intent?.action?.startsWith(WIDGET_ACTION_PREFIX) == true) {
            intent.action = null
        }
        if (!dartNavigationReady || channel == null) {
            pendingNavigation = target
        } else {
            channel?.invokeMethod("navigate", target)
        }
    }

    private fun navigationTarget(intent: Intent?): String? =
        intent?.getStringExtra(EXTRA_WIDGET_NAVIGATION)

    companion object {
        const val EXTRA_WIDGET_NAVIGATION = "on_display_widget_navigation"
        private const val WIDGET_ACTION_PREFIX = "app.shelfy.collector.ON_DISPLAY."
        private const val TAG = "ShelfyAndroidBackup"
    }
}
