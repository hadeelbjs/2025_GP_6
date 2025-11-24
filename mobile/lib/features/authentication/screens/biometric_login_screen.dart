import 'package:flutter/material.dart';
import '../../../services/biometric_service.dart';
import '../../../services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricLoginScreen extends StatefulWidget {
  final String userEmail;
  
  const BiometricLoginScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _promptBiometric();
  }

  Future<void> _promptBiometric() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _handleBiometricLogin();
  }

  Future<void> _handleBiometricLogin() async {
    final success = await BiometricService.authenticateWithBiometrics(
      reason: 'تسجيل الدخول إلى حسابك',
    );

    if (!success) {
      _showLoginOptions();
      return;
    }

    setState(() => _isLoading = true);
    
    final result = await _apiService.biometricLogin(widget.userEmail);
    
    setState(() => _isLoading = false);

    if (result['success']) {
      // حفظ وقت تسجيل الدخول
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_login_time', DateTime.now().toIso8601String());
      
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      _showMessage(result['message'] ?? 'فشل تسجيل الدخول', false);
    }
  }

  void _showLoginOptions() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الدخول'),
          content: const Text('هل تريد المحاولة مرة أخرى أو الدخول بالطريقة العادية؟'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('طريقة عادية'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleBiometricLogin();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String msg, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint, size: 100, color: Color(0xFF2D1B69)),
            SizedBox(height: 20),
            Text('المصادقة الحيوية', style: TextStyle(fontSize: 24)),
            SizedBox(height: 40),
            if (_isLoading) CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}