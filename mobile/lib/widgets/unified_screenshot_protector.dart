import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:screen_capture_event/screen_capture_event.dart';

///  Android: FLAG_SECURE (منع حقيقي)
///  iOS: إخفاء المحتوى عند inactive (تقنية Telegram)
///  Dialog تحذيري عند اكتشاف محاولة الالتقاط
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
        //  Android: FLAG_SECURE (منع حقيقي)
        await ScreenProtector.preventScreenshotOn();
        print(' Android: FLAG_SECURE enabled');
      } else if (Platform.isIOS) {
        //  iOS: نعتمد على didChangeAppLifecycleState فقط
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

/*import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:screen_protector/screen_protector.dart';
import 'package:screen_capture_event/screen_capture_event.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Android: صورة تحذير + شاشة سوداء
/// iOS: شاشة سوداء + إشعار
class UnifiedScreenshotProtector extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final String warningAsset;

  const UnifiedScreenshotProtector({
    super.key,
    required this.child,
    required this.enabled,
    this.warningAsset = 'assets/images/screenshot_blocked.png',
  });

  @override
  State<UnifiedScreenshotProtector> createState() =>
      _UnifiedScreenshotProtectorState();
}

class _UnifiedScreenshotProtectorState extends State<UnifiedScreenshotProtector>
    with WidgetsBindingObserver {
  final _capture = ScreenCaptureEvent();
  bool _showBlackScreen = false;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;

    //  إخفاء المحتوى عند الخروج (iOS + Android)
    setState(() {
      _showBlackScreen = state != AppLifecycleState.resumed;
    });
  }

  ///  تفعيل الحماية حسب المنصة
  Future<void> _applyProtection() async {
    if (!widget.enabled) {
      await _disableProtection();
      return;
    }

    try {
      if (Platform.isAndroid) {
        //  Android: FLAG_SECURE + Black overlay
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageWithColor(Colors.black);
        print(' Android: FLAG_SECURE + Black overlay enabled');
      } else if (Platform.isIOS) {
        //  iOS: Blur overlay فقط
        await ScreenProtector.protectDataLeakageWithBlur();
        print(' iOS: Blur protection enabled');
      }

      //  الاستماع للقطات والتسجيل (كلا المنصتين)
      _capture.addScreenShotListener(_onScreenshot);
      _capture.addScreenRecordListener(_onRecording);
      _capture.watch();

      print(' Screenshot detection enabled');
    } catch (e) {
      debugPrint(' Protection setup failed: $e');
    }
  }

  ///  إيقاف الحماية
  Future<void> _disableProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOff();
      }
      print(' Protection disabled');
    } catch (e) {
      debugPrint(' Failed to disable: $e');
    }
  }

  ///  معالجة لقطة الشاشة
  Future<void> _onScreenshot(String path) async {
    if (!widget.enabled) return;

    debugPrint(' Screenshot detected! Platform: ${Platform.operatingSystem}');

    //  عرض الشاشة السوداء فوراً (كلا المنصتين)
    if (mounted) {
      setState(() => _showBlackScreen = true);
    }

    if (Platform.isAndroid) {
      //  Android: حفظ صورة التحذير + حذف اللقطة الأصلية
      await _handleAndroidScreenshot(path);
    } else if (Platform.isIOS) {
      //  iOS: إشعار فقط (بدون حفظ صورة)
      _handleIOSScreenshot();
    }

    //  إخفاء الشاشة السوداء بعد نصف ثانية
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _showBlackScreen = false);
    }
  }

  ///  معالجة Android
  Future<void> _handleAndroidScreenshot(String path) async {
    debugPrint(' Android screenshot handling...');

    // 1️⃣ حذف اللقطة الأصلية
    await _deleteOriginalScreenshot(path);

    // 2️⃣ حفظ صورة التحذير
    await _saveWarningImage();

    // 3️⃣ إشعار
    _showSnackbar(' تم حفظ صورة تحذيرية بدلاً من المحتوى');
  }

  ///  معالجة iOS
  Future<void> _handleIOSScreenshot() async {
    debugPrint(' iOS screenshot handling...');

    //  حفظ صورة التحذير في iOS أيضاً
    await _saveWarningImage();

    // إشعار
    _showSnackbar(' تم حفظ صورة تحذيرية (اللقطة الأصلية موجودة)');

    // Dialog تحذيري
    _showIOSWarningDialog();
  }

  ///  حذف لقطة الشاشة الأصلية (Android)
  Future<void> _deleteOriginalScreenshot(String path) async {
    if (path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint(' Original screenshot deleted: $path');
      }
    } catch (e) {
      debugPrint(' Could not delete screenshot: $e');
    }
  }

  ///  حفظ صورة التحذير (Android فقط)
  Future<void> _saveWarningImage() async {
    try {
      // تحميل صورة التحذير من الأصول
      final byteData = await rootBundle.load(widget.warningAsset);
      final imageBytes = byteData.buffer.asUint8List();

      // حفظ مؤقت
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${tempDir.path}/warning_$timestamp.png';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(imageBytes);

      // حفظ في المعرض
      await Gal.putImage(tempPath, album: 'Waseed');

      debugPrint(' Warning image saved to gallery (Android)');

      // حذف الملف المؤقت بعد التأخير
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint(' Failed to save warning image: $e');
    }
  }

  ///  معالجة التسجيل
  void _onRecording(bool isRecording) {
    if (!widget.enabled) return;

    debugPrint(' Screen recording: $isRecording');

    if (mounted) {
      setState(() {
        _showBlackScreen = isRecording;
        _isRecording = isRecording;
      });
    }

    if (isRecording) {
      if (Platform.isAndroid) {
        _showSnackbar(' التسجيل ممنوع - سيتم حفظ فيديو أسود');
      } else {
        _showSnackbar(' لا يُسمح بتسجيل هذا المحتوى');
      }
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

  ///  Dialog تحذيري لـ iOS
  void _showIOSWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.red.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '⚠️ تحذير',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تم اكتشاف محاولة أخذ لقطة شاشة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'ملاحظة هامة:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '• تم تسجيل هذا الحدث\n'
                      '• تم إشعار الطرف الآخر\n'
                      '• مشاركة هذا المحتوى قد يعرضك للمساءلة',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'فهمت',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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

        //  الشاشة السوداء
        if (_showBlackScreen && widget.enabled)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showBlackScreen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
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
                            : Icons.security_rounded,
                        color: Colors.white,
                        size: 72,
                      ),

                      const SizedBox(height: 24),

                      // النص الرئيسي
                      Text(
                        _isRecording
                            ? ' تسجيل الشاشة غير مسموح'
                            : ' محتوى محمي',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      // نص توضيحي
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          Platform.isAndroid
                              ? (_isRecording
                                    ? 'سيتم حفظ فيديو أسود'
                                    : 'سيتم حفظ صورة تحذيرية')
                              : 'هذا المحتوى محمي ولا يمكن التقاطه',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // مؤشر التحميل للتسجيل
                      if (_isRecording)
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
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
