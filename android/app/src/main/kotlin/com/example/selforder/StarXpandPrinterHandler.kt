package com.zipzap.selforder

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.util.Log
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.starmicronics.stario10.*
import com.starmicronics.stario10.starxpandcommand.*
import com.starmicronics.stario10.starxpandcommand.printer.*
import com.starmicronics.stario10.starxpandcommand.drawer.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class StarXpandPrinterHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    private var discoveryManager: StarDeviceDiscoveryManager? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var activity: Activity? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val PERMISSION_REQUEST_CODE = 1001
    private val printableAreaMm = 72.0
    private val printableRasterWidthPx = 576
    private val printableRasterResolution = 72

    private data class PrintDocument(
        val commandBuilder: PrinterBuilder,
        val rasterText: String
    )

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    private fun parseInterfaceType(interfaceTypeStr: String): InterfaceType? {
        return when (interfaceTypeStr) {
            "Lan" -> InterfaceType.Lan
            "Bluetooth" -> InterfaceType.Bluetooth
            "Usb" -> InterfaceType.Usb
            else -> null
        }
    }

    private fun getPrinterModelHint(call: MethodCall, payload: Map<*, *>? = null): String {
        return listOfNotNull(
            call.argument<String>("modelName"),
            call.argument<String>("printerModelName"),
            payload?.get("modelName") as? String,
            payload?.get("printerModelName") as? String,
            payload?.get("printerName") as? String
        ).joinToString(" ")
    }

    private fun isGraphicsOnlyPrinter(printer: StarPrinter, identifier: String, modelHint: String): Boolean {
        val detectedText = mutableListOf(identifier, modelHint)

        try {
            val information = printer.information
            if (information != null) {
                detectedText += information.toString()
                for (member in information.javaClass.methods) {
                    val methodName = member.name.lowercase()
                    if (member.parameterTypes.isEmpty() && (
                            methodName.contains("model") ||
                            methodName.contains("name") ||
                            methodName.contains("emulation")
                        )
                    ) {
                        runCatching { member.invoke(information)?.toString() }
                            .getOrNull()
                            ?.let { detectedText += it }
                    }
                }
            }
        } catch (e: Exception) {
            Log.d("StarXpand", "Could not inspect printer model for graphics-only compatibility: ${e.message}")
        }

        val normalized = detectedText.joinToString(" ").uppercase()
            .replace("-", "")
            .replace("_", "")
            .replace(" ", "")

        return normalized.contains("TSP100III") ||
            normalized.contains("TSP100IIIBI") ||
            normalized.contains("TSP143III") ||
            normalized.contains("TSP113III") ||
            normalized.contains("TSP100IIU+") ||
            normalized.contains("TSP100IIU")
    }

    private fun getReceiptImageBitmap(payload: Map<*, *>): Bitmap? {
        val imageBase64 = payload["receiptImage"] as? String
        if (imageBase64.isNullOrBlank()) return null

        return try {
            val imageBytes = Base64.decode(imageBase64, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
        } catch (e: Exception) {
            Log.e("StarXpand", "Failed to decode receipt image fallback: ${e.message}", e)
            null
        }
    }

    private fun buildImageReceipt(bitmap: Bitmap): PrinterBuilder {
        val imgParam = ImageParameter(bitmap, printableRasterResolution)
        return PrinterBuilder()
            .actionPrintImage(imgParam)
            .actionCut(CutType.Partial)
    }

    private fun buildTextRasterReceipt(text: String): PrinterBuilder {
        return buildImageReceipt(renderReceiptTextBitmap(text))
    }

    private fun renderReceiptTextBitmap(text: String): Bitmap {
        val normalPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK
            textSize = 24f
            typeface = Typeface.MONOSPACE
        }
        val boldPaint = Paint(normalPaint).apply {
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        }
        val lineHeight = (normalPaint.fontMetrics.descent - normalPaint.fontMetrics.ascent + 8).toInt()
        val horizontalPadding = 16f
        val verticalPadding = 18
        val lines = text.trimEnd('\n').split('\n')
        val bitmapHeight = (lines.size * lineHeight + verticalPadding * 2).coerceAtLeast(lineHeight + verticalPadding * 2)
        val bitmap = Bitmap.createBitmap(printableRasterWidthPx, bitmapHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        var y = verticalPadding - normalPaint.fontMetrics.ascent
        for (line in lines) {
            val paint = if (line.startsWith("**") && line.endsWith("**")) boldPaint else normalPaint
            val printableLine = line.removePrefix("**").removeSuffix("**")
            canvas.drawText(printableLine, horizontalPadding, y, paint)
            y += lineHeight
        }

        return bitmap
    }

    private fun printDocument(
        interfaceTypeStr: String,
        identifier: String,
        modelHint: String,
        payload: Map<*, *>?,
        result: MethodChannel.Result,
        logLabel: String,
        documentFactory: () -> PrintDocument
    ) {
        val interfaceType = parseInterfaceType(interfaceTypeStr)
            ?: return result.error("INVALID_ARGUMENT", "Invalid interface type", null)

        coroutineScope.launch(Dispatchers.IO) {
            var printer: StarPrinter? = null
            try {
                val settings = StarConnectionSettings(interfaceType, identifier)
                printer = StarPrinter(settings, context)
                printer.openAsync().await()

                val document = documentFactory()
                val graphicsOnly = isGraphicsOnlyPrinter(printer, identifier, modelHint)
                val printerBuilder = if (graphicsOnly) {
                    Log.d("StarXpand", "Using raster image print path for graphics-only Star printer: $identifier")
                    payload?.let { getReceiptImageBitmap(it) }?.let { buildImageReceipt(it) }
                        ?: buildTextRasterReceipt(document.rasterText)
                } else {
                    document.commandBuilder
                }

                val builder = StarXpandCommandBuilder()
                builder.addDocument(
                    DocumentBuilder()
                        .settingPrintableArea(printableAreaMm)
                        .addPrinter(printerBuilder)
                )

                printer.printAsync(builder.getCommands()).await()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "$logLabel error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            } finally {
                try {
                    printer?.closeAsync()?.await()
                } catch (e: Exception) {
                    Log.d("StarXpand", "Printer close failed after $logLabel: ${e.message}")
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestBluetoothPermissions" -> requestBluetoothPermissions(result)
            "checkBluetoothPermissions" -> checkBluetoothPermissions(result)
            "discoverPrinters" -> discoverPrinters(call, result)
            "printTest" -> printTest(call, result)
            "printKitchenOrder" -> printKitchenOrder(call, result)
            "printImage" -> printImage(call, result)
            "printCustomerReceipt" -> printCustomerReceipt(call, result)
            "printQuote" -> printQuote(call, result)
            "printReport" -> printReport(call, result)
            "printVoidReceipt" -> printVoidReceipt(call, result)
            "getPrinterStatus" -> getPrinterStatus(call, result)
            "getPrinterInformation" -> getPrinterInformation(call, result)
            "openCashDrawer" -> openCashDrawer(call, result)
            else -> result.notImplemented()
        }
    }

    private fun printImage(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)
        val imageBase64 = call.argument<String>("imageBase64") ?: return result.error("INVALID_ARGUMENT", "imageBase64 required", null)
        val paperWidthMm = call.argument<Double>("paperWidthMm") ?: printableAreaMm

        val interfaceType = when (interfaceTypeStr) {
            "Lan" -> InterfaceType.Lan
            "Bluetooth" -> InterfaceType.Bluetooth
            "Usb" -> InterfaceType.Usb
            else -> return result.error("INVALID_ARGUMENT", "Invalid interface type", null)
        }

        coroutineScope.launch(Dispatchers.IO) {
            try {
                val imageBytes = Base64.decode(imageBase64, Base64.DEFAULT)

                val settings = StarConnectionSettings(interfaceType, identifier)
                val printer = StarPrinter(settings, context)

                printer.openAsync().await()

                val builder = StarXpandCommandBuilder()

                // Build a simple document that prints the image and then cuts
                val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                val imgParam = ImageParameter(bitmap, paperWidthMm.toInt())
                val printerBuilder = PrinterBuilder()
                    .actionPrintImage(imgParam)
                    .actionCut(CutType.Partial)

                builder.addDocument(
                    DocumentBuilder()
                        .settingPrintableArea(paperWidthMm)
                        .addPrinter(printerBuilder)
                )

                val commands = builder.getCommands()

                printer.printAsync(commands).await()
                printer.closeAsync().await()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Print image error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(allGranted)
            pendingPermissionResult = null
        }
    }

    private fun requestBluetoothPermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            result.success(true)
            return
        }

        val permissions = mutableListOf<String>()
        permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        permissions.add(Manifest.permission.BLUETOOTH_SCAN)

        val missingPermissions = permissions.filter {
            ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isEmpty()) {
            result.success(true)
            return
        }

        val activity = this.activity
        if (activity == null) {
            result.error("PERMISSION_ERROR", "Activity not available to request permissions", null)
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            missingPermissions.toTypedArray(),
            PERMISSION_REQUEST_CODE
        )
    }

    private fun checkBluetoothPermissions(result: MethodChannel.Result) {
        val hasPermission = hasBluetoothPermission()
        result.success(hasPermission)
    }

    private fun discoverPrinters(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypesList = call.argument<List<String>>("interfaceTypes") ?: listOf("Lan", "Bluetooth", "Usb")

        val interfaceTypes = mutableListOf<InterfaceType>()
        if (interfaceTypesList.contains("Lan")) interfaceTypes += InterfaceType.Lan
        if (interfaceTypesList.contains("Bluetooth")) {
            if (!hasBluetoothPermission()) {
                result.error("PERMISSION_ERROR", "Bluetooth permission required. Please request permissions first.", null)
                return
            }
            interfaceTypes += InterfaceType.Bluetooth
        }
        if (interfaceTypesList.contains("Usb")) interfaceTypes += InterfaceType.Usb

        if (interfaceTypes.isEmpty()) {
            result.error("INVALID_ARGUMENT", "At least one interface type must be specified", null)
            return
        }

        coroutineScope.launch {
            var resultCalled = false
            val discoveredPrinters = mutableListOf<Map<String, Any>>()

            try {
                // Stop any ongoing discovery
                discoveryManager?.stopDiscovery()

                // Create new discovery manager
                discoveryManager = StarDeviceDiscoveryManagerFactory.create(
                    interfaceTypes,
                    context
                )
                discoveryManager?.discoveryTime = 10000 // 10 seconds

                // Set callback before starting discovery
                discoveryManager?.callback = object : StarDeviceDiscoveryManager.Callback {
                    override fun onPrinterFound(printer: StarPrinter) {
                        val interfaceTypeStr = when (printer.connectionSettings.interfaceType) {
                            InterfaceType.Lan -> "Lan"
                            InterfaceType.Bluetooth -> "Bluetooth"
                            InterfaceType.Usb -> "Usb"
                            else -> "Unknown"
                        }

                        val identifier = printer.connectionSettings.identifier
                        var modelName: String? = null
                        var ipAddress: String? = null

                        // For LAN printers, identifier is the IP address
                        if (interfaceTypeStr == "Lan") {
                            ipAddress = identifier
                        }

                        // Try to get information from printer if available during discovery
                        try {
                            val information = printer.information
                            if (information != null) {
                                Log.d("StarXpand", "Information type: ${information.javaClass.simpleName}")

                                // Try to access model through reflection or known properties
                                // The StarPrinterInformation might have different properties
                                // Check the actual API structure
                            } else {
                                Log.d("StarXpand", "Printer information is null during discovery")
                            }
                        } catch (e: Exception) {
                            Log.d("StarXpand", "Could not access printer information during discovery: ${e.message}")
                        }

                        // Use identifier as fallback for model name if not available
                        if (modelName == null) {
                            modelName = identifier
                        }

                        val printerMap = mutableMapOf<String, Any>(
                            "identifier" to identifier,
                            "interfaceType" to interfaceTypeStr,
                            "modelName" to modelName
                        )

                        // Add IP address if available (for LAN printers)
                        if (ipAddress != null) {
                            printerMap["ipAddress"] = ipAddress
                        }

                        discoveredPrinters.add(printerMap)
                        Log.d("StarXpand", "Found printer: $identifier ($interfaceTypeStr)")
                    }

                    override fun onDiscoveryFinished() {
                        if (!resultCalled) {
                            resultCalled = true
                            Log.d("StarXpand", "Discovery finished. Found ${discoveredPrinters.size} printers")
                            result.success(discoveredPrinters)
                        }
                    }
                }

                // Start discovery
                discoveryManager?.startDiscovery()

                // Set a timeout to ensure result is always called
                delay(12000) // Wait slightly longer than discovery time
                if (!resultCalled) {
                    resultCalled = true
                    Log.d("StarXpand", "Discovery timeout. Found ${discoveredPrinters.size} printers")
                    result.success(discoveredPrinters)
                }
            } catch (e: StarIO10Exception) {
                if (!resultCalled) {
                    resultCalled = true
                    Log.e("StarXpand", "Discovery error: ${e.message}", e)
                    result.error("DISCOVERY_ERROR", e.message ?: "Unknown error", null)
                }
            } catch (e: Exception) {
                if (!resultCalled) {
                    resultCalled = true
                    Log.e("StarXpand", "Discovery error: ${e.message}", e)
                    result.error("DISCOVERY_ERROR", e.message ?: "Unknown error", null)
                }
            }
        }
    }

    private fun printTest(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)

        printDocument(
            interfaceTypeStr,
            identifier,
            getPrinterModelHint(call),
            null,
            result,
            "Print test"
        ) {
            PrintDocument(
                PrinterBuilder()
                    .actionPrintText("Test Print\n")
                    .actionCut(CutType.Partial),
                "Test Print\n"
            )
        }
    }

    private fun printKitchenOrder(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)
        val orderData = call.argument<Map<*, *>>("orderData") ?: return result.error("INVALID_ARGUMENT", "orderData required", null)

        printDocument(
            interfaceTypeStr,
            identifier,
            getPrinterModelHint(call, orderData),
            orderData,
            result,
            "Print kitchen order"
        ) {
            val orderType = (orderData["orderType"] as? String) ?: "PICKUP"
            val isDineIn = orderType.uppercase() == "DINE-IN" || orderType.uppercase() == "DINEIN"
            PrintDocument(
                if (isDineIn) buildDineInKitchenReceipt(orderData) else buildKitchenReceipt(orderData),
                if (isDineIn) buildDineInKitchenReceiptText(orderData) else buildKitchenReceiptText(orderData)
            )
        }
    }

    private fun buildCustomerReceipt(orderData: Map<*, *>): PrinterBuilder {
        val storeName = (orderData["storeName"] as? String) ?: ""
        val storeAddress = (orderData["storeAddress"] as? String) ?: ""
        val storePhone = (orderData["storePhone"] as? String) ?: ""
        val storeEmail = (orderData["storeEmail"] as? String) ?: ""
        val orderNumber = (orderData["orderNumber"] as? String) ?: ""
        val orderDate = (orderData["orderDate"] as? String) ?: ""
        val customerName = (orderData["customerName"] as? String) ?: ""
        val orderNote = (orderData["orderNote"] as? String) ?: ""
        val items = (orderData["items"] as? List<*>) ?: emptyList<Any>()
        val subtotal = (orderData["subtotal"] as? Number)?.toDouble() ?: 0.0
        val tax = (orderData["tax"] as? Number)?.toDouble() ?: 0.0
        val total = (orderData["total"] as? Number)?.toDouble() ?: 0.0

        val printerBuilder = PrinterBuilder()

        // Header
        printerBuilder
            .add(
                PrinterBuilder()
                    .styleMagnification(MagnificationParameter(2, 2))
                    .styleBold(true)
                    .styleAlignment(Alignment.Center)
                    .actionPrintText("$storeName\n")
            )
            .styleMagnification(MagnificationParameter(1, 1))
            .styleBold(false)
            .styleAlignment(Alignment.Center)
            .actionPrintText("$storeAddress\n")
            .actionPrintText("$storePhone\n")
            .actionPrintText("$storeEmail\n")
            .actionFeed(0.5)

        printerBuilder
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.3))
            .actionFeed(0.8)
            .styleAlignment(Alignment.Left)

        // Order meta
        printerBuilder
            .actionPrintText("Order : ", TextParameter().setWidth(20))
            .actionPrintText(
                "#$orderNumber\n",
                TextParameter().setWidth(52, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
            .actionPrintText("Customer : ", TextParameter().setWidth(20))
            .actionPrintText(
                "$customerName\n",
                TextParameter().setWidth(52, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
            .actionPrintText("Date : ", TextParameter().setWidth(20))
            .actionPrintText(
                "$orderDate\n",
                TextParameter().setWidth(52, TextWidthParameter().setAlignment(TextAlignment.Right))
            )

        if (orderNote.isNotEmpty()) {
            printerBuilder
                .actionPrintText("Order Note: ", TextParameter().setWidth(20))
                .actionPrintText(
                    "$orderNote\n",
                    TextParameter().setWidth(52, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
        }

        printerBuilder
            .actionFeed(0.5)
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(0.5)

        // Item headers
        printerBuilder
            .styleBold(true)
            .actionPrintText("Item", TextParameter().setWidth(28))
            .actionPrintText("Qty", TextParameter().setWidth(12, TextWidthParameter().setAlignment(TextAlignment.Right)))
            .actionPrintText(
                "Price\n",
                TextParameter().setWidth(20, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
            .styleBold(false)
            .actionFeed(0.5)

        // Items
        for (item in items) {
            val itemMap = item as? Map<*, *> ?: continue
            val quantity = (itemMap["quantity"] as? Number)?.toInt() ?: 1
            val name = (itemMap["name"] as? String) ?: ""
            val price = (itemMap["price"] as? Number)?.toDouble() ?: 0.0
            val modifiers = (itemMap["modifiers"] as? List<*>) ?: emptyList<Any>()
            val itemNote = (itemMap["itemNote"] as? String) ?: ""

            printerBuilder
                .styleBold(true)
                .actionPrintText(
                    name,
                    TextParameter().setWidth(28)
                )
                .actionPrintText(
                    quantity.toString(),
                    TextParameter().setWidth(12, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
                .actionPrintText(
                    "$" + String.format("%.2f\n", price),
                    TextParameter().setWidth(20, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
                .styleBold(false)

            for (modifier in modifiers) {
                val modMap = modifier as? Map<*, *> ?: continue
                val modName = (modMap["name"] as? String) ?: ""
                printerBuilder.actionPrintText("• $modName\n")
            }

            if (itemNote.isNotEmpty()) {
                printerBuilder.actionPrintText("• $itemNote\n")
            }
            printerBuilder.actionFeedLine(1)
        }

        printerBuilder
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(0.8)

        printerBuilder
            .actionPrintText(
                "Subtotal",
                TextParameter().setWidth(44)
            )
            .actionPrintText(
                "$" + String.format("%.2f\n", subtotal),
                TextParameter().setWidth(28, TextWidthParameter().setAlignment(TextAlignment.Right))
            )

        if (tax > 0) {
            printerBuilder
                .actionPrintText(
                    "Tax",
                    TextParameter().setWidth(44)
                )
                .actionPrintText(
                    "$" + String.format("%.2f\n", tax),
                    TextParameter().setWidth(28, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
        }

        printerBuilder
            .styleBold(true)
            .actionPrintText(
                "TOTAL",
                TextParameter().setWidth(44)
            )
            .actionPrintText(
                "$" + String.format("%.2f\n", total),
                TextParameter().setWidth(28, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
            .styleBold(false)

        printerBuilder
            .actionFeed(1.0)
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(0.8)
            .styleAlignment(Alignment.Center)
            .actionPrintText("Thank You!\n")
            .actionPrintText("Visit Again\n")
            .actionFeed(2.0)
            .actionCut(CutType.Partial)

        return printerBuilder
    }

    private fun printCustomerReceipt(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)
        val orderData = call.argument<Map<*, *>>("orderData") ?: return result.error("INVALID_ARGUMENT", "orderData required", null)

        printDocument(
            interfaceTypeStr,
            identifier,
            getPrinterModelHint(call, orderData),
            orderData,
            result,
            "Print customer receipt"
        ) {
            PrintDocument(buildCustomerReceipt(orderData), buildCustomerReceiptText(orderData))
        }
    }

    private fun buildKitchenReceipt(orderData: Map<*, *>): PrinterBuilder {
        val storeName = (orderData["storeName"] as? String) ?: ""
        val orderNumber = (orderData["orderNumber"] as? String) ?: ""
        val orderDate = (orderData["orderDate"] as? String) ?: ""
        val customerName = (orderData["customerName"] as? String) ?: ""
        val customerPhone = (orderData["customerPhone"] as? String) ?: ""
        val isReturningCustomer = (orderData["isReturningCustomer"] as? Boolean) ?: false
        val customerOrderCount = (orderData["customerOrderCount"] as? Number)?.toInt() ?: 0
        val items = (orderData["items"] as? List<*>) ?: emptyList<Any>()
        val note = (orderData["note"] as? String) ?: ""
        val orderType = (orderData["orderType"] as? String) ?: "PICKUP"
        val placedAt = (orderData["placedAt"] as? String) ?: orderDate
        val dueAt = (orderData["dueAt"] as? String) ?: ""

        val printerBuilder = PrinterBuilder()

        printerBuilder.actionFeedLine(2)

        printerBuilder
            .styleMagnification(MagnificationParameter(2, 2))
            .styleBold(true)
            .styleAlignment(Alignment.Center)
            .actionPrintText("$storeName\n")
            .actionFeed(0.5)
            .styleMagnification(MagnificationParameter(1, 1))
            .styleBold(false)
            .actionPrintText("$orderType\n")
            .actionFeed(0.5)

        val customerLine = if (customerName.isNotEmpty() && orderNumber.isNotEmpty()) {
            "$customerName - $orderNumber"
        } else if (customerName.isNotEmpty()) {
            customerName
        } else {
            "Guest"
        }

        printerBuilder
            .styleAlignment(Alignment.Center)
            .actionPrintText("$customerLine\n")

        if (isReturningCustomer) {
            val orderLabel = if (customerOrderCount == 1) "Order" else "Orders"
            val returningText = if (customerOrderCount > 0) {
                "Returning Customer [$customerOrderCount $orderLabel]"
            } else {
                "Returning Customer"
            }
            printerBuilder
                .actionFeed(0.3)
                .styleBold(true)
                .actionPrintText("$returningText\n")
                .styleBold(false)
        }

        if (customerPhone.isNotEmpty()) {
            printerBuilder
                .actionFeed(0.3)
                .styleAlignment(Alignment.Center)
                .actionPrintText("Phone: $customerPhone\n")
                .styleAlignment(Alignment.Left)
        }

        printerBuilder
            .actionFeed(0.5)
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(0.5)

        if (note.isNotEmpty()) {
            printerBuilder
                .styleBold(true)
                .actionPrintText("Order Note: \n")
                .styleBold(false)
                .actionPrintText("$note\n")
                .actionFeed(0.5)
                .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
                .actionFeed(0.5)
        }

        for (item in items) {
            val itemMap = item as? Map<*, *> ?: continue
            val quantity = (itemMap["quantity"] as? Number)?.toInt() ?: 1
            val name = (itemMap["name"] as? String) ?: ""
            val modifiers = (itemMap["modifiers"] as? List<*>) ?: emptyList<Any>()
            val itemNote = (itemMap["itemNote"] as? String) ?: ""

            printerBuilder
                .styleBold(true)
                .actionPrintText("$name\n")
                .styleBold(false)
                .actionPrintText(
                    quantity.toString() + "\n",
                    TextParameter().setWidth(72, TextWidthParameter().setAlignment(TextAlignment.Right))
                )

            for (modifier in modifiers) {
                val modMap = modifier as? Map<*, *> ?: continue
                val modName = (modMap["name"] as? String) ?: ""
                printerBuilder.actionPrintText("• $modName\n")
            }

            if (itemNote.isNotEmpty()) {
                printerBuilder.actionPrintText("Order Note: $itemNote\n")
            }

            printerBuilder.actionFeedLine(1)
        }

        printerBuilder
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(0.8)

        if (placedAt.isNotEmpty()) {
            printerBuilder.actionPrintText("Placed at: $placedAt\n")
        }
        if (dueAt.isNotEmpty()) {
            printerBuilder.actionPrintText("Due at: $dueAt\n")
        }

        printerBuilder
            .actionFeed(1.0)
            .actionCut(CutType.Partial)

        return printerBuilder
    }

    private fun buildDineInKitchenReceipt(orderData: Map<*, *>): PrinterBuilder {
        val storeName = (orderData["storeName"] as? String) ?: ""
        val orderNumber = (orderData["orderNumber"] as? String) ?: ""
        val orderDate = (orderData["orderDate"] as? String) ?: ""
        val customerName = (orderData["customerName"] as? String) ?: ""
        val customerPhone = (orderData["customerPhone"] as? String) ?: ""
        val isReturningCustomer = (orderData["isReturningCustomer"] as? Boolean) ?: false
        val customerOrderCount = (orderData["customerOrderCount"] as? Number)?.toInt() ?: 0
        val items = (orderData["items"] as? List<*>) ?: emptyList<Any>()
        val note = (orderData["note"] as? String) ?: ""
        val orderType = (orderData["orderType"] as? String) ?: "DINE-IN"
        val placedAt = (orderData["placedAt"] as? String) ?: orderDate

        // Dine-in specific fields
        val floorPlanName = (orderData["floorPlanName"] as? String) ?: ""
        val tableName = (orderData["tableName"] as? String) ?: ""
        val partySize = (orderData["partySize"] as? Number)?.toInt() ?: 0

        // Staff info from createdBy
        val createdByMap = orderData["createdBy"] as? Map<*, *>
        val staffFirstName = (createdByMap?.get("firstName") as? String) ?: ""
        val staffLastName = (createdByMap?.get("lastName") as? String) ?: ""
        val staffName = listOf(staffFirstName, staffLastName).filter { it.isNotEmpty() }.joinToString(" ")

        val printerBuilder = PrinterBuilder()

        // Header [Store Name     Order Type]
        printerBuilder
            .styleMagnification(MagnificationParameter(2, 2))
            .styleBold(true)
            .styleAlignment(Alignment.Left)
            .actionPrintText(
                storeName,
                TextParameter()
                    .setWidth(16, TextWidthParameter().setAlignment(TextAlignment.Left))
            )
            .actionPrintText(
                orderType,
                TextParameter()
                    .setWidth(8, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
            .actionPrintText("\n")

        // Floor Plan Name (Dine-in specific) - Large and centered
        if (floorPlanName.isNotEmpty()) {
            printerBuilder
                .actionFeed(0.5)
                .styleAlignment(Alignment.Center)
                .styleMagnification(MagnificationParameter(2, 2))
                .styleBold(true)
                .actionPrintText("$floorPlanName\n")
                .styleAlignment(Alignment.Left)
        }

        // Table name and customer in black bar (inverted with 2x magnification)
        // Table on left, customer name/order number on right
        val displayCustomerName = if (customerName.isNotEmpty()) customerName else "Guest"
        val rightSide = if (orderNumber.isNotEmpty()) "$displayCustomerName #$orderNumber" else displayCustomerName
        printerBuilder
            .add(
                PrinterBuilder()
                    .styleMagnification(MagnificationParameter(2, 3))
                    .styleInvert(true)
                    .styleBold(true)
                    .actionPrintText(
                        tableName,
                        TextParameter().setWidth(10)
                    )
                    .actionPrintText(
                        rightSide,
                        TextParameter().setWidth(14, TextWidthParameter().setAlignment(TextAlignment.Right))
                    )
                    .actionPrintText("\n")
            )
            .styleMagnification(MagnificationParameter(1, 2))
            .styleBold(false)
            .styleInvert(false)

        val infoLine = buildString {
            if (partySize > 0) append("Party of $partySize")
            if (isReturningCustomer) {
                if (isNotEmpty()) append(" • ")
                val orderLabel = if (customerOrderCount == 1) "Order" else "Orders"
                if (customerOrderCount > 0) {
                    append("Returning Customer ($customerOrderCount $orderLabel)")
                } else {
                    append("Returning Customer")
                }
            }
        }

        if (infoLine.isNotEmpty()) {
            printerBuilder
                .actionFeed(0.5)
                .styleAlignment(Alignment.Center)
                .styleBold(true)
                .actionPrintText("$infoLine\n")
                .styleAlignment(Alignment.Left)
        }

        // Customer phone number if found
        if (customerPhone.isNotEmpty()) {
            printerBuilder
                .actionFeed(0.5)
                .styleAlignment(Alignment.Center)
                .actionPrintText("Phone: $customerPhone\n")
                .styleAlignment(Alignment.Left)
        }

        // Staff name if available
        if (staffName.isNotEmpty()) {
            printerBuilder
                .actionFeed(0.5)
                .styleAlignment(Alignment.Center)
                .actionPrintText("Staff: $staffName\n")
                .styleAlignment(Alignment.Left)
        }

        printerBuilder.actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(1.0)

        // Group items by guestGroup (seat), with whole_table first then seats sorted numerically
        val itemsBySeat = items
            .mapNotNull { it as? Map<*, *> }
            .filter { item ->
                (item["guestGroup"] as? String)?.isNotBlank() == true
            }
            .groupBy { it["guestGroup"] as? String ?: "" }
            .toSortedMap(compareBy { key ->
                when (key) {
                    "whole_table" -> -1 // Whole table comes first
                    else -> {
                        // Extract numeric part for proper sorting (guest_2 before guest_10)
                        val number = key.removePrefix("guest_").removePrefix("seat_").toIntOrNull()
                        number ?: Int.MAX_VALUE
                    }
                }
            })

        // Print items grouped by seat
        for ((seatGroup, seatItems) in itemsBySeat) {
            if (seatItems.isEmpty()) continue

            // Section header - "WHOLE TABLE" or "SEAT #"
            val seatLabel = when (seatGroup) {
                "whole_table" -> "WHOLE TABLE"
                else -> {
                    val seatNumber = seatGroup.removePrefix("guest_").removePrefix("seat_")
                    "SEAT $seatNumber"
                }
            }

            printerBuilder
                .add(
                    PrinterBuilder()
                        .styleMagnification(MagnificationParameter(2, 2))
                        .styleInvert(true)
                        .styleBold(true)
                        .styleAlignment(Alignment.Center)
                        .actionPrintText(" $seatLabel ")
                        .actionPrintText("\n")
                )
                .actionFeed(0.5)

            // Print items for this seat
            for (item in seatItems) {
                val quantity = (item["quantity"] as? Number)?.toInt() ?: 1
                val name = (item["name"] as? String) ?: ""
                val modifiers = (item["modifiers"] as? List<*>) ?: emptyList<Any>()
                val itemNote = (item["itemNote"] as? String) ?: ""

                // Item line: quantity x name - 2x2 size, bold
                printerBuilder
                    .styleMagnification(MagnificationParameter(2, 2))
                    .styleBold(true)
                    .actionPrintText("$quantity x $name\n")
                    .styleMagnification(MagnificationParameter(2, 1))
                    .styleBold(false)

                // Modifiers
                for (modifier in modifiers) {
                    val modMap = modifier as? Map<*, *> ?: continue
                    val modName = (modMap["name"] as? String) ?: ""
                    printerBuilder.actionPrintText("  $modName\n")
                }

                // Item note with inverted style and 2x2 size
                if (itemNote.isNotEmpty()) {
                    printerBuilder
                        .actionFeed(0.5)
                        .add(
                            PrinterBuilder()
                                .styleMagnification(MagnificationParameter(2, 2))
                                .styleInvert(true)
                                .styleBold(true)
                                .actionPrintText("Note: $itemNote\n")
                        )
                }

                printerBuilder.actionFeedLine(1)
            }

            // Add separator after each seat section (except the last)
            if (seatGroup != itemsBySeat.keys.last()) {
                printerBuilder
                    .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
                    .actionFeed(1.0)
            }
        }

        printerBuilder.actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(1.0)

        // Timestamp
        if (placedAt.isNotEmpty()) {
            printerBuilder
                .actionFeed(1.0)
                .actionPrintText("Placed at: $placedAt\n")
        }

        // Order note with inverted style and 2x2 size
        if (note.isNotEmpty()) {
            printerBuilder
                .actionFeed(1.0)
                .add(
                    PrinterBuilder()
                        .styleMagnification(MagnificationParameter(2, 2))
                        .styleInvert(true)
                        .styleBold(true)
                        .actionPrintText("Order Note: $note\n")
                )
        }

        printerBuilder
            .actionFeed(1.0)
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(1.0)
            .actionCut(CutType.Partial)

        return printerBuilder
    }

    private fun printQuote(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)
        val orderData = call.argument<Map<*, *>>("orderData") ?: return result.error("INVALID_ARGUMENT", "orderData required", null)

        printDocument(
            interfaceTypeStr,
            identifier,
            getPrinterModelHint(call, orderData),
            orderData,
            result,
            "Print quote"
        ) {
            PrintDocument(buildQuoteReceipt(orderData), buildQuoteReceiptText(orderData))
        }
    }

    private fun buildQuoteReceipt(orderData: Map<*, *>): PrinterBuilder {
        val storeName = (orderData["storeName"] as? String) ?: ""
        val storeAddress = (orderData["storeAddress"] as? String) ?: ""
        val storePhone = (orderData["storePhone"] as? String) ?: ""
        val storeEmail = (orderData["storeEmail"] as? String) ?: ""
        val orderNumber = (orderData["orderNumber"] as? String) ?: ""
        val orderDate = (orderData["orderDate"] as? String) ?: ""
        val customerName = (orderData["customerName"] as? String) ?: ""
        val items = (orderData["items"] as? List<*>) ?: emptyList<Any>()
        val subtotal = (orderData["subtotal"] as? Number)?.toDouble() ?: 0.0
        val tax = (orderData["tax"] as? Number)?.toDouble() ?: 0.0
        val discount = (orderData["discount"] as? Number)?.toDouble() ?: 0.0
        val total = (orderData["total"] as? Number)?.toDouble() ?: 0.0
        val note = (orderData["note"] as? String) ?: ""
        val orderType = (orderData["orderType"] as? String) ?: "PICKUP"

        val printerBuilder = PrinterBuilder()

        // Header - Store name centered and large
        printerBuilder
            .add(
                PrinterBuilder()
                    .styleMagnification(MagnificationParameter(2, 2))
                    .styleBold(true)
                    .styleAlignment(Alignment.Center)
                    .actionPrintText("$storeName\n")
            )
            .styleAlignment(Alignment.Center)
            .actionPrintText("$storeAddress\n")
            .actionPrintText("$storePhone | $storeEmail\n")
            .actionFeed(1.0)

        // QUOTE header - Bold and inverted
        printerBuilder
            .add(
                PrinterBuilder()
                    .styleMagnification(MagnificationParameter(2, 2))
                    .styleBold(true)
                    .styleInvert(true)
                    .styleAlignment(Alignment.Center)
                    .actionPrintText(" QUOTE / ESTIMATE \n")
            )
            .actionFeed(1.0)

        // Quote details
        printerBuilder
            .styleAlignment(Alignment.Left)
            .styleInvert(false)
            .styleBold(false)
            .actionPrintText("Quote #: $orderNumber\n")
            .actionPrintText("Date: $orderDate\n")
            .actionPrintText("Type: $orderType\n")

        if (customerName.isNotEmpty()) {
            printerBuilder.actionPrintText("Customer: $customerName\n")
        }

        printerBuilder
            .actionFeed(1.0)
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1).setLineStyle(LineStyle.Single))
            .actionFeed(1.0)

        // Items section
        printerBuilder
            .styleBold(true)
            .actionPrintText("ITEMS:\n")
            .styleBold(false)
            .actionFeed(0.5)

        for (item in items) {
            val itemMap = item as? Map<*, *> ?: continue
            val quantity = (itemMap["quantity"] as? Number)?.toInt() ?: 1
            val name = (itemMap["name"] as? String) ?: ""
            val price = (itemMap["price"] as? Number)?.toDouble() ?: 0.0
            val modifiers = (itemMap["modifiers"] as? List<*>) ?: emptyList<Any>()
            val itemNote = (itemMap["itemNote"] as? String) ?: ""

            // Item line
            printerBuilder
                .actionPrintText(
                    "$quantity x $name",
                    TextParameter().setWidth(36)
                )
                .actionPrintText(
                    "$" + String.format("%.2f\n", price),
                    TextParameter()
                        .setWidth(12, TextWidthParameter().setAlignment(TextAlignment.Right))
                )

            // Modifiers
            for (modifier in modifiers) {
                val modMap = modifier as? Map<*, *> ?: continue
                val modName = (modMap["name"] as? String) ?: ""
                val modGroup = (modMap["group"] as? String) ?: ""
                val modPrice = (modMap["priceAdjustment"] as? Number)?.toDouble() ?: 0.0
                val modPriceStr = if (modPrice > 0) " (+$${String.format("%.2f", modPrice)})" else ""

                if (modGroup.isNotEmpty()) {
                    printerBuilder.actionPrintText("  $modGroup: $modName$modPriceStr\n")
                } else {
                    printerBuilder.actionPrintText("  $modName$modPriceStr\n")
                }
            }

            // Item note
            if (itemNote.isNotEmpty()) {
                printerBuilder.actionPrintText("  Note: $itemNote\n")
            }
            printerBuilder.actionFeedLine(1)
        }

        printerBuilder
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1).setLineStyle(LineStyle.Single))
            .actionFeed(1.0)

        // Pricing breakdown
        printerBuilder
            .actionPrintText(
                "Subtotal:",
                TextParameter().setWidth(36)
            )
            .actionPrintText(
                "$" + String.format("%.2f\n", subtotal),
                TextParameter()
                    .setWidth(12, TextWidthParameter().setAlignment(TextAlignment.Right))
            )

        if (discount > 0) {
            printerBuilder
                .actionPrintText(
                    "Discount:",
                    TextParameter().setWidth(36)
                )
                .actionPrintText(
                    "-$" + String.format("%.2f\n", discount),
                    TextParameter()
                        .setWidth(12, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
        }

        if (tax > 0) {
            printerBuilder
                .actionPrintText(
                    "Tax (13%):",
                    TextParameter().setWidth(36)
                )
                .actionPrintText(
                    "$" + String.format("%.2f\n", tax),
                    TextParameter()
                        .setWidth(12, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
        }

        // Estimated Total - Bold and larger
        printerBuilder
            .actionFeed(0.5)
            .add(
                PrinterBuilder()
                    .styleMagnification(MagnificationParameter(1, 1))
                    .styleBold(true)
                    .actionPrintText(
                        "ESTIMATED TOTAL:",
                        TextParameter().setWidth(36)
                    )
                    .actionPrintText(
                        "$" + String.format("%.2f\n", total),
                        TextParameter()
                            .setWidth(12, TextWidthParameter().setAlignment(TextAlignment.Right))
                    )
            )
            .actionFeed(1.0)

        // Order note
        if (note.isNotEmpty()) {
            printerBuilder
                .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1).setLineStyle(LineStyle.Single))
                .actionFeed(0.5)
                .styleBold(true)
                .actionPrintText("Special Instructions:\n")
                .styleBold(false)
                .actionPrintText("$note\n")
                .actionFeed(1.0)
        }

        // Disclaimer section with dashed border
        printerBuilder
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1).setLineStyle(LineStyle.Double))
            .actionFeed(0.5)
            .styleAlignment(Alignment.Center)
            .styleBold(true)
            .actionPrintText("IMPORTANT NOTICE\n")
            .styleBold(false)
            .styleAlignment(Alignment.Left)
            .actionPrintText("This is an estimate only. The final total may vary based on actual modifiers, availability, and current pricing.\n")
            .actionFeed(0.5)
            .actionPrintText("Quote valid for 24 hours from issue date.\n")
            .actionFeed(0.5)
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1).setLineStyle(LineStyle.Double))
            .actionFeed(1.0)

        // Footer
        printerBuilder
            .styleAlignment(Alignment.Center)
            .actionPrintText("Thank you for considering $storeName\n")
            .actionPrintText("Questions? Call us at $storePhone\n")
            .actionFeed(1.0)
            .actionPrintText("Powered by: ZipZap POS\n")
            .actionFeed(2.0)
            .actionCut(CutType.Partial)

        return printerBuilder
    }

    private fun printReport(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)
        val reportData = call.argument<Map<*, *>>("reportData") ?: return result.error("INVALID_ARGUMENT", "reportData required", null)

        printDocument(
            interfaceTypeStr,
            identifier,
            getPrinterModelHint(call, reportData),
            reportData,
            result,
            "Print report"
        ) {
            PrintDocument(buildReportReceipt(reportData), buildReportReceiptText(reportData))
        }
    }

    private fun buildReportReceipt(reportData: Map<*, *>): PrinterBuilder {
        val storeName = (reportData["storeName"] as? String) ?: ""
        val reportDate = (reportData["reportDate"] as? String) ?: ""
        val reportType = (reportData["reportType"] as? String) ?: "SALES REPORT"
        val items = (reportData["items"] as? List<*>) ?: emptyList<Any>()

        val printerBuilder = PrinterBuilder()

        // Header - Store name with larger text
        printerBuilder
            .add(
                PrinterBuilder()
                    .styleMagnification(MagnificationParameter(2, 2))
                    .styleAlignment(Alignment.Center)
                    .styleBold(true)
                    .actionPrintText(" $storeName \n")
            )
            .styleMagnification(MagnificationParameter(1, 1))
            .styleAlignment(Alignment.Center)
            .styleBold(false)
            .actionPrintText("$reportDate\n")
            .actionPrintText("$reportType\n")
            .actionFeed(0.5)
            .styleAlignment(Alignment.Left)

        // Financial metrics - clean list format
        for (item in items) {
            val itemMap = item as? Map<*, *> ?: continue
            val name = (itemMap["name"] as? String) ?: ""
            val price = (itemMap["price"] as? Number)?.toDouble() ?: 0.0

            printerBuilder
                .actionPrintText(
                    name,
                    TextParameter().setWidth(30)
                )
                .actionPrintText(
                    "$" + String.format("%.2f\n", price),
                    TextParameter().setWidth(18, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
        }

        // Footer
        printerBuilder
            .actionFeed(0.5)
            .styleAlignment(Alignment.Center)
            .styleBold(true)
            .actionPrintText("**Thank You for Your Business!**\n")
            .styleBold(false)
            .actionPrintText("Powered by ZipZap POS\n")
            .actionFeed(2.0)
            .actionCut(CutType.Partial)

        return printerBuilder
    }

    private fun printVoidReceipt(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)
        val orderData = call.argument<Map<*, *>>("orderData") ?: return result.error("INVALID_ARGUMENT", "orderData required", null)

        printDocument(
            interfaceTypeStr,
            identifier,
            getPrinterModelHint(call, orderData),
            orderData,
            result,
            "Print void receipt"
        ) {
            PrintDocument(buildVoidReceipt(orderData), buildVoidReceiptText(orderData))
        }
    }

    private fun buildVoidReceipt(orderData: Map<*, *>): PrinterBuilder {
        val storeName = (orderData["storeName"] as? String) ?: ""
        val orderNumber = (orderData["orderNumber"] as? String) ?: ""
        val orderType = (orderData["orderType"] as? String) ?: "PICKUP"
        val items = (orderData["items"] as? List<*>) ?: emptyList<Any>()
        val voidedAt = (orderData["voidedAt"] as? String) ?: ""
        val placedAt = (orderData["placedAt"] as? String) ?: ""

        val printerBuilder = PrinterBuilder()

        // Header [Store Name     Order Type]
        printerBuilder
            .styleMagnification(MagnificationParameter(2, 2))
            .styleBold(true)
            .styleAlignment(Alignment.Left)
            .actionPrintText(
                storeName,
                TextParameter()
                    .setWidth(16, TextWidthParameter().setAlignment(TextAlignment.Left))
            )
            .actionPrintText(
                orderType,
                TextParameter()
                    .setWidth(8, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
            .actionPrintText("\n")

        // VOID header - Large, bold, inverted
        printerBuilder
            .actionFeed(0.5)
            .add(
                PrinterBuilder()
                    .styleMagnification(MagnificationParameter(3, 3))
                    .styleInvert(true)
                    .styleBold(true)
                    .styleAlignment(Alignment.Center)
                    .actionPrintText(" VOID ")
                    .actionPrintText("\n")
            )
            .actionFeed(0.5)

        // Order number in black bar
        printerBuilder
            .add(
                PrinterBuilder()
                    .styleMagnification(MagnificationParameter(2, 3))
                    .styleInvert(true)
                    .styleBold(true)
                    .styleAlignment(Alignment.Center)
                    .actionPrintText(" #$orderNumber ")
                    .actionPrintText("\n")
            )
            .styleMagnification(MagnificationParameter(1, 2))
            .styleBold(false)
            .styleInvert(false)
            .actionFeed(0.5)

        printerBuilder.actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(1.0)

        // Voided items
        for (item in items) {
            val itemMap = item as? Map<*, *> ?: continue
            val quantity = (itemMap["quantity"] as? Number)?.toInt() ?: 1
            val name = (itemMap["name"] as? String) ?: ""
            val modifiers = (itemMap["modifiers"] as? List<*>) ?: emptyList<Any>()
            val itemNote = (itemMap["itemNote"] as? String) ?: ""

            // Item line: quantity x name - 2x2 size, bold
            printerBuilder
                .styleMagnification(MagnificationParameter(2, 2))
                .styleBold(true)
                .actionPrintText("$quantity x $name\n")
                .styleMagnification(MagnificationParameter(2, 1))
                .styleBold(false)

            // Modifiers
            for (modifier in modifiers) {
                val modMap = modifier as? Map<*, *> ?: continue
                val modName = (modMap["name"] as? String) ?: ""
                printerBuilder.actionPrintText("  $modName\n")
            }

            // Item note with inverted style
            if (itemNote.isNotEmpty()) {
                printerBuilder
                    .actionFeed(0.5)
                    .add(
                        PrinterBuilder()
                            .styleMagnification(MagnificationParameter(2, 2))
                            .styleInvert(true)
                            .styleBold(true)
                            .actionPrintText("Note: $itemNote\n")
                    )
            }

            printerBuilder.actionFeedLine(1)
        }

        printerBuilder.actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(1.0)

        // Timestamps
        if (placedAt.isNotEmpty()) {
            printerBuilder
                .styleMagnification(MagnificationParameter(1, 2))
                .actionPrintText("Placed at: $placedAt\n")
        }
        if (voidedAt.isNotEmpty()) {
            printerBuilder
                .styleMagnification(MagnificationParameter(1, 2))
                .actionPrintText("Voided at: $voidedAt\n")
        }

        printerBuilder
            .actionFeed(1.0)
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(1.0)
            .actionCut(CutType.Partial)

        return printerBuilder
    }

    private fun receiptDivider(char: Char = '-'): String = char.toString().repeat(42)

    private fun money(value: Double): String = "$" + String.format("%.2f", value)

    private fun receiptColumns(left: String, right: String, width: Int = 42): String {
        val safeLeft = left.take(width)
        val safeRight = right.take(width)
        val spaces = (width - safeLeft.length - safeRight.length).coerceAtLeast(1)
        return safeLeft + " ".repeat(spaces) + safeRight
    }

    private fun appendWrapped(builder: StringBuilder, text: String, indent: String = "", width: Int = 42) {
        if (text.isBlank()) return
        var current = text.trim()
        val contentWidth = (width - indent.length).coerceAtLeast(12)
        while (current.length > contentWidth) {
            val splitAt = current.take(contentWidth + 1).lastIndexOf(' ').takeIf { it > 0 } ?: contentWidth
            builder.append(indent).append(current.take(splitAt).trim()).append('\n')
            current = current.drop(splitAt).trim()
        }
        builder.append(indent).append(current).append('\n')
    }

    private fun buildCustomerReceiptText(orderData: Map<*, *>): String {
        val storeName = (orderData["storeName"] as? String) ?: ""
        val storeAddress = (orderData["storeAddress"] as? String) ?: ""
        val storePhone = (orderData["storePhone"] as? String) ?: ""
        val storeEmail = (orderData["storeEmail"] as? String) ?: ""
        val orderNumber = (orderData["orderNumber"] as? String) ?: ""
        val orderDate = (orderData["orderDate"] as? String) ?: ""
        val customerName = (orderData["customerName"] as? String) ?: ""
        val orderNote = (orderData["orderNote"] as? String) ?: ""
        val items = (orderData["items"] as? List<*>) ?: emptyList<Any>()
        val subtotal = (orderData["subtotal"] as? Number)?.toDouble() ?: 0.0
        val tax = (orderData["tax"] as? Number)?.toDouble() ?: 0.0
        val total = (orderData["total"] as? Number)?.toDouble() ?: 0.0

        return buildString {
            append("**").append(storeName).append("**\n")
            appendWrapped(this, storeAddress)
            appendWrapped(this, storePhone)
            appendWrapped(this, storeEmail)
            append(receiptDivider()).append('\n')
            append(receiptColumns("Order:", "#$orderNumber")).append('\n')
            append(receiptColumns("Customer:", customerName)).append('\n')
            append(receiptColumns("Date:", orderDate)).append('\n')
            if (orderNote.isNotEmpty()) appendWrapped(this, "Order Note: $orderNote")
            append(receiptDivider()).append('\n')
            append(receiptColumns("Item", "Qty   Price")).append('\n')
            append(receiptDivider()).append('\n')
            for (item in items) {
                val itemMap = item as? Map<*, *> ?: continue
                val quantity = (itemMap["quantity"] as? Number)?.toInt() ?: 1
                val name = (itemMap["name"] as? String) ?: ""
                val price = (itemMap["price"] as? Number)?.toDouble() ?: 0.0
                append(receiptColumns(name, "$quantity  ${money(price)}")).append('\n')
                val modifiers = (itemMap["modifiers"] as? List<*>) ?: emptyList<Any>()
                for (modifier in modifiers) {
                    val modMap = modifier as? Map<*, *> ?: continue
                    appendWrapped(this, "- ${modMap["name"] as? String ?: ""}", "  ")
                }
                val itemNote = (itemMap["itemNote"] as? String) ?: ""
                if (itemNote.isNotEmpty()) appendWrapped(this, "- $itemNote", "  ")
                append('\n')
            }
            append(receiptDivider()).append('\n')
            append(receiptColumns("Subtotal", money(subtotal))).append('\n')
            if (tax > 0) append(receiptColumns("Tax", money(tax))).append('\n')
            append("**").append(receiptColumns("TOTAL", money(total))).append("**\n")
            append(receiptDivider()).append('\n')
            append("Thank You!\nVisit Again\n\n")
        }
    }

    private fun buildKitchenReceiptText(orderData: Map<*, *>): String {
        val storeName = (orderData["storeName"] as? String) ?: ""
        val orderNumber = (orderData["orderNumber"] as? String) ?: ""
        val orderDate = (orderData["orderDate"] as? String) ?: ""
        val customerName = (orderData["customerName"] as? String) ?: ""
        val customerPhone = (orderData["customerPhone"] as? String) ?: ""
        val isReturningCustomer = (orderData["isReturningCustomer"] as? Boolean) ?: false
        val customerOrderCount = (orderData["customerOrderCount"] as? Number)?.toInt() ?: 0
        val items = (orderData["items"] as? List<*>) ?: emptyList<Any>()
        val note = (orderData["note"] as? String) ?: ""
        val orderType = (orderData["orderType"] as? String) ?: "PICKUP"
        val placedAt = (orderData["placedAt"] as? String) ?: orderDate
        val dueAt = (orderData["dueAt"] as? String) ?: ""
        val customerLine = when {
            customerName.isNotEmpty() && orderNumber.isNotEmpty() -> "$customerName - $orderNumber"
            customerName.isNotEmpty() -> customerName
            else -> "Guest"
        }

        return buildString {
            append("**").append(storeName).append("**\n")
            append(orderType).append('\n')
            append(customerLine).append('\n')
            if (isReturningCustomer) {
                val orderLabel = if (customerOrderCount == 1) "Order" else "Orders"
                append("**Returning Customer")
                if (customerOrderCount > 0) append(" [$customerOrderCount $orderLabel]")
                append("**\n")
            }
            if (customerPhone.isNotEmpty()) append("Phone: ").append(customerPhone).append('\n')
            append(receiptDivider()).append('\n')
            if (note.isNotEmpty()) {
                append("**Order Note:**\n")
                appendWrapped(this, note)
                append(receiptDivider()).append('\n')
            }
            appendKitchenItemsText(this, items)
            append(receiptDivider()).append('\n')
            if (placedAt.isNotEmpty()) append("Placed at: ").append(placedAt).append('\n')
            if (dueAt.isNotEmpty()) append("Due at: ").append(dueAt).append('\n')
            append('\n')
        }
    }

    private fun buildDineInKitchenReceiptText(orderData: Map<*, *>): String {
        val base = StringBuilder()
        val floorPlanName = (orderData["floorPlanName"] as? String) ?: ""
        val tableName = (orderData["tableName"] as? String) ?: ""
        val partySize = (orderData["partySize"] as? Number)?.toInt() ?: 0
        if (floorPlanName.isNotEmpty() || tableName.isNotEmpty()) {
            base.append("**").append(floorPlanName).append(" ").append(tableName).append("**\n")
        }
        if (partySize > 0) base.append("Party of ").append(partySize).append('\n')
        base.append(buildKitchenReceiptText(orderData))
        return base.toString()
    }

    private fun appendKitchenItemsText(builder: StringBuilder, items: List<*>) {
        for (item in items) {
            val itemMap = item as? Map<*, *> ?: continue
            val quantity = (itemMap["quantity"] as? Number)?.toInt() ?: 1
            val name = (itemMap["name"] as? String) ?: ""
            builder.append("**").append(quantity).append(" x ").append(name).append("**\n")
            val modifiers = (itemMap["modifiers"] as? List<*>) ?: emptyList<Any>()
            for (modifier in modifiers) {
                val modMap = modifier as? Map<*, *> ?: continue
                appendWrapped(builder, "- ${modMap["name"] as? String ?: ""}", "  ")
            }
            val itemNote = (itemMap["itemNote"] as? String) ?: ""
            if (itemNote.isNotEmpty()) appendWrapped(builder, "Note: $itemNote", "  ")
            builder.append('\n')
        }
    }

    private fun buildQuoteReceiptText(orderData: Map<*, *>): String {
        val text = StringBuilder(buildCustomerReceiptText(orderData))
        text.insert(0, "**QUOTE / ESTIMATE**\n")
        val note = (orderData["note"] as? String) ?: ""
        if (note.isNotEmpty()) {
            text.append(receiptDivider()).append('\n')
            text.append("Special Instructions:\n")
            appendWrapped(text, note)
        }
        text.append("This is an estimate only.\nQuote valid for 24 hours.\n")
        return text.toString()
    }

    private fun buildReportReceiptText(reportData: Map<*, *>): String {
        val storeName = (reportData["storeName"] as? String) ?: ""
        val reportDate = (reportData["reportDate"] as? String) ?: ""
        val reportType = (reportData["reportType"] as? String) ?: "SALES REPORT"
        val items = (reportData["items"] as? List<*>) ?: emptyList<Any>()
        return buildString {
            append("**").append(storeName).append("**\n")
            append(reportDate).append('\n')
            append(reportType).append('\n')
            append(receiptDivider()).append('\n')
            for (item in items) {
                val itemMap = item as? Map<*, *> ?: continue
                val name = (itemMap["name"] as? String) ?: ""
                val price = (itemMap["price"] as? Number)?.toDouble() ?: 0.0
                append(receiptColumns(name, money(price))).append('\n')
            }
            append(receiptDivider()).append('\n')
            append("**Thank You for Your Business!**\nPowered by ZipZap POS\n\n")
        }
    }

    private fun buildVoidReceiptText(orderData: Map<*, *>): String {
        val storeName = (orderData["storeName"] as? String) ?: ""
        val orderNumber = (orderData["orderNumber"] as? String) ?: ""
        val orderType = (orderData["orderType"] as? String) ?: "PICKUP"
        val items = (orderData["items"] as? List<*>) ?: emptyList<Any>()
        val voidedAt = (orderData["voidedAt"] as? String) ?: ""
        val placedAt = (orderData["placedAt"] as? String) ?: ""
        return buildString {
            append("**").append(storeName).append(" ").append(orderType).append("**\n")
            append("**VOID**\n")
            append("#").append(orderNumber).append('\n')
            append(receiptDivider()).append('\n')
            appendKitchenItemsText(this, items)
            append(receiptDivider()).append('\n')
            if (placedAt.isNotEmpty()) append("Placed at: ").append(placedAt).append('\n')
            if (voidedAt.isNotEmpty()) append("Voided at: ").append(voidedAt).append('\n')
            append('\n')
        }
    }

    private fun getPrinterStatus(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)

        val interfaceType = when (interfaceTypeStr) {
            "Lan" -> InterfaceType.Lan
            "Bluetooth" -> InterfaceType.Bluetooth
            "Usb" -> InterfaceType.Usb
            else -> return result.error("INVALID_ARGUMENT", "Invalid interface type", null)
        }

        coroutineScope.launch(Dispatchers.IO) {
            try {
                val settings = StarConnectionSettings(interfaceType, identifier)
                val printer = StarPrinter(settings, context)

                printer.openAsync().await()
                val status = printer.getStatusAsync().await()
                printer.closeAsync().await()

                val statusMap = mapOf(
                    "hasError" to status.hasError,
                    "paperEmpty" to status.paperEmpty,
                    "paperNearEmpty" to status.paperNearEmpty,
                    "coverOpen" to status.coverOpen,
                    "drawerOpenCloseSignal" to status.drawerOpenCloseSignal,
                    "offline" to status.hasError // Use hasError as offline indicator
                )

                withContext(Dispatchers.Main) {
                    result.success(statusMap)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Status error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("STATUS_ERROR", e.message, null)
                }
            }
        }
    }

    private fun getPrinterInformation(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)

        val interfaceType = when (interfaceTypeStr) {
            "Lan" -> InterfaceType.Lan
            "Bluetooth" -> InterfaceType.Bluetooth
            "Usb" -> InterfaceType.Usb
            else -> return result.error("INVALID_ARGUMENT", "Invalid interface type", null)
        }

        coroutineScope.launch(Dispatchers.IO) {
            try {
                val settings = StarConnectionSettings(interfaceType, identifier)
                val printer = StarPrinter(settings, context)

                printer.openAsync().await()

                val infoMap = mutableMapOf<String, Any>()

                // Get IP address (for LAN printers, identifier is the IP)
                if (interfaceType == InterfaceType.Lan) {
                    infoMap["ipAddress"] = identifier
                }

                // Note: Printer information (like model name) is typically only available
                // during discovery, not after opening a connection.
                // The IP address is always available for LAN printers (it's the identifier).
                // Model name should be captured during discovery if available.

                printer.closeAsync().await()

                withContext(Dispatchers.Main) {
                    result.success(infoMap)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Get information error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("INFO_ERROR", e.message, null)
                }
            }
        }
    }

    private fun hasBluetoothPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        // Check both BLUETOOTH_CONNECT and BLUETOOTH_SCAN for Android 12+
        val hasConnect = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.BLUETOOTH_CONNECT
        ) == PackageManager.PERMISSION_GRANTED

        val hasScan = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.BLUETOOTH_SCAN
        ) == PackageManager.PERMISSION_GRANTED

        return hasConnect && hasScan
    }

    private fun openCashDrawer(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)

        val interfaceType = when (interfaceTypeStr) {
            "Lan" -> InterfaceType.Lan
            "Bluetooth" -> InterfaceType.Bluetooth
            "Usb" -> InterfaceType.Usb
            else -> return result.error("INVALID_ARGUMENT", "Invalid interface type", null)
        }

        coroutineScope.launch(Dispatchers.IO) {
            try {
                val settings = StarConnectionSettings(interfaceType, identifier)
                val printer = StarPrinter(settings, context)

                printer.openAsync().await()

                val builder = StarXpandCommandBuilder()
                builder.addDocument(
                    DocumentBuilder()
                        .addDrawer(
                            DrawerBuilder()
                                .actionOpen(OpenParameter().setChannel(Channel.No1))
                        )
                )

                val commands = builder.getCommands()
                printer.printAsync(commands).await()
                printer.closeAsync().await()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Open cash drawer error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("DRAWER_ERROR", e.message, null)
                }
            }
        }
    }

    fun dispose() {
        discoveryManager?.stopDiscovery()
        coroutineScope.cancel()
    }
}
