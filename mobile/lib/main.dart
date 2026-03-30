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
import 'features/authentication/screens/biometric_login_screen.dart';
import 'features/services_hub/screens/services.dart';
import 'features/services_hub/screens/content_scan.dart';
import 'services/wifi_security_service.dart';
import 'package:geolocator/geolocator.dart';
import 'features/services_hub/screens/image_scanner_screen.dart';
import 'features/services_hub/screens/chatbot.dart';
import 'features/services_hub/screens/password_generator.dart';
import 'features/services_hub/screens/breach_lookup.dart';
import 'features/account/screens/frozen_account_screen.dart';
import 'package:app_links/app_links.dart';
import 'features/authentication/screens/reset_password.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  await dotenv.load(fileName: ".env");

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}
String? pendingDeepLinkRoute;
Map<String, dynamic>? pendingDeepLinkArgs;
class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
 @override
void initState() {
  super.initState();
  _appLinks = AppLinks();

  // انتظر التطبيق يبني نفسه كامل
  Future.delayed(const Duration(milliseconds: 300), () async {
    final uri = await _appLinks.getInitialAppLink();
    print('🔗 Initial after delay: $uri');
    if (uri != null && uri.scheme == 'waseed' && uri.host == 'frozen') {
      pendingDeepLinkRoute = '/frozen';
      pendingDeepLinkArgs = {'type': uri.queryParameters['type'] ?? 'email'};
    }
  });

  _appLinks.uriLinkStream.listen((uri) {
    print('🔗 Stream: $uri');
    if (uri.scheme == 'waseed' && uri.host == 'frozen') {
      final type = uri.queryParameters['type'] ?? 'email';
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/frozen',
        (route) => false,
        arguments: {'type': type},
      );
    }
  });
}
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وصيد',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'IBMPlexSansArabic',
      ),
      navigatorKey: navigatorKey,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/onboard': (context) => const OnboardingScreen(),
        '/services': (context) => const ServicesScreen(),
        '/content-scan': (context) => const ContentScanScreen(),
        '/dashboard': (context) => const ProtectedRoute(child: MainDashboard()),
        '/contacts': (context) =>
            const ProtectedRoute(child: ContactsListScreen()),
        '/add-contact': (context) =>
            const ProtectedRoute(child: AddContactScreen()),
        '/chats': (context) => const ProtectedRoute(child: ChatListScreen()),
        '/account': (context) =>
            const ProtectedRoute(child: AccountManagementScreen()),
        '/image-scanner': (context) => const ImageScannerScreen(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/password_generator': (context) => const PasswordGeneratorScreen(),
        '/frozen': (context) => const FrozenAccountScreen(),
        '/forgot-password': (context) => const ResetPasswordScreen(),
        '/breach-lookup' : (context) => BreachLookup(),

      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final AuthGuard _authGuard = AuthGuard();
  final WifiSecurityService _wifiService = WifiSecurityService();

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
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
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
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
  if (pendingDeepLinkRoute != null) {
    final route = pendingDeepLinkRoute!;
    final args = pendingDeepLinkArgs;
    pendingDeepLinkRoute = null;
    pendingDeepLinkArgs = null;
    Navigator.of(context).pushReplacementNamed(route, arguments: args);
    return;
  }

    try {
      print('Checking app state...');

      // 1. فحص إذا للتو تم logout
      final justLoggedOut = await BiometricService.getJustLoggedOut();
      print('Just logged out? $justLoggedOut');
      final isAuth = await _authGuard.isAuthenticated();
      if (!isAuth) {
        await BiometricService.setJustLoggedOut(false);
        Navigator.of(context).pushReplacementNamed('/onboard');
        return;
      }

      // 2. فحص إذا مسجل دخول
      print('Is authenticated? $isAuth');

      if (isAuth) {
        BiometricService.setJustLoggedOut(false);
        // تهيئة التشفير
        await _initializeEncryption();

        // تهيئة MessagingService (Socket + Listeners)
        await _initializeMessaging();
        //   WiFi Security Service
        await _initializeWifiSecurity();
        //  فحص الشبكة مرة واحدة فقط
        await _checkWifiOnce();

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
        print('MessagingService initialized successfully');
      } else {
        print('MessagingService initialization failed');
        // لا نوقف التطبيق - يمكن إعادة المحاولة لاحقاً
      }
    } catch (e) {
      print('❌ Error initializing MessagingService: $e');
      // لا نوقف التطبيق
    }
  }

  Future<void> clearOldKeys() async {
    final storage = FlutterSecureStorage();


    // حذف جميع المفاتيح
    final allKeys = await storage.readAll();

    for (var key in allKeys.keys) {
      if (key.contains('identity_key') ||
          key.contains('registration_id') ||
          key.contains('prekey_') ||
          key.contains('signed_prekey_') ||
          key.contains('session_') ||
          key.contains('peer_identity')) {
        await storage.delete(key: key);
        print('🗑️ Deleted: $key');
      }
    }

  }

  /// تهيئة التشفير للمستخدم المسجل دخول
  Future<void> _initializeEncryption() async {
    try {
      print('🔐 جاري تهيئة التشفير...');

      // 1. جلب userId أولاً
      final storage = const FlutterSecureStorage();
      final userDataStr = await storage.read(key: 'user_data');

      if (userDataStr == null) {
        print('❌ لا توجد بيانات مستخدم');
        return;
      }

      final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
      final userId = userData['id'] as String;

      print('👤 User ID: $userId');
      final userEmail = userData['email'] as String;
      print('user email: $userEmail');

      // 2. تهيئة SignalProtocolManager
      final signalManager = SignalProtocolManager();
      await signalManager.initialize(userId: userId);

      // 3. الفحص باستخدام userId
      final userIdentityKey = await storage.read(key: '${userId}_identity_key');

      if (userIdentityKey != null) {
        print('Kesy exist $userId');
        await signalManager.checkAndRefreshPreKeys();
        await signalManager.ensureSignedPreKeyRotation(userId);
        print(await signalManager.checkKeysStatus());
      } else {
        await signalManager.generateAndUploadKeys();
      }
    } catch (e) {
      print('❌ خطأ في تهيئة التشفير: $e');
    }
  }

  /// تهيئة خدمة أمان WiFi
  Future<void> _initializeWifiSecurity() async {
    try {
      print('📡 [3/3] Initializing WiFi Security Service...');
      final success = await _wifiService.initialize();
      if (success) {
        print('WiFi Security Service initialized successfully');
      }
    } catch (e) {
      print('WiFi Security Service initialization failed: $e');
    }
  }

  /// فحص الشبكة مرة واحدة فقط عند فتح التطبيق
  Future<void> _checkWifiOnce() async {
    try {
      print('Checking WiFi security once...');

      final result = await _wifiService.checkNetworkOnAppLaunch();

      switch (result.type) {
        case WifiCheckResultType.needsPermission:
          print('Need to request permissions');
          // سيتم طلبها من Dashboard
          break;

        case WifiCheckResultType.permissionDenied:
          print('⚠️ Permissions denied');
          // سيتم عرض dialog من Dashboard
          break;
        case WifiCheckResultType.userDeclined:
          print('ℹ️ User declined WiFi check permanently - respecting choice');
          // المستخدم رفض نهائياً - لا نزعجه
          break;

        case WifiCheckResultType.success:
          if (result.status != null && !result.status!.isSecure) {
            print('Insecure network detected: ${result.status!.ssid}');
            // سيتم عرض التحذير من Dashboard
          } else if (result.status != null) {
            print('Secure network: ${result.status!.ssid}');
          }
          break;

        case WifiCheckResultType.notConnected:
          print('Not connected to WiFi');
          break;

        case WifiCheckResultType.alreadyChecked:
          print('Already checked in this session');
          break;

        case WifiCheckResultType.error:
          print('Error: ${result.errorMessage}');
          break;
      }
    } catch (e) {
      print('Error checking WiFi: $e');
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
