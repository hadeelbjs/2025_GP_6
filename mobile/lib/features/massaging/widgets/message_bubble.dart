import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/message_models.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/colors.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel msg;
  final VoidCallback? onTap; // لفتح التحقق
  final VoidCallback? onLongPress; // شيت الحذف
  final VoidCallback? onExpired; // انتهاء المؤقّت
  final void Function(Attachment att)? onOpenImage;
  final void Function(Attachment att)? onOpenFile;

  const MessageBubble({
    super.key,
    required this.msg,
    this.onTap,
    this.onLongPress,
    this.onExpired,
    this.onOpenImage,
    this.onOpenFile,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _maybeStartTimer();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.msg.selfDestructAt != widget.msg.selfDestructAt ||
        oldWidget.msg.status != widget.msg.status) {
      _t?.cancel();
      _maybeStartTimer();
    }
  }

  void _maybeStartTimer() {
    final m = widget.msg;
    if (m.selfDestructAt == null || m.status == MessageStatus.deleted) return;
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = m.selfDestructAt!.difference(DateTime.now());
      if (remaining.isNegative) {
        _t?.cancel();
        widget.onExpired?.call();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isRight = msg.isMe;
    final bubbleColor = _bubbleColorByStatus(msg.status, isRight);
    final textColor = msg.status == MessageStatus.deleted
        ? AppColors.textHint
        : Colors.white;

    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isRight ? 16 : 2),
              bottomRight: Radius.circular(isRight ? 2 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: isRight
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildContent(textColor, msg),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: isRight
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (msg.selfDestructAt != null &&
                      msg.status != MessageStatus.deleted)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8.0),
                      child: _CountdownPill(until: msg.selfDestructAt!),
                    ),
                  if (msg.isMe) _ReadBadge(msg),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ——— المحتوى ———
  Widget _buildContent(Color textColor, MessageModel msg) {
    // قبل التحقق: لا نعرض أي نص/صورة/اسم ملف
    if (msg.status == MessageStatus.encryptedPendingVerify) {
      return _encryptedPlaceholder(msg);
    }

    if (msg.status == MessageStatus.deleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(
            'تم حذف هذه الرسالة',
            style: AppTextStyles.bodySmall.copyWith(color: textColor),
          ),
        ],
      );
    }

    switch (msg.kind) {
      case MessageKind.text:
        return Text(
          msg.text,
          style: AppTextStyles.bodyMedium.copyWith(color: textColor),
          textAlign: TextAlign.right,
        );
      case MessageKind.image:
        return _imageBubble(msg);
      case MessageKind.file:
        return _fileBubble(msg);
    }
  }

  // Placeholder موحّد بدون كشف قبل التحقق
  Widget _encryptedPlaceholder(MessageModel msg) {
    final bool isImage = msg.kind == MessageKind.image;

    final child = Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: isImage ? EdgeInsets.zero : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: isImage
          ? AspectRatio(
              aspectRatio: 4 / 3, // لا نستخدم الأبعاد الحقيقية
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(.25),
                      Colors.black.withOpacity(.35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: _lockRow('صورة مشفّرة • اضغط للتحقق')),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    msg.kind == MessageKind.file
                        ? 'ملف مشفّـر • اضغط للتحقق'
                        : 'رسالة مشفّرة • اضغط للتحقق',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    return Semantics(
      label: 'Encrypted content',
      value: 'Locked',
      excludeSemantics: true,
      child: child,
    );
  }

  Widget _lockRow(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
        ),
      ],
    );
  }

  // صورة + كابتشن (بعد التحقق)
  Widget _imageBubble(MessageModel msg) {
    final att = msg.attachment!;
    final list = <Widget>[
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 220,
          child: AspectRatio(
            aspectRatio:
                (att.width != null && att.height != null && att.height! > 0)
                ? att.width! / att.height!
                : 4 / 3,
            child: Image.network(
              att.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    ];

    if (msg.text.trim().isNotEmpty) {
      list.add(const SizedBox(height: 6));
      list.add(
        Text(
          msg.text,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
          textAlign: TextAlign.right,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: list,
    );
  }

  // ملف (بعد التحقق)
  Widget _fileBubble(MessageModel msg) {
    final att = msg.attachment!;
    final icon = _fileIcon(att.mime ?? att.name);
    final size = _formatSize(att.sizeBytes);

    return InkWell(
      onTap: widget.onOpenFile != null ? () => widget.onOpenFile!(att) : null,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    att.name,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (size != null)
                    Text(
                      size,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download_rounded, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String hint) {
    final h = hint.toLowerCase();
    if (h.contains('pdf')) return Icons.picture_as_pdf;
    if (h.contains('ppt')) return Icons.slideshow;
    if (h.contains('xls') || h.contains('csv')) return Icons.table_chart;
    if (h.contains('doc')) return Icons.description;
    if (h.contains('zip') || h.contains('rar')) return Icons.archive;
    return Icons.insert_drive_file;
  }

  String? _formatSize(int? bytes) {
    if (bytes == null) return null;
    const kb = 1024, mb = 1024 * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  Color _bubbleColorByStatus(MessageStatus status, bool isRight) {
    if (status == MessageStatus.deleted)
      return AppColors.textHint.withOpacity(.15);
    return isRight ? AppColors.primary : AppColors.secondary.withOpacity(.25);
  }
}

// ——— شارة المقروء + العدّاد ———
class _CountdownPill extends StatelessWidget {
  final DateTime until;
  const _CountdownPill({required this.until});

  @override
  Widget build(BuildContext context) {
    final d = until.difference(DateTime.now());
    final secs = d.isNegative ? 0 : d.inSeconds;
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$mm:$ss',
        style: AppTextStyles.caption.copyWith(color: Colors.white),
      ),
    );
  }
}

class _ReadBadge extends StatelessWidget {
  final MessageModel msg;
  const _ReadBadge(this.msg);

  @override
  Widget build(BuildContext context) {
    final isRead = msg.readAt != null || msg.status == MessageStatus.read;
    final icon = isRead ? Icons.done_all : Icons.done;
    final color = isRead ? Colors.lightBlueAccent : Colors.white70;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          _formatTime(msg.createdAt),
          style: AppTextStyles.caption.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
