import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../services/notification_service.dart';
import '../../../core/models/app_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

class SimpleNotificationsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          iconTheme: const IconThemeData(color: AppColors.primary),
          title: const Text(
            'الإشعارات',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: StreamBuilder<List<AppNotification>>(
          stream: NotificationService().notificationsStream,
          initialData: NotificationService().notifications,
          builder: (context, snapshot) {
            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد إشعارات حالياً',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildNotificationCard(context, n),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ─── فك الـ JSON ────────────────────────────────────────────
  Map<String, dynamic> _parseMessage(AppNotification n) {
    if (n.type != NotificationType.breachAlert) return {};
    try {
      return jsonDecode(n.message) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ─── Card ───────────────────────────────────────────────────
  Widget _buildNotificationCard(BuildContext context, AppNotification n) {
    final color = _getColor(n.type);
    final icon = _getIcon(n.type);
    final data = _parseMessage(n);
    final hasPassword = data['hasPassword'] ?? false;

    String cardText;
    if (n.type == NotificationType.breachAlert) {
      cardText = hasPassword
          ? 'بريدك موجود في هذا التسريب. غيّر كلمة مرورك فوراً.'
          : 'بريدك الإلكتروني موجود في هذا التسريب.';
    } else {
      cardText = n.message;
    }

    return GestureDetector(
      onTap: () {
        NotificationService().markAsRead(n.id);
        _showDetailDialog(context, n);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: n.isRead ? Colors.grey.shade200 : color.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // ✅ الأيقونة يمين
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),

            // النصوص
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    n.title,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 15,
                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cardText,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(n.createdAt),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),

            // نقطة الإشعار
            if (!n.isRead)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Detail Dialog ──────────────────────────────────────────
  void _showDetailDialog(BuildContext context, AppNotification n) {
  final icon = _getIcon(n.type);
  final data = _parseMessage(n);
  final hasPassword = data['hasPassword'] ?? false;
  final dataClasses = List<String>.from(data['dataClasses'] ?? []);
  final breachDate = data['breachDate'] as String? ?? '';
  final domain = data['domain'] as String? ?? '';

  showDialog(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFF2D1B69),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              /// العنوان
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      n.title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),

              /// تحذير كلمة المرور
              if (n.type == NotificationType.breachAlert && hasPassword) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: const [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تم تسريب كلمة المرور — غيّرها فوراً',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

            /// تاريخ التسريب
if (breachDate.isNotEmpty) ...[
  Align(
    alignment: Alignment.centerRight,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        Text(
          'تاريخ التسريب: $breachDate',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.calendar_today,
          size: 13,
          color: Colors.white.withOpacity(0.6),
        ),
      ],
    ),
  ),
  const SizedBox(height: 16),
],

/// عنوان البيانات
if (dataClasses.isNotEmpty) ...[
  const Align(
    alignment: Alignment.centerRight,
    child: Text(
      'البيانات التي تم تسريبها:',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        fontSize: 13,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),

  const SizedBox(height: 10),

  Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      alignment: WrapAlignment.end,
      textDirection: TextDirection.rtl,
      spacing: 8,
      runSpacing: 8,
      children: dataClasses.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        );
      }).toList(),
    ),
  ),

  const SizedBox(height: 20),
],
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),

              /// زر تغيير كلمة المرور
              if (n.type == NotificationType.breachAlert &&
                  hasPassword &&
                  domain.isNotEmpty) ...[
                ElevatedButton.icon(
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text(
                    'الانتقال لتغيير كلمة المرور',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () async {
                    final url = Uri.parse('https://$domain');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2D1B69),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Center(
                  child: Text(
                    domain,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],

              /// زر الإغلاق
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'حسناً، فهمت',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  // ─── Helpers ────────────────────────────────────────────────
  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.wifiWarning:
        return Icons.wifi_off;
      case NotificationType.breachAlert:
        return Icons.security;
      case NotificationType.friendRequest:
        return Icons.person_add;
    }
  }

  Color _getColor(NotificationType type) {
    switch (type) {
      case NotificationType.wifiWarning:
        return Colors.orange;
      case NotificationType.breachAlert:
        return Colors.red;
      case NotificationType.friendRequest:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}