package com.money_load_manager.money_load_manager

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.money_load_manager.wifi"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "acquireMulticastLock") {
                acquireMulticastLock()
                result.success(true)
            } else if (call.method == "releaseMulticastLock") {
                releaseMulticastLock()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun acquireMulticastLock() {
        if (multicastLock == null) {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            multicastLock = wifiManager.createMulticastLock("money_load_manager_multicast_lock")
            multicastLock?.setReferenceCounted(true)
        }
        multicastLock?.acquire()
    }

    private fun releaseMulticastLock() {
        if (multicastLock?.isHeld == true) {
            multicastLock?.release()
        }
    }
}
