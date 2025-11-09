package com.waseed.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.ScanResult
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val CHANNEL = "com.waseed.app/wifi_security"
    private val PERMISSION_REQUEST_CODE = 1001
    
    private lateinit var wifiManager: WifiManager
    private var methodChannel: MethodChannel? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getWifiSecurityStatus" -> {
                        handleWifiSecurityCheck(result)
                    }
                    "requestPermissions" -> {
                        requestNecessaryPermissions(result)
                    }
                    "checkPermissions" -> {
                        val hasPermissions = checkAllPermissions()
                        result.success(hasPermissions)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }
    
    private fun checkAllPermissions(): Boolean {
        val permissions = getRequiredPermissions()
        return permissions.all { permission ->
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        }
    }
    
    private fun getRequiredPermissions(): List<String> {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                listOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_WIFI_STATE,
                    Manifest.permission.CHANGE_WIFI_STATE,
                    Manifest.permission.NEARBY_WIFI_DEVICES
                )
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                listOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_WIFI_STATE,
                    Manifest.permission.CHANGE_WIFI_STATE
                )
            }
            else -> {
                listOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_WIFI_STATE
                )
            }
        }
    }
    
    private fun requestNecessaryPermissions(result: MethodChannel.Result) {
        val permissions = getRequiredPermissions()
        val permissionsToRequest = permissions.filter { permission ->
            ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        }
        
        if (permissionsToRequest.isEmpty()) {
            result.success(true)
        } else {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
            result.success(null)
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            methodChannel?.invokeMethod("onPermissionsResult", allGranted)
        }
    }
    
    // Android يقرأ التشفير مباشرة
    private fun handleWifiSecurityCheck(result: MethodChannel.Result) {
        try {
            if (!checkAllPermissions()) {
                result.error("PERMISSION_DENIED", "Required permissions not granted", null)
                return
            }
            
            if (!wifiManager.isWifiEnabled) {
                result.error("WIFI_DISABLED", "WiFi is not enabled", null)
                return
            }
            
            @Suppress("DEPRECATION")
            val wifiInfo: WifiInfo = wifiManager.connectionInfo
            
            if (wifiInfo.networkId == -1) {
                result.error("NOT_CONNECTED", "Not connected to any WiFi network", null)
                return
            }
            
            var ssid = wifiInfo.ssid ?: "<unknown>"
            ssid = ssid.replace("\"", "").trim()
            
            if (ssid == "<unknown>" || ssid.isEmpty()) {
                result.error("UNKNOWN_NETWORK", "Cannot determine network name", null)
                return
            }
            
            val bssid = wifiInfo.bssid ?: "unknown"
            
            if (bssid == "unknown" || bssid == "02:00:00:00:00:00") {
                result.error("INVALID_BSSID", "Cannot get valid BSSID", null)
                return
            }
            
            @Suppress("DEPRECATION")
            val scanResults = wifiManager.scanResults
            val currentNetwork = findCurrentNetwork(scanResults, ssid, bssid)
            
            if (currentNetwork == null) {
                result.error("NETWORK_NOT_FOUND", "Network not found in scan results", null)
                return
            }
            
            val securityInfo = analyzeSecurityType(currentNetwork.capabilities)
            
            result.success(
                mapOf(
                    "ssid" to ssid,
                    "bssid" to bssid,
                    "securityType" to securityInfo["type"],
                    "isSecure" to securityInfo["isSecure"],
                    "source" to "Android Native",
                    "platform" to "Android",
                    "confidence" to 100
                )
            )
            
            println("✅ Android WiFi check successful:")
            println("   SSID: $ssid")
            println("   Security: ${securityInfo["type"]}")
            println("   Is Secure: ${securityInfo["isSecure"]}")
            
        } catch (e: Exception) {
            result.error("ERROR", "Error: ${e.message}", null)
        }
    }
    
    private fun findCurrentNetwork(
        scanResults: List<ScanResult>,
        ssid: String,
        bssid: String
    ): ScanResult? {
        return scanResults.find { it.BSSID.equals(bssid, ignoreCase = true) }
            ?: scanResults.find { it.SSID == ssid }
    }
    
    private fun analyzeSecurityType(capabilities: String): Map<String, Any> {
        val caps = capabilities.uppercase()
        
        return when {
            caps.contains("WPA3") || caps.contains("SAE") -> {
                mapOf("type" to "WPA3", "isSecure" to true)
            }
            caps.contains("WPA2") -> {
                mapOf("type" to "WPA2", "isSecure" to true)
            }
            caps.contains("WPA") && !caps.contains("WPA2") && !caps.contains("WPA3") -> {
                mapOf("type" to "WPA", "isSecure" to false)
            }
            caps.contains("WEP") -> {
                mapOf("type" to "WEP", "isSecure" to false)
            }
            caps.contains("ESS") && !caps.contains("WPA") && !caps.contains("WEP") -> {
                mapOf("type" to "OPEN", "isSecure" to false)
            }
            else -> {
                mapOf("type" to "UNKNOWN", "isSecure" to false)
            }
        }
    }
}