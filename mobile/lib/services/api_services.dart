// lib/services/api_services.dart
import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:waseed/services/crypto/signal_protocol_manager.dart';
import 'dart:async';
import 'socket_service.dart';
import 'package:path/path.dart';
import 'package:http_parser/http_parser.dart';
import 'package:waseed/config/appConfig.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'local_db/database_helper.dart';
import '../features/dashboard/services/notification_service.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiService {
  // ============================
  // Base URL deployment
  // ============================
  static String? get baseUrl => AppConfig.apiBaseUrl;

  // ─── HIBP Config ───────────────────────────────────────────
  static String _hibpApiKey = AppConfig.hibpApikey;
  static const String _hibpBaseUrl = 'https://haveibeenpwned.com/api/v3';


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
  ApiService._internal();
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;
  final _storage = const FlutterSecureStorage();

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
          'newPassword': password,
        }),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في الاتصال'};
    }
  }

  // ============================================
  // التحقق من الإيميل وإنشاء الحساب - الخطوة 2
  // ============================================
  Future<Map<String, dynamic>> verifyEmailAndCreate({
    required String code,
    required String newRegistrationId,
    String? deviceName
  }) async {
    try {
      String detectedDevice = "Unknown Device";
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      detectedDevice = "${androidInfo.manufacturer} ${androidInfo.model}"; 
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      detectedDevice = iosInfo.name;
    }
      final requestBody = {
        'code': code,
        'newRegistrationId': newRegistrationId,
        'deviceName': detectedDevice,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-email-and-create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
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
        body: jsonEncode({'newRegistrationId': newRegistrationId}),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في الاتصال'};
    }
  }

  //  إرسال رمز التحقق للجوال عبر SMS (Twilio)
  Future<Map<String, dynamic>> sendPhoneVerification(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/send-phone-verification'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  //  تأكيد رقم الهاتف برمز التحقق (يحفظ التوكن)
  Future<Map<String, dynamic>> verifyPhone({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-phone'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'phone': phone, 'code': code}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await _storage.write(key: 'access_token', value: data['accessToken']);
        await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // إعادة إرسال رمز التحقق بالإيميل
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/resend-verification-email'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // إعادة إرسال رمز التحقق برقم الجوال
  Future<Map<String, dynamic>> resendVerificationPhone(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/resend-verification-phone'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // تسجيل الدخول (يرسل رمز 2FA دائماً)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      // تسجيل الدخول يرسل دائماً رمز 2FA
      // لا نحفظ التوكن هنا - سيتم بعد التحقق من رمز 2FA

      return data;
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // إعادة إرسال رمز 2FA
  Future<Map<String, dynamic>> resend2FACode(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/resend-2fa'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // تخطي التحقق من الجوال (يرسل توكن)
  Future<Map<String, dynamic>> skipPhoneVerification({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/skip-phone-verification'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      // حفظ التوكن إذا نجحت العملية
      if (response.statusCode == 200 && data['success']) {
        await _storage.write(key: 'access_token', value: data['accessToken']);
        await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        await _storage.write(
          key: 'refresh_data',
          value: jsonEncode(data['user']),
        );
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  //  التحقق من رمز 2FA
  Future<Map<String, dynamic>> verify2FA({
    required String email,
    required String code,
    String? deviceName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-2fa'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'code': code, if (deviceName != null) 'deviceName': deviceName,}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await _storage.write(key: 'access_token', value: data['accessToken']);
        await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  //  طلب إعادة تعيين كلمة المرور (إرسال رمز)
  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // التحقق من رمز إعادة التعيين
  Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-reset-code'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'code': code}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // إعادة تعيين كلمة المرور
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
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
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('known_breach_names');
    NotificationService().resetSession();

    // قطع اتصال الـ Socket عند تسجيل الخروج
    final socketService = SocketService();
    socketService.disconnectOnLogout();
  }

  // ===== وضع الطوارئ =====

  /// إبلاغ السيرفر بتفعيل وضع الطوارئ (timeout 3 ثواني)
  Future<bool> activateEmergencyModeOnServer() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/emergency-mode'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 3));

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      // Timeout أو ما فيه نت - نكمل المسح المحلي
      return false;
    }
  }

  /// مسح جميع البيانات المحلية فوراً (وضع الطوارئ)
  Future<void> emergencyWipeAllLocalData() async {
    // 1. قطع اتصال الـ Socket فوراً
    final socketService = SocketService();
    socketService.disconnectOnLogout();

    // 2. مسح كل الـ SecureStorage (tokens + مفاتيح تشفير + بصمة)
    try {
      await _storage.deleteAll();
    } catch (e) {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'user_data');
      await _storage.delete(key: 'refresh_data');
      await _storage.delete(key: 'biometric_enabled');
      await _storage.delete(key: 'biometric_user_email');
    }

    // 3. مسح كل SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    // 4. مسح كل SQLite (رسائل + محادثات + مدد)
    try {
      final db = DatabaseHelper.instance;
      await db.clearAllData();
    } catch (_) {}

    // 5. مسح ملفات مؤقتة
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
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
      final response = await http
          .post(
            Uri.parse('$baseUrl/contacts/search'),
            headers: headers,
            body: jsonEncode({'searchQuery': searchQuery}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  Uri _buildUri(String path) {
    if (path.startsWith('http')) return Uri.parse(path);
    final needsSlash = !path.startsWith('/');
    return Uri.parse('${ApiService.baseUrl}${needsSlash ? '/' : ''}$path');
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await _authHeaders();
      final res = await http
          .put(_buildUri(path), headers: headers, body: jsonEncode(body))
          .timeout(timeout);
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'PUT failed: $e'};
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final headers = await _authHeaders();
      final res = await http
          .get(_buildUri(path), headers: headers)
          .timeout(timeout);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        return {
          'success': false,
          'message': 'Request failed with status: ${res.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'GET failed: $e'};
    }
  }

  // إرسال طلب صداقة
  Future<Map<String, dynamic>> sendContactRequest(String userId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/contacts/send-request'),
            headers: headers,
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // جلب الطلبات المعلقة (Notifications)
  Future<Map<String, dynamic>> getPendingRequests() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/contacts/pending-requests'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // قبول طلب صداقة
  Future<Map<String, dynamic>> acceptContactRequest(String requestId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/contacts/accept-request/$requestId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // رفض طلب صداقة
  Future<Map<String, dynamic>> rejectContactRequest(String requestId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/contacts/reject-request/$requestId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // جلب قائمة الأصدقاء
  Future<Map<String, dynamic>> getContactsList() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/contacts/list'), headers: headers)
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // حذف صديق
  Future<Map<String, dynamic>> deleteContact(String contactId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/contacts/$contactId'), headers: headers)
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }
  // ============================================
  // Account Management API Methods
  // ============================================

  // تحديث الصورة الرمزية (Memoji)
  Future<Map<String, dynamic>> updateMemoji(String memoji) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/user/update-memoji'),
            headers: headers,
            body: jsonEncode({'memoji': memoji}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      // تحديث بيانات المستخدم المحفوظة
      if (data['success'] && data['user'] != null) {
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // تحديث اسم المستخدم
  Future<Map<String, dynamic>> updateUsername(String username) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/user/update-username'),
            headers: headers,
            body: jsonEncode({'username': username}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      // تحديث بيانات المستخدم المحفوظة
      if (data['success'] && data['user'] != null) {
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // طلب تغيير البريد الإلكتروني (إرسال رمز تحقق)
  Future<Map<String, dynamic>> requestEmailChange(String newEmail) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/request-email-change'),
            headers: headers,
            body: jsonEncode({'newEmail': newEmail}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // التحقق من تغيير البريد الإلكتروني
  Future<Map<String, dynamic>> verifyEmailChange(
    String newEmail,
    String code,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/verify-email-change'),
            headers: headers,
            body: jsonEncode({'newEmail': newEmail, 'code': code}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      // تحديث بيانات المستخدم المحفوظة
      if (data['success'] && data['user'] != null) {
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // طلب تغيير رقم الهاتف (إرسال رمز تحقق)
  Future<Map<String, dynamic>> requestPhoneChange(String newPhone) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/request-phone-change'),
            headers: headers,
            body: jsonEncode({'newPhone': newPhone}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // التحقق من تغيير رقم الهاتف
  Future<Map<String, dynamic>> verifyPhoneChange(
    String newPhone,
    String code,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/verify-phone-change'),
            headers: headers,
            body: jsonEncode({'newPhone': newPhone, 'code': code}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      // تحديث بيانات المستخدم المحفوظة
      if (data['success'] && data['user'] != null) {
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  // تغيير كلمة المرور
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/change-password'),
            headers: headers,
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }
  // تسجيل دخول بالبايومتريكس

  // طلب تفعيل البايومتركس
  Future<Map<String, dynamic>> requestBiometricEnable() async {
    try {

      final headers = await _authHeaders();

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/request-biometric-enable'),
            headers: headers,
          )
          .timeout(
            const Duration(seconds: 30), 
            onTimeout: () {
              throw TimeoutException('انتهى وقت الانتظار، حاول مرة أخرى');
            },
          );


      final data = jsonDecode(response.body);

      return data;
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'message':
            'انتهى وقت الانتظار، تأكد من اتصالك بالإنترنت وحاول مرة أخرى',
      };
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  Future<void> Logout() async {
    await logout();
  }

  // تأكيد تفعيل البايومتركس
  Future<Map<String, dynamic>> verifyBiometricEnable(String code) async {
    try {

      final headers = await _authHeaders();

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-biometric-enable'),
            headers: headers,
            body: jsonEncode({'code': code}),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('انتهى وقت الانتظار');
            },
          );


      return jsonDecode(response.body);
    } on TimeoutException catch (e) {
      return {'success': false, 'message': 'انتهى وقت الانتظار، حاول مرة أخرى'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  // إلغاء البايومتركس
  Future<Map<String, dynamic>> disableBiometric() async {
    try {

      final headers = await _authHeaders();

      final response = await http
          .post(Uri.parse('$baseUrl/auth/disable-biometric'), headers: headers)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('انتهى وقت الانتظار');
            },
          );


      return jsonDecode(response.body);
    } on TimeoutException catch (e) {
      return {'success': false, 'message': 'انتهى وقت الانتظار، حاول مرة أخرى'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  // دخول بالبايومتركس
  Future<Map<String, dynamic>> biometricLogin(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/biometric-login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

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
  Future<Map<String, dynamic>> deleteMessageForRecipient(
    String messageId,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/messages/delete-for-recipient/$messageId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل حذف الرسالة: $e'};
    }
  }

  // حذف للجميع
  Future<Map<String, dynamic>> deleteMessageForEveryone(
    String messageId,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/messages/delete-for-everyone/$messageId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل حذف الرسالة: $e'};
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
      final response = await http
          .post(
            Uri.parse('$baseUrl/messages/send'),
            headers: headers,
            body: jsonEncode({
              'recipientId': recipientId,
              'encryptedType': encryptedType,
              'encryptedBody': encryptedBody,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل إرسال الرسالة: $e'};
    }
  }

  // جلب المحادثة
  Future<Map<String, dynamic>> getConversation(String userId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/messages/conversation/$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'فشل جلب المحادثة: $e'};
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

      return {'success': false, 'message': 'Failed to get version'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPeerKeysVersion(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/prekeys/version/user/$userId'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'version': data['version'],
          'exists': data['exists'] == true,
          'lastUpdate': data['lastUpdate'],
        };
      }

      return {'success': false, 'message': 'Failed to get peer version'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ===================================
  //  التحقق من حالة المزامنة
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
        'message': needsSync ? 'Keys are out of sync' : 'Keys are synchronized',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ===================================
  // رفع Bundle كامل مع النسخة
  // ===================================
  Future<Map<String, dynamic>> uploadKeyBundle(
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
          'version': data['version'],
          'totalKeys': data['totalKeys'],
          'availableKeys': data['availableKeys'],
        };
      }

      return {'success': false, 'message': data['message'] ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ===================================
  // جلب PreKey Bundle
  // ===================================
  Future<Map<String, dynamic>> getPreKeyBundle(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/prekeys/$userId'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'bundle': data['bundle']};
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to get bundle',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ===================================
  //  التحقق من عدد PreKeys
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

      return {'success': false, 'message': 'Failed to check count'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ===================================
  //  حذف Bundle (عند حذف الحساب)
  // ===================================
  Future<Map<String, dynamic>> deletePreKeyBundle() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/prekeys/delete-bundle'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Bundle deleted successfully'};
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to delete bundle',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ===================================
  //  Helper: الحصول على Headers مع التوكن
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

  // ===================================
  // Chatbot API Methods
  // ===================================
  Future<Map<String, dynamic>> askChatbot(String message) async {
    try {
      final uri = Uri.parse('$baseUrl/chatbot/ask');

      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 20));

      // لو السيرفر رجّع HTML/نص مو JSON
      dynamic data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        return {
          'success': false,
          'reply': '⚠️ السيرفر رجّع رد غير مفهوم (مو JSON).',
          'reason': 'BAD_RESPONSE',
          'statusCode': res.statusCode,
          'raw': res.body.toString().substring(
            0,
            res.body.length.clamp(0, 300),
          ),
        };
      }

      // ضمان مفاتيح ثابتة
      return {
        'success': data['success'] == true,
        'reply': (data['reply'] ?? '').toString(),
        'reason': (data['reason'] ?? 'UNKNOWN').toString(),
        'statusCode': res.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'reply': '⚠️ تعذر الاتصال بالمساعد الذكي',
        'reason': 'NETWORK_ERROR',
        'error': e.toString(),
      };
    }
  }
  Future<Map<String, dynamic>> checkAnomalies({
  double? lat,
  double? lng,
  String? locationName,
  String? ssid,
  String? deviceName,
}) async {
  try {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/anomaly/check'),
      headers: headers,
      body: jsonEncode({
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (locationName != null) 'locationName': locationName,
        if (ssid != null) 'ssid': ssid,
        if (deviceName != null) 'deviceName': deviceName,
      }),
    ).timeout(const Duration(seconds: 15));
    return jsonDecode(response.body);
  } catch (e) {
    return {'success': false, 'anomalies': []};
  }
}
Future<Map<String, dynamic>> unfreezeAccount({
  required String email,
  required String code,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/user/unfreeze-account'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    return jsonDecode(response.body);
  } catch (e) {
    return {'success': false, 'message': 'خطأ في الاتصال'};
  }
}
Future<Map<String, dynamic>> freezeByToken(String token) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/user/freeze-by-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );
    return jsonDecode(response.body);
  } catch (e) {
    return {'success': false};
  }
}


Future<Map<String, dynamic>> sendOTPforIdentityVerification(String email) async {
  try {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'message': 'يجب تسجيل الدخول'};

    final response = await http.post(
      Uri.parse('$baseUrl/auth/send-otp'),
      headers: {'Content-Type': 'application/json',
       'Authorization': 'Bearer $token',},
      body: jsonEncode({"email": email}),
    );
    return jsonDecode(response.body);
  } catch (e) {
    return {'success': false, 'message': 'خطأ في الاتصال'};
  }
}
Future<Map<String, dynamic>> verifyOTPforIdentityVerification(String code) async {
  try {
      final token = await getAccessToken();
      if (token == null) return {'success': false, 'message': 'يجب تسجيل الدخول'};


    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token',},
      body: jsonEncode({
      'code' :code
      }),
    );
    return jsonDecode(response.body);
  } catch (e) {
    return {'success': false, 'message': 'خطأ في الاتصال'};
  }
}

Future<List> checkEmailBreach(String email) async {
 try {
   final token = await getAccessToken();
    if (token == null) throw Exception('يجب تسجيل الدخول');

    final url = Uri.parse(
      '$_hibpBaseUrl/breachedaccount/${Uri.encodeComponent(email)}?truncateResponse=false',
    );

    final response = await http.get(url, headers: {
      'hibp-api-key': _hibpApiKey,
      'user-agent': 'MyFlutterApp',
    });

    if (response.statusCode == 200) {
      final List breaches = jsonDecode(response.body);
     
      return breaches;

    } else if (response.statusCode == 404){
      return [];
    }
    else {
      throw new Exception('فشل البحث: ${response.statusCode} ');
    }
 } catch (e){
  throw Exception('خطأ: $e');
 }



}

Future<int> checkPasswordBreach(String password) async {
  try {
    // نحول الباسورد إلى SHA-1
    final bytes = utf8.encode(password);
    final sha1Hash = sha1.convert(bytes).toString().toUpperCase();

    // نرسل أول 5 أحرف فقط (k-Anonymity)
    final prefix = sha1Hash.substring(0, 5);
    final suffix = sha1Hash.substring(5);

    final url = Uri.parse('https://api.pwnedpasswords.com/range/$prefix');
    final response = await http.get(url, headers: {
      'user-agent': 'MyFlutterApp',
    });

    if (response.statusCode == 200) {
      final lines = response.body.split('\n');

      for (var line in lines) {
        final parts = line.split(':');
        if (parts[0].trim() == suffix) {
          return int.parse(parts[1].trim()); // ← عدد مرات التسريب
        }
      }
      return 0; 
    } else {
      throw Exception('فشل البحث: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('خطأ: $e');
  }
}


}