// lib/main.dart
import 'package:flutter/material.dart';
import 'services/auth_guard.dart';
import 'features/authentication/screens/login_screen.dart';
import 'features/authentication/screens/register_screen.dart';
import 'features/dashboard/screens/main_dashboard.dart';
import 'features/contact/screens/contacts_list_screen.dart';
import 'features/contact/screens/add_contact_screen.dart';
import 'features/massaging/screens/chat_list_screen.dart';
import 'features/account/screens/manage_account_screen.dart';
import 'features/contact/screens/notifications_screen.dart';

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
        
        // 🔒 الصفحات المحمية - تحتاج تسجيل دخول
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
        '/notifications': (context) => const ProtectedRoute(
          child: NotificationsScreen(),
        ),
        '/account': (context) => const ProtectedRoute(
          child: AccountManagementScreen(),
        ),
      },
    );
  }
}

// ============================================
// 🚀 Splash Screen - للتحقق من حالة تسجيل الدخول
// ============================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthGuard _authGuard = AuthGuard();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // انتظار ثانية للتأثير البصري
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final isAuth = await _authGuard.isAuthenticated();

    if (isAuth) {
      // مسجل دخول - اذهب للـ Dashboard
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      // غير مسجل - اذهب لصفحة تسجيل الدخول
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D1B69),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // شعار التطبيق
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.chat_bubble,
                size: 60,
                color: Color(0xFF2D1B69),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'وصيد',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}