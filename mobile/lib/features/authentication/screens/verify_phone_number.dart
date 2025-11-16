import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waseed/services/crypto/signal_protocol_manager.dart';
import 'dart:async';
import '../../../services/api_services.dart';

import '../../dashboard/screens/main_dashboard.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _apiService = ApiService();

class VerifyPhoneScreen extends StatefulWidget {
  final String phone;
  final String fullName;
  final String email;

  const VerifyPhoneScreen({
    super.key,
    required this.phone,
    required this.fullName,
    required this.email,
  });

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
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

  // بدء مؤقت إعادة الإرسال
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
  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();

    if (code.length != 6) {
      _showMessage('الرجاء إدخال الرمز كاملاً', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.verifyPhone(
      phone: widget.phone,
      code: code,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
  _showMessage('تم تأكيد رقم الجوال بنجاح!', isError: false);
  
  await Future.delayed(const Duration(seconds: 1));
  if (!mounted) return;
  
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const MainDashboard()), 
  );

 
} else {
      _showMessage(result['message'] ?? 'الرمز غير صحيح', isError: true);
      // مسح الحقول
      for (var controller in _codeControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  // إعادة إرسال الرمز
  Future<void> _resendCode() async {
    if (_resendTimer > 0) return;

    setState(() => _isResending = true);

    final result = await _apiService.resendVerificationPhone(widget.phone);

    setState(() => _isResending = false);

    if (!mounted) return;

    if (result['success']) {
      _showMessage('تم إرسال الرمز مرة أخرى', isError: false);
      _startResendTimer();
    } else {
      _showMessage(result['message'] ?? 'فشل إعادة الإرسال', isError: true);
    }
  }

  // عرض رسالة
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
                isError ? 'خطأ' : 'نجاح',
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
      backgroundColor: isError ? const Color.fromARGB(255, 211, 47, 47) : Colors.green.shade700,
      duration: const Duration(seconds: 3),
    ),
  );
}

  //  الواجهة

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
              
              // أيقونة
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
              
              // العنوان
              const Text(
                'تأكيد رقم الجوال',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 16),
              
              // الوصف
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
                widget.phone,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 40),
              
              // حقول الرمز
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
                        
                        // التحقق التلقائي عند الانتهاء
                        if (index == 5 && value.isNotEmpty) {
                          _verifyCode();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              
              // زر التحقق
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
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
              const SizedBox(height: 16),

            
              const SizedBox(height: 20),

              // إعادة إرسال الرمز
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