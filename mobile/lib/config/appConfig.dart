// lib/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/api';
  }
  
  static bool get isProduction {
    final value = dotenv.env['PRODUCTION']?.toLowerCase();
    return value == 'true' || value == '1';
  }

  static String get socketUrl {
    return dotenv.env['SOCKET_URL'] ?? 'http://localhost:3000';
  }

  static String get hosting {
    return dotenv.env['HOSTING'] ?? 'http://localhost:3000';
  }
  
  // دالة مساعدة للتحقق من التحميل
  static bool get isLoaded {
    return dotenv.isInitialized;
  }
  
  static void printConfig() {
    print('🔧 App Configuration:');
    print('   - API Base URL: $apiBaseUrl');
    print('   - Socket URL: $socketUrl');
    print('   - Hosting: $hosting');
    print('   - Production: $isProduction');
    print('   - DotEnv Loaded: $isLoaded');
  }
  
  // التحقق من صحة الإعدادات
  static bool validate() {
    if (!isLoaded) {
      print('❌ .env file not loaded!');
      return false;
    }
    
    if (isProduction) {
      if (!apiBaseUrl.startsWith('https://')) {
        print('⚠️ Warning: Production should use HTTPS!');
        return false;
      }
    }
    
    print('✅ Configuration validated successfully');
    return true;
  }
}