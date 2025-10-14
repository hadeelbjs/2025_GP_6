import 'package:flutter/material.dart';

enum MessageKind { text, image, file }

class Attachment {
  final String name; // اسم الملف/وصف الصورة (لن يُعرض قبل التحقق)
  final String url; // لن يُستخدم قبل التحقق
  final String? mime; // image/png, application/pdf...
  final int? sizeBytes;
  final int? width; // لأبعاد الصورة بعد التحقق
  final int? height;

  const Attachment({
    required this.name,
    required this.url,
    this.mime,
    this.sizeBytes,
    this.width,
    this.height,
  });
}

enum MessageStatus {
  sending,
  encryptedPendingVerify, // قبل التحقق: لا نعرض أي محتوى
  delivered,
  read,
  deleted,
}

class MessageModel {
  final String id;
  String text; // نص الرسالة/كابتشن الصورة
  final String senderId;
  final DateTime createdAt;
  final bool isMe;

  final MessageKind kind;
  final Attachment? attachment;

  // إيصال/قراءة
  DateTime? deliveredAt;
  DateTime? readAt;

  // مؤقّت الحذف الذاتي
  Duration? ttl;
  DateTime? selfDestructAt;

  MessageStatus status;

  MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.createdAt,
    required this.isMe,
    required this.status,
    required this.kind,
    this.attachment,
    this.deliveredAt,
    this.readAt,
    this.ttl,
    this.selfDestructAt,
  });
}
