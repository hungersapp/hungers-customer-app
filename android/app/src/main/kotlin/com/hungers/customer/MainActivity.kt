package com.hungers.customer

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tukkito/maps_credentials",
        ).setMethodCallHandler { call, result ->
            if (call.method != "get") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val key = mapsApiKey()
            val cert = signingSha1()
            if (key.isNullOrEmpty() || cert.isNullOrEmpty()) {
                result.error("unavailable", "Maps credentials are unavailable.", null)
                return@setMethodCallHandler
            }
            result.success(
                mapOf(
                    "apiKey" to key,
                    "packageName" to packageName,
                    "sha1" to cert,
                ),
            )
        }
    }

    private fun mapsApiKey(): String? {
        val info = packageManager.getApplicationInfo(
            packageName,
            PackageManager.GET_META_DATA,
        )
        return info.metaData?.getString("com.google.android.geo.API_KEY")
    }

    private fun signingSha1(): String? {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            val info = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNATURES,
            )
            @Suppress("DEPRECATION")
            info.signatures
        }
        val signature = signatures?.firstOrNull() ?: return null
        val digest = MessageDigest.getInstance("SHA-1").digest(signature.toByteArray())
        return digest.joinToString("") { "%02X".format(it) }
    }
}
