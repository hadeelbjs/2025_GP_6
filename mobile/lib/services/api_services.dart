// lib/services/api_services.dart
import 'dart:convert';
import 'dart:io' show Platform, File; 
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:waseed/services/crypto/signal_protocol_manager.dart';
import 'dart:async';
import 'socket_service.dart';
import 'package:path/path.dart';
import 'package:waseed/config/appConfig.dart';

class ApiService {
  // ============================
  // Base URL deployment
  // ============================
    static String get baseUrl => AppConfig.apiBaseUrl;    
    
  // Base URL بحسب المنصة
  // ============================

  /*
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
  }*/
  
  final _storage = const FlutterSecureStorage();
  
  // ============================================
  // Upload Methods - رفع الصور والملفات
  // ============================================

  Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    try {
      final token = await _storage.read(key: 'access_token');
      
      if (token == null) {
        return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
      }

      final uri = Uri.parse('$baseUrl/upload/image');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل رفع الصورة: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadFile(File file) async {
    try {
      final token = await _storage.read(key: 'access_token');
      
      if (token == null) {
        return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
      }

      final uri = Uri.parse('$baseUrl/upload/file');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل رفع الملف: $e'};
    }
  }

  static String getFullUrl(String relativePath) {
    if (relativePath.startsWith('http')) {
      return relativePath;
    }
    
    final cleanPath = relativePath.startsWith('/') 
        ? relativePath.substring(1) 
        : relativePath;
    
    
      return '$baseUrl/$cleanPath';
    
  }


  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  //  التسجيل (يرسل رمز التحقق للإيميل)
  // ============================================
  // التسجيل - الخطوة 1
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'username': username,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('❌ Registration error: $e');
      return {'success': false, 'message': 'حدث خطأ في الاتصال'};
    }
  }

  // ============================================
  // التحقق من الإيميل وإنشاء الحساب - الخطوة 2
  // ============================================
  Future<Map<String, dynamic>> verifyEmailAndCreate({
    required String code,
    required String newRegistrationId,
  }) async {
    try {
      
      final requestBody = {
        'code': code,
        'newRegistrationId': newRegistrationId,
      };

     
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-email-and-create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('❌ Verify email error: $e');
      return {'success': false, 'message': 'حدث خطأ في الاتصال'};
    }
  }

  // ============================================
  // إعادة إرسال رمز التحقق (قبل إنشاء الحساب)
  // ============================================
  Future<Map<String, dynamic>> resendRegistrationCode({
    required String newRegistrationId,
  }) async {
    try {
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/resend-registration-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'newRegistrationId': newRegistrationId,
        }),
      );

     
      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('❌ Resend registration code error: $e');
      return {'success': false, 'message': 'حدث خطأ في الاتصال'};
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

    // حفظ التوكن إذا نجحت العملية
    if (response.statusCode == 200 && data['success']) {
      await _storage.write(key: 'access_token', value: data['accessToken']);
      await _storage.write(key: 'refresh_token', value: data['refreshToken']);
      await _storage.write(key: 'refresh_data', value: jsonEncode(data['user']));
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

  // تسجيل الخروج
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'refresh_data');

    // قطع اتصال الـ Socket عند تسجيل الخروج
    final socketService = SocketService();
    socketService.disconnectOnLogout();
    
  }

  // ================================
  // (إضافاتك) دوال الـ Contacts فقط
  // ================================

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // البحث عن مستخدم (username أو phone)
  Future<Map<String, dynamic>> searchContact(String searchQuery) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/search'),
        headers: headers,
        body: jsonEncode({'searchQuery': searchQuery}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e',
      };
    }
  }

  // إرسال طلب صداقة
  Future<Map<String, dynamic>> sendContactRequest(String userId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/send-request'),
        headers: headers,
        body: jsonEncode({'userId': userId}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e',
      };
    }
  }

  // جلب الطلبات المعلقة (Notifications)
  Future<Map<String, dynamic>> getPendingRequests() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/contacts/pending-requests'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e',
      };
    }
  }

  // قبول طلب صداقة
  Future<Map<String, dynamic>> acceptContactRequest(String requestId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/accept-request/$requestId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e',
      };
    }
  }

  // رفض طلب صداقة
  Future<Map<String, dynamic>> rejectContactRequest(String requestId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/reject-request/$requestId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e',
      };
    }
  }

  // جلب قائمة الأصدقاء
  Future<Map<String, dynamic>> getContactsList() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/contacts/list'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e',
      };
    }
  }

  // حذف صديق
  Future<Map<String, dynamic>> deleteContact(String contactId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/contacts/$contactId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بالسيرفر: $e',
      };
    }
  }
