// lib/services/api_services.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {


 
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';  // Android Emulator
    } else if (Platform.isIOS) {
      return 'http://localhost:3000/api';  // iOS Simulator
    } else {
      return 'http://localhost:3000/api';  // الباقي (Desktop/Web)
    }
  }

  
  final _storage = const FlutterSecureStorage();

  
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  //  البحث عن مستخدم (username أو phone)
  // ============================================
  Future<Map<String, dynamic>> searchContact(String searchQuery) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/search'),
        headers: headers,
        body: jsonEncode({'searchQuery': searchQuery}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // ====================
  // إرسال طلب صداقة
  // ====================
  Future<Map<String, dynamic>> sendContactRequest(String userId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/send-request'),
        headers: headers,
        body: jsonEncode({'userId': userId}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // ====================================
  // جلب الطلبات المعلقة (Notifications)
  // ===================================
  Future<Map<String, dynamic>> getPendingRequests() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/contacts/pending-requests'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // =======================
  //  قبول طلب صداقة
  // =======================
  Future<Map<String, dynamic>> acceptContactRequest(String requestId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/accept-request/$requestId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }
  // =====================
  // رفض طلب صداقة
  // ==================
  Future<Map<String, dynamic>> rejectContactRequest(String requestId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/reject-request/$requestId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // ============================================
  // جلب قائمة الأصدقاء
  // ============================================
  Future<Map<String, dynamic>> getContactsList() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/contacts/list'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // ============================================
  //  حذف صديق
  // ============================================
  Future<Map<String, dynamic>> deleteContact(String contactId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/contacts/$contactId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // ============================================
  // Authentication 
  // ============================================
  
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

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

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

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

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

  // ============================================
  // دوال المساعدة
  // ============================================
  
  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final userDataString = await _storage.read(key: 'user_data');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_data');
  }
}