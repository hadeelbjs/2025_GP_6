import 'dart:io';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

/// خدمة حماية لقطات الشاشة
/// Android: FLAG_SECURE
/// iOS: Native Method Channel
class ScreenshotProtectionService {
  static const _channel = MethodChannel('com.waseed/screenshot_protection');

  static Function()? _onScreenshotTaken;
  static Function(bool)? _onScreenRecordingChanged;
  static bool _isInitialized = false;
  static bool _isEnabled = false;

  /// تهيئة الخدمة
  static Future<void> initialize({
    Function()? onScreenshotTaken,
    Function(bool)? onScreenRecordingChanged,
  }) async {
    if (_isInitialized) {
      // تحديث callbacks فقط
      _onScreenshotTaken = onScreenshotTaken;
      _onScreenRecordingChanged = onScreenRecordingChanged;
      return;
    }

    _onScreenshotTaken = onScreenshotTaken;
    _onScreenRecordingChanged = onScreenRecordingChanged;

    // الاستماع لأحداث iOS
    if (Platform.isIOS) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }

    _isInitialized = true;
    print(' ScreenshotProtectionService initialized');
  }

  /// معالجة الأحداث من iOS
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScreenshotTaken':
        print('📸 Screenshot detected from iOS!');
        _onScreenshotTaken?.call();
        break;

      case 'onScreenRecordingChanged':
        final isRecording = call.arguments['isRecording'] as bool;
        print('🎥 Screen recording changed: $isRecording');
        _onScreenRecordingChanged?.call(isRecording);
        break;
    }
  }

  /// تفعيل الحماية
  static Future<bool> enable() async {
    if (_isEnabled) return true;

    try {
      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOn();
        print(' Android: FLAG_SECURE enabled');
      } else if (Platform.isIOS) {
        final result = await _channel.invokeMethod('enableProtection');
        print(' iOS: Screenshot protection enabled: $result');
      }
      _isEnabled = true;
      return true;
    } catch (e) {
      print('❌ Error enabling screenshot protection: $e');
      return false;
    }
  }

  /// إيقاف الحماية
  static Future<bool> disable() async {
    if (!_isEnabled) return true;

    try {
      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOff();
        print('🔓 Android: Screenshot protection disabled');
      } else if (Platform.isIOS) {
        final result = await _channel.invokeMethod('disableProtection');
        print('🔓 iOS: Screenshot protection disabled: $result');
      }
      _isEnabled = false;
      return true;
    } catch (e) {
      print('❌ Error disabling screenshot protection: $e');
      return false;
    }
  }

  /// التحقق من حالة الحماية
  static Future<bool> isEnabled() async {
    try {
      if (Platform.isIOS) {
        return await _channel.invokeMethod('isProtectionEnabled') ?? false;
      }
      return _isEnabled;
    } catch (e) {
      return _isEnabled;
    }
  }

  /// تحديث callbacks
  static void updateCallbacks({
    Function()? onScreenshotTaken,
    Function(bool)? onScreenRecordingChanged,
  }) {
    if (onScreenshotTaken != null) {
      _onScreenshotTaken = onScreenshotTaken;
    }
    if (onScreenRecordingChanged != null) {
      _onScreenRecordingChanged = onScreenRecordingChanged;
    }
  }
}
