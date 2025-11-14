//lib/features/dashboard/screens/main_dashboard.dart
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
import '../../../services/wifi_security_service.dart';
import 'package:permission_handler/permission_handler.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final _apiService = ApiService();
    final _wifiService = WifiSecurityService();

  int _notificationCount = 0;
  bool _hasCheckedWifiThisSession = false;
  bool _userCanceledPermissionDenialAlert = false;


  @override
  void initState() {
    super.initState();
    // للواي فاي تاخير بسيط
    _loadNotificationCount();

    
   Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_hasCheckedWifiThisSession) {
        _checkWifiOnDashboardOpen();
      }
    });
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

      if (result['success'] && mounted) {
        setState(() {
          _notificationCount = result['count'] ?? 0;
        });
      }
    } catch (e) {
      // Silent fail
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
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
              const SizedBox(width: 10),
              const Expanded(
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
                // تسجيل أن المستخدم اختار "ليس الآن" - لا نزعجه مرة أخرى
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
              onPressed: () async {
                Navigator.pop(context);
                final granted = await _wifiService.requestPermissions();
                if (granted && mounted) {
                  // أعد الفحص بعد منح الصلاحيات
                  _hasCheckedWifiThisSession = false;
                  _checkWifiOnDashboardOpen();
                }
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
  // ============================================
  // رسالة: التحذير الأمني
  // ============================================
  
  void _showSecurityAlert(WifiSecurityStatus status) {
    final isAndroid = status.platform == 'Android';
    
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
                color: isAndroid ? Colors.red.shade400 : Colors.orange.shade400,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAndroid ? 'تحذير أمني' : 'تنبيه',
                  style: const TextStyle(
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
              isAndroid
                  ? ' شبكة "${status.ssid}" غير آمنة!\n\nنوع الحماية: ${status.securityType}\n\n التوصيات:\n• استخدم VPN للحماية الكاملة\n• تجنب إدخال معلومات حساسة\n• لا تدخل كلمات السر أو بيانات بنكية\n• اتصل بشبكة آمنة إن أمكن'
                  : 'قد تكون شبكة "${status.ssid}" غير آمنة\n\nالتحليل: بناءً على اسم الشبكة\n\n التوصيات:\n• استخدم VPN للأمان\n• تجنب إدخال معلومات حساسة\n• لا تدخل كلمات السر\n• اتصل بشبكة موثوقة إن أمكن',
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const HeaderWidget(
                title: '',
                showBackground: true,
                alignTitleRight: false,
              ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.06),
                  child: Transform.translate(
                    offset: Offset(0, -height * 0.045),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),

                        const Align(
                          alignment: Alignment.topLeft,
                          child: _Bell(),
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

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Navigation Bar
             BottomNavBar(currentIndex: 0)

            ],
          ),
        ),
      ),
    );
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
              'تم اكتشاف تسجيل دخول مريب',
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
      child: Stack(
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