// lib/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String? get apiBaseUrl {
    if (isProduction) {
      return dotenv.env['API_BASE_URL'];
      }
     
    else {
     return 'http://localhost:3000/api';
     }
  }

  static bool get isProduction {
    final value = dotenv.env['PRODUCTION']?.toLowerCase();
    return value == 'true' || value == '0';
  }

  static String? get socketUrl {
    if(isProduction){
    return dotenv.env['SOCKET_URL']; 
    }else{
    return 'http://localhost:3000';}
  }

  static String get hibpApikey {

    return dotenv.env['HIBP_API_KEY'] ?? "00000000"; 

  }

  static String get virustotalApiKey {
    return dotenv.env['VIRUS_TOTAL_API_KEY'] ?? 'http://localhost:3000';
  }
  static String get imageModelUrl {
    return dotenv.env['IMAGE_MODEL_URL'] ?? 'http://localhost:3000';
  }

  static String get hosting {
    return dotenv.env['HOSTING'] ?? 'http://localhost:3000';
  }

  // دالة مساعدة للتحقق من التحميل
  static bool get isLoaded {
    return dotenv.isInitialized;
  }

  
  
}
