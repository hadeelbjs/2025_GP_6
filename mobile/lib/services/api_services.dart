import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      return 'http://localhost:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  final _storage = const FlutterSecureStorage();
  bool _isRefreshing = false;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  //  دالة معالجة Response مع Auto Token Refresh
  // ============================================
  Future<Map<String, dynamic>> _handleAuthenticatedRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();
      final data = jsonDecode(response.body);

      // التحقق من انتهاء صلاحية التوكن
      if (response.statusCode == 401 && 
          (data['code'] == 'TOKEN_EXPIRED' || 
           data['code'] == 'INVALID_TOKEN' || 
           data['code'] == 'NO_TOKEN')) {
        
        // محاولة تحديث التوكن
        final refreshed = await _refreshAccessToken();
        
        if (refreshed) {
          // إعادة المحاولة بالتوكن الجديد
          final retryResponse = await request();
          return jsonDecode(retryResponse.body);
        } else {
          // فشل التحديث - إرجاع خطأ انتهاء الصلاحية
          return {
            'success': false,
            'message': 'انتهت صلاحية الجلسة، الرجاء تسجيل الدخول مرة أخرى',
            'code': 'SESSION_EXPIRED'
          };
        }
      }

      return data;
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e'
      };
    }
  }

  // ============================================
  // تحديث Access Token
  // ============================================
  Future<bool> _refreshAccessToken() async {
    if (_isRefreshing) return false;
    
    _isRefreshing = true;

    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      
      if (refreshToken == null) {
        _isRefreshing = false;
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await _storage.write(key: 'access_token', value: data['accessToken']);
        if (data['refreshToken'] != null) {
          await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        }
        _isRefreshing = false;
        return true;
      }

      _isRefreshing = false;
      return false;
    } catch (e) {
      _isRefreshing = false;
      return false;
    }
  }

  // ============================================
  // البحث عن مستخدم (username أو phone)
  // ============================================
  Future<Map<String, dynamic>> searchContact(String searchQuery) async {
    return _handleAuthenticatedRequest(() async {
      final headers = await _getHeaders();
      return await http.post(
        Uri.parse('$baseUrl/contacts/search'),
        headers: headers,
        body: jsonEncode({'searchQuery': searchQuery}),
      ).timeout(const Duration(seconds: 10));
    });
  }

  // ============================================
  // إرسال طلب صداقة
  // ============================================
  Future<Map<String, dynamic>> sendContactRequest(String userId) async {
    return _handleAuthenticatedRequest(() async {
      final headers = await _getHeaders();
      return await http.post(
        Uri.parse('$baseUrl/contacts/send-request'),
        headers: headers,
        body: jsonEncode({'userId': userId}),
      ).timeout(const Duration(seconds: 10));
    });
  }

  // ============================================
  // جلب الطلبات المعلقة (Notifications)
  // ============================================
  Future<Map<String, dynamic>> getPendingRequests() async {
    return _handleAuthenticatedRequest(() async {
      final headers = await _getHeaders();
      return await http.get(
        Uri.parse('$baseUrl/contacts/pending-requests'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
    });
  }

  // ============================================
  // قبول طلب صداقة
  // ============================================
  Future<Map<String, dynamic>> acceptContactRequest(String requestId) async {
    return _handleAuthenticatedRequest(() async {
      final headers = await _getHeaders();
      return await http.post(
        Uri.parse('$baseUrl/contacts/accept-request/$requestId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
    });
  }

  // ============================================
  // رفض طلب صداقة
  // ============================================
  Future<Map<String, dynamic>> rejectContactRequest(String requestId) async {
    return _handleAuthenticatedRequest(() async {
      final headers = await _getHeaders();
      return await http.post(
        Uri.parse('$baseUrl/contacts/reject-request/$requestId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
    });
  }

  // ============================================
  // جلب قائمة الأصدقاء
  // ============================================
  Future<Map<String, dynamic>> getContactsList() async {
    return _handleAuthenticatedRequest(() async {
      final headers = await _getHeaders();
      return await http.get(
        Uri.parse('$baseUrl/contacts/list'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
    });
  }

  // ============================================
  // حذف صديق
  // ============================================
  Future<Map<String, dynamic>> deleteContact(String contactId) async {
    return _handleAuthenticatedRequest(() async {
      final headers = await _getHeaders();
      return await http.delete(
        Uri.parse('$baseUrl/contacts/$contactId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
    });
  }

  // ============================================
  // Authentication APIs
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
  // دوال مساعدة
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