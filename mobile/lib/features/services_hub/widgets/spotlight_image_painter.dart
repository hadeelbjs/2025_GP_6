import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';

class SensitiveItem {
  final Rect rect;
  final String label;
  final Color color;

  SensitiveItem({required this.rect, required this.label, required this.color});
}

class SpotlightImagePainter extends CustomPainter {
  final ui.Image image;
  final List<SensitiveItem> items;

  SpotlightImagePainter({required this.image, required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    // حساب نسبة الـ BoxFit.contain
    final scale = min(size.width / imgW, size.height / imgH);
    final scaledW = imgW * scale;
    final scaledH = imgH * scale;
    final dx = (size.width - scaledW) / 2;
    final dy = (size.height - scaledH) / 2;
    final imageRect = Rect.fromLTWH(dx, dy, scaledW, scaledH);

    // 1. رسم الصورة الأصلية
    paintImage(canvas: canvas, rect: imageRect, image: image, fit: BoxFit.fill);

    if (items.isEmpty) return;

    // تحويل إحداثيات الصورة → إحداثيات الـ canvas
    final canvasRects = items.map((item) {
      return RRect.fromRectAndRadius(
        Rect.fromLTWH(
          dx + item.rect.left * scale,
          dy + item.rect.top * scale,
          item.rect.width * scale,
          item.rect.height * scale,
        ),
        const Radius.circular(8),
      );
    }).toList();

    // 2. رسم الـ Overlay الداكن مع ثقوب على المناطق الحساسة
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // الطبقة الداكنة
    canvas.drawRect(imageRect, Paint()..color = Colors.black.withOpacity(0.68));

    // ثقب كل منطقة حساسة (تظهر الصورة الأصلية)
    for (final rRect in canvasRects) {
      canvas.drawRRect(rRect, Paint()..blendMode = BlendMode.clear);
    }

    canvas.restore();

    // 3. رسم الـ Glow والحدود حول كل منطقة
    for (int i = 0; i < canvasRects.length; i++) {
      final rRect = canvasRects[i];
      final color = items[i].color;

      // Glow خارجي
      canvas.drawRRect(
        rRect.inflate(2),
        Paint()
          ..color = color.withOpacity(0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
      );

      // حدود واضحة
      canvas.drawRRect(
        rRect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // 4. رسم التاغ (الاسم) فوق كل منطقة
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final rRect = canvasRects[i];
      final rect = rRect.outerRect;

      final tp = TextPainter(
        text: TextSpan(
          text: item.label,
          style: TextStyle(
            color: item.color == const Color(0xFFFFFFFF)
                ? const Color(0xFF2D1B69)
                : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        textDirection: TextDirection.rtl,
      );
      tp.layout(maxWidth: 200);

      final tagW = tp.width + 18;
      const tagH = 24.0;

      // الموضع: فوق الـ box، في المنتصف
      double tagX = rect.left + (rect.width - tagW) / 2;
      double tagY = rect.top - tagH - 5;

      // تأكد ما يطلع خارج الصورة
      tagX = tagX.clamp(dx, dx + scaledW - tagW);
      tagY = tagY.clamp(dy, rect.top - tagH);

      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagX, tagY, tagW, tagH),
        const Radius.circular(12),
      );

      // خلفية التاغ
      canvas.drawRRect(tagRect, Paint()..color = item.color);

      // نص التاغ
      tp.paint(canvas, Offset(tagX + 9, tagY + (tagH - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(SpotlightImagePainter old) =>
      old.image != image || old.items.length != items.length;
}

// دالة مساعدة لاستخراج Rect من بيانات API
Rect? extractRect(Map<String, dynamic> data) {
  // الصيغة الفعلية من السيرفر: bbox: {x1, y1, x2, y2}
  if (data['bbox'] is Map) {
    final b = data['bbox'] as Map;
    final x1 = (b['x1'] as num).toDouble();
    final y1 = (b['y1'] as num).toDouble();
    final x2 = (b['x2'] as num).toDouble();
    final y2 = (b['y2'] as num).toDouble();
    if (x2 > x1 && y2 > y1) return Rect.fromLTRB(x1, y1, x2, y2);
  }

  // صيغة bbox: [x1, y1, x2, y2] كـ List
  if (data['bbox'] is List) {
    final b = data['bbox'] as List;
    if (b.length >= 4) {
      final x1 = (b[0] as num).toDouble();
      final y1 = (b[1] as num).toDouble();
      final x2 = (b[2] as num).toDouble();
      final y2 = (b[3] as num).toDouble();
      if (x2 > x1 && y2 > y1) return Rect.fromLTRB(x1, y1, x2, y2);
    }
  }

  return null;
}
