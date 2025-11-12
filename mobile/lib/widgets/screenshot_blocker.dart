// lib/widgets/screenshot_blocker.dart
import 'dart:io'; //show Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:screen_protector/screen_protector.dart';
import 'package:screen_capture_event/screen_capture_event.dart';
//import 'package:image_gallery_saver/image_gallery_saver.dart';
//import 'package:gallery_saver/gallery_saver.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class ScreenshotBlocker extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final String warningAsset;

  const ScreenshotBlocker({
    super.key,
    required this.child,
    required this.enabled,
    this.warningAsset = 'assets/images/screenshot_blocked.png',
  });

  @override
  State<ScreenshotBlocker> createState() => _ScreenshotBlockerState();
}

class _ScreenshotBlockerState extends State<ScreenshotBlocker> {
  final _capture = ScreenCaptureEvent();
  bool _overlayOn = false;

  @override
  void initState() {
    super.initState();
    _applyAndroidFlagSecure();
    _attachListeners();
  }

  @override
  void didUpdateWidget(covariant ScreenshotBlocker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _applyAndroidFlagSecure();
    }
  }

  @override
  void dispose() {
    _detachListeners();
    _disableAndroidFlagSecure();
    super.dispose();
  }

  Future<void> _applyAndroidFlagSecure() async {
    if (Platform.isAndroid) {
      try {
        if (widget.enabled) {
          await ScreenProtector.preventScreenshotOn();
          await ScreenProtector.protectDataLeakageWithColor(Colors.black);
        } else {
          await ScreenProtector.preventScreenshotOff();
          await ScreenProtector.protectDataLeakageOff();
        }
      } catch (e) {
        debugPrint('flag secure error: $e');
      }
    }
  }

  Future<void> _disableAndroidFlagSecure() async {
    if (Platform.isAndroid) {
      try {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageOff();
      } catch (_) {}
    }
  }

  void _attachListeners() {
    _capture.addScreenShotListener(_onShot);
    _capture.addScreenRecordListener(_onRecord);
    _capture.watch();
  }

  void _detachListeners() {
    _capture.dispose();
  }

  Future<void> _onShot(String path) async {
    if (!widget.enabled) return;

    setState(() => _overlayOn = true);
    _snack('🚫 لا يُسمح بأخذ لقطات شاشة لهذا المحتوى');

    await _saveWarningImage();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _overlayOn = false);
  }

  void _onRecord(bool isRecording) {
    if (!widget.enabled) return;
    setState(() => _overlayOn = isRecording);
    if (isRecording) {
      _snack('🚫 لا يُسمح بتسجيل الشاشة لهذا المحتوى');
    }
  }

  Future<void> _saveWarningImage() async {
    try {
      // 1) حمل الصورة من الأصول كـ bytes
      final bytes = await rootBundle.load(widget.warningAsset);
      final data = bytes.buffer.asUint8List();

      // 2) حاول الحفظ مباشرة
      await Gal.putImageBytes(data, album: 'Waseed');
    } catch (e) {
      // 3) خطة بديلة: احفظ كملف مؤقت ثم أضفه للمعرض
      try {
        final tmp = await getTemporaryDirectory();
        final path =
            '${tmp.path}/blocked_${DateTime.now().millisecondsSinceEpoch}.png';
        final f = File(path);
        final bytes = await rootBundle.load(widget.warningAsset);
        await f.writeAsBytes(bytes.buffer.asUint8List());
        await Gal.putImage(path, album: 'Waseed');
        // (اختياري) احذف الملف المؤقت
        // await f.delete();
      } catch (e2) {
        debugPrint('Save warning image failed: $e2');
      }
    }
  }

  /*Future<void> _saveWarningImage() async {
    try {
      // 1) حمّلنا الأصل من الأصول
      final bytes = await rootBundle.load(widget.warningAsset);
      final data = bytes.buffer.asUint8List();

      // 2) خزّناه ملف مؤقت
      final tmpDir = await getTemporaryDirectory();
      final filePath =
          '${tmpDir.path}/blocked_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(data);

      // 3) خزّنه في الألبوم
      await GallerySaver.saveImage(file.path, albumName: 'Waseed');

      // (اختياري) احذف المؤقت
      // await file.delete();
    } catch (e) {
      debugPrint('Save warning image failed: $e');
    }
  }

  Future<void> _saveWarningImage() async {
    try {
      final bytes = await rootBundle.load(widget.warningAsset);
      final Uint8List data = bytes.buffer.asUint8List();
      await ImageGallerySaver.saveImage(
        data,
        name: 'blocked_screenshot_${DateTime.now().millisecondsSinceEpoch}',
        quality: 100,
        isReturnImagePathOfIOS: true,
      );
    } catch (e) {
      debugPrint('Save warning image failed: $e');
    }
  }*/

  void _snack(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(msg),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          ignoring: true,
          child: AnimatedOpacity(
            opacity: _overlayOn && widget.enabled ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    widget.warningAsset,
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'لا يُسمح بأخذ لقطة شاشة لهذا المحتوى',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
