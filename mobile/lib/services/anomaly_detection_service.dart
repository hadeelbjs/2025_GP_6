// lib/services/anomaly_detection_service.dart

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_services.dart';
import '../features/dashboard/services/notification_service.dart';
import '../core/models/app_notifications.dart';

class AnomalyDetectionService {
  static const String _wifiSsidKey = 'last_checked_ssid';
  final ApiService _api = ApiService();

  // ----------------------------------------------------------
  // الدالة الرئيسية — تُستدعى من main_dashboard.dart
  // ----------------------------------------------------------
  Future<void> runChecks() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 Anomaly Detection: بدء الفحص...');

    try {
      final deviceName = await _getDeviceName();
      print('📱 Device: ${deviceName ?? 'غير متاح'}');

      final locationData = await _getLocationData();
      if (locationData != null) {
        print('✅ Location: ${locationData['locationName']}');
      } else {
        print('⚠️ Location: غير متاح');
      }

      final ssid = await _getCurrentSSID();
      print('📶 SSID: ${ssid ?? 'غير متاح'}');

      print('📡 إرسال للـ Backend...');
      final result = await _api.checkAnomalies(
        lat: locationData?['lat'],
        lng: locationData?['lng'],
        locationName: locationData?['locationName'],
        ssid: ssid,
        deviceName: deviceName,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => {'success': false, 'message': 'timeout'},
      );

      print('📥 Backend Response: $result');

      if (result['success'] == true && result['anomalies'] != null) {
        final List anomalies = result['anomalies'];
        print('🚨 Anomalies: ${anomalies.length}');

        for (final a in anomalies) {
          print('   → type: ${a['type']} | detail: ${a['detail']}');

          NotificationService().addNotification(AppNotification(
            id: '${a['type']}_${DateTime.now().millisecondsSinceEpoch}',
            type: _mapType(a['type']),
            title: _getTitle(a['type']),
            message: a['detail'] ?? '',
            createdAt: DateTime.now(),
            isRead: false,
          ));
        }
      } else {
        print('✅ لا يوجد anomalies');
      }
    } catch (e) {
      print('❌ Anomaly check failed: $e');
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // ----------------------------------------------------------
  // جلب اسم الجهاز
  // ----------------------------------------------------------
  Future<String?> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.name;
      }
      return null;
    } catch (e) {
      print('⚠️ Device info failed: $e');
      return null;
    }
  }

  // ----------------------------------------------------------
  // جلب الموقع
  // ----------------------------------------------------------
  Future<Map<String, dynamic>?> _getLocationData() async {
    try {
      final permission = await Geolocator.checkPermission();
      print('📋 Location Permission: $permission');

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('⛔ الصلاحيات مرفوضة');
        return null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        print('⚠️ GPS timeout — جاري تجربة آخر موقع معروف...');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        print('❌ لا يوجد موقع متاح');
        return null;
      }

      print('📌 GPS: ${position.latitude}, ${position.longitude}');

      String locationName = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          locationName = [
            if (p.locality?.isNotEmpty == true) p.locality,
            if (p.country?.isNotEmpty == true) p.country,
          ].join('، ');
          print('🏙️ City: $locationName');
        }
      } catch (e) {
        print('⚠️ Reverse Geocoding فشل: $e');
        locationName =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'locationName': locationName,
      };
    } catch (e) {
      print('❌ Location fetch failed: $e');
      return null;
    }
  }

  // ----------------------------------------------------------
  // قراءة SSID
  // ----------------------------------------------------------
  Future<String?> _getCurrentSSID() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ssid = prefs.getString(_wifiSsidKey);
      return (ssid != null && ssid.isNotEmpty) ? ssid : null;
    } catch (e) {
      print('⚠️ SSID fetch failed: $e');
      return null;
    }
  }

  // ----------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------
  NotificationType _mapType(String type) {
    switch (type) {
      case 'unknown_device':  return NotificationType.unknownDevice;
      case 'new_location':    return NotificationType.newLocation;
      case 'new_wifi':        return NotificationType.newWifi;
      case 'failed_attempts': return NotificationType.failedAttempts;
      default:                return NotificationType.breachAlert;
    }
  }

  String _getTitle(String type) {
    switch (type) {
      case 'unknown_device':  return 'تسجيل دخول من جهاز جديد';
      case 'new_location':    return 'تسجيل دخول من موقع جديد';
      case 'new_wifi':        return 'اتصال بشبكة جديدة';
      case 'failed_attempts': return 'محاولات دخول فاشلة';
      default:                return 'نشاط مشبوه';
    }
  }
}