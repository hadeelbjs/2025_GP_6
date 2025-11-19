
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';

import '../../../models/message_models.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/colors.dart';
import '../widgets/message_bubble.dart';
import '../widgets/delete_message_sheet.dart';
import 'verify_identity_screen.dart';

class MessageThreadScreen extends StatefulWidget {
  final String peerName;
  final String peerUsername;
  // أضِف peerId/threadId هنا لاحقًا عند ربط الـAPI

  const MessageThreadScreen({
    super.key,
    required this.peerName,
    required this.peerUsername,
  });

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final _ctl = TextEditingController();
  final List<MessageModel> _messages = [];

  Duration? _selectedTTL; // مدة الحذف الذاتي
  Attachment? _pendingAttachment; // مرفق قبل الإرسال
  MessageKind? _pendingKind; // نوع المرفق

  @override
  void initState() {
    super.initState();
    _ctl.addListener(() => setState(() {})); // لتحديث زر الإرسال
    _seedDemo();
  }

  void _seedDemo() {
    _messages.addAll([
      MessageModel(
        id: 'm1',
        text: 'Home@2024 كلمة المرور',
        senderId: 'peer',
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
        isMe: false,
        status: MessageStatus.delivered,
        kind: MessageKind.text,
      ),
      // مثال رسالة مشفّرة لصورة (قبل التحقق)
      MessageModel(
        id: 'm2',
        text: '',
        senderId: 'me',
        createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
        isMe: true,
        status: MessageStatus.encryptedPendingVerify,
        kind: MessageKind.image,
        attachment: const Attachment(
          name: 'صورة',
          url: 'https://picsum.photos/800/600',
          mime: 'image/jpeg',
          width: 800,
          height: 600,
        ),
      ),
    ]);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  // ——— إرسال ———
  bool get _canSend =>
      _ctl.text.trim().isNotEmpty || _pendingAttachment != null;

  void _send() {
    if (!_canSend) return;

    final now = DateTime.now();
    final ttl = _selectedTTL;
    final destructAt = ttl != null ? now.add(ttl) : null;

    final hasAttachment = _pendingAttachment != null && _pendingKind != null;
    final msg = MessageModel(
      id: now.millisecondsSinceEpoch.toString(),
      text: _ctl.text.trim(), // كابتشن اختياري للمرفق
      senderId: 'me',
      createdAt: now,
      isMe: true,
      status: MessageStatus.sending,
      kind: hasAttachment ? _pendingKind! : MessageKind.text,
      attachment: hasAttachment ? _pendingAttachment : null,
      ttl: ttl,
      selfDestructAt: destructAt,
      deliveredAt: now,
    );

    setState(() {
      _messages.add(msg);
      _ctl.clear();
      _pendingAttachment = null;
      _pendingKind = null;
    });

    // TODO: API إرسال (plaintext/ciphertext + attachment + ttlSeconds)
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => msg.status = MessageStatus.delivered);
    });
  }

  // ——— اختيار مرفق (Android + iOS) ———
  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('صورة من المعرض'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('التقاط صورة'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: const Text('اختيار ملف'),
                  onTap: () => Navigator.pop(context, 'file'),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );

    if (choice == null) return;

    try {
      if (choice == 'gallery') {
        final XFile? picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (picked == null) return;

        final localPath = picked.path; // دائمًا غير null
        setState(() {
          _pendingKind = MessageKind.image;
          _pendingAttachment = Attachment(
            name: p.basename(localPath),
            url: localPath, // مسار محلي صالح على Android/iOS
            mime:
                'image/${p.extension(localPath).replaceFirst('.', '').toLowerCase()}',
          );
        });
      } else if (choice == 'camera') {
        final XFile? picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (picked == null) return;

        final localPath = picked.path;
        setState(() {
          _pendingKind = MessageKind.image;
          _pendingAttachment = Attachment(
            name: p.basename(localPath),
            url: localPath,
            mime:
                'image/${p.extension(localPath).replaceFirst('.', '').toLowerCase()}',
          );
        });
      } else {
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.any,
          withData: true, // لو رجّع بدون path نستخدم bytes
        );
        if (res == null || res.files.isEmpty) return;

        final f = res.files.single;
        String? pickedPath = f.path;

        // إذا ما فيه path لكن فيه bytes — نخزّنها مؤقتاً ونستخدم المسار
        if ((pickedPath == null || pickedPath.isEmpty) && f.bytes != null) {
          pickedPath = await _saveBytesToTemp(f.name, f.bytes!);
        }
        if (pickedPath == null || pickedPath.isEmpty) {
          _showMessage('تعذّر الوصول للملف (لا يوجد path)', false);
          return;
        }

        final localPath = pickedPath; // مضمون غير null من هنا
        final ext = (f.extension != null && f.extension!.isNotEmpty)
            ? '.${f.extension!.toLowerCase()}'
            : p.extension(localPath).toLowerCase();

        setState(() {
          _pendingKind = MessageKind.file;
          _pendingAttachment = Attachment(
            name: f.name.isNotEmpty ? f.name : p.basename(localPath),
            url: localPath, // مسار محلي غير nullable
            mime: _guessMimeFromExt(ext), // تخمين نوع الملف
            sizeBytes: f.size,
          );
        });
      }
    } catch (e) {
      _showMessage('تعذّر اختيار المرفق: $e', false);
    }
  }

  // يحفظ bytes في ملف مؤقت ويرجع المسار (Android/iOS)
  Future<String> _saveBytesToTemp(String filename, List<int> bytes) async {
    final safeName = filename.isEmpty ? 'file.bin' : filename;
    final tmpPath = '${Directory.systemTemp.path}/$safeName';
    final file = File(tmpPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _guessMimeFromExt(String ext) {
    final e = ext.trim().toLowerCase();
    final withDot = e.startsWith('.') ? e : '.$e';
    switch (withDot) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.heic':
        return 'image/heic';
      case '.mp4':
        return 'video/mp4';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  void _clearPendingAttachment() {
    setState(() {
      _pendingAttachment = null;
      _pendingKind = null;
    });
  }

  // ——— فتح المحتوى ———
  Future<void> _openEncrypted(MessageModel m) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VerifyIdentityScreen()),
    );
    if (ok == true) {
      setState(() {
        m.status = MessageStatus.read;
        // بعد التحقق فقط نعرض المحتوى الحقيقي (تجريبي)
        if (m.kind == MessageKind.text) {
          m.text = 'المحتوى السري بعد التحقق ✅';
        } else if (m.kind == MessageKind.image) {
          m.text = 'صورة سرّية بعد التحقق';
        } else if (m.kind == MessageKind.file) {
          m.text = '';
        }
      });
    }
  }

  void _openImageViewer(Attachment att) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageViewerScreen(url: att.url, title: att.name),
      ),
    );
  }

  void _openFile(Attachment att) async {
    final isLocal =
        !(att.url.startsWith('http://') || att.url.startsWith('https://'));
    if (isLocal) {
      await OpenFilex.open(att.url);
    } else {
      _showMessage('الملف على رابط؛ نزّليه أول ثم افتحيه.', false);
      // TODO: تنزيل ثم OpenFilex.open(path)
    }
  }

  void _expireMessage(MessageModel m) {
    setState(() {
      m.status = MessageStatus.deleted;
      m.text = '';
    });
    // TODO: أبلغ السيرفر بانتهاء الصلاحية إن لزم
  }

  // ——— حذف ———
  void _onLongPress(MessageModel m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) => DeleteMessageSheet(
        onSelect: (act) async {
          Navigator.pop(context);
          switch (act) {
            case DeleteAction.deleteForMe:
              setState(() {
                m.status = MessageStatus.deleted;
                m.text = '';
              });
              break;
            case DeleteAction.deleteAfterReading:
              _showMessage('سيُحذف بعد المشاهدة (يتطلب ربط API).', false);
              break;
            case DeleteAction.deleteAfterMinutes:
              setState(() {
                m.ttl = const Duration(minutes: 10);
                m.selfDestructAt = DateTime.now().add(m.ttl!);
              });
              break;
            case DeleteAction.deleteNowForBoth:
              final yes = await _confirmDeleteForBoth(context);
              if (yes) {
                setState(() {
                  m.status = MessageStatus.deleted;
                  m.text = '';
                });
              }
              break;
          }
        },
      ),
    );
  }

  Future<bool> _confirmDeleteForBoth(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تأكيد حذف للطرفين', style: AppTextStyles.h4),
          content: Text(
            'سيتم حذف هذه الرسالة من محادثتك ومحادثة المستلم نهائيًا. لا يمكن التراجع عن هذا الإجراء.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد الحذف'),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  // ——— UI ———
  @override
  Widget build(BuildContext context) {
    final canSend = _canSend;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Image.asset(
              'assets/icons/back_arrow_white.png', // السهم الأبيض فقط
              width: 22,
              height: 22,
            ),
          ),
          title: Text(
            widget.peerName, // الاسم فقط بدون صورة الحساب
            style: AppTextStyles.h4.copyWith(color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 14),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  return MessageBubble(
                    msg: m,
                    onTap: m.status == MessageStatus.encryptedPendingVerify
                        ? () => _openEncrypted(m)
                        : null,
                    onLongPress: () => _onLongPress(m),
                    onExpired: () => _expireMessage(m),
                    onOpenImage: (att) => _openImageViewer(att),
                    onOpenFile: (att) => _openFile(att),
                  );
                },
              ),
            ),
            _attachmentPreviewBar(),
            _composer(canSend),
          ],
        ),
      ),
    );
  }

  Widget _attachmentPreviewBar() {
    if (_pendingAttachment == null) return const SizedBox.shrink();
    final att = _pendingAttachment!;
    final isImage = _pendingKind == MessageKind.image;

    final isLocal =
        !(att.url.startsWith('http://') || att.url.startsWith('https://'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.03),
        border: Border(
          top: BorderSide(color: Colors.black.withOpacity(.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isLocal
                  ? Image.file(
                      File(att.url),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      att.url,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
            )
          else
            const Icon(Icons.insert_drive_file, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              att.name,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'إزالة المرفق',
            onPressed: _clearPendingAttachment,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _composer(bool canSend) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // زر المرفقات
            IconButton(
              onPressed: _pickAttachment,
              icon: const Icon(Icons.attach_file),
              color: AppColors.primary,
              tooltip: 'إرفاق',
            ),
            // حقل النص
            Expanded(
              child: TextField(
                controller: _ctl,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة…',
                  hintStyle: AppTextStyles.hint,
                  filled: true,
                  fillColor: AppColors.secondary.withOpacity(.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (canSend) _send();
                },
              ),
            ),
            const SizedBox(width: 6),
            // اختيار TTL
            IconButton(
              onPressed: _pickTTL,
              icon: const Icon(Icons.timer_outlined),
              color: _selectedTTL == null
                  ? AppColors.textHint
                  : AppColors.primary,
              tooltip: 'مؤقّت الحذف',
            ),
            // زر الإرسال (مع تعطيل)
            const SizedBox(width: 4),
            Opacity(
              opacity: canSend ? 1.0 : 0.45,
              child: InkWell(
                onTap: canSend ? _send : null,
                borderRadius: BorderRadius.circular(26),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: canSend
                      ? AppColors.primary
                      : AppColors.textHint,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTTL() async {
    final ttl = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TTLPickerSheet(current: _selectedTTL),
    );
    if (ttl != null) setState(() => _selectedTTL = ttl);
  }

  void _showMessage(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ——— عارض صورة بسيط (محلي/شبكة) ———
class _ImageViewerScreen extends StatelessWidget {
  final String url;
  final String title;
  const _ImageViewerScreen({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    final isLocal = !(url.startsWith('http://') || url.startsWith('https://'));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        backgroundColor: Colors.black,
        body: Center(
          child: InteractiveViewer(
            child: isLocal
                ? Image.file(File(url), fit: BoxFit.contain)
                : Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ——— شيت اختيار TTL ———
class _TTLPickerSheet extends StatelessWidget {
  final Duration? current;
  const _TTLPickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final opts = <String, Duration?>{
      'بدون مؤقّت': null,
      '30 ثانية': const Duration(seconds: 30),
      '1 دقيقة': const Duration(minutes: 1),
      '5 دقائق': const Duration(minutes: 5),
      '10 دقائق': const Duration(minutes: 10),
    };

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              ...opts.entries.map(
                (e) => ListTile(
                  title: Text(e.key, textAlign: TextAlign.center),
                  trailing: current == e.value
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, e.value),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
