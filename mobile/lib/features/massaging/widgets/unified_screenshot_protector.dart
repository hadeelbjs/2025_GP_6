import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_capture_event/screen_capture_event.dart';
import '../../../services/screenshot_protection_service.dart';

/// حماية شاملة للشاشة
/// Android: FLAG_SECURE (منع تام)
/// iOS: Native protection via Method Channel + كشف Screenshot

class UnifiedScreenshotProtector extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback? onScreenshotAttempt;
  final String? peerName;

  const UnifiedScreenshotProtector({
    super.key,
    required this.child,
    required this.enabled,
    this.onScreenshotAttempt,
    this.peerName,
  });

  @override
  State<UnifiedScreenshotProtector> createState() =>
      _UnifiedScreenshotProtectorState();
}

class _UnifiedScreenshotProtectorState extends State<UnifiedScreenshotProtector>
    with WidgetsBindingObserver {
  final ScreenCaptureEvent _capture = ScreenCaptureEvent();
  bool _showPrivacyScreen = false;
  bool _isRecording = false;
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeProtection();
  }

  @override
  void didUpdateWidget(UnifiedScreenshotProtector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _updateProtection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _capture.dispose();
    _disableProtection();
    super.dispose();
  }

  /// تهيئة الحماية
  Future<void> _initializeProtection() async {
    // تهيئة الخدمة مع callbacks
    await ScreenshotProtectionService.initialize(
      onScreenshotTaken: _onScreenshotDetected,
      onScreenRecordingChanged: _onRecordingChanged,
    );

    // إضافة listener للـ Android
    _capture.addScreenShotListener((path) => _onScreenshotDetected());
    _capture.addScreenRecordListener(_onRecordingChanged);
    _capture.watch();

    if (widget.enabled) {
      await ScreenshotProtectionService.enable();
    }
  }

  /// تحديث الحماية
  Future<void> _updateProtection() async {
    if (widget.enabled) {
      await ScreenshotProtectionService.enable();
    } else {
      await ScreenshotProtectionService.disable();
      if (mounted) {
        setState(() {
          _showPrivacyScreen = false;
          _isRecording = false;
        });
      }
    }
  }

  /// إيقاف الحماية
  Future<void> _disableProtection() async {
    await ScreenshotProtectionService.disable();
  }

  /// عند اكتشاف لقطة شاشة
  void _onScreenshotDetected() {
    if (!widget.enabled || !mounted) return;

    debugPrint('📸 Screenshot detected!');

    // إشعار الطرف الآخر
    widget.onScreenshotAttempt?.call();

    // عرض إشعار
    _showScreenshotNotification();
  }

  /// عند تغيير حالة التسجيل
  void _onRecordingChanged(bool isRecording) {
    if (!widget.enabled || !mounted) return;

    debugPrint('🎥 Screen recording: $isRecording');

    setState(() {
      _isRecording = isRecording;
      _showPrivacyScreen = isRecording;
    });

    if (isRecording) {
      _showRecordingWarning();
    }
  }

  /// حماية عند الخروج من التطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _wasInBackground = true;
        if (mounted) {
          setState(() => _showPrivacyScreen = true);
        }
        debugPrint('🛡️ App backgrounded - Privacy screen shown');
        break;

      case AppLifecycleState.resumed:
        if (_wasInBackground) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_isRecording) {
              setState(() => _showPrivacyScreen = false);
            }
          });
          _wasInBackground = false;
        }
        debugPrint('🛡️ App resumed');
        break;

      default:
        break;
    }
  }

  /// إشعار التقاط الشاشة
  void _showScreenshotNotification() {
    if (!mounted) return;

    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, -20 * (1 - value)),
                child: child,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم التقاط الشاشة - سيتم إشعار ${widget.peerName ?? "الطرف الآخر"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  /// تحذير التسجيل
  void _showRecordingWarning() {
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: const Row(
          children: [
            Icon(Icons.videocam_off, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'تسجيل الشاشة غير مسموح',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // المحتوى
        widget.child,

        // شاشة الحماية
        if (_showPrivacyScreen && widget.enabled)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isRecording
                              ? Icons.videocam_off_rounded
                              : Icons.lock_outline_rounded,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isRecording ? 'تسجيل الشاشة ممنوع' : 'محتوى محمي',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isRecording
                            ? 'أوقف التسجيل لعرض المحادثة'
                            : 'عد للتطبيق لعرض المحادثة',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 15,
                        ),
                      ),
                      if (_isRecording) ...[
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
