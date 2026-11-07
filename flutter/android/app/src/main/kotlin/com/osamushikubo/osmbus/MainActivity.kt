package com.osamushikubo.osmbus

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Android の Maps SDK はキーを manifest からしか読まないので、ビルド時のキーだけを使う。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "osmbus/google_maps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "state" -> {
                        val key = bundledKey()
                        result.success(
                            mapOf("userKey" to null, "bundledKey" to key, "activeKey" to key, "canEditKey" to false),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun bundledKey(): String? {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        return info.metaData?.getString("com.google.android.geo.API_KEY")?.trim()?.takeIf { it.isNotEmpty() }
    }
}
