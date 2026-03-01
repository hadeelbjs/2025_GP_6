import 'dart:async';
import '../../../core/models/app_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../../core/models/post.dart';
import 'package:http/http.dart' as http;
import '../../../config/appConfig.dart';
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ─── HIBP Config ───────────────────────────────────────────
  static String _hibpApiKey = AppConfig.hibpApikey;
  static const String _hibpBaseUrl = 'https://haveibeenpwned.com/api/v3';

  final List<AppNotification> _notifications = [];
  final StreamController<List<AppNotification>> _controller =
      StreamController.broadcast();

  Stream<List<AppNotification>> get notificationsStream => _controller.stream;
  List<AppNotification> get notifications => _notifications;

  // ─── HIBP: تحقق من تسريب الإيميل ──────────────────────────
  Future<void> checkEmailBreachAndNotify() async {
    final email = await getUserData('email');

    if (email == 'No data' || email == 'not valid key') {
      print('❌ تعذّر جلب الإيميل');
      return;
    }

    try {
      final url = Uri.parse(
        '$_hibpBaseUrl/breachedaccount/${Uri.encodeComponent(email)}?truncateResponse=false',
      );

      final response = await http.get(url, headers: {
        'hibp-api-key': _hibpApiKey,
        'user-agent': 'MyFlutterApp',
      });

      if (response.statusCode == 200) {
        final List breaches = jsonDecode(response.body);

        for (final breach in breaches) {
          final notification = AppNotification(
            id: 'hibp_${breach['Name']}',
            type: NotificationType.breachAlert,
            title: 'تسريب بيانات: ${breach['Name']}',
            message: 'تم رصد بريدك الإلكتروني في تسريب "${breach['Title']}" بتاريخ ${breach['BreachDate']}.',
            createdAt: DateTime.now(),
            isRead: false,
          );
          addNotification(notification);
        }

        print('🔴 وُجد ${breaches.length} تسريب للإيميل: $email');

      } else if (response.statusCode == 404) {
        print('✅ الإيميل آمن، لا يوجد تسريبات');

      } else if (response.statusCode == 401) {
        print('❌ API Key غير صحيح');

      } else if (response.statusCode == 429) {
        print('⏳ تجاوزت الحد المسموح، انتظر قليلاً');

      } else {
        throw Exception('HIBP Error: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ خطأ في التحقق من HIBP: $e');
    }
  }

  // ─── Fetch Post ────────────────────────────────────────────
  Future<Post> fetchPost() async {
    final response = await http
        .get(Uri.parse('https://jsonplaceholder.typicode.com/posts/1'));

    if (response.statusCode == 200) {
      return Post.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to load post');
    }
  }

  // ─── Get User Data ─────────────────────────────────────────
  Future<String> getUserData(String key) async {
    final storage = const FlutterSecureStorage();
    final userDataStr = await storage.read(key: 'user_data');

    if (userDataStr == null) {
      print('❌ لا توجد بيانات مستخدم');
      return 'No data';
    }

    final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
    final userId = userData['id'] as String;
    print('👤 User ID: $userId');

    final userEmail = userData['email'] as String;

    if (key == 'email') return userEmail;

    return 'not valid key';
  }

  // ─── Notifications ─────────────────────────────────────────
 void addNotification(AppNotification notification) {
  // تحقق إذا الإشعار موجود مسبقاً بنفس الـ id
  final exists = _notifications.any((n) => n.id == notification.id);
  if (exists) return;
  
  _notifications.insert(0, notification);
  _controller.add(_notifications);
}

  void markAsRead(String id) {
    final index = _notifications.indexWhere((element) => element.id == id);
    if (index != -1) {
      _notifications[index] = AppNotification(
        id: _notifications[index].id,
        type: _notifications[index].type,
        title: _notifications[index].title,
        message: _notifications[index].message,
        createdAt: _notifications[index].createdAt,
        isRead: true,
      );
      _controller.add(_notifications);
    }
  }

  int get unreadCount => _notifications.where((e) => !e.isRead).length;
}