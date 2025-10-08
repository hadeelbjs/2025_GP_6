// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/auth_guard.dart';
import 'services/api_services.dart';
import 'features/authentication/screens/login_screen.dart';
import 'features/authentication/screens/register_screen.dart';
import 'features/dashboard/screens/main_dashboard.dart';
import 'features/contact/screens/contacts_list_screen.dart';
import 'features/contact/screens/add_contact_screen.dart';
import 'features/massaging/screens/chat_list_screen.dart';
import 'features/account/screens/manage_account_screen.dart';
import 'features/contact/screens/notifications_screen.dart';
import 'package:flutter/foundation.dart';
import 'services/biometric_service.dart';
import 'features/authentication/screens/biometric_login_screen.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وصيد',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'IBMPlexSansArabic',
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        
        // الصفحات المحمية - تحتاج تسجيل دخول
        '/dashboard': (context) => const ProtectedRoute(
          child: MainDashboard(),
        ),
        '/contacts': (context) => const ProtectedRoute(
          child: ContactsListScreen(),
        ),
        '/add-contact': (context) => const ProtectedRoute(
          child: AddContactScreen(),
        ),
        '/chats': (context) => const ProtectedRoute(
          child: ChatListScreen(),
        ),
       // '/notifications': (context) => const ProtectedRoute(
         // child: NotificationsScreen(),
       // ),
        '/account': (context) => const ProtectedRoute(
          child: AccountManagementScreen(),
        ),
      },
    );
  }
}

// Splash Screen للتحقق من حالة تسجيل الدخول
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final AuthGuard _authGuard = AuthGuard();
  final ApiService _apiService = ApiService(); // ← أضيفي هذا السطر
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // تأثير Animation للوقو
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
  // انتظار للتأثير البصري
  await Future.delayed(const Duration(seconds: 2));

  if (!mounted) return;

  try {
    // فحص وجود tokens
    final isAuth = await _authGuard.isAuthenticated();
    
    if (!isAuth) {
      // لا توجد جلسة - اذهب لتسجيل الدخول
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // توجد جلسة - فحص البصمة
    final canUseBiometric = await _apiService.canUseBiometric();
    
    if (canUseBiometric) {
      // البصمة مفعلة - اذهب لشاشة البصمة
      final biometricUser = await BiometricService.getBiometricUser();
      
      if (biometricUser != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BiometricLoginScreen(userEmail: biometricUser),
          ),
        );
      } else {
        // خطأ في البيانات - اذهب للـ login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else {
      // البصمة غير مفعلة - اذهب للداشبورد مباشرة
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }

  } catch (e) {
    // خطأ في الفحص - اذهب للـ login لضمان الأمان
    debugPrint('خطأ في السبلاش: $e');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D1B69),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // شعار التطبيق SVG
              SvgPicture.asset(
              'assets/images/logo-white.svg',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
              
              const SizedBox(height: 30),
              
              const Text(
                'وصيد',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic',
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 10),
              
              Text(
                'أمانك بِلُغَتِك',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
              
              const SizedBox(height: 60),
              
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}