// ============================================
// Account Management API Methods
// ============================================

// تحديث الصورة الرمزية (Memoji)
Future<Map<String, dynamic>> updateMemoji(String memoji) async {
  try {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/user/update-memoji'),
      headers: headers,
      body: jsonEncode({'memoji': memoji}),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    
    // تحديث بيانات المستخدم المحفوظة
    if (data['success'] && data['user'] != null) {
      await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
    }
    
    return data;
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل الاتصال بالسيرفر: $e',
    };
  }
}

// تحديث اسم المستخدم
Future<Map<String, dynamic>> updateUsername(String username) async {
  try {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/user/update-username'),
      headers: headers,
      body: jsonEncode({'username': username}),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    
    // تحديث بيانات المستخدم المحفوظة
    if (data['success'] && data['user'] != null) {
      await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
    }
    
    return data;
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل الاتصال بالسيرفر: $e',
    };
  }
}

// طلب تغيير البريد الإلكتروني (إرسال رمز تحقق)
Future<Map<String, dynamic>> requestEmailChange(String newEmail) async {
  try {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/user/request-email-change'),
      headers: headers,
      body: jsonEncode({'newEmail': newEmail}),
    ).timeout(const Duration(seconds: 10));

    return jsonDecode(response.body);
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل الاتصال بالسيرفر: $e',
    };
  }
}

// التحقق من تغيير البريد الإلكتروني
Future<Map<String, dynamic>> verifyEmailChange(String newEmail, String code) async {
  try {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/user/verify-email-change'),
      headers: headers,
      body: jsonEncode({
        'newEmail': newEmail,
        'code': code,
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    
    // تحديث بيانات المستخدم المحفوظة
    if (data['success'] && data['user'] != null) {
      await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
    }
    
    return data;
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل الاتصال بالسيرفر: $e',
    };
  }
}

// طلب تغيير رقم الهاتف (إرسال رمز تحقق)
Future<Map<String, dynamic>> requestPhoneChange(String newPhone) async {
  try {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/user/request-phone-change'),
      headers: headers,
      body: jsonEncode({'newPhone': newPhone}),
    ).timeout(const Duration(seconds: 10));

    return jsonDecode(response.body);
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل الاتصال بالسيرفر: $e',
    };
  }
}

// التحقق من تغيير رقم الهاتف
Future<Map<String, dynamic>> verifyPhoneChange(String newPhone, String code) async {
  try {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/user/verify-phone-change'),
      headers: headers,
      body: jsonEncode({
        'newPhone': newPhone,
        'code': code,
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    
    // تحديث بيانات المستخدم المحفوظة
    if (data['success'] && data['user'] != null) {
      await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
    }
    
    return data;
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل الاتصال بالسيرفر: $e',
    };
  }
}

// تغيير كلمة المرور
Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
  try {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/user/change-password'),
      headers: headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    ).timeout(const Duration(seconds: 10));

    return jsonDecode(response.body);
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل الاتصال بالسيرفر: $e',
    };
  }
}
// تسجيل دخول بالبايومتريكس

