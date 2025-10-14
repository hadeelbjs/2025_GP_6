// lib/main.dart
import 'package:flutter/material.dart';
import 'services/api_services.dart';
import 'services/biometric_service.dart';
import 'features/authentication/screens/biometric_login_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/auth_guard.dart';
import 'features/authentication/screens/login_screen.dart';
import 'features/authentication/screens/register_screen.dart';
import 'features/dashboard/screens/main_dashboard.dart';
import 'features/contact/screens/contacts_list_screen.dart';
import 'features/contact/screens/add_contact_screen.dart';
import 'features/massaging/screens/chat_list_screen.dart';
import 'features/account/screens/manage_account_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/crypto/signal_protocol_manager.dart';
import 'features/massaging/screens/chat_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        '/account': (context) => const ProtectedRoute(
          child: AccountManagementScreen(),
        ),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final AuthGuard _authGuard = AuthGuard();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
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
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      print('Checking app state...');
      
      // 1. فحص إذا للتو تم logout
      final justLoggedOut = await BiometricService.getJustLoggedOut();
      print('Just logged out? $justLoggedOut');
      
      if (justLoggedOut) {
        await BiometricService.setJustLoggedOut(false);
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // 2. فحص إذا مسجل دخول
      final isAuth = await _authGuard.isAuthenticated();
      print('Is authenticated? $isAuth');
      
      if (isAuth) {
        // تهيئة التشفير للمستخدم المسجل
        await _initializeEncryption();
        
        Navigator.of(context).pushReplacementNamed('/dashboard');
        return;
      }

      // 3. غير مسجل دخول - الذهاب للوقن
      Navigator.of(context).pushReplacementNamed('/login');

    } catch (e) {
      print('Error in Splash: $e');
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  /// تهيئة التشفير للمستخدم المسجل دخول
  Future<void> _initializeEncryption() async {
    try {
      final storage = const FlutterSecureStorage();
      
      print('User logged in - checking keys...');
      
      // التحقق الصحيح من وجود المفاتيح
      final identityKey = await storage.read(key: 'identity_key');
      final registrationId = await storage.read(key: 'registration_id');
      
      if (identityKey != null && registrationId != null) {
        print('Keys already exist');
        
        // تهيئة SignalProtocolManager
        final signalManager = SignalProtocolManager();
        await signalManager.initialize();
        
        // التحقق من عدد PreKeys المتبقية
        await signalManager.checkAndRefreshPreKeys();
        return;
      }
      
      // المفاتيح غير موجودة - توليد جديدة
      print('No keys found - generating...');
      
      final signalManager = SignalProtocolManager();
      final success = await signalManager.generateAndUploadKeys();
      
      if (success) {
        print('Keys generated and uploaded successfully');
      } else {
        print('Failed to generate/upload keys - will retry later');
      }
      
    } catch (e) {
      print('Error initializing encryption: $e');
      // لا نوقف التطبيق - يمكن إعادة المحاولة لاحقاً
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