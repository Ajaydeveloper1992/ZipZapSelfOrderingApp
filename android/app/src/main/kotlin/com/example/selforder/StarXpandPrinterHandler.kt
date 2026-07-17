package com.zipzap.selforder

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
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

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestBluetoothPermissions" -> requestBluetoothPermissions(result)
            "checkBluetoothPermissions" -> checkBluetoothPermissions(result)
            "discoverPrinters" -> discoverPrinters(call, result)
            "printTest" -> printTest(call, result)
            "printKitchenOrder" -> printKitchenOrder(call, result)
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
                        .addPrinter(
                            PrinterBuilder()
                                .actionPrintText("Test Print\n")
                                .actionCut(CutType.Partial)
                        )
                )

                val commands = builder.getCommands()

                printer.printAsync(commands).await()
                printer.closeAsync().await()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Print error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }
        }
    }

    private fun printKitchenOrder(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)
        val orderData = call.argument<Map<*, *>>("orderData") ?: return result.error("INVALID_ARGUMENT", "orderData required", null)

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
                
                // Check if this is a dine-in order to use appropriate receipt builder
                val orderType = (orderData["orderType"] as? String) ?: "PICKUP"
                val isDineIn = orderType.uppercase() == "DINE-IN" || orderType.uppercase() == "DINEIN"
                val receiptBuilder = if (isDineIn) {
                    buildDineInKitchenReceipt(orderData)
                } else {
                    buildKitchenReceipt(orderData)
                }
                
                builder.addDocument(
                    DocumentBuilder()
                        .settingPrintableArea(72.0)
                        .addPrinter(receiptBuilder)
                )

                val commands = builder.getCommands()

                printer.printAsync(commands).await()
                printer.closeAsync().await()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Print kitchen order error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }
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
        val customerPhone = (orderData["customerPhone"] as? String) ?: ""
        val items = (orderData["items"] as? List<*>) ?: emptyList<Any>()
        val subtotal = (orderData["subtotal"] as? Number)?.toDouble() ?: 0.0
        val tax = (orderData["tax"] as? Number)?.toDouble() ?: 0.0
        val tip = (orderData["tip"] as? Number)?.toDouble() ?: 0.0
        val discount = (orderData["discount"] as? Number)?.toDouble() ?: 0.0
        val total = (orderData["total"] as? Number)?.toDouble() ?: 0.0
        val splitInfo = (orderData["splitInfo"] as? String)
        val fullTotal = (orderData["fullTotal"] as? Number)?.toDouble()

        val printerBuilder = PrinterBuilder()

        // Store header - Bold and large
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
            .actionPrintText("$storePhone\n")
            .actionPrintText("$storeEmail\n")

        // Split indicator (e.g., "Split 1 of 2")
        if (!splitInfo.isNullOrEmpty()) {
            printerBuilder
                .actionFeed(0.5)
                .add(
                    PrinterBuilder()
                        .styleMagnification(MagnificationParameter(1, 1))
                        .styleBold(true)
                        .styleInvert(true)
                        .styleAlignment(Alignment.Center)
                        .actionPrintText(" $splitInfo \n")
                )
        }

        printerBuilder
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.3))
            .actionFeed(1.0)
            .styleAlignment(Alignment.Left) // Reset to left alignment

        // Order details
        printerBuilder
            .actionPrintText(
                "Order Date:",
                TextParameter().setWidth(24)
            )
            .actionPrintText(
                "$orderDate\n",
                TextParameter()
                    .setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
            .actionPrintText(
                "Order #:",
                TextParameter().setWidth(24)
            )
            .actionPrintText(
                "$orderNumber",
                TextParameter().setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
            )

        // Customer info
        if (customerName.isNotEmpty()) {
            printerBuilder.actionPrintText("Customer Name: ", TextParameter().setWidth(24))
            .actionPrintText(
                "$customerName",
                TextParameter().setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
        }
        if (customerPhone.isNotEmpty()) {
            printerBuilder.actionPrintText("Customer Phone: ", TextParameter().setWidth(24))
            .actionPrintText(
                "$customerPhone",
                TextParameter().setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
        }

        printerBuilder.actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
        .actionFeed(1.0)
        printerBuilder.actionPrintText("Item ", TextParameter().setWidth(24))
        .actionPrintText(
            "Price",
            TextParameter().setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
        )
        printerBuilder.actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
        .actionFeed(1.0)

        // Items
        for (item in items) {
            val itemMap = item as? Map<*, *> ?: continue
            val quantity = (itemMap["quantity"] as? Number)?.toInt() ?: 1
            val name = (itemMap["name"] as? String) ?: ""
            val price = (itemMap["price"] as? Number)?.toDouble() ?: 0.0
            val modifiers = (itemMap["modifiers"] as? List<*>) ?: emptyList<Any>()
            val itemNote = (itemMap["itemNote"] as? String) ?: ""

            // Item line: quantity x name on left, price on right
            printerBuilder
                .styleBold(true)
                .actionPrintText(
                    "$quantity x $name",
                    TextParameter().setWidth(36)
                )
                .actionPrintText(
                    "$" + String.format("%.2f\n", price),
                    TextParameter().setWidth(12, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
                .styleBold(false)

            // Modifiers
            for (modifier in modifiers) {
                val modMap = modifier as? Map<*, *> ?: continue
                val modName = (modMap["name"] as? String) ?: ""
                val modPrice = (modMap["priceAdjustment"] as? Number)?.toDouble() ?: 0.0
                val modPriceStr = if (modPrice > 0) " (+$${String.format("%.2f", modPrice)})" else ""
                printerBuilder.actionPrintText("  $modName$modPriceStr\n")
            }

            // Item note
            if (itemNote.isNotEmpty()) {
                printerBuilder.actionPrintText("  Note: $itemNote\n")
            }
            printerBuilder.actionFeedLine(1)
        }

        printerBuilder.actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
        .actionFeed(1.0)

        // Summary
        printerBuilder
            .actionPrintText(
                "Sub Total:",
                TextParameter().setWidth(24)
            )
            .actionPrintText(
                "$" + String.format("%.2f\n", subtotal),
                TextParameter()
                    .setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
            )

        if (discount > 0) {
            printerBuilder
                .actionPrintText(
                    "Discount:",
                    TextParameter().setWidth(24)
                )
                .actionPrintText(
                    "-$" + String.format("%.2f\n", discount),
                    TextParameter()
                        .setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
        }

        if (tax > 0) {
            printerBuilder
                .actionPrintText(
                    "Tax:",
                    TextParameter().setWidth(24)
                )
                .actionPrintText(
                    "$" + String.format("%.2f\n", tax),
                    TextParameter()
                        .setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
        }

        if (tip > 0) {
            printerBuilder
                .actionPrintText(
                    "Tip:",
                    TextParameter().setWidth(24)
                )
                .actionPrintText(
                    "$" + String.format("%.2f\n", tip),
                    TextParameter()
                        .setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
                )
        }

        // Total line - show split/full format when split info is present
        val totalDisplay = if (splitInfo != null && fullTotal != null) {
            "$" + String.format("%.2f", total) + " / $" + String.format("%.2f\n", fullTotal)
        } else {
            "$" + String.format("%.2f\n", total)
        }
        
        printerBuilder
            .styleBold(true)
            .actionPrintText(
                "Total:",
                TextParameter().setWidth(24)
            )
            .actionPrintText(
                totalDisplay,
                TextParameter()
                    .setWidth(24, TextWidthParameter().setAlignment(TextAlignment.Right))
            )
            .styleBold(false)

        // Footer
        printerBuilder
            .actionFeed(1.0)
            .actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
            .actionFeed(1.0)
            .styleAlignment(Alignment.Center)
            .actionPrintText("Thank you for your business!\n")
            .actionPrintText("Powered by: ZipZap POS\n")
            .actionFeed(2.0)
            .actionCut(CutType.Partial)

        return printerBuilder
    }

    private fun printCustomerReceipt(call: MethodCall, result: MethodChannel.Result) {
        val interfaceTypeStr = call.argument<String>("interfaceType") ?: return result.error("INVALID_ARGUMENT", "interfaceType required", null)
        val identifier = call.argument<String>("identifier") ?: return result.error("INVALID_ARGUMENT", "identifier required", null)
        val orderData = call.argument<Map<*, *>>("orderData") ?: return result.error("INVALID_ARGUMENT", "orderData required", null)

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
                        .settingPrintableArea(72.0)
                        .addPrinter(
                            buildCustomerReceipt(orderData)
                        )
                )

                val commands = builder.getCommands()

                printer.printAsync(commands).await()
                printer.closeAsync().await()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Print customer receipt error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }
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
        val subtotal = (orderData["subtotal"] as? Number)?.toDouble() ?: 0.0
        val tax = (orderData["tax"] as? Number)?.toDouble() ?: 0.0
        val total = (orderData["total"] as? Number)?.toDouble() ?: 0.0
        val note = (orderData["note"] as? String) ?: ""
        val orderType = (orderData["orderType"] as? String) ?: "PICKUP"
        val placedAt = (orderData["placedAt"] as? String) ?: orderDate
        val dueAt = (orderData["dueAt"] as? String) ?: ""

        val printerBuilder = PrinterBuilder()

        printerBuilder.actionFeedLine(2)

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

        // Customer name and order ID in black bar (inverted with 2x magnification)
        // Customer name on left, order number on right
        val displayCustomerName = if (customerName.isNotEmpty()) customerName else "Guest"
        printerBuilder
            .add(
                PrinterBuilder()
                    .styleMagnification(MagnificationParameter(2, 3))
                    .styleInvert(true)
                    .styleBold(true)
                    .actionPrintText(
                        displayCustomerName,
                        TextParameter().setWidth(14)
                    )
                    .actionPrintText(
                        orderNumber,
                        TextParameter().setWidth(10, TextWidthParameter().setAlignment(TextAlignment.Right))
                    )
                    .actionPrintText("\n")
            )
            .styleMagnification(MagnificationParameter(1, 2))  // Slightly larger size (1x width, 2x height)
            .styleBold(false)                                   // Reset bold
            .styleInvert(false)    

        if (isReturningCustomer) {
            val orderLabel = if (customerOrderCount == 1) "Order" else "Orders"
            val returningText = if (customerOrderCount > 0) {
                " Returning Customer ($customerOrderCount $orderLabel) "
            } else {
                " Returning Customer "
            }
            printerBuilder
                .actionFeed(0.5)
                .add(
                    PrinterBuilder()
                        .styleAlignment(Alignment.Center)
                        .styleInvert(true)
                        .styleBold(true)
                        .actionPrintText(returningText)
                )
                .actionPrintText("\n")
        }     
            
        // Customer phone number in centered align if found
        if (customerPhone.isNotEmpty()) {
            printerBuilder
                .actionFeed(0.5)
                .styleAlignment(Alignment.Center)
                .actionPrintText("Phone: $customerPhone\n")
                .styleAlignment(Alignment.Left)
        }

        // Disposable items (can be added to orderData if needed)
        // printerBuilder
        //     .styleInvert(false)
        //     .styleBold(false)
        //     .actionPrintText("Disposable items: No\n")
        //     .actionFeed(1.0)

        printerBuilder.actionPrintRuledLine(RuledLineParameter(72.0).setThickness(0.1))
        .actionFeed(1.0)

        // Items
        for (item in items) {
            val itemMap = item as? Map<*, *> ?: continue
            val quantity = (itemMap["quantity"] as? Number)?.toInt() ?: 1
            val name = (itemMap["name"] as? String) ?: ""
            val price = (itemMap["price"] as? Number)?.toDouble() ?: 0.0
            val modifiers = (itemMap["modifiers"] as? List<*>) ?: emptyList<Any>()
            val itemNote = (itemMap["itemNote"] as? String) ?: ""

            // Item line: quantity x name (no price for kitchen) - 2x2 size, bold
            printerBuilder
                .styleMagnification(MagnificationParameter(2, 2))
                .styleBold(true)
                .actionPrintText("$quantity x $name\n")
                .styleMagnification(MagnificationParameter(2, 1))
                .styleBold(false)

            // Modifiers (no price for kitchen)
            for (modifier in modifiers) {
                val modMap = modifier as? Map<*, *> ?: continue
                val modName = (modMap["name"] as? String) ?: ""
                printerBuilder.actionPrintText("  $modName\n")
            }

            // Item note with inverted style and 2x2 size (same as order note)
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
                .actionFeed(1.0)
                .actionPrintText("Placed at: $placedAt\n")
        }
        if (dueAt.isNotEmpty()) {
            printerBuilder.actionPrintText("Due at: $dueAt\n")
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
                        .settingPrintableArea(72.0)
                        .addPrinter(
                            buildQuoteReceipt(orderData)
                        )
                )

                val commands = builder.getCommands()

                printer.printAsync(commands).await()
                printer.closeAsync().await()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Print quote error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }
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
                        .settingPrintableArea(72.0)
                        .addPrinter(
                            buildReportReceipt(reportData)
                        )
                )

                val commands = builder.getCommands()

                printer.printAsync(commands).await()
                printer.closeAsync().await()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Print report error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }
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
                        .settingPrintableArea(72.0)
                        .addPrinter(
                            buildVoidReceipt(orderData)
                        )
                )

                val commands = builder.getCommands()

                printer.printAsync(commands).await()
                printer.closeAsync().await()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("StarXpand", "Print void receipt error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }
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