// طلب تفعيل البايومتركس
Future<Map<String, dynamic>> requestBiometricEnable() async {
  try {
    print('📱 Requesting biometric enable...');
    
    final headers = await _authHeaders();
    
    // ✅ زيادة الـ timeout من 10 إلى 30 ثانية
    final response = await http.post(
      Uri.parse('$baseUrl/auth/request-biometric-enable'),
      headers: headers,
    ).timeout(
      const Duration(seconds: 30), // كان 10 ثواني
      onTimeout: () {
        throw TimeoutException('انتهى وقت الانتظار، حاول مرة أخرى');
      },
    );

    print('✅ Response received: ${response.statusCode}');
    
    final data = jsonDecode(response.body);
    print('Response data: $data');
    
    return data;
  } on TimeoutException catch (e) {
    print('⏱️ Timeout: $e');
    return {
      'success': false,
      'message': 'انتهى وقت الانتظار، تأكد من اتصالك بالإنترنت وحاول مرة أخرى'
    };
  } catch (e) {
    print('❌ Error: $e');
    return {
      'success': false,
      'message': 'خطأ في الاتصال: ${e.toString()}'
    };
  }
}

Future<void> Logout() async {
  print("Alert the server of the logout action");
  await logout();
}

// تأكيد تفعيل البايومتركس
Future<Map<String, dynamic>> verifyBiometricEnable(String code) async {
  try {
    print('🔐 Verifying biometric code: $code');
    
    final headers = await _authHeaders();
    
    // ✅ timeout معقول (15 ثانية)
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-biometric-enable'),
      headers: headers,
      body: jsonEncode({'code': code}),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException('انتهى وقت الانتظار');
      },
    );

    print('✅ Verification response: ${response.statusCode}');
    
    return jsonDecode(response.body);
  } on TimeoutException catch (e) {
    print('⏱️ Timeout: $e');
    return {
      'success': false,
      'message': 'انتهى وقت الانتظار، حاول مرة أخرى'
    };
  } catch (e) {
    print('❌ Error: $e');
    return {
      'success': false,
      'message': 'خطأ في الاتصال: ${e.toString()}'
    };
  }
}

// إلغاء البايومتركس
Future<Map<String, dynamic>> disableBiometric() async {
  try {
    print('🔓 Disabling biometric...');
    
    final headers = await _authHeaders();
    
    // ✅ timeout معقول (15 ثانية)
    final response = await http.post(
      Uri.parse('$baseUrl/auth/disable-biometric'),
      headers: headers,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException('انتهى وقت الانتظار');
      },
    );

    print('✅ Disable response: ${response.statusCode}');
    
    return jsonDecode(response.body);
  } on TimeoutException catch (e) {
    print('⏱️ Timeout: $e');
    return {
      'success': false,
      'message': 'انتهى وقت الانتظار، حاول مرة أخرى'
    };
  } catch (e) {
    print('❌ Error: $e');
    return {
      'success': false,
      'message': 'خطأ في الاتصال: ${e.toString()}'
    };
  }
}

// دخول بالبايومتركس
Future<Map<String, dynamic>> biometricLogin(String email) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/biometric-login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    
    if (response.statusCode == 200 && data['success']) {
      await _storage.write(key: 'access_token', value: data['accessToken']);
      await _storage.write(key: 'refresh_token', value: data['refreshToken']);
      await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
    }
    
    return data;
  } catch (e) {
    return {'success': false, 'message': 'خطأ في الاتصال: $e'};
  }
}

// ============================================
// Messages - الرسائل المشفرة
// ============================================

// حذف من عند المستقبل فقط
Future<Map<String, dynamic>> deleteMessageForRecipient(String messageId) async {
  try {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/messages/delete-for-recipient/$messageId'),
      headers: headers,
    ).timeout(const Duration(seconds: 10));

    return jsonDecode(response.body);
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل حذف الرسالة: $e',
    };
  }
}

// حذف للجميع
Future<Map<String, dynamic>> deleteMessageForEveryone(String messageId) async {
  try {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/messages/delete-for-everyone/$messageId'),
      headers: headers,
    ).timeout(const Duration(seconds: 10));

    return jsonDecode(response.body);
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل حذف الرسالة: $e',
    };
  }
}

