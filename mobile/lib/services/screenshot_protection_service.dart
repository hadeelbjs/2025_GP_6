import 'dart:io';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

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
  }

  /// معالجة الأحداث من iOS
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScreenshotTaken':
        _onScreenshotTaken?.call();
        break;

      case 'onScreenRecordingChanged':
        final isRecording = call.arguments['isRecording'] as bool;
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
      } else if (Platform.isIOS) {
        final result = await _channel.invokeMethod('enableProtection');
      }
      _isEnabled = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// إيقاف الحماية
  static Future<bool> disable() async {
    if (!_isEnabled) return true;

    try {
      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOff();
      } else if (Platform.isIOS) {
        final result = await _channel.invokeMethod('disableProtection');
      }
      _isEnabled = false;
      return true;
    } catch (e) {
      print('Error disabling screenshot protection: $e');
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
