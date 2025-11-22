import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:screen_capture_event/screen_capture_event.dart';

/// Android: FLAG_SECURE
/// iOS: إخفاء المحتوى عند inactive (Telegram)
/// Dialog تحذيري عند اكتشاف محاولة الالتقاط

class UnifiedScreenshotProtector extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const UnifiedScreenshotProtector({
    super.key,
    required this.child,
    required this.enabled,
  });

  @override
  State<UnifiedScreenshotProtector> createState() =>
      _UnifiedScreenshotProtectorState();
}

class _UnifiedScreenshotProtectorState extends State<UnifiedScreenshotProtector>
    with WidgetsBindingObserver {
  final _capture = ScreenCaptureEvent();
  bool _coverContent = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyProtection();
  }

  @override
  void didUpdateWidget(UnifiedScreenshotProtector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _applyProtection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _capture.dispose();
    _disableProtection();
    super.dispose();
  }

  ///  تقنية Telegram: إخفاء المحتوى عند inactive
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;

    if (Platform.isIOS) {
      //  iOS: إخفاء عند inactive أو paused
      setState(() {
        _coverContent =
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused;
      });

      if (_coverContent) {
        print(' iOS: Content hidden (Screenshot attempt)');
      } else {
        print(' iOS: Content visible again');
      }
    } else if (Platform.isAndroid) {
      //  Android: إخفاء عند الخروج من التطبيق فقط
      setState(() {
        _coverContent = state != AppLifecycleState.resumed;
      });
    }
  }

  ///  تفعيل الحماية حسب المنصة
  Future<void> _applyProtection() async {
    if (!widget.enabled) {
      await _disableProtection();
      return;
    }

    try {
      if (Platform.isAndroid) {
        //  Android: FLAG_SECURE
        await ScreenProtector.preventScreenshotOn();
        print(' Android: FLAG_SECURE enabled');
      } else if (Platform.isIOS) {
        //  iOS: نعتمد على didChangeAppLifecycleState
        print(' iOS: Lifecycle protection enabled (Telegram technique)');
      }

      //  الاستماع للقطات والتسجيل
      _capture.addScreenShotListener(_onScreenshot);
      _capture.addScreenRecordListener(_onRecording);
      _capture.watch();
    } catch (e) {
      debugPrint(' Protection setup failed: $e');
    }
  }

  ///  إيقاف الحماية
  Future<void> _disableProtection() async {
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOff();
      }
      print(' Protection disabled');
    } catch (e) {
      debugPrint(' Failed to disable: $e');
    }
  }

  ///  معالجة لقطة الشاشة (إشعار + Dialog)
  Future<void> _onScreenshot(String path) async {
    if (!widget.enabled) return;

    debugPrint(' Screenshot detected! Platform: ${Platform.operatingSystem}');

    //  إشعار
    _showSnackbar(' تم منع لقطة الشاشة');

    //  Dialog تحذيري
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _showWarningDialog();
    }
  }

  ///  معالجة التسجيل
  void _onRecording(bool isRecording) {
    if (!widget.enabled) return;

    debugPrint(' Screen recording: $isRecording');

    if (mounted) {
      setState(() {
        _isRecording = isRecording;
        if (Platform.isIOS) {
          _coverContent = isRecording;
        }
      });
    }

    if (isRecording) {
      _showSnackbar(' لا يُسمح بتسجيل هذا المحتوى');
    }
  }

  ///  عرض Snackbar
  void _showSnackbar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// ⚠️ Dialog تحذيري
  void _showWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            ' تنبيه',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'هذا المحتوى محمي ولا يُسمح بالتقاط الشاشة.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'حسنًا',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        //  المحتوى الأصلي
        widget.child,

        //  الغطاء الأسود (تقنية Telegram)
        if (_coverContent && widget.enabled)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // الأيقونة
                    Icon(
                      _isRecording
                          ? Icons.videocam_off_rounded
                          : Icons.lock_outline,
                      color: Colors.white,
                      size: 64,
                    ),

                    const SizedBox(height: 20),

                    // النص
                    Text(
                      _isRecording ? ' تسجيل الشاشة غير مسموح' : ' محتوى محمي',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // وصف
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        Platform.isIOS
                            ? 'هذا المحتوى محمي ولا يمكن التقاطه'
                            : 'الالتقاط ممنوع في هذه المحادثة',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // مؤشر للتسجيل
                    if (_isRecording) ...[
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
