import UIKit
import Flutter
import NetworkExtension
import SystemConfiguration.CaptiveNetwork

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private let CHANNEL = "com.waseed.app/wifi_security"
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let wifiChannel = FlutterMethodChannel(
            name: CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        
        wifiChannel.setMethodCallHandler({ [weak self]
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE",
                                  message: "AppDelegate not available",
                                  details: nil))
                return
            }
            
            switch call.method {
            case "getWifiSecurityStatus":
                self.getWifiSecurityStatus(result: result)
                
            case "requestPermissions":
                self.requestLocationPermission(result: result)
                
            case "checkPermissions":
                let hasPermissions = self.checkLocationPermission()
                result(hasPermissions)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // ============================================
    // MARK: - WiFi Security Detection (Rule-Based Only)
    // ============================================
    
    private func getWifiSecurityStatus(result: @escaping FlutterResult) {
        
        guard checkLocationPermission() else {
            result(FlutterError(
                code: "PERMISSION_DENIED",
                message: "Location permission required",
                details: nil
            ))
            return
        }
        
        guard let wifiInfo = getWifiInfo() else {
            result(FlutterError(
                code: "NO_WIFI",
                message: "Not connected to WiFi",
                details: nil
            ))
            return
        }
        
        let ssid = wifiInfo["SSID"] as? String ?? "Unknown"
        let bssid = wifiInfo["BSSID"] as? String ?? "unknown"
        // delete after check 
        print("📡 iOS WiFi Info:")
        print("   SSID: \(ssid)")
        print("   BSSID: \(bssid)")
        
        // (Rule-Based)
        let analysis = analyzeNetworkByName(ssid: ssid)
        
        var response: [String: Any] = [
            "ssid": ssid,
            "bssid": bssid,
            "platform": "iOS",
            "securityType": analysis["type"] ?? "UNKNOWN",
            "isSecure": analysis["isSecure"] ?? true,
            "source": "Rule-Based Analysis",
            "confidence": analysis["confidence"] ?? 60,
            "warning": "التحليل بناءً على اسم الشبكة فقط"
        ]
        // delete after check 
        print("📊 iOS Result: \(response)")
        result(response)
    }
    
    // ============================================
    // MARK: - Rule-Based Analysis
    // ============================================
    
    private func analyzeNetworkByName(ssid: String) -> [String: Any] {
        let ssidLower = ssid.lowercased()
        
        // كلمات تدل على شبكات عامة غير آمنة
        let publicKeywords = [
            "free", "public", "guest", "open", "wifi",
            "airport", "hotel", "cafe", "restaurant", "mall",
            "starbucks", "mcdonald", "subway", "costa",
             "مجاني", "عام", "ضيوف", "زوار", "مطار",
    "فندق", "مقهى", "مطعم"
        ]
        
        // كلمات تدل على شبكات ضعيفة
        let weakKeywords = [
            "test", "temp", "default", "admin",
            "tp-link", "dlink", "tenda"
        ]
        
        //كلمات تدل على شبكات خاصة آمنة
        let privateKeywords = [
            "home", "house", "office", "work",
            "منزل", "مكتب", "بيت"
        ]
        
        //  فحص الشبكات العامة (غير آمنة)
        for keyword in publicKeywords {
            if ssidLower.contains(keyword) {
                return [
                    "type": "OPEN/PUBLIC",
                    "isSecure": false,
                    "confidence": 85,
                    "reason": "شبكة عامة - اسم يدل على شبكة مفتوحة"
                ]
            }
        }
        
        // فحص الشبكات الضعيفة
        for keyword in weakKeywords {
            if ssidLower.contains(keyword) {
                return [
                    "type": "WEAK",
                    "isSecure": false,
                    "confidence": 70,
                    "reason": "شبكة ضعيفة - قد تكون إعدادات افتراضية"
                ]
            }
        }
        
        //  فحص الشبكات الخاصة
        for keyword in privateKeywords {
            if ssidLower.contains(keyword) {
                return [
                    "type": "PRIVATE",
                    "isSecure": true,
                    "confidence": 75,
                    "reason": "شبكة خاصة - محتمل WPA2"
                ]
            }
        }
        
        //  افتراضي: شبكة خاصة (محتمل آمنة)
        return [
            "type": "UNKNOWN",
            "isSecure": false,
            "confidence": 40,
            "reason": "لا يمكن تحديد نوع الشبكة - افتراضياً خاصة"
        ]
    }
    
    // ============================================
    // MARK: - WiFi Info Retrieval
    // ============================================
    
    private func getWifiInfo() -> [String: Any]? {
        if #available(iOS 14.0, *) {
            return getWifiInfoModern()
        }
        return getWifiInfoLegacy()
    }
    
    @available(iOS 14.0, *)
    private func getWifiInfoModern() -> [String: Any]? {
        var wifiInfo: [String: Any]?
        let semaphore = DispatchSemaphore(value: 0)
        
        NEHotspotNetwork.fetchCurrent { network in
            defer { semaphore.signal() }
            
            guard let network = network else {
                print("⚠️ No WiFi network detected")
                return
            }
            
            wifiInfo = [
                "SSID": network.ssid,
                "BSSID": network.bssid
            ]
        }
        
        _ = semaphore.wait(timeout: .now() + 2.0)
        return wifiInfo
    }
    
    private func getWifiInfoLegacy() -> [String: Any]? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
            print("⚠️ No network interfaces found")
            return nil
        }
        
        for interface in interfaces {
            guard let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any] else {
                continue
            }
            return info
        }
        
        print("⚠️ Could not get WiFi info")
        return nil
    }
    
    // ============================================
    // MARK: - Permissions
    // ============================================
    
    private func requestLocationPermission(result: @escaping FlutterResult) {
        result(checkLocationPermission())
    }
    
    private func checkLocationPermission() -> Bool {
        let status = CLLocationManager.authorizationStatus()
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

import CoreLocation
extension AppDelegate: CLLocationManagerDelegate {}