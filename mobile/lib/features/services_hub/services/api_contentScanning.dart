import 'package:http/http.dart';
import 'package:waseed/config/appConfig.dart';
import 'dart:convert';

class ApiContentService {
  static String virustotalURL = 'https://www.virustotal.com/api/v3/files'; 

  Future<ScanResult> scanURL(String url) async {
    final uri = Uri.parse('https://www.virustotal.com/api/v3/urls');
    final headers = {
      'x-apikey': AppConfig.virustotalApiKey,
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    
    final body = 'url=$url';

    try {
      // خطوة 1: إرسال URL للفحص
      final response = await post(uri, headers: headers, body: body);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to scan URL: ${response.statusCode}');
      }
      
      final jsonResponse = json.decode(response.body);
      final analysisId = jsonResponse['data']['id'];
      
      // خطوة 2: الانتظار قليلاً ثم جلب النتائج
      await Future.delayed(Duration(seconds: 3));
      
      // خطوة 3: جلب نتيجة التحليل
      final analysisUri = Uri.parse('https://www.virustotal.com/api/v3/analyses/$analysisId');
      final analysisResponse = await get(analysisUri, headers: {
        'x-apikey': AppConfig.virustotalApiKey,
      });
      
      if (analysisResponse.statusCode != 200) {
        throw Exception('Failed to get analysis results');
      }
      
      final analysisData = json.decode(analysisResponse.body);
      return ScanResult.fromJson(analysisData);
      
    } catch (e) {
      throw Exception('Error scanning URL: $e');
    }
  }

  Future<ScanResult> scanFile(String hash) async {
    final uri = Uri.parse('https://www.virustotal.com/api/v3/files/$hash');
    final headers = {
      'x-apikey': AppConfig.virustotalApiKey,
    };

    try {
      final response = await get(uri, headers: headers);
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ScanResult.fromJson(jsonResponse);
      } else if (response.statusCode == 404) {
        // الملف غير موجود في قاعدة بيانات VirusTotal
        return ScanResult(
          isSafe: true,
          maliciousCount: 0,
          suspiciousCount: 0,
          harmlessCount: 0,
          status: 'not_found',
        );
      } else {
        throw Exception('Failed to scan file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error scanning file: $e');
    }
  }
}


// كلاس لتخزين نتيجة الفحص
class ScanResult {
  final bool isSafe;
  final int maliciousCount;
  final int suspiciousCount;
  final int harmlessCount;
  final String status;
  
  ScanResult({
    required this.isSafe,
    required this.maliciousCount,
    required this.suspiciousCount,
    required this.harmlessCount,
    required this.status,
  });
  
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final stats = json['data']['attributes']['stats'] ?? {};
    
    final malicious = stats['malicious'] ?? 0;
    final suspicious = stats['suspicious'] ?? 0;
    final harmless = stats['harmless'] ?? 0;
    final status = json['data']['attributes']['status'] ?? 'unknown';
    
    return ScanResult(
      isSafe: malicious == 0 && suspicious == 0,
      maliciousCount: malicious,
      suspiciousCount: suspicious,
      harmlessCount: harmless,
      status: status,
    );
  }
}
