//lib/features/dashboard/screens/main_dashboard.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/biometric_service.dart';
import '../../../services/socket_service.dart';
import '../../../services/messaging_service.dart';
import '../../../services/wifi_security_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notifications.dart';
import '../services/notification_service.dart';
import '../../../core/models/app_notifications.dart';
import '../../../services/anomaly_detection_service.dart';
import 'dart:convert';

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
  
}

class _MainDashboardState extends State<MainDashboard> with WidgetsBindingObserver {
  final _apiService = ApiService();
    final _wifiService = WifiSecurityService();
  final _messagingService = MessagingService();
  StreamSubscription<WifiSecurityStatus>? _wifiSubscription;

  int _notificationCount = 0;
  bool _hasCheckedWifiThisSession = false;
  bool _userCanceledPermissionDenialAlert = false;
  String? _lastLoginTime;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    // للواي فاي تاخير بسيط
    _loadNotificationCount();
    _loadLastLoginTime();

    
   Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_hasCheckedWifiThisSession) {
        _checkWifiOnDashboardOpen();
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
    if (mounted) {
      _checkEmailBreach();
    }
    });

    Future.delayed(const Duration(seconds: 1), () {
  if (mounted) AnomalyDetectionService().runChecks();
});
    
    // التأكد من الاتصال بالـ Socket عند فتح Dashboard
    _ensureSocketConnection();
    _wifiSubscription = _wifiService.onNetworkChanged.listen((status) {
    if (mounted) {
      if (status.shouldShowWarning) {
        _showSecurityAlert(status);
      } else {
        _showSecureNetworkAlert(status);
      }
    }
  });
  
}

 Future<void> _checkEmailBreach() async {
  try {
    await NotificationService().checkEmailBreachAndNotify();

    if (!mounted) return;

    if (NotificationService().notifications
        .any((n) => n.type == NotificationType.breachAlert)) {
      _showBreachAlert();
    }
  } catch (e) {
    print('خطأ في فحص HIBP: $e');
  }
}
  
  @override
  void dispose() {
    _wifiSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
    //  مراقبة lifecycle للتطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
     // print('🔄 App resumed - reconnecting socket...');
      _ensureSocketConnection();
    } else if (state == AppLifecycleState.paused) {
      print('⏸️ App paused');
    }
  }
  
  Future<void> _ensureSocketConnection() async {
    try {
      if (!_messagingService.isConnected) {
        print('🔌 Socket not connected - initializing...');
        final success = await _messagingService.initialize();
        if (success) {
          print('✅ Socket connected after resume');
          // طلب الحالة لجميع جهات الاتصال بعد الاتصال
          await _requestAllContactsStatus();
        } else {
          print('❌ Failed to connect socket after resume');
        }
      } else {
        print('✅ Socket already connected');
        // حتى لو كان متصل، نطلب الحالة عند العودة للتطبيق
        await _requestAllContactsStatus();
      }
    } catch (e) {
      print('❌ Error ensuring socket connection: $e');
    }
  }

  // طلب الحالة لجميع جهات الاتصال
  Future<void> _requestAllContactsStatus() async {
    try {
      // انتظر قليلاً للتأكد من اكتمال الاتصال
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!_messagingService.isConnected) {
        print('⚠️ Socket not connected, skipping status requests');
        return;
      }

      // جلب قائمة جهات الاتصال
      final result = await _apiService.getContactsList();
      
      if (result['success'] == true && result['contacts'] != null) {
        final contacts = result['contacts'] as List;
        print('📡 Requesting status for ${contacts.length} contacts...');
        
        // طلب الحالة لكل جهة اتصال
        for (var contact in contacts) {
          final contactId = contact['id']?.toString();
          if (contactId != null) {
            _messagingService.requestUserStatus(contactId);
          }
        }
        
        print('✅ Status requests sent for all contacts');
      }
    } catch (e) {
      print('❌ Error requesting contacts status: $e');
    }
  }

