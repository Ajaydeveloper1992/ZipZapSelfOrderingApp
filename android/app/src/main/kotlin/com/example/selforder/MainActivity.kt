package com.zipzap.selforder

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var printerHandler: StarXpandPrinterHandler? = null
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the StarXpand printer handler
        printerHandler = StarXpandPrinterHandler(applicationContext)
        printerHandler?.setActivity(this)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.zipzap/starxpand_printer")
        channel?.setMethodCallHandler(printerHandler)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        printerHandler?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        printerHandler?.dispose()
        super.onDestroy()
    }
}
