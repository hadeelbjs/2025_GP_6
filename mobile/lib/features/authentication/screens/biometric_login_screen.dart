import 'package:flutter/material.dart';
import '../../../services/api_services.dart';
import '../../../services/biometric_service.dart';
import 'login_screen.dart';

class BiometricLoginScreen extends StatefulWidget {
  final String userEmail;
  
  const BiometricLoginScreen({
    super.key, 
    required this.userEmail,
  });

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  bool _isAuthenticating = false;
  int _attemptCount = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticateWithBiometric();
    });
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithBiometric() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
      _attemptCount++;
    });

    try {
      final success = await BiometricService.authenticateWithBiometrics(
        reason: 'ضع بصمتك للدخول إلى وصيد',
      );

      if (!mounted) return;

      if (success) {
        await _handleBiometricSuccess();
      } else {
        _handleBiometricFailure();
      }
    } catch (e) {
      if (mounted) {
        _handleBiometricError(e.toString());
      }
    }
    
    if (mounted) {
      setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _handleBiometricSuccess() async {
    _showMessage('مرحباً بعودتك!', true);
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  void _handleBiometricFailure() {
    if (_attemptCount >= 3) {
      _showMessage('فشل في التحقق، الرجاء استخدام كلمة المرور', false);
      _navigateToLogin();
    } else {
      _showRetryDialog();
    }
  }

  void _handleBiometricError(String error) {
    _showMessage('خطأ في البصمة، الرجاء المحاولة مرة أخرى', false);
    _showRetryDialog();
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'فشل في التحقق',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            _attemptCount >= 3 
                ? 'تم تجاوز الحد الأقصى للمحاولات.\nهل تريد استخدام كلمة المرور؟'
                : 'فشل في التحقق من البصمة.\nهل تريد المحاولة مرة أخرى؟',
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
          actions: [
            if (_attemptCount < 3) ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToLogin();
                },
                child: const Text(
                  'كلمة المرور',
                  style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _authenticateWithBiometric();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D1B69),
                ),
                child: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    color: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToLogin();
                },
                child: const Text(
                  'موافق',
                  style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showMessage(String message, bool isSuccess) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          textAlign: TextAlign.center,
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D1B69),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _navigateToLogin,
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'تسجيل الدخول السريع',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.fingerprint,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'مرحباً بعودتك',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.userEmail,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isAuthenticating 
                          ? 'جاري التحقق...'
                          : 'ضع بصمتك للدخول',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (_isAuthenticating)
                      const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _authenticateWithBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2D1B69),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: TextButton.icon(
                  onPressed: _navigateToLogin,
                  icon: Icon(
                    Icons.lock_outline,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  label: Text(
                    'استخدام كلمة المرور بدلاً',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      fontFamily: 'IBMPlexSansArabic',
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}