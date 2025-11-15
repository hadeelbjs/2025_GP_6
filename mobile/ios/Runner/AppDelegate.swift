import UIKit
import Flutter
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import CoreLocation
@main
@objc class AppDelegate: FlutterAppDelegate {
    //استدعي الدوال اللي بفلتر باستخدام channel
    private let CHANNEL = "com.waseed.app/wifi_security"
    //نستخدمه لطلب صلاحية الموقع
     private lazy var locationManager: CLLocationManager = { 
        let manager = CLLocationManager()
        return manager
    }()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        //Listener
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
        
        // الحصول على معلومات الواي فاي. إذا كان iOS >= 14، سيتم جلب معلومات الأمان أيضاً
        guard var response = getWifiInfo() else {
            result(FlutterError(
                code: "NO_WIFI",
                message: "Not connected to WiFi",
                details: nil
            ))
            return
        }
        
        let ssid = response["ssid"] as? String ?? "Unknown"
        
        // 1. التحقق من موثوقية البيانات
        // إذا كانت الثقة عالية (من NEHotspotNetwork أو Legacy)، نستخدمها مباشرة
        if response["confidence"] as? Int ?? 0 >= 90 {
            print("📊 iOS Result (High Confidence): \(response)")
            result(response)
            return
        }

        
        
        // 2. التحليل المستند إلى القاعدة (Fallback)
        // يتم هذا فقط إذا فشل الحصول على معلومات الأمان من NEHotspotNetwork (للإصدارات القديمة أو فشل NE)
        
        print("ℹ️ Falling back to Rule-Based analysis...")
        let analysis = analyzeNetworkByName(ssid: ssid)
        
        // دمج نتائج التحليل القديم في الرد
        response["ssid"] = ssid
        response["bssid"] = response["bssid"] as? String ?? "unknown"
        response["platform"] = "iOS"
        response["securityType"] = analysis["type"] ?? "UNKNOWN"
        response["isSecure"] = analysis["isSecure"] ?? false
        response["source"] = "Rule-Based Analysis (Fallback)"
        response["confidence"] = analysis["confidence"] ?? 40
        response["warning"] = "التحليل بناءً على اسم الشبكة فقط"
        
        print("📊 iOS Result (Low Confidence Fallback): \(response)")
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
            "isSecure": true,
            "confidence": 40,
            "reason": "لا يمكن تحديد نوع الشبكة - افتراضياً خاصة"
        ]
    }
    
    
    // WiFi Info Retrieval
    
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
            print("⚠️ No WiFi network detected or Location permission denied.")
            return
        }
        
        // **الآن نحصل على نوع الأمان الفعلي**
        let securityType = self.mapSecurityType(network.securityType)
        let isSecure = securityType != "OPEN" && securityType != "WEP"
        
        wifiInfo = [
            "ssid": network.ssid,
            "bssid": network.bssid,
            "securityType": securityType,
            "isSecure": isSecure,
            "source": "iOS Native (NEHotspotNetwork)",
            "platform": "iOS",
            "warning": securityType == "WPA/WPA2/WPA3" ? "لا يمكن التحديد بدقة بين WPA2 و WPA3" : nil
        ]
        
        print("✅ NEHotspotNetwork Info: \(wifiInfo ?? [:])") //
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
            let ssid = info["SSID"] as? String ?? "Unknown"
            let bssid = info["BSSID"] as? String ?? "unknown"
        return [
                "ssid": ssid,
                "bssid": bssid,
                "securityType": "UNKNOWN", 
                "isSecure": false,
                "source": "iOS Legacy (CNCopyCurrentNetworkInfo)",
                "platform": "iOS",
                "confidence": 50 
            ]
        }
        
        print("⚠️ Could not get WiFi info")
        return nil
    }
    private func mapSecurityType(_ type: NEHotspotNetworkSecurityType) -> String {
    switch type {
    case .open:
        return "OPEN"
    case .WEP:
        return "WEP"
    case .personal:
        // يشمل WPA/WPA2/WPA3 Personal
        return "WPA/WPA2/WPA3"
    case .enterprise:
        return "WPA_ENTERPRISE"
    case .unknown:
        return "UNKNOWN"
    @unknown default:
        return "UNKNOWN"
    }
}



    // ============================================
    // MARK: - Permissions
    // ============================================
    
    private func requestLocationPermission(result: @escaping FlutterResult) {
    // إذا لم يتم تحديد حالة الصلاحية بعد، قم بطلبها
    if CLLocationManager.authorizationStatus() == .notDetermined {
         locationManager.requestWhenInUseAuthorization() 
    }
    // ارجع الحالة الحالية (سواء تمت الموافقة، الرفض، أو لا تزال قيد الانتظار)
    result(checkLocationPermission())
} 
    
    private func checkLocationPermission() -> Bool {
        let status = CLLocationManager.authorizationStatus()
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

import CoreLocation
extension AppDelegate: CLLocationManagerDelegate {}