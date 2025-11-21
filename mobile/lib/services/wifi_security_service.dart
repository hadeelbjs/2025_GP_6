// lib/services/wifi_security_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

/// خدمة فحص أمان شبكات WiFi
class WifiSecurityService {
  static final WifiSecurityService _instance = WifiSecurityService._internal();
  factory WifiSecurityService() => _instance;
  WifiSecurityService._internal();

  static const platform = MethodChannel('com.waseed.app/wifi_security');
  final Connectivity _connectivity = Connectivity();
  final _networkStatusController = StreamController<WifiSecurityStatus>.broadcast();

  
  // مفاتيح التخزين
  static const String _permissionsAskedKey = 'wifi_permissions_asked';
  static const String _permissionsGrantedKey = 'wifi_permissions_granted';
  static const String _userDeclinedPermanentlyKey = 'wifi_user_declined_permanently';
  static const String _lastCheckedSSIDKey = 'last_checked_ssid';
  static const String _lastCheckedBSSIDKey = 'last_checked_bssid';
  static const String _lastWarningSSIDKey = 'last_warning_ssid';
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Stream<WifiSecurityStatus> get onNetworkChanged => _networkStatusController.stream;

  bool _isInitialized = false;
  bool _isCheckingNetwork = false;

  bool get isInitialized => _isInitialized;

  ///   - تُستدعى مرة واحدة عند تشغيل التطبيق
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('✅ WiFi Security Service already initialized');
      return true;
    }

    try {
      // بدء مراقبة تغييرات الشبكة
      _startNetworkMonitoring();
      
      _isInitialized = true;
      print('✅ WiFi Security Service initialized');
      return true;
      
    } catch (e) {
      print('❌ Error initializing WiFi Security Service: $e');
      return false;
    }
  }

  /// التحقق من حالة الصلاحيات المحفوظة
  Future<PermissionState> getPermissionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
       //  هل المستخدم رفض نهائياً؟
    final userDeclinedPermanently = prefs.getBool(_userDeclinedPermanentlyKey) ?? false;
    if (userDeclinedPermanently) {
      return PermissionState.userDeclinedPermanently;
    }
      
      // هل تم السؤال من قبل؟
      final wasAsked = prefs.getBool(_permissionsAskedKey) ?? false;
      
      if (!wasAsked) {
        return PermissionState.neverAsked;
      }
      
      // هل تم منح الصلاحيات؟
      final wasGranted = prefs.getBool(_permissionsGrantedKey) ?? false;
      
      // التحقق من الحالة الفعلية (قد يكون المستخدم غيّرها من الإعدادات)
      final currentlyGranted = await _checkPlatformPermissions();
      
      // تحديث الحالة المحفوظة
      if (currentlyGranted != wasGranted) {
        await prefs.setBool(_permissionsGrantedKey, currentlyGranted);
      }
      
      if (currentlyGranted) {
        return PermissionState.granted;
      } else {
        return PermissionState.denied;
      }
      
    } catch (e) {
      print('❌ Error getting permission state: $e');
      return PermissionState.neverAsked;
    }
  }
  /// تسجيل أن المستخدم رفض نهائياً (ضغط "لاحقاً" أو "إلغاء")
