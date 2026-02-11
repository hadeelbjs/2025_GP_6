import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:waseed/config/appConfig.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
class ApiContentService {
  static String virustotalURL = 'https://www.virustotal.com/api/v3/files'; 
  Map<String, dynamic>? lastResult;
  final String baseUrl = AppConfig.virustotalApiKey;

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

  Future<Map<String, dynamic>?> scanImage(File? imageFile) async {
    if (imageFile == null) {
      print('❌ لا توجد صورة');
      return null;
    }

    try {
      print('📤 إرسال الصورة للتحليل...');
      
      // إنشاء الطلب
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/analyze'),
      );

      // إضافة الصورة
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      // إرسال الطلب
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('📥 رمز الاستجابة: ${response.statusCode}');

      if (response.statusCode == 200) {
        // فك تشفير النتيجة
        var jsonData = json.decode(response.body);
        
        print('✅ نجح التحليل!');
        print('النتيجة: ${jsonData['status']}');
        
        // حفظ النتيجة
        lastResult = jsonData;
        
        return jsonData;
      } else {
        print('❌ خطأ: ${response.statusCode}');
        print('الاستجابة: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ خطأ في الاتصال: $e');
      return null;
    }
  }
  
  // دالة للتحقق إذا الصورة آمنة
  bool isSafe() {
    if (lastResult == null) return true;
    
    var summary = lastResult!['summary'];
    
    // إذا فيه أي بيانات حساسة
    bool hasKeywords = (summary['total_keywords'] ?? 0) > 0;
    bool hasNames = (summary['total_names'] ?? 0) > 0;
    bool hasBarcodes = (summary['total_barcodes'] ?? 0) > 0;
    
   bool hasFaces = (lastResult!['summary']['total_faces'] ?? 0) > 0;

    return !(hasKeywords || hasNames || hasBarcodes || hasFaces);

  }
  
  // الحصول على قائمة البيانات المكتشفة
  List<Map<String, dynamic>> getDetectedItems() {
    if (lastResult == null) return [];
    
    List<Map<String, dynamic>> items = [];
    
    // الكلمات المفتاحية
    if (lastResult!['keywords'] != null) {
      for (var kw in lastResult!['keywords']) {
        items.add({
          'icon': _getIconForType(kw['type']),
          'text': '${_getTypeLabel(kw['type'])}: ${kw['text']}',
          'type': kw['type'],
        });
      }
    }
    
    // الأسماء
    if (lastResult!['names'] != null) {
      for (var name in lastResult!['names']) {
        items.add({
          'icon': 'person',
          'text': 'اسم شخص: ${name['text']}',
          'type': 'NAME',
        });
      }
    }
    
    // الباركود
    if (lastResult!['barcodes'] != null) {
      for (var bc in lastResult!['barcodes']) {
        if (bc['analysis']['sensitive'] == true) {
          items.add({
            'icon': 'qr_code',
            'text': 'باركود: ${bc['analysis']['data_type']}',
            'type': 'BARCODE',
          });
        }
      }
    }

    // الوجوه
    if (lastResult!['yolo_faces'] != null) {
      for (var face in lastResult!['yolo_faces']) {
        items.add({
          'icon': 'face',
          'text': 'وجه بشري مكتشف',
          'type': 'FACE',
        });
      }
    }

    
    return items;
  }
  
  String _getIconForType(String type) {
    Map<String, String> icons = {
      'NATIONAL_ID_LABEL': 'badge',
      'IQAMA_LABEL': 'card_membership',
      'PASSPORT_LABEL': 'flight',
      'EMAIL_LABEL': 'email',
      'PHONE_LABEL': 'phone',
      'BANK_LABEL': 'account_balance',
      'NAME_LABEL': 'person',
    };
    return icons[type] ?? 'info';
  }
  
  String _getTypeLabel(String type) {
    Map<String, String> labels = {
      'NATIONAL_ID_LABEL': 'هوية وطنية',
      'NAME_LABEL': 'حقل اسم',
      'IQAMA_LABEL': 'إقامة',
      'PASSPORT_LABEL': 'جواز سفر',
      'EMAIL_LABEL': 'بريد إلكتروني',
      'PHONE_LABEL': 'رقم جوال',
      'BANK_LABEL': 'حساب بنكي',
      'DATE_LABEL': 'تاريخ',
    };
    return labels[type] ?? type;
  }
  
  // للحصول على الملخص
  Map<String, int> getSummary() {
    if (lastResult == null) {
      return {
        'total_words': 0,
        'total_keywords': 0,
        'total_names': 0,
        'total_barcodes': 0,
        'total_faces': 0,
      };
    }

    return {
      'total_words': lastResult!['summary']['total_words'] ?? 0,
      'total_keywords': lastResult!['summary']['total_keywords'] ?? 0,
      'total_names': lastResult!['summary']['total_names'] ?? 0,
      'total_barcodes': lastResult!['summary']['total_barcodes'] ?? 0,
      'total_faces': lastResult!['summary']['total_faces'] ?? 0,
    };
  }

}

class ImageScanResult {
    final bool isClean;
    ImageScanResult({
      required this.isClean
    });
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
