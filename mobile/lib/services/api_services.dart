// lib/services/api_services.dart

import 'dart:convert';
import 'dart:io' show Platform; 
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';
import 'package:flutter/foundation.dart';



class ApiService {
  // ============================
  // Base URL بحسب المنصة
  // ============================
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Android Emulator -> يصل للـ localhost على المضيف عبر 10.0.2.2
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      // iOS Simulator -> يتصل مباشرة على نفس الجهاز
      return 'http://localhost:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }
  
  final _storage = const FlutterSecureStorage();

  //  التسجيل (يرسل رمز التحقق للإيميل)
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'fullName': fullName,
          'username': username,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  //  تأكيد البريد الإلكتروني (بدون حفظ توكن)
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-email'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      // لا نحفظ التوكن هنا - سيتم بعد التحقق من الجوال أو التخطي
      return data;
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  //  إرسال رمز التحقق للجوال عبر SMS (Twilio)
  Future<Map<String, dynamic>> sendPhoneVerification(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-phone-verification'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'phone': phone}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  //  تأكيد رقم الهاتف برمز التحقق (يحفظ التوكن)
  Future<Map<String, dynamic>> verifyPhone({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-phone'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await _storage.write(key: 'access_token', value: data['token']);
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // إعادة إرسال رمز التحقق بالإيميل
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/resend-verification-email'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // إعادة إرسال رمز التحقق برقم الجوال
  Future<Map<String, dynamic>> resendVerificationPhone(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/resend-verification-phone'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'phone': phone}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // تسجيل الدخول (يرسل رمز 2FA دائماً)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      // تسجيل الدخول يرسل دائماً رمز 2FA
      // لا نحفظ التوكن هنا - سيتم بعد التحقق من رمز 2FA

      return data;
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

// إعادة إرسال رمز 2FA
Future<Map<String, dynamic>> resend2FACode(String email) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/resend-2fa'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 10));

    return jsonDecode(response.body);
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل الاتصال بالسيرفر: $e'
    };
  }
}

// تخطي التحقق من الجوال (يرسل توكن)
Future<Map<String, dynamic>> skipPhoneVerification({
  required String email,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/skip-phone-verification'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success']) {
      await _storage.write(key: 'access_token', value: data['token']);
      await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
    }

    return data;
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل الاتصال بالسيرفر: $e'
    };
  }
}
  //  التحقق من رمز 2FA
  Future<Map<String, dynamic>> verify2FA({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-2fa'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await _storage.write(key: 'access_token', value: data['accessToken']);
        await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  //  طلب إعادة تعيين كلمة المرور (إرسال رمز)
  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // التحقق من رمز إعادة التعيين
  Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-reset-code'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // إعادة تعيين كلمة المرور
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // الحصول على التوكن
  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  // الحصول على بيانات المستخدم
  Future<Map<String, dynamic>?> getUserData() async {
    final userDataString = await _storage.read(key: 'user_data');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  // التحقق من تسجيل الدخول
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

Future<void> logout({bool keepBiometric = true}) async {
  // حذف بيانات الجلسة دائماً
  await _storage.delete(key: 'access_token');
  await _storage.delete(key: 'refresh_token');
  await _storage.delete(key: 'user_data');
  
  // حذف البصمة فقط إذا طُلب ذلك
  if (!keepBiometric) {
    await BiometricService.disableBiometric();
  }
}

  // ============================================
// دوال البصمة الجديدة
// ============================================

// دالة للتحقق من إمكانية استخدام البصمة
Future<bool> canUseBiometric() async {
  try {
    final isEnabled = await BiometricService.isBiometricEnabled();
    final biometricUser = await BiometricService.getBiometricUser();
    final userData = await getUserData();
    
    return isEnabled && 
           biometricUser != null && 
           userData != null && 
           biometricUser == userData['email'];
  } catch (e) {
    return false;
  }
}

// دالة تفعيل البصمة
Future<bool> enableBiometric() async {
  try {
    final userData = await getUserData();
    if (userData == null) return false;
    
    return await BiometricService.enableBiometric(userData['email']);
  } catch (e) {
debugPrint('خطأ في تفعيل البصمة: $e');
    return false;
  }
}

// دالة منفصلة لحذف البصمة
Future<void> disableBiometric() async {
  await BiometricService.disableBiometric();
}

}