Future<void> markUserDeclinedPermanently() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userDeclinedPermanentlyKey, true);
    await prefs.setBool(_permissionsAskedKey, true);
    print('ℹ️ User declined WiFi check permanently');
  } catch (e) {
    print('❌ Error marking user declined: $e');
  }
}

  /// طلب الصلاحيات (يُستدعى مرة واحدة فقط)
  Future<bool> requestPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // تسجيل أننا سألنا
      await prefs.setBool(_permissionsAskedKey, true);
      
      // طلب صلاحية الموقع من Flutter plugin
      await _requestLocationPermission();
      
      // طلب صلاحيات من Native code
      final result = await platform.invokeMethod<bool>('requestPermissions');
      final granted = result ?? false;
      
      // حفظ النتيجة
      await prefs.setBool(_permissionsGrantedKey, granted);
      
      print('✅ Permissions requested: $granted');
      return granted;
      
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// فحص الشبكة الحالية - يُستدعى عند فتح Dashboard
  Future<WifiCheckResult> checkNetworkOnAppLaunch() async {
    try {
      // التحقق من الصلاحيات
      final permissionState = await getPermissionState();
      
      if (permissionState == PermissionState.neverAsked) {
        return WifiCheckResult.needsPermission();
      }
      if (permissionState == PermissionState.userDeclinedPermanently) {
      return WifiCheckResult.userDeclined();
    }
      
      if (permissionState == PermissionState.denied) {
        return WifiCheckResult.permissionDenied();
      }
      
      // إجراء الفحص
      final status = await _performNetworkCheck();
      
      if (status == null) {
        return WifiCheckResult.notConnected();
      }
      
      // التحقق: هل سبق وفحصنا هذه الشبكة؟
      final alreadyChecked = await _isNetworkAlreadyChecked(status.ssid, status.bssid);
      
      if (alreadyChecked) {
        print('ℹ️ Network "${status.ssid}" already checked - skipping alert');
        return WifiCheckResult.alreadyChecked();
      }
      
      // تسجيل أننا فحصنا هذه الشبكة
      await _markNetworkAsChecked(status.ssid, status.bssid, status.isSecure);
      
      return WifiCheckResult.success(status);
      
    } catch (e) {
      print('❌ Error checking network on app launch: $e');
      return WifiCheckResult.error(e.toString());
    }
  }

  /// التحقق من أن الشبكة تم فحصها من قبل
  Future<bool> _isNetworkAlreadyChecked(String ssid, String bssid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSSID = prefs.getString(_lastCheckedSSIDKey);
      final lastBSSID = prefs.getString(_lastCheckedBSSIDKey);
      
      // مقارنة BSSID (أدق)
      if (lastBSSID != null && lastBSSID == bssid) {
        return true;
      }
      
      // مقارنة SSID كبديل
      if (lastSSID != null && lastSSID == ssid) {
        return true;
      }
      
      return false;
      
    } catch (e) {
      print('❌ Error checking if network was checked: $e');
      return false;
    }
  }

  /// تسجيل أننا فحصنا هذه الشبكة
  Future<void> _markNetworkAsChecked(String ssid, String bssid, bool isSecure) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckedSSIDKey, ssid);
      await prefs.setString(_lastCheckedBSSIDKey, bssid);
      
      // حفظ أننا عرضنا التحذير إذا كانت غير آمنة
      if (!isSecure) {
        await prefs.setString(_lastWarningSSIDKey, ssid);
      }
      
      print('✅ Network "$ssid" marked as checked');
      
    } catch (e) {
      print('❌ Error marking network as checked: $e');
    }
  }

  /// إعادة تعيين حالة الفحص (عند تغيير الشبكة أو الانقطاع)
  Future<void> resetCheckState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastCheckedSSIDKey);
      await prefs.remove(_lastCheckedBSSIDKey);
      await prefs.remove(_lastWarningSSIDKey);
      print('🔄 Check state reset - ready for new network');
    } catch (e) {
      print('❌ Error resetting check state: $e');
    }
  }

  /// التحقق من الصلاحيات الفعلية من النظام
  Future<bool> _checkPlatformPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('checkPermissions');
      return result ?? false;
    } on PlatformException catch (e) {
      print('❌ Permission check failed: ${e.message}');
      return false;
    }
  }

  /// طلب صلاحية الموقع من Flutter
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }
  }

  /// إجراء الفحص الفعلي للشبكة
  Future<WifiSecurityStatus?> _performNetworkCheck() async {
    if (_isCheckingNetwork) {
      print('⏳ Already checking network...');
      return null;
    }

    _isCheckingNetwork = true;

    try {
     
final Map<dynamic, dynamic> rawData = 
        await platform.invokeMethod('getWifiSecurityStatus');
    
    if (rawData.isEmpty) {
      print('⚠️ No network data received');
      _isCheckingNetwork = false;
      return null;
    }

    final status = WifiSecurityStatus.fromMap(Map<String, dynamic>.from(rawData));
    
    _isCheckingNetwork = false;
    return status;
    
  } on PlatformException catch (e) {
    print('❌ Platform Error: ${e.code} - ${e.message}');
    _isCheckingNetwork = false;
    return null;
    
  } catch (e) {
    print('❌ Unexpected Error: $e');
    _isCheckingNetwork = false;
    return null;
  }
}

  /// مراقبة تغييرات الشبكة
  void _startNetworkMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> result) async {
        if (result.contains(ConnectivityResult.wifi)) {
          print('🔄 WiFi connection detected - checking if network changed');
          
          // التحقق من أن الشبكة تغيرت فعلاً
          final changed = await _hasNetworkChanged();
          
          if (changed) {
            print('🆕 New network detected - resetting and will check on next dashboard open');
            await resetCheckState();
            final status = await _performNetworkCheck();
            if (status != null) {
              _networkStatusController.add(status); 
            }
            //  سيتم الفحص عند فتح Dashboard
          } else {
            print('ℹ️ Same network - no action needed');
          }
        } else {
          print('📵 Disconnected from WiFi');
        //await resetCheckState();
        }
      },
    );
  }

  /// التحقق من أن الشبكة تغيرت
  Future<bool> _hasNetworkChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSSID = prefs.getString(_lastCheckedSSIDKey);
      final lastBSSID = prefs.getString(_lastCheckedBSSIDKey);
      
      // إذا ما في بيانات محفوظة، يعني شبكة جديدة
      if (lastSSID == null || lastBSSID == null) {
        return true;
      }
      
      // محاولة الحصول على معلومات الشبكة الحالية
      try {
        final Map<dynamic, dynamic> rawData = 
            await platform.invokeMethod('getWifiSecurityStatus');
        
        final currentSSID = rawData['ssid'] as String?;
        final currentBSSID = rawData['bssid'] as String?;
        
        // مقارنة BSSID (أدق من SSID)
        if (currentBSSID != null && currentBSSID != lastBSSID) {
          return true;
        }
        
        // إذا ما قدرنا نحصل BSSID، نقارن SSID
        if (currentSSID != null && currentSSID != lastSSID) {
          return true;
        }
        
        return false;
        
      } catch (e) {
        // إذا فشل الحصول على البيانات، نعتبرها شبكة جديدة للأمان
        return true;
      }
      
    } catch (e) {
      print('❌ Error checking network change: $e');
      return true; // للأمان، نعتبرها شبكة جديدة
    }
  }

  

  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController.close();
   _isInitialized = false;
    print('🛑 WiFi Security Service disposed');
  }
}