// إرسال رسالة مشفرة
Future<Map<String, dynamic>> sendEncryptedMessage({
  required String recipientId,
  required int encryptedType,
  required String encryptedBody,
}) async {
  try {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/messages/send'),
      headers: headers,
      body: jsonEncode({
        'recipientId': recipientId,
        'encryptedType': encryptedType,
        'encryptedBody': encryptedBody,
      }),
    ).timeout(const Duration(seconds: 10));

    return jsonDecode(response.body);
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل إرسال الرسالة: $e',
    };
  }
}

// جلب المحادثة
Future<Map<String, dynamic>> getConversation(String userId) async {
  try {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/messages/conversation/$userId'),
      headers: headers,
    ).timeout(const Duration(seconds: 10));

    return jsonDecode(response.body);
  } catch (e) {
    return {
      'success': false,
      'message': 'فشل جلب المحادثة: $e',
    };
  }
}

Future<Map<String, dynamic>> getKeysVersion() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/prekeys/version/current'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'version': data['version'],
          'exists': data['exists'],
          'lastUpdate': data['lastUpdate'],
        };
      }

      return {
        'success': false,
        'message': 'Failed to get version',
      };
    } catch (e) {
      print('❌ Error getting keys version: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ===================================
  // 🔄 التحقق من حالة المزامنة
  // ===================================
  Future<Map<String, dynamic>> checkSyncStatus(int localVersion) async {
    try {
      final serverResult = await getKeysVersion();
      
      if (!serverResult['success']) {
        return serverResult;
      }

      final serverVersion = serverResult['version'];
      
      if (serverVersion == null) {
        return {
          'success': true,
          'needsSync': false,
          'needsGeneration': true,
          'message': 'No keys on server',
        };
      }

      final needsSync = serverVersion != localVersion;

      return {
        'success': true,
        'needsSync': needsSync,
        'needsGeneration': false,
        'serverVersion': serverVersion,
        'localVersion': localVersion,
        'message': needsSync 
          ? 'Keys are out of sync' 
          : 'Keys are synchronized',
      };
    } catch (e) {
      print('❌ Error checking sync status: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ===================================
  // 🔑 رفع Bundle كامل مع النسخة
  // ===================================
  Future<Map<String, dynamic>> uploadPreKeyBundle(
    Map<String, dynamic> bundle,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/prekeys/upload'),
        headers: await _getAuthHeaders(),
        body: jsonEncode(bundle),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'version': data['version'], // ✅ استقبال النسخة
          'totalKeys': data['totalKeys'],
          'availableKeys': data['availableKeys'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Upload failed',
      };
    } catch (e) {
      print('❌ Error uploading bundle: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ===================================
  // 📥 جلب PreKey Bundle
  // ===================================
  Future<Map<String, dynamic>> getPreKeyBundle(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/prekeys/$userId'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'bundle': data['bundle'],
        };
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to get bundle',
      };
    } catch (e) {
      print('❌ Error getting bundle: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ===================================
  // 📊 التحقق من عدد PreKeys
  // ===================================
  Future<Map<String, dynamic>> checkPreKeysCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/prekeys/count/remaining'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'count': data['count'],
          'total': data['total'],
          'version': data['version'],
          'needsRefresh': data['needsRefresh'],
        };
      }

      return {
        'success': false,
        'message': 'Failed to check count',
      };
    } catch (e) {
      print('❌ Error checking PreKeys count: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ===================================
  // 🗑️ حذف Bundle (عند حذف الحساب)
  // ===================================
  Future<Map<String, dynamic>> deletePreKeyBundle() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/prekeys/delete-bundle'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Bundle deleted successfully',
        };
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to delete bundle',
      };
    } catch (e) {
      print('❌ Error deleting bundle: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ===================================
  // 🔧 Helper: الحصول على Headers مع التوكن
  // ===================================
  Future<Map<String, String>> _getAuthHeaders() async {
  final token = await _storage.read(key: 'access_token');  
  
  if (token == null) {
    throw Exception('جلسة غير صالحة');
  }
  
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

}