Future<void> _initializeSocket() async {
  try {
    await SocketService().connect();
    if (kDebugMode) {
      print('Socket connected from Dashboard!');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Socket connection failed in Dashboard: $e');
    }
  }
}

 

  void _showMessage(String message, bool isSuccess) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          textAlign: TextAlign.center,
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadNotificationCount() async {
    try {
      final result = await _apiService.getPendingRequests();
      
      if (!mounted) return;
      

      if (result['code'] == 'SESSION_EXPIRED' || 
          result['code'] == 'TOKEN_EXPIRED' ||
          result['code'] == 'NO_TOKEN') {
        _handleSessionExpired();
        return;
      }
      if (result['success'] && result['requests'] != null) {
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

      if (result['success'] && mounted) {
        setState(() {
          _notificationCount = result['count'] ?? 0;
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _loadLastLoginTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginTimeStr = prefs.getString('last_login_time');
      
      DateTime loginTime;
      if (loginTimeStr != null) {
        loginTime = DateTime.parse(loginTimeStr);
      } else {
        // إذا لم يكن هناك وقت محفوظ، نستخدم الوقت الحالي
        loginTime = DateTime.now();
      }
      
      final now = DateTime.now();
      
      // التحقق إذا كان تسجيل الدخول اليوم
      if (loginTime.year == now.year && 
          loginTime.month == now.month && 
          loginTime.day == now.day) {
        // تنسيق الوقت
        final hour = loginTime.hour;
        final minute = loginTime.minute.toString().padLeft(2, '0');
        final period = hour < 12 ? 'ص' : 'م';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        
        setState(() {
          _lastLoginTime = 'تم تسجيل دخول ناجح من جهازك اليوم الساعة $displayHour:$minute $period';
        });
      } else {
        // إذا لم يكن اليوم، نعرض التاريخ
        final day = loginTime.day;
        final month = loginTime.month;
        final hour = loginTime.hour;
        final minute = loginTime.minute.toString().padLeft(2, '0');
        final period = hour < 12 ? 'ص' : 'م';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        
        setState(() {
          _lastLoginTime = 'تم تسجيل دخول ناجح من جهازك في $day/$month الساعة $displayHour:$minute $period';
        });
      }
    } catch (e) {
      print('Error loading last login time: $e');
      // في حالة الخطأ، نعرض رسالة افتراضية بالوقت الحالي
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute.toString().padLeft(2, '0');
      final period = hour < 12 ? 'ص' : 'م';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      setState(() {
        _lastLoginTime = 'تم تسجيل دخول ناجح من جهازك اليوم الساعة $displayHour:$minute $period';
      });
    }
  }

  void _handleSessionExpired() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'انتهت صلاحية الجلسة، الرجاء تسجيل الدخول مرة أخرى',
          style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.red,
      ),
    );
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    });
  }


 /// فحص الشبكة عند فتح Dashboard - مرة واحدة فقط
  Future<void> _checkWifiOnDashboardOpen() async {
    if (_hasCheckedWifiThisSession) {
      print('ℹ️ WiFi already checked in this dashboard session');
      return;
    }

    _hasCheckedWifiThisSession = true;

    try {
      final result = await _wifiService.checkNetworkOnAppLaunch();
      
      if (!mounted) return;
      
      switch (result.type) {
        case WifiCheckResultType.needsPermission:
          // أول مرة - نطلب الصلاحيات
          _showPermissionRequestDialog();
          break;
          
        case WifiCheckResultType.permissionDenied:
          // الصلاحيات مرفوضة - نعرض dialog لفتح الإعدادات
          _showPermissionDeniedDialog();
          break;
          case WifiCheckResultType.userDeclined:
          // المستخدم رفض نهائياً - لا نزعجه
          print('ℹ️ User declined WiFi check - respecting choice');
          break;
          
        case WifiCheckResultType.success:
          // نجح الفحص - نعرض التحذير إذا لزم الأمر
          if (result.status != null && result.status!.shouldShowWarning) {
            _showSecurityAlert(result.status!);
            
          }else{
          _showSecureNetworkAlert(result.status!);

          }
          break;
          
        case WifiCheckResultType.notConnected:
          print('ℹ️ User is not connected to WiFi');
          break;
          
        case WifiCheckResultType.alreadyChecked:
          print('ℹ️ Already checked in this app session');
          break;
          
        case WifiCheckResultType.error:
          print('❌ Error: ${result.errorMessage}');
          break;
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ WiFi check error: $e');
      }
    }
  }
  
