// lib/services/wifi_security_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// خدمة فحص أمان شبكات WiFi
class WifiSecurityService {
  static final WifiSecurityService _instance = WifiSecurityService._internal();
  factory WifiSecurityService() => _instance;
  WifiSecurityService._internal();

  static const platform = MethodChannel('com.waseed.app/wifi_security');
  final Connectivity _connectivity = Connectivity();
  static const String _lastWarningKey = 'last_wifi_warning_ssid';

  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _lastCheckedSSID;
  String? _lastCheckedBSSID;
  bool _isInitialized = false;
  bool _permissionsGranted = false;
  bool _isCheckingNetwork = false;


  bool get isInitialized => _isInitialized;

  /// تهيئة الخدمة
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('✅ WiFi Security Service already initialized');
      return true;
    }

    try {
      
      _permissionsGranted = await _requestPlatformPermissions();
      
      if (!_permissionsGranted) {
        print('⚠️ Permissions not granted - service will have limited functionality');
        return false;
      }
      
      _startNetworkMonitoring();
      
      _isInitialized = true;
      print('✅ WiFi Security Service initialized successfully');
      return true;
      
    } catch (e) {
      print('❌ Error initializing WiFi Security Service: $e');
      return false;
    }
  }

  ///  فحص الشبكة الحالية - 
  Future<WifiSecurityStatus?> checkCurrentNetwork() async {
    if (_isCheckingNetwork) {
      print('Already checking network...');
      return null;
    }

    if (!_permissionsGranted) {
      print('⚠️ Cannot check network - permissions not granted');
      return WifiSecurityStatus.permissionDenied();
    }

    _isCheckingNetwork = true;

    try {
      // . التحقق من الاتصال بـ WiFi
      final List<ConnectivityResult> connectivityResult = 
          await _connectivity.checkConnectivity();
      
      if (!connectivityResult.contains(ConnectivityResult.wifi)) {
        print('🔵 Not connected to WiFi');
        _isCheckingNetwork = false;
        return WifiSecurityStatus.notConnectedToWifi();
      }

      // 2. الحصول على معلومات الشبكة من Native Code
      final Map<dynamic, dynamic> rawData = 
          await platform.invokeMethod('getWifiSecurityStatus');
      
      if (rawData.isEmpty) {
        print('⚠️ No network data received');
        _isCheckingNetwork = false;
        return null;
      }

      // 3. تحويل البيانات
      final status = WifiSecurityStatus.fromMap(Map<String, dynamic>.from(rawData));
      
      //. فحص: هل هذه نفس الشبكة السابقة؟
      if (_lastCheckedSSID == status.ssid && _lastCheckedBSSID == status.bssid) {
        print('ℹ️ Same network - skipping notification');
        _isCheckingNetwork = false;
        return null; // لا ترجع البيانات لتجنب التحذير المكرر
      }
      
      // 5. حفظ آخر شبكة تم فحصها
      _lastCheckedSSID = status.ssid;
      _lastCheckedBSSID = status.bssid;
      
      _printNetworkStatus(status);
      _isCheckingNetwork = false;
      
      return status;
      
    } on PlatformException catch (e) {
      print('❌ Platform Error: ${e.code} - ${e.message}');
      _isCheckingNetwork = false;
      
          if (e.code == 'UNKNOWN_NETWORK' || e.code == 'INVALID_BSSID') {
      print('⚠️ No location permission - showing dialog');
      return WifiSecurityStatus.permissionDenied();
    }
    
    if (e.code == 'PERMISSION_DENIED') {
      return WifiSecurityStatus.permissionDenied();
    }
    
    return WifiSecurityStatus.error(e.message ?? 'Unknown error');
      
    } catch (e) {
      print('❌ Unexpected Error: $e');
      _isCheckingNetwork = false;
      return WifiSecurityStatus.error(e.toString());
    }
  }

  /// إعادة تعيين الحالة (للاختبار أو عند تغيير الشبكة)
  void resetLastChecked() {
    _lastCheckedSSID = null;
    _lastCheckedBSSID = null;
    print('🔄 Reset last checked network');
  }


 /// فحص إذا تم عرض التحذير لهذه الشبكة من قبل
  Future<bool> wasWarningShown(String ssid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWarning = prefs.getString(_lastWarningKey);
      return lastWarning == ssid;
    } catch (e) {
      return false;
    }
  }
  
  /// حفظ أنه تم عرض التحذير لهذه الشبكة
  Future<void> markWarningShown(String ssid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastWarningKey, ssid);
      print('✅ Warning marked as shown for: $ssid');
    } catch (e) {
      print('❌ Error marking warning: $e');
    }
  }
  
  /// مسح السجل (عند تغيير الشبكة)
  Future<void> clearWarningHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastWarningKey);
    } catch (e) {
      print('❌ Error clearing history: $e');
    }
  }
  void dispose() {
    _connectivitySubscription?.cancel();
    _isInitialized = false;
    _lastCheckedSSID = null;
    _lastCheckedBSSID = null;
    print('🛑 WiFi Security Service disposed');
  }

  // ============================================
  // Private Methods
  // ============================================

  Future<bool> _requestPlatformPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } on PlatformException catch (e) {
      print('❌ Permission request failed: ${e.message}');
      return false;
    }
  }

  void _startNetworkMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> result) {
        if (result.contains(ConnectivityResult.wifi)) {
          print('🔄 WiFi connection detected - resetting check');
          resetLastChecked();
        } else {
          print('🔵 Disconnected from WiFi');
          resetLastChecked();
        }
      },
    );
  }
