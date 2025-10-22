import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../services/api_services.dart';
import '../../../services/crypto/signal_protocol_manager.dart';
import '../../dashboard/screens/main_dashboard.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String? fullName;
  final String? phone;
  final bool is2FA;
  final String? newRegistrationId;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.fullName,
    this.phone,
    this.is2FA = false,
    this.newRegistrationId,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _apiService = ApiService();
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  final _previousValues = List.generate(6, (_) => '');
  
  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _setupControllerListeners();
  }

  void _setupControllerListeners() {
    for (int i = 0; i < 6; i++) {
      _codeControllers[i].addListener(() {
        final currentValue = _codeControllers[i].text;
        final previousValue = _previousValues[i];
        
        if (currentValue.isEmpty && previousValue.isNotEmpty) {
          if (i > 0) {
            Future.delayed(const Duration(milliseconds: 50), () {
              _focusNodes[i - 1].requestFocus();
            });
          }
        }
        
        _previousValues[i] = currentValue;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  // التحقق من الرمز
  Future<void> _verifyCodeAndReturn() async {
    final code = _codeControllers.map((c) => c.text).join();

    if (code.length != 6) {
      _showMessage('الرجاء إدخال الرمز كاملاً', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = widget.is2FA
          ? await _apiService.verify2FA(
              email: widget.email,
              code: code,
            )
          : await _apiService.verifyEmailAndCreate(code: code, newRegistrationId: widget.newRegistrationId!,);


      if (!mounted) return;

      if (result['success']) {
        _showMessage(
          widget.is2FA 
            ? 'تم تسجيل الدخول بنجاح!' 
            : 'تم تأكيد البريد الإلكتروني بنجاح!',
          isError: false
        );
        
        // ✅ إذا كان 2FA (تسجيل دخول)، نولد المفاتيح
        if (widget.is2FA) {
          await _initializeEncryption();
          
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainDashboard()),
            (route) => false,
          );
        } else {
          // ✅ إذا كان تسجيل جديد (verify email)، نرجع للشاشة السابقة
          // المفاتيح ستتولد في verify_phone أو skip_phone
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          
          Navigator.pop(context, true);
        }
      } else {
        setState(() => _isLoading = false);
        _showMessage(result['message'] ?? 'الرمز غير صحيح', isError: true);
        _clearAllFields();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showMessage('حدث خطأ في الاتصال. يرجى المحاولة مرة أخرى', isError: true);
    }
  }

  // تهيئة التشفير (فقط عند 2FA - تسجيل دخول)
  Future<void> _initializeEncryption() async {
    try {
      print('🔐 جاري التحقق من مفاتيح التشفير...');
      
      final signalManager = SignalProtocolManager();
      await signalManager.initialize();
      
      // التحقق من وجود المفاتيح
      final storage = const FlutterSecureStorage();
      final identityKey = await storage.read(key: 'identity_key');
      
      if (identityKey == null) {
        print('🔑 لا توجد مفاتيح - جاري التوليد...');
        final success = await signalManager.generateAndUploadKeys();
        
        if (success) {
          print('✅ تم توليد ورفع المفاتيح بنجاح');
        } else {
          print('⚠️ فشل توليد/رفع المفاتيح');
        }
      } else {
        print('✅ المفاتيح موجودة بالفعل');
        // التحقق من عدد PreKeys المتبقية
        await signalManager.checkAndRefreshPreKeys();
      }
    } catch (e) {
      print('❌ خطأ في تهيئة التشفير: $e');
    }
  }

  Future<void> _resendCode() async {
    if (_resendTimer > 0) return;

    setState(() => _isResending = true);

    try {
      final result = widget.is2FA
          ? await _apiService.resend2FACode(widget.email) 
          : await _apiService.resendRegistrationCode(newRegistrationId: widget.newRegistrationId!);
;

      setState(() => _isResending = false);

      if (!mounted) return;

      if (result['success']) {
        _showMessage('تم إرسال الرمز مرة أخرى', isError: false);
        _startResendTimer();
      } else {
        _showMessage(result['message'] ?? 'فشل إعادة الإرسال', isError: true);
      }
    } catch (e) {
      setState(() => _isResending = false);
      if (!mounted) return;
      _showMessage('حدث خطأ في الاتصال. يرجى المحاولة مرة أخرى', isError: true);
    }
  }

  void _clearAllFields() {
    for (var controller in _codeControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isError ? 'خطأ' : 'نجاح',
                    style: const TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 252, 249, 249),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D1B69)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1B69).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    size: 50,
                    color: Color(0xFF2D1B69),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              Text(
                widget.is2FA ? 'التحقق بخطوتين' : 'تأكيد البريد الإلكتروني',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'تم إرسال رمز التحقق المكون من 6 أرقام إلى',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'IBMPlexSansArabic',
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 40),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                textDirection: TextDirection.ltr,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 55,
                    child: Stack(
                      children: [
                        TextField(
                          controller: _codeControllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          enabled: !_isLoading,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.transparent,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: false,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2D1B69),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2D1B69),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2D1B69),
                                width: 2,
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          onChanged: (value) {
                            setState(() {});
                            
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isNotEmpty && index == 5) {
                              _verifyCodeAndReturn();
                            }
                          },
                        ),
                        IgnorePointer(
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              _codeControllers[index].text,
                              style: const TextStyle(
                                fontSize: 24,
                                color: Color(0xFF2D1B69),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyCodeAndReturn,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  backgroundColor: const Color(0xFF2D1B69),
                  disabledBackgroundColor: const Color(0xFF2D1B69).withOpacity(0.5),
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
                        'تأكيد',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'IBMPlexSansArabic',
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _resendTimer == 0 && !_isResending
                        ? _resendCode
                        : null,
                    child: _isResending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2D1B69),
                            ),
                          )
                        : Text(
                            _resendTimer > 0
                                ? 'إعادة الإرسال بعد $_resendTimer ثانية'
                                : 'إعادة إرسال الرمز',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.w500,
                              color: _resendTimer == 0
                                  ? const Color(0xFF2D1B69)
                                  : Colors.grey,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}