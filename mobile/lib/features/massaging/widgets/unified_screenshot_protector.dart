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

    // إضافة listener للـ Android أيضاً
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

/*import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:screen_capture_event/screen_capture_event.dart';

/// حماية شاملة للشاشة
/// Android: FLAG_SECURE (منع تام)
/// iOS: إخفاء المحتوى + كشف Screenshot + إشعار الطرف الآخر

class UnifiedScreenshotProtector extends StatefulWidget {
  final Widget child;
  final bool enabled; // هل الحماية مفعلة (الطرف الآخر منع)
  final VoidCallback? onScreenshotAttempt; // callback عند محاولة الالتقاط
  final String? peerName; // اسم الطرف الآخر للإشعارات

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
  bool _coverContent = false;
  bool _isRecording = false;
  bool _wasInBackground = false;

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

  ///  حماية عند تغيير حالة التطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;

    switch (state) {
      case AppLifecycleState.inactive:
        //  المستخدم سحب من الأعلى أو ضغط home أو فتح app switcher
        setState(() => _coverContent = true);
        _wasInBackground = true;
        debugPrint('🛡️ App inactive - Content hidden');
        break;

      case AppLifecycleState.paused:
        //  التطبيق في الخلفية
        setState(() => _coverContent = true);
        _wasInBackground = true;
        debugPrint('🛡️ App paused - Content hidden');
        break;

      case AppLifecycleState.resumed:
        //  العودة للتطبيق
        if (_wasInBackground) {
          // تأخير بسيط قبل إظهار المحتوى (لمنع الالتقاط السريع)
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() => _coverContent = false);
            }
          });
          _wasInBackground = false;
        } else {
          setState(() => _coverContent = false);
        }
        debugPrint('🛡️ App resumed - Content visible');
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        setState(() => _coverContent = true);
        break;
    }
  }

  ///  تفعيل الحماية
  Future<void> _applyProtection() async {
    if (!widget.enabled) {
      await _disableProtection();
      return;
    }

    try {
      if (Platform.isAndroid) {
        //  Android: FLAG_SECURE - منع تام للالتقاط
        await ScreenProtector.preventScreenshotOn();
        debugPrint('🛡️ Android: FLAG_SECURE enabled');
      } else if (Platform.isIOS) {
        //  iOS: نستخدم lifecycle + كشف
        debugPrint('🛡️ iOS: Lifecycle protection enabled');
      }

      //  الاستماع للقطات والتسجيل (iOS بشكل رئيسي)
      _capture.addScreenShotListener(_onScreenshotDetected);
      _capture.addScreenRecordListener(_onRecordingDetected);
      _capture.watch();
    } catch (e) {
      debugPrint('❌ Protection setup failed: $e');
    }
  }

  ///  إيقاف الحماية
  Future<void> _disableProtection() async {
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOff();
      }
      setState(() {
        _coverContent = false;
        _isRecording = false;
      });
      debugPrint('🔓 Protection disabled');
    } catch (e) {
      debugPrint('❌ Failed to disable protection: $e');
    }
  }

  ///  عند اكتشاف لقطة شاشة (iOS)
  void _onScreenshotDetected(String path) {
    if (!widget.enabled || !mounted) return;

    debugPrint('📸 Screenshot detected!');

    // 1. إشعار الطرف الآخر عبر callback
    widget.onScreenshotAttempt?.call();

    // 2. عرض تنبيه على الشاشة
    _showScreenshotNotification();
  }

  ///  عند اكتشاف تسجيل شاشة
  void _onRecordingDetected(bool isRecording) {
    if (!widget.enabled || !mounted) return;

    debugPrint('🎥 Screen recording: $isRecording');

    setState(() {
      _isRecording = isRecording;
      if (isRecording) {
        _coverContent = true;
      }
    });

    if (isRecording) {
      _showRecordingWarning();
    }
  }

  ///  إشعار خفيف عند الالتقاط (على الخلفية)
  void _showScreenshotNotification() {
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
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

    // إزالة بعد 3 ثواني
    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });
  }

  ///  تحذير تسجيل الشاشة
  void _showRecordingWarning() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: const Row(
          children: [
            Icon(Icons.videocam_off, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'تسجيل الشاشة غير مسموح في هذه المحادثة',
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
        // المحتوى الأصلي
        widget.child,

        //  شاشة الحماية
        if (_coverContent && widget.enabled)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // أيقونة
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

                      // النص الرئيسي
                      Text(
                        _isRecording ? 'تسجيل الشاشة ممنوع' : 'محتوى محمي',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      // الوصف
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _isRecording
                              ? 'أوقف التسجيل لعرض المحادثة'
                              : 'عد للتطبيق لعرض المحادثة',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // مؤشر دوران عند التسجيل
                      if (_isRecording) ...[
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
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
}*/

/*import 'dart:io';
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
}*/
