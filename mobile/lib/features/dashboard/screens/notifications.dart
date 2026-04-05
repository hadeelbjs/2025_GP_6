import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../services/notification_service.dart';
import '../../../core/models/app_notifications.dart';
import '../../../services/biometric_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_services.dart';


class SimpleNotificationsPage extends StatelessWidget {
  const SimpleNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
                  'لا توجد إشعارات حاليًا',
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

                // "أنا من فعل ذلك" — يختفي نهائياً
                if (n.actionTaken == true) return const SizedBox.shrink();

                final isAnomaly = {
                  //NotificationType.unknownDevice,
                  NotificationType.newLocation,
                  NotificationType.newWifi,
                  NotificationType.failedAttempts,
                }.contains(n.type);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      _buildNotificationCard(context, n, isAnomaly),
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

  // ─── فك الـ JSON ────────────────────────────────────────────
  Map<String, dynamic> _parseMessage(AppNotification n) {
    if (n.type != NotificationType.breachAlert) return {};
    try {
      return jsonDecode(n.message) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ─── Card ────────────────────────────────────────────────────
  Widget _buildNotificationCard(BuildContext context, AppNotification n, bool isAnomaly) {
    final color = _getColor(n.type);
    final icon = _getIcon(n.type);
    final data = _parseMessage(n);
    final hasPassword = data['hasPassword'] ?? false;

    final String cardText;
    if (n.type == NotificationType.breachAlert) {
      cardText = hasPassword
          ? 'بريدك موجود في هذا التسريب. غيّر كلمة مرورك فوراً.'
          : 'بريدك الإلكتروني موجود في هذا التسريب.';
    } else {
      cardText = n.message;
    }

    final cardColor = isAnomaly ? Colors.white : (n.isRead ? Colors.white : color.withOpacity(0.04));
    final borderColor = isAnomaly
        ? const Color(0xFF2D1B69).withOpacity(0.25)
        : (n.isRead ? Colors.grey.shade200 : color.withOpacity(0.25));

    return GestureDetector(
      onTap: () {
        NotificationService().markAsRead(n.id);
        _showDetailDialog(context, n);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAnomaly
                        ? const Color(0xFF2D1B69).withOpacity(0.08)
                        : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isAnomaly ? const Color(0xFF2D1B69) : color,
                    size: 22,
                  ),
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
                              n.title,
                              style: TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                fontSize: 14,
                                fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!n.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isAnomaly ? const Color(0xFF2D1B69) : color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cardText,
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(n.createdAt),
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

            // ── تم الإبلاغ — يظهر بعد "لم أقم بذلك" ──
            if (n.actionTaken == false) ...[
              const SizedBox(height: 10),
              Divider(
                color: const Color(0xFF2D1B69).withOpacity(0.1),
                thickness: 1,
                height: 1,
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: Color(0xFF2D1B69), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'تم الإبلاغ',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                      color: Color(0xFF2D1B69),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Anomaly Buttons ─────────────────────────────────────────
  Widget _buildAnomalyButtons(BuildContext context, AppNotification n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // لم أقم بذلك — بنفسجي
          Expanded(
            child: GestureDetector(
              onTap: () => _handleAction(context, n, false),
              child: Container(
                margin: const EdgeInsets.only(top: 8, left: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B69),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2D1B69)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gpp_bad_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'لم أقم بذلك',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // أنا من فعل ذلك — أبيض
          Expanded(
            child: GestureDetector(
              onTap: () => _handleAction(context, n, true),
              child: Container(
                margin: const EdgeInsets.only(top: 8, right: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2D1B69)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined, color: Color(0xFF2D1B69), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'أنا من فعل ذلك',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D1B69),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Handle Action ───────────────────────────────────────────
  Future<void> _handleAction(BuildContext context, AppNotification n, bool wasMe) async {
    if (wasMe) {
      NotificationService().updateAnomalyAction(n.id, true);
      return;
    }

    final canUse = await BiometricService.canCheckBiometrics();
    final hasEnrolled = await BiometricService.hasEnrolledBiometrics();

    if (!canUse || !hasEnrolled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يجب تفعيل البصمة أولاً من إعدادات الحساب',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final verified = await BiometricService.authenticateWithBiometrics(
      reason: 'تحقق من هويتك لتأكيد البلاغ',
      biometricOnly: true,
    );

    if (!verified) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'فشل التحقق — لم يتم تسجيل البلاغ',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    NotificationService().updateAnomalyAction(n.id, false);

    if (!context.mounted) return;
    if (n.type == NotificationType.failedAttempts) {
  _showSecurityAlert(context, n.type);
} else {
  _showForcePasswordChangeDialog(context);
}
  }

  // ─── Detail Dialog ───────────────────────────────────────────
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [

                // العنوان
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

                // تحذير كلمة المرور
                if (n.type == NotificationType.breachAlert && hasPassword) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
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

                // تاريخ التسريب
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
                        Icon(Icons.calendar_today, size: 13, color: Colors.white.withOpacity(0.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // البيانات المسرّبة
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

                // زر تغيير كلمة المرور
                if (n.type == NotificationType.breachAlert && hasPassword && domain.isNotEmpty) ...[
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
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2D1B69),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                // زر الإغلاق
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ─── Security Alert ──────────────────────────────────────────
  void _showSecurityAlert(BuildContext context, NotificationType type) {
    final alertData = _getAlertData(type);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(alertData['icon'] as IconData, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                alertData['title'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Text(
            alertData['content'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'IBMPlexSansArabic',
              height: 1.8,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'حسناً',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
   void _showForcePasswordChangeDialog(BuildContext context) {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final apiService = ApiService();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.lock_reset, color: Color(0xFF2D1B69)),
            SizedBox(width: 8),
            Text(
              'يجب تغيير كلمة المرور',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
             children: [
           Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1B69).withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D1B69).withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFF2D1B69), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'تم رصد نشاط مشبوه على حسابك.\nلحماية حسابك يجب تغيير كلمة المرور الآن.',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 13,
                      color: Color(0xFF2D1B69),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
              const SizedBox(height: 16),
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                ),
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'لاحقاً',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة المرور غير متطابقة',
                        style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل',
                        style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final result = await apiService.changePassword(
                currentPasswordController.text,
                newPasswordController.text,
              );

              if (!context.mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result['success'] == true ? 'تم تغيير كلمة المرور بنجاح ' : result['message'] ?? 'حدث خطأ',
                    style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                  ),
                  backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D1B69),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'تغيير الآن',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}


  // ─── Alert Data ──────────────────────────────────────────────
  Map<String, dynamic> _getAlertData(NotificationType type) {
    switch (type) {
      /*
      case NotificationType.unknownDevice:
        return {
          'icon': Icons.devices,
          'title': 'جهاز غير معروف!',
          'content': '• غيّر كلمة المرور فوراً\n• راجع الأجهزة المرتبطة بحسابك\n• تواصل مع الدعم إذا لزم',
        };
        */
      case NotificationType.newLocation:
        return {
          'icon': Icons.location_on,
          'title': 'دخول من موقع مجهول!',
          'content': '• تأكد أنك لم تسافر مؤخراً\n• غيّر كلمة المرور فوراً\n• راجع نشاط حسابك',
        };
      case NotificationType.newWifi:
        return {
          'icon': Icons.wifi_off,
          'title': 'شبكة واي فاي مجهولة!',
          'content': '• تجنب استخدام شبكات عامة\n• غيّر كلمة المرور كإجراء احترازي\n• تأكد من أمان الشبكة الحالية',
        };
      case NotificationType.failedAttempts:
        return {
          'icon': Icons.lock_outline,
          'title': 'محاولات دخول مشبوهة!',
          'content': '• غيّر كلمة المرور فوراً\n• لا تشارك بياناتك مع أحد\n• تواصل مع الدعم إذا استمر الأمر',
        };
      default:
        return {
          'icon': Icons.warning_amber,
          'title': 'تحذير أمني!',
          'content': '• غيّر كلمة المرور فوراً\n• راجع نشاط حسابك',
        };
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────
  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.wifiWarning:    return Icons.wifi_off;
      case NotificationType.breachAlert:    return Icons.security;
      case NotificationType.friendRequest:  return Icons.person_add;
      case NotificationType.unknownDevice:  return Icons.devices;
      case NotificationType.newLocation:    return Icons.location_on;
      case NotificationType.newWifi:        return Icons.wifi;
      case NotificationType.failedAttempts: return Icons.lock_outline;
    }
  }

  Color _getColor(NotificationType type) {
    switch (type) {
      case NotificationType.wifiWarning:    return Colors.orange;
      case NotificationType.breachAlert:    return Colors.red;
      case NotificationType.friendRequest:  return Colors.blue;
      case NotificationType.unknownDevice:  return Colors.red;
      case NotificationType.newLocation:    return Colors.red;
      case NotificationType.newWifi:        return Colors.orange;
      case NotificationType.failedAttempts: return Colors.red;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1)  return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}