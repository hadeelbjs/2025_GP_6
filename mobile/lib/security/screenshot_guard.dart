
// lib/security/screenshot_guard.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

class ScreenshotGuard {
  static final ScreenshotGuard _i = ScreenshotGuard._();
  ScreenshotGuard._();
  factory ScreenshotGuard() => _i;

  bool _enabled = false;
  bool get enabled => _enabled;

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    await _applyPlatform();
  }

  Future<void> _applyPlatform() async {
    try {
      if (Platform.isAndroid) {
        if (_enabled) {
          await ScreenProtector.preventScreenshotOn();
          await ScreenProtector.protectDataLeakageWithColor(Colors.black);
        } else {
          await ScreenProtector.preventScreenshotOff();
          await ScreenProtector.protectDataLeakageOff();
        }
      } else {
        // iOS: handled via UI overlay
      }
    } catch (e) {
      debugPrint('ScreenshotGuard error: $e');
    }
  }
}