//to check i well remove it 
  void _printNetworkStatus(WifiSecurityStatus status) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📡 Network Security Status:');
    print('   SSID: ${status.ssid}');
    print('   BSSID: ${status.bssid}');
    print('   Security: ${status.securityType}');
    print('   Is Secure: ${status.isSecure ? "✅" : "❌"}');
    print('   Source: ${status.dataSource}');
    print('   Platform: ${status.platform}');
    print('   Confidence: ${status.confidence}%');
    if (status.trustScore != null) {
      print('   Trust Score: ${status.trustScore}');
    }
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}

// ============================================
// Data Model
// ============================================

class WifiSecurityStatus {
  final String ssid;
  final String bssid;
  final String securityType;
  final bool isSecure;
  final String dataSource;
  final String platform;
  final int confidence;
  final int? trustScore;
  final int? reportCount;
  final String? warning;
  final bool hasError;
  final String? errorMessage;

  WifiSecurityStatus({
    required this.ssid,
    required this.bssid,
    required this.securityType,
    required this.isSecure,
    required this.dataSource,
    required this.platform,
    required this.confidence,
    this.trustScore,
    this.reportCount,
    this.warning,
    this.hasError = false,
    this.errorMessage,
  });

  factory WifiSecurityStatus.fromMap(Map<String, dynamic> map) {
    return WifiSecurityStatus(
      ssid: map['ssid'] as String? ?? 'Unknown',
      bssid: map['bssid'] as String? ?? 'unknown',
      securityType: map['securityType'] as String? ?? 'UNKNOWN',
      isSecure: map['isSecure'] as bool? ?? false,
      dataSource: map['source'] as String? ?? 'Unknown',
      platform: map['platform'] as String? ?? Platform.operatingSystem,
      confidence: map['confidence'] as int? ?? 0,
      trustScore: map['trustScore'] as int?,
      reportCount: map['reportCount'] as int?,
      warning: map['warning'] as String?,
      hasError: false,
    );
  }

  factory WifiSecurityStatus.notConnectedToWifi() {
    return WifiSecurityStatus(
      ssid: '',
      bssid: '',
      securityType: 'N/A',
      isSecure: true,
      dataSource: 'System',
      platform: Platform.operatingSystem,
      confidence: 100,
      hasError: false,
    );
  }

  factory WifiSecurityStatus.permissionDenied() {
    return WifiSecurityStatus(
      ssid: '',
      bssid: '',
      securityType: 'N/A',
      isSecure: true,
      dataSource: 'System',
      platform: Platform.operatingSystem,
      confidence: 0,
      hasError: true,
      errorMessage: 'Permission denied',
    );
  }

  factory WifiSecurityStatus.error(String message) {
    return WifiSecurityStatus(
      ssid: '',
      bssid: '',
      securityType: 'ERROR',
      isSecure: true,
      dataSource: 'Error',
      platform: Platform.operatingSystem,
      confidence: 0,
      hasError: true,
      errorMessage: message,
    );
  }

  

  bool get shouldShowWarning => !isSecure && !hasError && ssid.isNotEmpty;
  
  String get securityDescription {
    if (hasError) return 'خطأ في الفحص';
    if (ssid.isEmpty) return 'غير متصل';
    
    switch (securityType.toUpperCase()) {
      case 'WPA3':
      case 'WPA3-SAE':
        return 'آمن جداً (WPA3)';
      case 'WPA2':
      case 'WPA2-PSK':
        return 'آمن (WPA2)';
      case 'WPA':
        return 'أمان ضعيف (WPA)';
      case 'WEP':
        return 'غير آمن (WEP)';
      case 'OPEN':
        return 'مفتوح - غير آمن';
      default:
        return 'غير معروف';
    }
  }
}