// Enums & Data Models
enum PermissionState {
  neverAsked,  // لم يُسأل من قبل
  granted,     // تم منح الصلاحيات
  denied, // تم رفض الصلاحيات
  userDeclinedPermanently,      
}

class WifiCheckResult {
  final WifiCheckResultType type;
  final WifiSecurityStatus? status;
  final String? errorMessage;

  WifiCheckResult({
    required this.type,
    this.status,
    this.errorMessage,
  });

  factory WifiCheckResult.needsPermission() {
    return WifiCheckResult(type: WifiCheckResultType.needsPermission);
  }

  factory WifiCheckResult.permissionDenied() {
    return WifiCheckResult(type: WifiCheckResultType.permissionDenied);
  }
  factory WifiCheckResult.userDeclined() {
    return WifiCheckResult(type: WifiCheckResultType.userDeclined);
  }

  factory WifiCheckResult.success(WifiSecurityStatus status) {
    return WifiCheckResult(
      type: WifiCheckResultType.success,
      status: status,
    );
  }

  factory WifiCheckResult.notConnected() {
    return WifiCheckResult(type: WifiCheckResultType.notConnected);
  }

  factory WifiCheckResult.alreadyChecked() {
    return WifiCheckResult(type: WifiCheckResultType.alreadyChecked);
  }

  factory WifiCheckResult.error(String message) {
    return WifiCheckResult(
      type: WifiCheckResultType.error,
      errorMessage: message,
    );
  }
}

enum WifiCheckResultType {
  needsPermission,   // يحتاج صلاحيات
  permissionDenied, // الصلاحيات مرفوضة
  userDeclined, 
  success,           // نجح الفحص
  notConnected,      // غير متصل بـ WiFi
  alreadyChecked,    // تم الفحص مسبقاً في هذه الجلسة
  error,             // خطأ
}

class WifiSecurityStatus {
  final String ssid;
  final String bssid;
  final String securityType;
  final bool isSecure;
  final String dataSource;
  final String platform;
  final int confidence;
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
      warning: map['warning'] as String?,
      hasError: false,
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