// Dialog لطلب الصلاحيات لأول مرة
  void _showPermissionRequestDialog() {
    
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF2D1B69),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: const [
            Icon(Icons.shield_outlined, color: Colors.white, size: 32),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'فحص أمان الشبكات',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'للحفاظ على أمانك، نود فحص أمان شبكات WiFi التي تتصل بها.\n\nنحتاج صلاحية الموقع للوصول إلى معلومات الشبكة.\n\nهذا الفحص يتم مرة واحدة فقط عند الاتصال بشبكة جديدة.',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 14,
            height: 1.6,
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _wifiService.markUserDeclinedPermanently();
            },
            child: const Text(
              'ليس الآن',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _handlePermissionGranted(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2D1B69),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'منح الصلاحية',
              style: TextStyle(
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
Future<void> _handlePermissionGranted() async {
  // إغلاق dialog الصلاحيات
  Navigator.pop(context);
  
  // عرض Loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF2D1B69),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'جاري فحص الشبكة...',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  
  // ✨ استخدام الدالة الجديدة
  final result = await _wifiService.requestPermissionsAndCheck();
  
  // إغلاق Loading
  if (mounted && Navigator.canPop(context)) {
    Navigator.pop(context);
  }
  
  if (!mounted) return;
  
  // عرض النتيجة
  switch (result.type) {
    case WifiCheckResultType.success:
      if (result.status != null) {
        if (result.status!.shouldShowWarning) {
          _showSecurityAlert(result.status!);
        } else {
          _showSecureNetworkAlert(result.status!);
        }
      }
      break;
      
    case WifiCheckResultType.permissionDenied:
      _showPermissionDeniedDialog();
      break;
      
    case WifiCheckResultType.notConnected:
      _showMessage('غير متصل بشبكة WiFi', false);
      break;
      
    case WifiCheckResultType.error:
      _showMessage('حدث خطأ أثناء الفحص', false);
      break;
      
    default:
      break;
  }
}

  /// Dialog عند رفض الصلاحيات
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 32),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تفعيل الموقع مطلوب',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'لاستخدام ميزة فحص أمان الشبكات، يجب تفعيل الموقع.\n\nالذهاب إلى الإعدادات وتفعيل صلاحية الموقع للتطبيق.',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.right,
          ),
          actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                // تسجيل أن المستخدم اختار "إلغاء" - لا نزعجه مرة أخرى
                _wifiService.markUserDeclinedPermanently();
              },
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2D1B69),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'فتح الإعدادات',
                style: TextStyle(
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
  // رسالة: التحذير الأمني
  
 void _showSecurityAlert(WifiSecurityStatus status) {
  NotificationService().addNotification(
  AppNotification(
    id: DateTime.now().toString(),
    type: NotificationType.wifiWarning,
    title: 'تحذير: شبكة غير آمنة',
    message: 'أنت متصل بشبكة ${status.ssid}',
    createdAt: DateTime.now(),
  ),
);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF2D1B69),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade400,
              size: 32,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'تحذير أمني',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'شبكة "${status.ssid}" غير آمنة!\n\nنوع الحماية: ${status.securityType}\n\nالتوصيات:\n• استخدم VPN للحماية\n• تجنب إدخال معلومات حساسة\n• لا تدخل كلمات السر أو بيانات بنكية\n• اتصل بشبكة آمنة إن أمكن',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'حسناً، فهمت',
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
void _showBreachAlert() {
  final breachNotifications = NotificationService()
      .notifications
      .where((n) => n.type == NotificationType.breachAlert)
      .toList();

  final count = breachNotifications.length;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF2D1B69),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.red.shade400, size: 32),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'تنبيه أمني',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'تم رصد بريدك الإلكتروني في $count تسريب جديد للبيانات.\n\nاضغط على الإشعار لمعرفة التفاصيل.',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 14,
            height: 1.6,
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SimpleNotificationsPage()),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'عرض الإشعارات',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'لاحقاً',
              style: TextStyle(
                  color: Colors.white70, fontFamily: 'IBMPlexSansArabic'),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildBellButton() {
  final w = MediaQuery.of(context).size.width;

  return StreamBuilder<List<AppNotification>>(
    stream: NotificationService().notificationsStream,
    initialData: NotificationService().notifications,
    builder: (context, snapshot) {
      final notifications = snapshot.data ?? [];
      final unreadCount =
          notifications.where((n) => !n.isRead).length;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(w * 0.03),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SimpleNotificationsPage(),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(w * 0.022),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(w * 0.03),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.2),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications,
                  color: AppColors.textPrimary,
                  size: w * 0.066,
                ),

                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
// رسالة للشبكة الآمنة (جديدة)
void _showSecureNetworkAlert(WifiSecurityStatus status) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF2D1B69),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.verified_user,
              color: Colors.green.shade400,
              size: 32,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'شبكة آمنة',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'أنت متصل بشبكة "${status.ssid}"\n\n الشبكة آمنة ومحمية',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 14,
            height: 1.6,
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        bottomNavigationBar: BottomNavBar(currentIndex: 0,),
        backgroundColor: AppColors.background,
        body:  SafeArea(
  child: Stack(
    children: [
      const HeaderWidget(
        title: '',
        showBackground: true,
        alignTitleRight: false,
      ),

      Padding(
        padding: EdgeInsets.only(
          top: height * 0.12, // 👈 نتحكم بالموقع هنا
          left: width * 0.06,
          right: width * 0.06,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: _buildBellButton(),
            ),

            const SizedBox(height: 6),

            _buildTitle('مرحبًا بك', width * 0.085, context),
            const SizedBox(height: 10),
            _buildTitle('لوحة المعلومات', width * 0.05, context),
            const SizedBox(height: 8),
            _buildInfoCard(context),
            const SizedBox(height: 12),
            _buildTipHeader(context),
            const SizedBox(height: 8),
            _buildTipText(context),
          ],
        ),
      ),
    ],
  ),
),
    ));
  }



  Widget _buildTitle(String text, double size, BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AppTextStyles.h1.copyWith(
        fontSize: size,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    return Container(
      padding: EdgeInsets.all(width * 0.055),
      constraints: BoxConstraints(
        minHeight: size.height * 0.16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: [
          BoxShadow(
            blurRadius: 15,
            offset: const Offset(0, 3),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              color: const Color(0xFFFFB74D), size: width * 0.06),
          SizedBox(width: width * 0.035),
          Expanded(
            child: Text(
              _lastLoginTime ?? '',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(
                fontSize: width * 0.042,
                color: AppColors.textPrimary.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipHeader(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lightbulb_outline,
            color: const Color(0xFFFFD54F), size: width * 0.055),
        SizedBox(width: width * 0.02),
        Text(
          'نصيحة اليوم',
          style: AppTextStyles.h3.copyWith(
            fontSize: width * 0.05,
          ),
        ),
      ],
    );
  }

  Widget _buildTipText(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: width * 0.01,
            height: width * 0.088,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: width * 0.03),
          Expanded(
            child: Text(
              'لا تستخدم نفس كلمة المرور في أكثر من حساب',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: width * 0.0375,
                color: AppColors.textPrimary.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _Bell extends StatelessWidget {
  const _Bell();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Transform.translate(
      offset: const Offset(0, -20), 
      child: Stack(  // ← شلنا GestureDetector من هنا
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(w * 0.022),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(w * 0.03),
              border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
            ),
            child: Icon(Icons.notifications,
                color: AppColors.textPrimary, size: w * 0.066),
          ),
          const Positioned(
            top: -5,
            right: -3,
            child: _RedDot(),
          ),
        ],
      ),
    );
  }
}

class _RedDot extends StatelessWidget {
  const _RedDot();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      width: w * 0.038,
      height: w * 0.038,
      decoration: const BoxDecoration(
        color: Color(0xFFE53935),
        shape: BoxShape.circle,
      ),
    );
  }
}