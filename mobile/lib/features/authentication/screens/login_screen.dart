import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/custom-text-field.dart';
import '../../../services/api_services.dart';
import '../../../services/crypto/signal_protocol_manager.dart';
import 'verify-email.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'register_screen.dart';
import 'reset_password.dart';
import '../../../services/biometric_service.dart';
import '../../dashboard/screens/main_dashboard.dart';
import '../../../services/messaging_service.dart'; // ✅ إضافة

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================
  // معالجة تسجيل الدخول العادي
  // ============================================
  Future<void> _handleLogin() async {
    bool isValid = _formKey.currentState!.validate();
    
    if (!isValid) {
      return;
    }
    
    setState(() => _isLoading = true);

    final result = await _apiService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    
    setState(() => _isLoading = false);
    if (!mounted) return; 
    
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رمز التحقق إلى بريدك الإلكتروني'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: _emailController.text.trim(),
            is2FA: true, 
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'حدث خطأ'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _initializeMessagingAfterLogin() async {
    try {
      print('🔌 [LOGIN] Initializing MessagingService...');
      
      // تهيئة Signal Protocol
      await SignalProtocolManager().initialize();
      print('[LOGIN] Signal Protocol initialized');
      
      // تهيئة MessagingService (Socket)
      final success = await MessagingService().initialize();
      
      if (success) {
        print('[LOGIN] MessagingService initialized successfully');
      } else {
        print('[LOGIN] MessagingService initialization failed');
      }
      
    } catch (e) {
      print('[LOGIN] Error initializing MessagingService: $e');
    }
  }

  // ============================================
  // معالجة الدخول بالبايومتركس
  // ============================================
  Future<void> _handleBiometricLogin() async {
    // 1 - الحصول على إيميل المستخدم المحفوظ
    final biometricUser = await BiometricService.getBiometricUser();
    
    if (biometricUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على بيانات البصمة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2 - طلب البصمة
    final authenticated = await BiometricService.authenticateWithBiometrics(
      reason: 'تسجيل الدخول إلى حسابك',
    );

    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل التحقق من البصمة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3 - تسجيل الدخول
    setState(() => _isLoading = true);
    
    final result = await _apiService.biometricLogin(biometricUser);
    
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      // توليد/تحديث المفاتيح
      await _initializeEncryption();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الدخول بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'حدث خطأ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // تهيئة التشفير بعد تسجيل الدخول
  Future<void> _initializeEncryption() async {
    try {
      print('جاري التحقق من مفاتيح التشفير...');
      
      final signalManager = SignalProtocolManager();
      await signalManager.initialize();
      
      // التحقق من وجود المفاتيح
      const storage = FlutterSecureStorage();
      final identityKey = await storage.read(key: 'identity_key');
      final registrationId = await storage.read(key: 'registration_id');
      final signedPreKeyId = await storage.read(key: 'signed_pre_key_id');
      final signedPreKey = await storage.read(key: 'signed_pre_key');
      final signedPreKeySignature = await storage.read(key: 'signed_pre_key_signature');
      final preKeys = await storage.read(key: 'pre_keys');
      final preKeyId = await storage.read(key: 'pre_key_id');

      if (identityKey == null || registrationId == null ||
          signedPreKeyId == null || signedPreKey == null || signedPreKeySignature == null ||
          preKeys == null || preKeyId == null) {
        print(' لا توجد مفاتيح - جاري التوليد...');
        final success = await signalManager.generateAndUploadKeys();
        
        if (success) {
          print(' تم توليد ورفع المفاتيح بنجاح');
        } else {
          print(' فشل توليد/رفع المفاتيح');
        }
      } else {
        print(' المفاتيح موجودة بالفعل');
        // التحقق من عدد PreKeys المتبقية
        await signalManager.checkAndRefreshPreKeys();
      }
    } catch (e) {
      print(' خطأ في تهيئة التشفير: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 252, 249, 249),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: SvgPicture.asset(
              'assets/images/reg-bg-shapes.svg',
              width: 400.96,
              height: 180,
            ),
          ),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 130),
                      const Text(
                        ' مرحـبًا بـعودتك!',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'IBMPlexSansArabic',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const Text(
                        'تسجيل الدخول',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 31.44,
                          fontFamily: 'IBMPlexSansArabic',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // البريد الإلكتروني
                      CustomTextField(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        hint: 'ranasalem@gmail.com',
                        icon: Icons.email,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال البريد الإلكتروني';
                          }
                          final email = value.trim();
                          final emailRegex = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
                          );
                          if (!emailRegex.hasMatch(email)) {
                            return 'الرجاء إدخال بريد إلكتروني صالح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // كلمة المرور
                      CustomTextField(
                        controller: _passwordController,
                        label: 'كلمة المرور',
                        hint: 'أدخل كلمة المرور',
                        icon: Icons.lock,
                        isPassword: true,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال كلمة المرور';
                          }
                          if (value.length < 6) {
                            return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.pushReplacement(
                                    context, 
                                    MaterialPageRoute(builder: (_) => const ResetPasswordScreen())
                                  );
                                },
                          child: const Text(
                            'نسيت كلمة المرور؟',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // زر التسجيل
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          backgroundColor: const Color(0xFF2D1B69),
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'تسجيل الدخول',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'IBMPlexSansArabic',
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // زر البايومتركس
                      FutureBuilder<bool>(
                        future: BiometricService.isBiometricEnabled(),
                        builder: (context, snapshot) {
                          final isEnabled = snapshot.data ?? false;
                          
                          if (!isEnabled) return const SizedBox.shrink();
                          
                          return Column(
                            children: [
                              const SizedBox(height: 20),
                              
                              // خط فاصل
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'أو',
                                      style: TextStyle(
                                        fontFamily: 'IBMPlexSansArabic',
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // زر البايومتركس
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF2D1B69),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isLoading ? null : _handleBiometricLogin,
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.fingerprint,
                                            size: 26,
                                            color: Color(0xFF2D1B69),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'الدخول بالبصمة',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontFamily: 'IBMPlexSansArabic',
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2D1B69),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      
                      // زر إنشاء حساب جديد
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context, 
                                  MaterialPageRoute(builder: (_) => const RegisterScreen())
                                );
                              },
                        child: const Text(
                          'لا يوجد لديك حساب؟ إنشاء حساب',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'IBMPlexSansArabic',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}