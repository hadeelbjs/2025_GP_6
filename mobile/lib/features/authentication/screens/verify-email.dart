import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../services/api_services.dart';
import 'home_screen.dart';
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String? fullName; // اختياري
  final String? phone;    // اختياري
  final bool is2FA;       // لتحديد إذا كان 2FA أو تسجيل حساب جديد

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.fullName,
    this.phone,
    this.is2FA = false, // القيمة الافتراضية false (تسجيل عادي)
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _apiService = ApiService();
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
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

  // التحقق من الإيميل وإرجاع النتيجة للصفحة السابقة
  Future<void> _verifyCodeAndReturn() async {
  final code = _codeControllers.map((c) => c.text).join();

  if (code.length != 6) {
    _showMessage('الرجاء إدخال الرمز كاملاً', isError: true);
    return;
  }

  setState(() => _isLoading = true);

  // إذا كان 2FA استخدم verify2FA، وإلا استخدم verifyEmail
  final result = widget.is2FA
      ? await _apiService.verify2FA(
          email: widget.email,
          code: code,
        )
      : await _apiService.verifyEmail(
          email: widget.email,
          code: code,
        );

  setState(() => _isLoading = false);

  if (!mounted) return;

  if (result['success']) {
    _showMessage(
      widget.is2FA 
        ? 'تم تسجيل الدخول بنجاح!' 
        : 'تم تأكيد البريد الإلكتروني بنجاح!',
      isError: false
    );
    
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    if (widget.is2FA) {
      // إذا كان 2FA، اذهب للصفحة الرئيسية
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      // إذا كان تسجيل عادي، ارجع للصفحة السابقة
      Navigator.pop(context, true);
    }
  } else {
    _showMessage(result['message'] ?? 'الرمز غير صحيح', isError: true);
    for (var controller in _codeControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }
}

  Future<void> _resendCode() async {
  if (_resendTimer > 0) return;

  setState(() => _isResending = true);

  // إذا كان 2FA، أعد إرسال كود 2FA، وإلا أعد إرسال كود تحقق الإيميل
  final result = widget.is2FA
      ? await _apiService.resend2FACode(widget.email) 
      : await _apiService.resendVerificationEmail(widget.email);

  setState(() => _isResending = false);

  if (!mounted) return;

  if (result['success']) {
    _showMessage('تم إرسال الرمز مرة أخرى', isError: false);
    _startResendTimer();
  } else {
    _showMessage(result['message'] ?? 'فشل إعادة الإرسال', isError: true);
  }
}

  void _showMessage(String message, {required bool isError}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                isError ? 'خطأ' : 'نجح',
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
        ],
      ),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      duration: const Duration(seconds: 3),
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
              
              Container(
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
              const SizedBox(height: 30),
              
              const Text(
                'تأكيد البريد الإلكتروني',
                textAlign: TextAlign.center,
                style: TextStyle(
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
                    child: TextField(
                      controller: _codeControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      enabled: !_isLoading,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        
                        if (index == 5 && value.isNotEmpty) {
                          _verifyCodeAndReturn();
                        }
                      },
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _resendTimer > 0
                                ? 'إعادة الإرسال بعد $_resendTimer ثانية'
                                : 'إعادة إرسال الرمز',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'IBMPlexSansArabic',
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