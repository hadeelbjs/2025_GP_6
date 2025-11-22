import UIKit
import Flutter
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let CHANNEL = "com.waseed.app/wifi_security"
     
     //Screenshot Protection Channel
    private let SCREENSHOT_CHANNEL = "com.waseed/screenshot_protection"
    
    private lazy var locationManager: CLLocationManager = { 
        let manager = CLLocationManager()
        return manager
    }()

// Screenshot Protection Properties
    private var secureView: UIView?
    private var secureTextField: UITextField?
    private var screenshotMethodChannel: FlutterMethodChannel?

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
        
        // ============================================
        // 2. Screenshot Protection Channel 
        // ============================================
        screenshotMethodChannel = FlutterMethodChannel(
            name: SCREENSHOT_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        
        screenshotMethodChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate not available", details: nil))
                return
            }
            
            switch call.method {
            case "enableProtection":
                self.enableScreenshotProtection()
                result(true)
            case "disableProtection":
                self.disableScreenshotProtection()
                result(true)
            case "isProtectionEnabled":
                result(self.secureView != nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        // Setup Screenshot Detection
        setupScreenshotDetection()

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
     // ============================================
    // Screenshot Protection Methods
    // ============================================
    
    private func enableScreenshotProtection() {
        guard let window = window else { return }
        
        // إذا الحماية مفعلة مسبقاً
        if secureView != nil { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // إنشاء UITextField مع isSecureTextEntry
            let textField = UITextField()
            textField.isSecureTextEntry = true
            self.secureTextField = textField
            
            // الحصول على الـ secure view
            guard let secureLayer = textField.layer.sublayers?.first,
                  let secureViewFromLayer = secureLayer.delegate as? UIView else {
                print("⚠️ iOS: Could not get secure view, using fallback")
                self.enableProtectionFallback()
                return
            }
            
            self.secureView = secureViewFromLayer
            secureViewFromLayer.subviews.forEach { $0.removeFromSuperview() }
            
            secureViewFromLayer.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(secureViewFromLayer)
            
            NSLayoutConstraint.activate([
                secureViewFromLayer.topAnchor.constraint(equalTo: window.topAnchor),
                secureViewFromLayer.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                secureViewFromLayer.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                secureViewFromLayer.trailingAnchor.constraint(equalTo: window.trailingAnchor)
            ])
            
            window.sendSubviewToBack(secureViewFromLayer)
            print("✅ iOS: Screenshot protection enabled")
        }
    }
    
    private func enableProtectionFallback() {
        // Fallback protection using privacy screen
        print("⚠️ iOS: Using fallback protection method")
    }
    
    private func disableScreenshotProtection() {
        DispatchQueue.main.async { [weak self] in
            self?.secureView?.removeFromSuperview()
            self?.secureView = nil
            self?.secureTextField = nil
            print("🔓 iOS: Screenshot protection disabled")
        }
    }
    
    // Screenshot Detection
    
    private func setupScreenshotDetection() {
        // كشف Screenshot
        NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📸 iOS: Screenshot detected!")
            self?.screenshotMethodChannel?.invokeMethod("onScreenshotTaken", arguments: nil)
        }
        
        // كشف تسجيل الشاشة (iOS 11+)
        if #available(iOS 11.0, *) {
            NotificationCenter.default.addObserver(
                forName: UIScreen.capturedDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                let isRecording = UIScreen.main.isCaptured
                print("🎥 iOS: Screen recording: \(isRecording)")
                self?.screenshotMethodChannel?.invokeMethod(
                    "onScreenRecordingChanged",
                    arguments: ["isRecording": isRecording]
                )
            }
        }
    }
    
    // App Lifecycle for Privacy Screen
    
    override func applicationWillResignActive(_ application: UIApplication) {
        // إضافة شاشة خصوصية عند الخروج
        if secureView != nil {
            addPrivacyScreen()
        }
        super.applicationWillResignActive(application)
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        // إزالة شاشة الخصوصية  
        removePrivacyScreen()
        super.applicationDidBecomeActive(application)
    }
    
    private func addPrivacyScreen() {
        guard let window = window else { return }
        
        if window.viewWithTag(888) != nil { return }
        
        let privacyView = UIView(frame: window.bounds)
        privacyView.backgroundColor = .black
        privacyView.tag = 888
        
        let lockIcon = UIImageView(image: UIImage(systemName: "lock.fill"))
        lockIcon.tintColor = .white
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        lockIcon.center = privacyView.center
        privacyView.addSubview(lockIcon)
        
        window.addSubview(privacyView)
    }
    
    private func removePrivacyScreen() {
        window?.viewWithTag(888)?.removeFromSuperview()
    }
    
    // ============================================
    // MARK: - WiFi Security Detection
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
        
        guard var response = getWifiInfo() else {
            result(FlutterError(
                code: "NO_WIFI",
                message: "Not connected to WiFi",
                details: nil
            ))
            return
        }
        
        let ssid = response["ssid"] as? String ?? "Unknown"
        
        // التحقق من موثوقية البيانات
        if response["confidence"] as? Int ?? 0 >= 90 {
            print("📊 iOS Result (High Confidence): \(response)")
            result(response)
            return
        }
        
        // التحليل المستند إلى القاعدة (Fallback)
        print("ℹ️ Falling back to Rule-Based analysis...")
        let analysis = analyzeNetworkByName(ssid: ssid)
        
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
        
        let publicKeywords = [
            "free", "public", "guest", "open", "wifi",
            "airport", "hotel", "cafe", "restaurant", "mall",
            "starbucks", "mcdonald", "subway", "costa",
            "مجاني", "عام", "ضيوف", "زوار", "مطار",
            "فندق", "مقهى", "مطعم"
        ]
        
        let weakKeywords = [
            "test", "temp", "default", "admin",
            "tp-link", "dlink", "tenda"
        ]
        
        let privateKeywords = [
            "home", "house", "office", "work",
            "منزل", "مكتب", "بيت"
        ]
        
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
        
        return [
            "type": "UNKNOWN",
            "isSecure": true,
            "confidence": 40,
            "reason": "لا يمكن تحديد نوع الشبكة - افتراضياً خاصة"
        ]
    }
    
    // ============================================
    // MARK: - WiFi Info Retrieval
    // ============================================
    
    private func getWifiInfo() -> [String: Any]? {
        if #available(iOS 15.0, *) {
            return getWifiInfoModern()
        }
        return getWifiInfoLegacy()
    }
    
    @available(iOS 15.0, *)
    private func getWifiInfoModern() -> [String: Any]? {
        var wifiInfo: [String: Any]?
        let semaphore = DispatchSemaphore(value: 0)
        
        NEHotspotNetwork.fetchCurrent { network in
            defer { semaphore.signal() }
            
            guard let network = network else {
                print("⚠️ No WiFi network detected or Location permission denied.")
                return
            }
            
            let securityType = self.mapSecurityType(network.securityType)
            let isSecure = securityType != "OPEN" && securityType != "WEP"
            
            wifiInfo = [
                "ssid": network.ssid,
                "bssid": network.bssid,
                "securityType": securityType,
                "isSecure": isSecure,
                "source": "iOS Native (NEHotspotNetwork)",
                "platform": "iOS",
                "confidence": 95,
                "warning": securityType == "WPA/WPA2/WPA3" ? "لا يمكن التحديد بدقة بين WPA2 و WPA3" : nil
            ]
            
            print("✅ NEHotspotNetwork Info: \(wifiInfo ?? [:])")
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
    
    @available(iOS 15.0, *)
    private func mapSecurityType(_ type: NEHotspotNetworkSecurityType) -> String {
        switch type {
        case .open:
            return "OPEN"
        case .WEP:
            return "WEP"
        case .personal:
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
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestWhenInUseAuthorization() 
        }
        result(checkLocationPermission())
    } 
    
    private func checkLocationPermission() -> Bool {
        let status = CLLocationManager.authorizationStatus()
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

extension AppDelegate: CLLocationManagerDelegate {}