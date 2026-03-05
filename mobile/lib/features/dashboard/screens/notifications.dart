import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../services/notification_service.dart';
import '../../../core/models/app_notifications.dart';
import '../../../services/biometric_service.dart';

class SimpleNotificationsPage extends StatelessWidget {
  
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        appBar: AppBar(
          iconTheme: const IconThemeData(
            color: AppColors.primary,
          ),
          title: Text('الإشعارات', style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: AppColors.primary, fontWeight: FontWeight.w600)),
          backgroundColor: Color(0xFFFFF),
        ),
        body: StreamBuilder<List<AppNotification>>(
  stream: NotificationService().notificationsStream,
  initialData: NotificationService().notifications,
  builder: (context, snapshot) {
    final notifications = snapshot.data ?? [];

    if (notifications.isEmpty) {
      return Center(
        child: Text(
          'لا توجد إشعارات حالياً',
          style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: notifications.length,
     itemBuilder: (context, index) {
  final n = notifications[index];
  final isAnomaly = {
    NotificationType.unknownDevice,
    NotificationType.newLocation,
    NotificationType.newWifi,
    NotificationType.failedAttempts,
  }.contains(n.type);

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      children: [
        _buildNotificationCard(
          icon: _getIcon(n.type),
          title: n.title,
          message: n.message,
          time: _formatTime(n.createdAt),
          color: _getColor(n.type),
          isRead: n.isRead,
        ),
        if (isAnomaly && n.actionTaken == null)
          _buildAnomalyButtons(context, n),
      ],
    ),
  );
},
    );
  },
),
      ),
    );
  }
  IconData _getIcon(NotificationType type) {
  switch (type) {
    case NotificationType.wifiWarning:
      return Icons.wifi_off;
    case NotificationType.breachAlert:
      return Icons.warning_amber;
    case NotificationType.friendRequest:
      return Icons.person_add;
      case NotificationType.unknownDevice: 
         return Icons.devices;
      case NotificationType.newLocation: 
   return Icons.location_on;
  case NotificationType.newWifi:    
    return Icons.wifi;
    case NotificationType.failedAttempts: 
    return Icons.lock_outline;
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
      case NotificationType.unknownDevice: 
       return Colors.red;
      case NotificationType.newLocation: 
        return Colors.red;
      case NotificationType.newWifi:  
      return Colors.orange;
    case NotificationType.failedAttempts:
      return Colors.red;
  }
}

String _formatTime(DateTime time) {
  final diff = DateTime.now().difference(time);

  if (diff.inMinutes < 60) {
    return 'منذ ${diff.inMinutes} دقيقة';
  } else if (diff.inHours < 24) {
    return 'منذ ${diff.inHours} ساعة';
  } else {
    return 'منذ ${diff.inDays} يوم';
  }
}

 Widget _buildNotificationCard({
  required IconData icon,
  required String title,
  required String message,
  required String time,
  required Color color,
  required bool isRead,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: isRead ? Colors.white : color.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isRead ? Colors.grey.shade200 : color.withOpacity(0.25),
        width: 1,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                message,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                time,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 11,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}
Widget _buildAnomalyButtons(BuildContext context, AppNotification n) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _handleAction(context, n, false),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gpp_bad_outlined, color: Colors.red, size: 18),
                  SizedBox(width: 6),
                  Text('لم أقم بذلك',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      )),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _handleAction(context, n, true),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, color: Colors.green, size: 18),
                  SizedBox(width: 6),
                  Text('أنا من فعل ذلك',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      )),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _handleAction(BuildContext context, AppNotification n, bool wasMe) async {
  if (!wasMe) {
    final canUse = await BiometricService.canCheckBiometrics();
    final hasEnrolled = await BiometricService.hasEnrolledBiometrics();
    if (canUse && hasEnrolled) {
      final verified = await BiometricService.authenticateWithBiometrics(
        reason: 'تحقق من هويتك لتأكيد البلاغ',
        biometricOnly: true,
      );
      if (!verified) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('فشل التحقق — لم يتم تسجيل البلاغ',
                  style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
  }

  NotificationService().updateAnomalyAction(n.id, wasMe);

  if (!context.mounted) return;

  if (!wasMe) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تحذير أمني عاجل',
              style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold)),
          content: const Text(
            '• غيّر كلمة المرور فوراً\n• راجع الأجهزة المرتبطة\n• فعّل المصادقة الثنائية',
            style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic')),
            ),
          ],
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم تأكيد العملية بنجاح',
            style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}