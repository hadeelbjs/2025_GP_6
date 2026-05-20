// lib/services/anomaly_detection_service.dart

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_services.dart';
import '../features/dashboard/services/notification_service.dart';
import '../core/models/app_notifications.dart';
import 'package:waseed/main.dart';

class AnomalyDetectionService {
  static const String _wifiSsidKey = 'last_checked_ssid';
  final ApiService _api = ApiService();

  static final List<DateTime> _chatOpenHistory = [];
  static const int _maxChatsThreshold = 3;
  static const Duration _windowDuration = Duration(minutes: 1);

  Future<void> trackChatOpening() async {
    final now = DateTime.now();
    _chatOpenHistory.removeWhere(
      (time) => now.difference(time) > _windowDuration,
    );
    _chatOpenHistory.add(now);

    if (_chatOpenHistory.length >= _maxChatsThreshold) {
      NotificationService().addNotification(
        AppNotification(
          id: 'unusual_chat_activity_${DateTime.now().millisecondsSinceEpoch}',
          type: NotificationType.unusualChatActivity,
          title: 'فتح متكرر وسريع للمحادثات',
          message: 'تم رصد فتح متكرر للمحادثات في وقت قصير',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      );

      _api
          .checkAnomalies(
            customType: 'unusual_chat_activity',
            locationName: 'سلوك مستخدم غير معتاد',
          )
          .ignore();

      _chatOpenHistory.clear();
    }
  }

  // الدالة الرئيسية — تُستدعى من main_dashboard.dart
  Future<void> runChecks() async {

    try {
      final locationData = await _getLocationData();
      final ssid = await _getCurrentSSID();

      final result = await _api.checkAnomalies(
        lat: locationData?['lat'],
        lng: locationData?['lng'],
        locationName: locationData?['locationName'],
        ssid: ssid,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => {'success': false, 'message': 'timeout'},
      );


      if (result['action'] == 'FORCE_LOGOUT') {
      await _api.logout();
      final context = navigatorKey.currentContext;
      if (context != null) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
      }
      return;
    }

      if (result['success'] == true && result['anomalies'] != null) {
        final List anomalies = result['anomalies'];
        final prefs = await SharedPreferences.getInstance();

        final hasWifiAlert = anomalies.any((a) => a['type'] == 'new_wifi');
        if (!hasWifiAlert) await prefs.remove('last_shown_new_wifi');

        final hasLocationAlert = anomalies.any(
          (a) => a['type'] == 'new_location',
        );
        if (!hasLocationAlert) await prefs.remove('last_shown_new_location');

        for (final a in anomalies) {

          if (a['type'] == 'new_wifi' || a['type'] == 'new_location') {
            final key = 'last_shown_${a['type']}';
            final lastShown = prefs.getString(key) ?? '';
            if (lastShown == a['detail']) {
              continue;
            }
            await prefs.setString(key, a['detail']);
          }

          NotificationService().addNotification(
            AppNotification(
              id: '${a['type']}_${DateTime.now().millisecondsSinceEpoch}',
              type: _mapType(a['type']),
              title: _getTitle(a['type']),
              message: a['detail'] ?? '',
              createdAt: DateTime.now(),
              isRead: false,
            ),
          );
        }
      }
    } catch (e) {
      print('Anomaly check failed: $e');
    }
  }

  // جلب الموقع
  Future<Map<String, dynamic>?> _getLocationData() async {
    try {
      final permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return null;
      }


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
        }
      } catch (e) {
        locationName =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'locationName': locationName,
      };
    } catch (e) {
      return null;
    }
  }

  // SSID
  Future<String?> _getCurrentSSID() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ssid = prefs.getString(_wifiSsidKey);
      return (ssid != null && ssid.isNotEmpty) ? ssid : null;
    } catch (e) {
      return null;
    }
  }

  // Helpers
  NotificationType _mapType(String type) {
    switch (type) {
      case 'new_location':
        return NotificationType.newLocation;
      case 'new_wifi':
        return NotificationType.newWifi;
      case 'failed_attempts':
        return NotificationType.failedAttempts;
      case 'unusual_chat_activity':
        return NotificationType.unusualChatActivity;
      default:
        return NotificationType.breachAlert;
    }
  }

  String _getTitle(String type) {
    switch (type) {
      case 'new_location':
        return 'تسجيل دخول من موقع جديد';
      case 'new_wifi':
        return 'اتصال بشبكة جديدة';
      case 'failed_attempts':
        return 'محاولات تسجيل دخول غير ناجحة';
      case 'unusual_chat_activity':
        return 'نشاط محادثات مشبوه';
      default:
        return 'نشاط مشبوه';
    }
  }
}
