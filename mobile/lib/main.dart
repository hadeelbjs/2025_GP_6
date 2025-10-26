import 'package:flutter/material.dart';
import 'services/api_services.dart';
import 'services/biometric_service.dart';
import 'services/messaging_service.dart'; 
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
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/authentication/screens/splash_screen.dart';
void main() async {
  await dotenv.load(fileName: ".env");
  
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
        '/onboard': (context) => const OnboardingScreen(),
        
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
      final isAuth = await _authGuard.isAuthenticated();
      if (justLoggedOut || !isAuth) {
        await BiometricService.setJustLoggedOut(false);
        Navigator.of(context).pushReplacementNamed('/onboard');
        return;
      }

      // 2. فحص إذا مسجل دخول
      print('Is authenticated? $isAuth');
      
      if (isAuth) {
        // ✅ تهيئة التشفير
        await _initializeEncryption();
        
        // ✅ تهيئة MessagingService (Socket + Listeners)
        await _initializeMessaging();
        
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

  ///  تهيئة MessagingService
  Future<void> _initializeMessaging() async {
    try {
      print('🔌 Initializing MessagingService...');
      
      final success = await MessagingService().initialize();
      
      if (success) {
        print('✅ MessagingService initialized successfully');
      } else {
        print('❌ MessagingService initialization failed');
        // لا نوقف التطبيق - يمكن إعادة المحاولة لاحقاً
      }
      
    } catch (e) {
      print('❌ Error initializing MessagingService: $e');
      // لا نوقف التطبيق
    }
  }

  /// تهيئة التشفير للمستخدم المسجل دخول
Future<void> _initializeEncryption() async {
  try {
    print('🔐 جاري تهيئة التشفير...');

    
    
    // ✅ 1. جلب userId أولاً
    final storage = const FlutterSecureStorage();
    final userDataStr = await storage.read(key: 'user_data');
    
    if (userDataStr == null) {
      print('❌ لا توجد بيانات مستخدم');
      return;
    }
    
    final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
    final userId = userData['id'] as String;
    
    print('👤 User ID: $userId');
    
    // ✅ 2. تهيئة SignalProtocolManager
    final signalManager = SignalProtocolManager();
    await signalManager.initialize();
    
    // ✅ 3. الفحص باستخدام userId
    final userIdentityKey = await storage.read(key: 'identity_key_$userId');
    
    if (userIdentityKey != null) {
      print('✅ المفاتيح موجودة للمستخدم $userId');
      await signalManager.checkAndRefreshPreKeys();
    } else {
      print('🆕 توليد مفاتيح جديدة للمستخدم $userId');
      await signalManager.generateAndUploadKeys();
    }
    
  } catch (e) {
    print('❌ خطأ في تهيئة التشفير: $e');
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