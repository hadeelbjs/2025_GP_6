import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/api_services.dart';
import '../../../services/messaging_service.dart';
import '../../../services/wifi_security_service.dart';
import '../../../services/anomaly_detection_service.dart';
import '../../../core/models/app_notifications.dart';
import '../../services_hub/services/api_contentScanning.dart';
import '../services/notification_service.dart';
import 'notifications.dart';

class DashboardData {
  final String todayTip;
  final Map<String, dynamic>? passwordExp;
  final Map<String, dynamic>? contentScanningStats;

  const DashboardData({
    required this.todayTip,
    this.passwordExp,
    this.contentScanningStats,
  });
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> with WidgetsBindingObserver {
  final _apiService = ApiService();
  final _apiContentScanning = ApiContentService();
  final _wifiService = WifiSecurityService();
  final _messagingService = MessagingService();
  
  StreamSubscription<WifiSecurityStatus>? _wifiSubscription;
  DashboardData? _dashboardData;
  String? _lastLoginTime;
  bool _isLoading = true;
  bool _hasCheckedWifiThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDashboard();
  }

  @override
  void dispose() {
    _wifiSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureSocketConnection();
    }
  }

  // --- Data Initialization & Orchestration ---
  Future<void> _initializeDashboard() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final results = await Future.wait([
      _apiService.getTodaySecurityTip().catchError((_) => {'success': false}),
      _apiService.getPasswordExpDate().catchError((_) => {'success': false}),
      _apiContentScanning.getAllStats().catchError((_) => <String, dynamic>{}),
      _loadNotificationCount().catchError((_) => null),
      _loadLastLoginTime().catchError((_) => null),
    ]);

    final tipRes = results[0] as Map<String, dynamic>;
    final passRes = results[1] as Map<String, dynamic>;
    final statsRes = results[2] as Map<String, dynamic>;

    String tipText = 'لا توجد نصيحة متاحة حالياً.';
    if (tipRes['success'] == true && tipRes['tip'] != null && tipRes['tip']['tip_ar'] != null) {
      tipText = tipRes['tip']['tip_ar'].toString();
    }

    _dashboardData = DashboardData(
      todayTip: tipText,
      passwordExp: passRes['success'] != false ? passRes : null,
      contentScanningStats: statsRes.isNotEmpty ? statsRes : null,
    );

    setState(() => _isLoading = false);
    _runBackgroundSecurityChecks();
  }

  void _runBackgroundSecurityChecks() {
    _ensureSocketConnection();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_hasCheckedWifiThisSession) _checkWifiOnDashboardOpen();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _checkEmailBreach();
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) AnomalyDetectionService().runChecks();
    });

    _wifiSubscription = _wifiService.onNetworkChanged.listen((status) {
      if (!mounted) return;
      status.shouldShowWarning ? _showSecurityAlert(status) : _showSecureNetworkAlert(status);
    });
  }

  // --- Core Services Bindings ---
  Future<void> _ensureSocketConnection() async {
    try {
      if (!_messagingService.isConnected) {
        final success = await _messagingService.initialize();
        if (success) await _requestAllContactsStatus();
      } else {
        await _requestAllContactsStatus();
      }
    } catch (e) {
      debugPrint('Socket connection binding failed: $e');
    }
  }

  Future<void> _requestAllContactsStatus() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_messagingService.isConnected) return;

      final result = await _apiService.getContactsList();
      if (result['success'] == true && result['contacts'] != null) {
        for (var contact in (result['contacts'] as List)) {
          final id = contact['id']?.toString();
          if (id != null) _messagingService.requestUserStatus(id);
        }
      }
    } catch (e) {
      debugPrint('Error requesting contacts status: $e');
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final result = await _apiService.getPendingRequests();
      if (!mounted) return;

      if (['SESSION_EXPIRED', 'TOKEN_EXPIRED', 'NO_TOKEN'].contains(result['code'])) {
        _handleSessionExpired();
        return;
      }
      if (result['success'] == true && result['requests'] != null) {
        for (var req in result['requests']) {
          NotificationService().addNotification(
            AppNotification(
              id: req['id'].toString(),
              type: NotificationType.friendRequest,
              title: 'طلب إضافة جديد',
              message: '${req['name']} يريد إضافتك',
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLastLoginTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginTimeStr = prefs.getString('last_login_time');
      final loginTime = loginTimeStr != null ? DateTime.parse(loginTimeStr) : DateTime.now();
      final now = DateTime.now();

      final hour = loginTime.hour;
      final minute = loginTime.minute.toString().padLeft(2, '0');
      final period = hour < 12 ? 'ص' : 'م';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      setState(() {
        if (loginTime.year == now.year && loginTime.month == now.month && loginTime.day == now.day) {
          _lastLoginTime = 'تم تسجيل دخول ناجح من جهازك اليوم الساعة $displayHour:$minute $period';
        } else {
          _lastLoginTime = 'تم تسجيل دخول ناجح من جهازك في ${loginTime.day}/${loginTime.month} الساعة $displayHour:$minute $period';
        }
      });
    } catch (_) {}
  }

  Future<void> _checkEmailBreach() async {
    try {
      await NotificationService().checkEmailBreachAndNotify();
      if (mounted && NotificationService().notifications.any((n) => n.type == NotificationType.breachAlert)) {
        _showBreachAlert();
      }
    } catch (e) {
      debugPrint('Email breach background check failure: $e');
    }
  }

  void _handleSessionExpired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('انتهت صلاحية الجلسة، الرجاء تسجيل الدخول مرة أخرى', style: TextStyle(fontFamily: 'IBMPlexSansArabic')), 
        backgroundColor: Colors.red,
      ),
    );
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _checkWifiOnDashboardOpen() async {
    if (_hasCheckedWifiThisSession) return;
    _hasCheckedWifiThisSession = true;

    try {
      final result = await _wifiService.checkNetworkOnAppLaunch();
      if (!mounted) return;

      switch (result.type) {
        case WifiCheckResultType.needsPermission:
          _showPermissionRequestDialog();
          break;
        case WifiCheckResultType.permissionDenied:
          _showPermissionDeniedDialog();
          break;
        case WifiCheckResultType.success:
          if (result.status != null) {
            result.status!.shouldShowWarning ? _showSecurityAlert(result.status!) : _showSecureNetworkAlert(result.status!);
          }
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('WiFi network inspection error: $e');
    }
  }

  void _showMessage(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'IBMPlexSansArabic'), textAlign: TextAlign.center),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI Presentation Dialogs ---
  void _showPermissionRequestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.white, size: 32),
              SizedBox(width: 10),
              Expanded(child: Text('فحص أمان الشبكات', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 20, fontWeight: FontWeight.bold))),
            ],
          ),
          content: const Text('للحفاظ على أمانك، نود فحص أمان شبكات WiFi التي تتصل بها.\n\nنحتاج صلاحية الموقع للوصول إلى معلومات الشبكة.', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 14, height: 1.6)),
          actions: [
            TextButton(onPressed: () { Navigator.pop(context); _wifiService.markUserDeclinedPermanently(); }, child: const Text('ليس الآن', style: TextStyle(color: Colors.white70, fontFamily: 'IBMPlexSansArabic'))),
            ElevatedButton(
              onPressed: () => _handlePermissionGranted(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF2D1B69), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('منح الصلاحية', style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePermissionGranted() async {
    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Color(0xFF2D1B69),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text('جاري فحص الشبكة...', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 16)),
            ],
          ),
        ),
      ),
    );

    final result = await _wifiService.requestPermissionsAndCheck();
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    if (!mounted) return;

    if (result.type == WifiCheckResultType.success && result.status != null) {
      result.status!.shouldShowWarning ? _showSecurityAlert(result.status!) : _showSecureNetworkAlert(result.status!);
    } else if (result.type == WifiCheckResultType.permissionDenied) {
      _showPermissionDeniedDialog();
    } else if (result.type == WifiCheckResultType.notConnected) {
      _showMessage('غير متصل بشبكة WiFi', false);
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.white, size: 32),
              SizedBox(width: 10),
              Expanded(child: Text('تفعيل الموقع مطلوب', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 20, fontWeight: FontWeight.bold))),
            ],
          ),
          content: const Text('لاستخدام ميزة فحص أمان الشبكات، يجب تفعيل الموقع من إعدادات النظام.', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 14, height: 1.6)),
          actions: [
            TextButton(onPressed: () { Navigator.pop(context); _wifiService.markUserDeclinedPermanently(); }, child: const Text('إلغاء', style: TextStyle(color: Colors.white70, fontFamily: 'IBMPlexSansArabic'))),
            ElevatedButton(onPressed: () async { Navigator.pop(context); await openAppSettings(); }, child: const Text('فتح الإعدادات')),
          ],
        ),
      ),
    );
  }

  void _showSecurityAlert(WifiSecurityStatus status) {
    NotificationService().addNotification(AppNotification(id: DateTime.now().toString(), type: NotificationType.wifiWarning, title: 'تحذير: شبكة غير آمنة', message: 'أنت متصل بشبكة ${status.ssid}', createdAt: DateTime.now()));
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          title: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 32), const SizedBox(width: 10), const Text('تحذير أمني', style: TextStyle(color: Colors.white))]),
          content: Text('شبكة "${status.ssid}" غير آمنة!\n\nنوع الحماية: ${status.securityType}\n\nتجنب إدخال أي معلومات حساسة.', style: const TextStyle(color: Colors.white, height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('فهمت'))],
        ),
      ),
    );
  }

  void _showSecureNetworkAlert(WifiSecurityStatus status) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          title: Row(children: [Icon(Icons.verified_user, color: Colors.green.shade400, size: 32), const SizedBox(width: 10), const Text('شبكة آمنة', style: TextStyle(color: Colors.white))]),
          content: Text('أنت متصل بشبكة "${status.ssid}" والمحمية بشكل آمن.', style: const TextStyle(color: Colors.white)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      ),
    );
  }

  void _showBreachAlert() {
    final count = NotificationService().notifications.where((n) => n.type == NotificationType.breachAlert).length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          title: Row(children: [Icon(Icons.security, color: Colors.red.shade400, size: 32), const SizedBox(width: 10), const Text('تنبيه أمني', style: TextStyle(color: Colors.white))]),
          content: Text('تم رصد بريدك الإلكتروني في $count تسريب جديد للبيانات.', style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('لاحقاً')),
            ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SimpleNotificationsPage())); }, child: const Text('عرض الإشعارات')),
          ],
        ),
      ),
    );
  }

  // --- Build Framework ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        bottomNavigationBar: const BottomNavBar(currentIndex: 0),
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              const HeaderWidget(title: '', showBackground: true, alignTitleRight: false),
              Padding(
                padding: EdgeInsets.only(top: size.height * 0.12, left: size.width * 0.06, right: size.width * 0.06),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.topLeft, child: NotificationBellButton(onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SimpleNotificationsPage()));
                    })),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator()) 
                        : DashboardContentView(
                            data: _dashboardData!, 
                            lastLoginTime: _lastLoginTime,
                            onRefreshBreaches: () => setState(() {}),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Componentized Sub-Widgets Section (Clean, Const, Isolated)
// =========================================================================

class NotificationBellButton extends StatelessWidget {
  final VoidCallback onTap;
  const NotificationBellButton({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService().notificationsStream,
      initialData: NotificationService().notifications,
      builder: (context, snapshot) {
        final unreadCount = (snapshot.data ?? []).where((n) => !n.isRead).length;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(w * 0.03),
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.all(w * 0.022),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(w * 0.03),
                border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications, color: AppColors.textPrimary, size: w * 0.066),
                  if (unreadCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Center(
                          child: Text(unreadCount > 99 ? '99+' : '$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DashboardContentView extends StatelessWidget {
  final DashboardData data;
  final String? lastLoginTime;
  final VoidCallback onRefreshBreaches;

  const DashboardContentView({
    Key? key, 
    required this.data, 
    this.lastLoginTime,
    required this.onRefreshBreaches,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مرحبًا بك', style: AppTextStyles.h1.copyWith(fontSize: width * 0.085)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: const Color(0xFFFFD54F), size: width * 0.055),
              const SizedBox(width: 8),
              Text('نصيحة اليوم', style: AppTextStyles.h3.copyWith(fontSize: width * 0.05)),
            ],
          ),
          const SizedBox(height: 8),
          SecurityTipCard(tipText: data.todayTip),
          const SizedBox(height: 12),
          Text('لوحة المعلومات', style: AppTextStyles.h1.copyWith(fontSize: width * 0.05)),
          const SizedBox(height: 8),
          if (data.passwordExp != null) PasswordExpirationCard(data: data.passwordExp!),
          const SizedBox(height: 8),
          if (data.contentScanningStats != null) ContentScanningSection(stats: data.contentScanningStats!),
          const SizedBox(height: 8),
          DataBreachSection(onRefresh: onRefreshBreaches),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class SecurityTipCard extends StatelessWidget {
  final String tipText;
  const SecurityTipCard({Key? key, required this.tipText}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(width: width * 0.01, height: width * 0.088, decoration: BoxDecoration(color: const Color(0xFFFFD54F), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Text(tipText, style: AppTextStyles.bodyMedium.copyWith(fontSize: width * 0.0375, color: AppColors.textPrimary.withOpacity(0.75)))),
        ],
      ),
    );
  }
}

class PasswordExpirationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const PasswordExpirationCard({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final daysTillExp = data['daysTillExp'] as int? ?? 0;
    final expDateStr = data['expDate'] as String?;
    final expDate = expDateStr != null ? DateTime.parse(expDateStr) : DateTime.now();
    final formattedDate = '${expDate.day.toString().padLeft(2, '0')}/${expDate.month.toString().padLeft(2, '0')}/${expDate.year}';

    final Color expColor = daysTillExp <= 14 ? const Color(0xFFC62828) : daysTillExp <= 30 ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
    final IconData expIcon = daysTillExp <= 14 ? Icons.warning : daysTillExp <= 30 ? Icons.info : Icons.check_circle;

    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(width: width * 0.01, height: width * 0.12, decoration: BoxDecoration(color: expColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Icon(expIcon, color: expColor, size: width * 0.055),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('صلاحية كلمة المرور', style: AppTextStyles.bodyMedium.copyWith(fontSize: width * 0.035, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('تنتهي خلال $daysTillExp يوم — $formattedDate', style: AppTextStyles.bodyMedium.copyWith(fontSize: width * 0.033, color: expColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContentScanningSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  const ContentScanningSection({Key? key, required this.stats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final linkStats = stats['linkStats'] as Map<String, dynamic>? ?? {};
    final fileStats = stats['fileStats'] as Map<String, dynamic>? ?? {};
    final imageStats = stats['imageStats'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('إحصائيات الفحص', style: AppTextStyles.h3.copyWith(fontSize: width * 0.05)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: StatCard(title: 'الروابط', stats: linkStats, icon: Icons.link)),
            SizedBox(width: width * 0.03),
            Expanded(child: StatCard(title: 'الملفات', stats: fileStats, icon: Icons.folder)),
            SizedBox(width: width * 0.03),
            Expanded(child: StatCard(title: 'الصور', stats: imageStats, icon: Icons.image, safeLabel: 'غير حساسة', vulnerableLabel: 'حساسة')),
          ],
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> stats;
  final IconData icon;
  final String safeLabel;
  final String vulnerableLabel;

  const StatCard({
    Key? key,
    required this.title,
    required this.stats,
    required this.icon,
    this.safeLabel = 'آمن',
    this.vulnerableLabel = 'خطر',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final total = stats['total'] ?? 0;
    final safe = stats['safe'] ?? 0;
    final vulnerable = stats['vulnerable'] ?? 0;

    return Container(
      padding: EdgeInsets.all(width * 0.035),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.secondary, size: width * 0.055),
          SizedBox(height: width * 0.02),
          Text(title, style: AppTextStyles.bodyMedium.copyWith(fontSize: width * 0.035, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          SizedBox(height: width * 0.02),
          StatRow(label: 'الكل', value: total, color: Colors.grey, icon: Icons.circle_outlined),
          StatRow(label: safeLabel, value: safe, color: const Color(0xFF2E7D32), icon: Icons.check_circle),
          StatRow(label: vulnerableLabel, value: vulnerable, color: const Color(0xFFC62828), icon: Icons.warning),
        ],
      ),
    );
  }
}

class StatRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const StatRow({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.only(bottom: width * 0.01),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: width * 0.03),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: width * 0.03, color: AppColors.textPrimary.withOpacity(0.7), fontFamily: 'IBMPlexSansArabic')),
            ],
          ),
          Text('$value', style: TextStyle(fontSize: width * 0.03, color: color, fontWeight: FontWeight.bold, fontFamily: 'IBMPlexSansArabic')),
        ],
      ),
    );
  }
}

class DataBreachSection extends StatelessWidget {
  final VoidCallback onRefresh;
  const DataBreachSection({Key? key, required this.onRefresh}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: NotificationService().getAllBreaches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final breaches = snapshot.data ?? [];

        return FutureBuilder<Set<String>>(
          future: NotificationService().getFixedBreaches(),
          builder: (context, fixedSnapshot) {
            final fixedBreaches = fixedSnapshot.data ?? {};
            final activeBreaches = breaches.where((b) => !fixedBreaches.contains(b['name'])).toList();
            final latestBreach = activeBreaches.isNotEmpty ? activeBreaches.first : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تسريبات البيانات', style: AppTextStyles.h3.copyWith(fontSize: width * 0.05)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(width * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(width * 0.04),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 3))],
                  ),
                  child: activeBreaches.isEmpty
                      ? Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 22),
                            const SizedBox(width: 10),
                            Text('لا توجد تسريبات نشطة', style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF2E7D32))),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.warning, color: Color(0xFFC62828), size: 22),
                            const SizedBox(width: 10),
                            Expanded(child: Text('عدد التسريبات المرتبطة ببريدك: ${activeBreaches.length}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold))),
                          ],
                        ),
                ),
                if (latestBreach != null) ...[
                  const SizedBox(height: 8),
                  Text('أحدث التسريبات', style: AppTextStyles.h3.copyWith(fontSize: width * 0.045)),
                  const SizedBox(height: 8),
                  BreachCard(breach: latestBreach, fixedBreaches: fixedBreaches, onUpdate: onRefresh),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class BreachCard extends StatelessWidget {
  final Map<String, dynamic> breach;
  final Set<String> fixedBreaches;
  final VoidCallback onUpdate;

  const BreachCard({
    Key? key,
    required this.breach,
    required this.fixedBreaches,
    required this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isFixed = fixedBreaches.contains(breach['name']);
    final dataClasses = List<String>.from(breach['dataClasses'] ?? []);
    final hasPassword = breach['hasPassword'] as bool? ?? false;

    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        border: Border.all(color: isFixed ? const Color(0xFF2E7D32).withOpacity(0.3) : AppColors.primary.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.language, color: AppColors.primary, size: width * 0.05),
                  const SizedBox(width: 8),
                  Text(breach['title'] as String? ?? 'تسريب غير معروف', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(breach['breachDate'] as String? ?? '', style: AppTextStyles.bodyMedium.copyWith(fontSize: width * 0.03, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 8),
          Text('يشمل: ${dataClasses.take(3).join('، ')}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          if (hasPassword && !isFixed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
              child: const Text('⚠️ يرجى تغيير كلمة المرور فوراً وتفعيل التحقق الثنائي.', style: TextStyle(color: Color(0xFFC62828), fontSize: 12)),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final name = breach['name'] as String;
                  isFixed ? await NotificationService().unmarkBreachAsFixed(name) : await NotificationService().markBreachAsFixed(name);
                  onUpdate();
                },
                icon: Icon(isFixed ? Icons.check_circle : Icons.shield, size: 16),
                label: Text(isFixed ? 'تم الإصلاح ✓' : 'علم كمصلح'),
                style: ElevatedButton.styleFrom(backgroundColor: isFixed ? const Color(0xFF2E7D32) : AppColors.primary, foregroundColor: Colors.white),
              ),
              if (breach['domain'] != null && (breach['domain'] as String).isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('https://${breach['domain']}');
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('زيارة الموقع'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}