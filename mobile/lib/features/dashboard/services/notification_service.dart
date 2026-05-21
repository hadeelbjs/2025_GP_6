import 'dart:async';
import '../../../core/models/app_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../../core/models/post.dart';
import 'package:http/http.dart' as http;
import '../../../config/appConfig.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _hasCheckedBreach = false;
  static const Map<String, String> _dataClassTranslations = {
  'Email addresses': 'عناوين البريد الإلكتروني',
  'Passwords': 'كلمات المرور',
  'Usernames': 'أسماء المستخدمين',
  'IP addresses': 'عناوين IP',
  'Phone numbers': 'أرقام الهاتف',
  'Physical addresses': 'العناوين الفعلية',
  'Names': 'الأسماء',
  'Dates of birth': 'تواريخ الميلاد',
  'Credit cards': 'بطاقات الائتمان',
  'Bank account numbers': 'أرقام الحسابات البنكية',
  'Social security numbers': 'أرقام الضمان الاجتماعي',
  'Geographic locations': 'المواقع الجغرافية',
  'Device information': 'معلومات الجهاز',
  'Password hints': 'تلميحات كلمات المرور',
  'Security questions and answers': 'أسئلة وأجوبة الأمان',
  'Profile photos': 'صور الملف الشخصي',
  'Genders': 'الجنس',
  'Ages': 'الأعمار',
  'Spoken languages': 'اللغات',
  'Education levels': 'المستويات التعليمية',
  'Job titles': 'المسميات الوظيفية',
  'Government issued IDs': 'بطاقات الهوية الحكومية',
  'Bios': 'السيرة الذاتية',
  'Social media profiles': 'ملفات التواصل الاجتماعي',
  'User': 'بيانات المستخدم',
  'Website URLs': 'روابط المواقع',
  'website URLs': 'روابط المواقع',
  'Website activity': 'نشاط الموقع',
  'Browsing histories': 'سجل التصفح',
  'Chat logs': 'سجلات المحادثات',
};



String _translateDataClass(String english) {
  return _dataClassTranslations[english] ?? english;
}
  // ─── HIBP: تحقق من تسريب الإيميل ──────────────────────────
 Future<void> checkEmailBreachAndNotify() async {
  if (_hasCheckedBreach) return;
  _hasCheckedBreach = true;

  final email = await getUserData('email');
  if (email == 'No data' || email == 'not valid key') {
    _hasCheckedBreach = false;
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
      await saveAllBreaches(breaches);
      final prefs = await SharedPreferences.getInstance();

      final savedJson = prefs.getString('known_breaches') ?? '{}';
      final Map<String, dynamic> savedBreaches = jsonDecode(savedJson);

      final List newBreaches = breaches.where((breach) {
        final name = breach['Name'] as String;
        final date = breach['BreachDate'] as String;

        if (!savedBreaches.containsKey(name)) return true;
        if (savedBreaches[name] != date) return true;
        return false;
      }).toList();

      if (newBreaches.isNotEmpty) {
        for (final breach in newBreaches) {
          final List<String> dataClassesList =
              (breach['DataClasses'] as List)
                  .map((d) => _translateDataClass(d as String))
                  .toList();

          final bool hasPassword = (breach['DataClasses'] as List)
              .any((d) => (d as String).toLowerCase().contains('password'));

          final messageData = jsonEncode({
            'hasPassword': hasPassword,
            'dataClasses': dataClassesList,
            'breachDate': breach['BreachDate'] as String, 
          });

          addNotification(AppNotification(
            id: 'hibp_${breach['Name']}',
            type: NotificationType.breachAlert,
            title: 'تسريب: ${breach['Title']}',
            message: messageData,
            createdAt: DateTime.now(),
            isRead: false,
          ));
        }

        // ─── احفظ كل الـ breaches الحالية ────────────────────
        final Map<String, String> allBreaches = {
          for (var b in breaches)
            b['Name'] as String: b['BreachDate'] as String,
        };
        await prefs.setString('known_breaches', jsonEncode(allBreaches));

      } else {
      }

    } else if (response.statusCode == 404) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('known_breaches');
    } else if (response.statusCode == 401) {
      _hasCheckedBreach = false;
    } else if (response.statusCode == 429) {
      _hasCheckedBreach = false;
    } else {
      throw Exception('HIBP Error: ${response.statusCode}');
    }
  } catch (e) {
    print('خطأ في التحقق من HIBP: $e');
    _hasCheckedBreach = false;
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
      return 'No data';
    }

    final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
    final userId = userData['id'] as String;

    final userEmail = userData['email'] as String;

    if (key == 'email') return userEmail;

    return 'not valid key';
  }
  
void resetSession() {
  _hasCheckedBreach = false;
  _notifications.clear();
  _controller.add(_notifications);
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
  void updateAnomalyAction(String id, bool wasMe) {
  final index = _notifications.indexWhere((n) => n.id == id);
  if (index == -1) return;
  _notifications[index] = _notifications[index].copyWith(
    isRead: true,
    actionTaken: wasMe,
  );
  _controller.add(_notifications);
}

// ─── Breach Storage (مستقل عن الإشعارات) ──────────────────
static const String _breachesStorageKey = 'all_breaches_data';
static const String _fixedBreachesKey = 'fixed_breaches';

Future<void> saveAllBreaches(List breaches) async {
  final prefs = await SharedPreferences.getInstance();
  final List<Map<String, dynamic>> breachList = breaches.map((b) {
    final List<String> dataClassesList = (b['DataClasses'] as List)
        .map((d) => _translateDataClass(d as String))
        .toList();
    final bool hasPassword = (b['DataClasses'] as List)
        .any((d) => (d as String).toLowerCase().contains('password'));
    return {
      'name': b['Name'] as String,
      'title': b['Title'] as String,
      'breachDate': b['BreachDate'] as String,
      'domain': b['Domain'] as String? ?? '',
      'dataClasses': dataClassesList,
      'hasPassword': hasPassword,
    };
  }).toList();

  await prefs.setString(_breachesStorageKey, jsonEncode(breachList));
}

Future<List<Map<String, dynamic>>> getAllBreaches() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_breachesStorageKey);
  if (json == null) return [];
  return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
}

Future<Set<String>> getFixedBreaches() async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_fixedBreachesKey) ?? [];
  return list.toSet();
}

Future<void> markBreachAsFixed(String name) async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_fixedBreachesKey) ?? [];
  if (!list.contains(name)) {
    list.add(name);
    await prefs.setStringList(_fixedBreachesKey, list);
  }
}

Future<void> unmarkBreachAsFixed(String name) async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_fixedBreachesKey) ?? [];
  list.remove(name);
  await prefs.setStringList(_fixedBreachesKey, list);
}

}