import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';



class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Keys للتخزين الآمن
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricUserKey = 'biometric_user_email';

  /// التحقق من دعم الجهاز للبصمة
  static Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('خطأ في التحقق من دعم الجهاز: $e');
      return false;
    }
  }
static void openBiometricSettings() {
  AppSettings.openAppSettings(type: AppSettingsType.security);
}
  /// التحقق من توفر البصمات في الجهاز
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('خطأ في التحقق من توفر البصمات: $e');
      return false;
    }
  }

   ///  دالة جديدة: التحقق من وجود بصمات مسجلة فعلياً في الجهاز
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('خطأ في التحقق من البصمات المسجلة: $e');
      return false;
    }
  }

  /// تفعيل البصمة لمستخدم معين
  static Future<bool> enableBiometric(String userEmail) async {
    try {
      final canUse = await canCheckBiometrics();
      if (!canUse) return false;

      final success = await authenticateWithBiometrics(
        reason: 'تأكيد تفعيل البصمة لحسابك'
      );
      
      if (success) {
        await _storage.write(key: _biometricEnabledKey, value: 'true');
        await _storage.write(key: _biometricUserKey, value: userEmail);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('خطأ في تفعيل البصمة: $e');
      return false;
    }
  }

  /// إلغاء البصمة
  static Future<void> disableBiometric() async {
    try {
      await _storage.delete(key: _biometricEnabledKey);
      await _storage.delete(key: _biometricUserKey);
    } catch (e) {
      debugPrint('خطأ في إلغاء البصمة: $e');
    }
  }

  /// فحص تفعيل البصمة
  static Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _storage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }

  /// الحصول على إيميل المستخدم المربوط بالبصمة
  static Future<String?> getBiometricUser() async {
    try {
      return await _storage.read(key: _biometricUserKey);
    } catch (e) {
      return null;
    }
  }

  /// التحقق من البصمة
  static Future<bool> authenticateWithBiometrics({
    String? reason,
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) return false;

      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      final String finalReason = reason ?? 'تحقق من هويتك للدخول إلى وصيد';

      return await _localAuth.authenticate(
        localizedReason: finalReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

    } catch (e) {
      debugPrint('خطأ في التحقق من البصمة: $e');
      return false;
    }
  }

  // حفظ علامة إن المستخدم للتو سوى logout
static Future<void> setJustLoggedOut(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('just_logged_out', value);
}

// فحص إذا المستخدم للتو سوى logout
static Future<bool> getJustLoggedOut() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('just_logged_out') ?? false;
}
}