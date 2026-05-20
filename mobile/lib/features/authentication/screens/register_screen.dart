import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/custom-text-field.dart';
import '../../../services/api_services.dart';
import 'verify-email.dart';
import 'verify_phone_number.dart';
import 'login_screen.dart';
import '../../dashboard/screens/main_dashboard.dart';
import '../../../services/crypto/signal_protocol_manager.dart';
import '../widgets/MessageDialog.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../services/socket_service.dart';
import 'package:phone_text_field/phone_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _passwordValue = '';
  bool _passwordFocused = false;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // real time check for password
  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() => _passwordValue = _passwordController.text);
    });
  }

  final menaCountries = [
    {'name': 'السعودية', 'code': 'SA', 'dial_code': '+966', 'flag': '🇸🇦'},
    {'name': 'مصر', 'code': 'EG', 'dial_code': '+20', 'flag': '🇪🇬'},
    {'name': 'الإمارات', 'code': 'AE', 'dial_code': '+971', 'flag': '🇦🇪'},
    {'name': 'الأردن', 'code': 'JO', 'dial_code': '+962', 'flag': '🇯🇴'},
    {'name': 'الكويت', 'code': 'KW', 'dial_code': '+965', 'flag': '🇰🇼'},
    {'name': 'البحرين', 'code': 'BH', 'dial_code': '+973', 'flag': '🇧🇭'},
    {'name': 'قطر', 'code': 'QA', 'dial_code': '+974', 'flag': '🇶🇦'},
    {'name': 'عُمان', 'code': 'OM', 'dial_code': '+968', 'flag': '🇴🇲'},
    {'name': 'العراق', 'code': 'IQ', 'dial_code': '+964', 'flag': '🇮🇶'},
    {'name': 'سوريا', 'code': 'SY', 'dial_code': '+963', 'flag': '🇸🇾'},
    {'name': 'لبنان', 'code': 'LB', 'dial_code': '+961', 'flag': '🇱🇧'},
    {'name': 'فلسطين', 'code': 'PS', 'dial_code': '+970', 'flag': '🇵🇸'},
    {'name': 'تونس', 'code': 'TN', 'dial_code': '+216', 'flag': '🇹🇳'},
    {'name': 'الجزائر', 'code': 'DZ', 'dial_code': '+213', 'flag': '🇩🇿'},
    {'name': 'المغرب', 'code': 'MA', 'dial_code': '+212', 'flag': '🇲🇦'},
    {'name': 'ليبيا', 'code': 'LY', 'dial_code': '+218', 'flag': '🇱🇾'},
    {'name': 'السودان', 'code': 'SD', 'dial_code': '+249', 'flag': '🇸🇩'},
    {'name': 'جيبوتي', 'code': 'DJ', 'dial_code': '+253', 'flag': '🇩🇯'},
    {'name': 'الصومال', 'code': 'SO', 'dial_code': '+252', 'flag': '🇸🇴'},
    {'name': 'اليمن', 'code': 'YE', 'dial_code': '+967', 'flag': '🇾🇪'},
    {'name': 'إيران', 'code': 'IR', 'dial_code': '+98', 'flag': '🇮🇷'},
    {'name': 'تركيا', 'code': 'TR', 'dial_code': '+90', 'flag': '🇹🇷'},
  ];

  // معالجة التسجيل
  Future<void> _handleRegister() async {
    bool isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    setState(() => _isLoading = true);

    final result = await _apiService.register(
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      //  newRegistrationId
      final String? newRegistrationId = result['newRegistrationId'];
      if (newRegistrationId == null) {
        _showMessage('حدث خطأ: لم يتم استلام معرف التسجيل', isError: true);
        return;
      }

      // الانتقال لصفحة التحقق من الإيميل
      final emailVerified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyEmailScreen(
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            fullName: _fullNameController.text.trim(),
            newRegistrationId: newRegistrationId,
          ),
        ),
      );

      if (emailVerified == true && mounted) {
        _proceedToPhoneVerification();
      }
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', isError: true);
    }
  }

  // عرض رسالة
  void _showMessage(String message, {required bool isError}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MessageDialog(message: message, isError: isError);
      },
    );
  }

  // توليد ورفع المفاتيح
  Future<void> _generateAndUploadKeys() async {
    try {
      FlutterSecureStorage storage = const FlutterSecureStorage();
      final userData = await storage.read(key: 'user_data');
      final accessToken = await storage.read(key: 'access_token');
      final userId = jsonDecode(userData!)['id'].toString();

      final signalManager = SignalProtocolManager();
      await signalManager.initialize();
      final keysUploaded = await signalManager.generateAndUploadKeys();

      if (!keysUploaded) {
        _showMessage('تحذير: فشل إعداد مفاتيح تشفير الرسائل', isError: true);
      }
    } catch (e) {
      print('خطأ في توليد/رفع المفاتيح: $e');
    }
  }

  // عرض خيارات التحقق من الجوال
  void _showPhoneVerificationOptions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'تحقق من رقم الجوال',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.w600,
              ),
            ),
            content: const Text(
              'لإكمال التسجيل، يجب التحقق من رقم جوالك',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _proceedToPhoneVerification();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D1B69),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'متابعة',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // الانتقال لتحقق الجوال
  Future<void> _proceedToPhoneVerification() async {
    setState(() => _isLoading = true);

    final sendSmsResult = await _apiService.sendPhoneVerification(
      _phoneController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (sendSmsResult['success']) {
      final phoneVerified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyPhoneScreen(
            phone: _phoneController.text.trim(),
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حدث خطأ في إرسال رمز التحقق من الخادم. يمكنك التحقق لاحقاً من الإعدادات',
            style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );

      _skipPhoneVerification();

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
        (route) => false,
      );
    }
  }

  // تخطي تحقق الجوال
  Future<void> _skipPhoneVerification() async {
    setState(() => _isLoading = true);

    final result = await _apiService.skipPhoneVerification(
      email: _emailController.text.trim(),
    );

    if (!mounted) return;

    final storage = const FlutterSecureStorage();

    if (result['success']) {
      final token = result['token'];
      final user = result['user'];

      if (token != null) {
        await storage.write(key: 'access_token', value: token);
      }
      if (user != null) {
        await storage.write(key: 'user_data', value: jsonEncode(user));
      }

      await _generateAndUploadKeys();
      await SocketService().connect();

      setState(() => _isLoading = false);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
        (route) => false,
      );
    } else {
      setState(() => _isLoading = false);
      _showMessage(result['message'], isError: true);
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
                      const SizedBox(height: 100),
                      const Text(
                        'إنشـاء حساب',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 31.44,
                          fontFamily: 'IBMPlexSansArabic',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomTextField(
                        controller: _fullNameController,
                        label: 'الاسم الكامل',
                        hint: 'رنا سالم',
                        icon: Icons.person,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال الاسم الكامل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _usernameController,
                        label: 'اسم المستخدم',
                        hint: 'ranaasalem1',
                        icon: Icons.person,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال اسم المستخدم';
                          }
                          if (value.length < 3) {
                            return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
                          }
                          if (value.contains(' ')) {
                            return 'اسم المستخدم لا يمكن أن يحتوي على فراغات';
                          }
                          final regex = RegExp(r'^[a-zA-Z0-9_]+$');
                          if (!regex.hasMatch(value)) {
                            return 'اسم المستخدم يجب أن يحتوي فقط على أحرف أو أرقام أو _';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
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
                            r'^[a-zA-Z0-9._]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          );
                          if (!emailRegex.hasMatch(email)) {
                            return 'الرجاء إدخال بريد إلكتروني صالح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      PhoneTextField(
                        locale: const Locale('ar'),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,

                          labelText: 'رقم الهاتف',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        searchFieldInputDecoration: const InputDecoration(
                          filled: true,

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          suffixIcon: Icon(Icons.search),
                          hintText: 'بحث عن بالاسم او الرمز',
                        ),
                        dialogTitle: 'اختر الدولة',
                        initialCountryCode: 'SA',
                        onChanged: (phoneNumber) {
                          debugPrint(
                            'رقم الهاتف: ${phoneNumber.completeNumber}',
                          );
                          _phoneController.text = phoneNumber.completeNumber;
                        },
                        invalidNumberMessage: "الرجاء إدخال رقم هاتف صالح",
                      ),

                      const SizedBox(height: 16),
                      Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus) setState(() => _passwordFocused = true);
                        },
                        child: CustomTextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          label: 'كلمة المرور',
                          hint: 'أدخل كلمة المرور',
                          icon: Icons.lock,
                          isPassword: true,
                          enabled: !_isLoading,
                          suffixIcon: IconButton(
                            icon: Icon(
                              !_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'الرجاء إدخال كلمة المرور';
                            if (value.length < 8)
                              return 'يجب أن تكون كلمة المرور 8 أحرف على الأقل';
                            if (!RegExp(r'[0-9]').hasMatch(value))
                              return 'يجب أن تحتوي على رقم';
                            if (!RegExp(
                              r'[!@#$%^&*(),.?":{}|<>]',
                            ).hasMatch(value))
                              return 'يجب أن تحتوي على رمز خاص';
                            if (!RegExp(r'[a-zA-Z]').hasMatch(value))
                              return 'يجب أن تحتوي على حرف إنجليزي';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_passwordFocused)
                        _PasswordRequirements(password: _passwordValue),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
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
                                'إنشـاء حسـاب',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'IBMPlexSansArabic',
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                        child: const Text(
                          'لديك حساب؟ تسجيل الدخول',
                          style: TextStyle(
                            fontSize: 15,
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

class _PasswordRequirements extends StatelessWidget {
  final String password;
  const _PasswordRequirements({required this.password});

  @override
  Widget build(BuildContext context) {
    final checks = [
      {'label': '8 أحرف على الأقل', 'met': password.length >= 8},
      {
        'label': 'رقم واحد على الأقل',
        'met': RegExp(r'[0-9]').hasMatch(password),
      },
      {
        'label': 'رمز خاص (!@#\$...)',
        'met': RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
      },
      {
        'label': 'حرف إنجليزي واحد على الأقل',
        'met': RegExp(r'[a-zA-Z]').hasMatch(password),
      },
    ];

    const purple = Color(0xFF2D1B69);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE8E0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'متطلبات كلمة المرور:',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.w600,
              color: purple,
            ),
          ),
          const SizedBox(height: 8),
          ...checks.map((c) {
            final met = c['met'] as bool;
            final isEmpty = password.isEmpty;
            final color = isEmpty
                ? Colors.grey.shade400
                : met
                ? purple
                : Colors.red.shade400;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    met && !isEmpty
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'IBMPlexSansArabic',
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
