import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:waseed/config/appConfig.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_heic_to_jpg/flutter_heic_to_jpg.dart';
import '../../../services/api_services.dart';

class ApiContentService {
  static String virustotalURL = 'https://www.virustotal.com/api/v3/files';
  Map<String, dynamic>? lastResult;
  Uint8List? annotatedImageBytes;
  final String imageBaseUrl = AppConfig.imageModelUrl;
  final String? apiBaseUrl = AppConfig.apiBaseUrl;
  static ScanStats linkStats = ScanStats();
  static ScanStats fileStats = ScanStats();
  ApiService _apiService = ApiService();
  int _uploadedWidth = 0;
  int _uploadedHeight = 0;

  Future<ScanResult> scanURL(String url) async {
    final uri = Uri.parse('https://www.virustotal.com/api/v3/urls');
    final headers = {
      'x-apikey': AppConfig.virustotalApiKey,
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    final body = 'url=$url';

    try {
      final response = await post(uri, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw Exception('Failed to scan URL: ${response.statusCode}');
      }

      final jsonResponse = json.decode(response.body);
      final analysisId = jsonResponse['data']['id'];

      await Future.delayed(Duration(seconds: 3));

      final analysisUri = Uri.parse(
        'https://www.virustotal.com/api/v3/analyses/$analysisId',
      );
      final analysisResponse = await get(
        analysisUri,
        headers: {'x-apikey': AppConfig.virustotalApiKey},
      );

      if (analysisResponse.statusCode != 200) {
        throw Exception('Failed to get analysis results');
      }

      final analysisData = json.decode(analysisResponse.body);
      print(analysisData);
      ScanResult scanResult = ScanResult.fromJson(analysisData);
      if (scanResult.isSafe) {
        linkStats.recordSafe();
        await updateScanStats('link', false);
      } else {
        linkStats.recordVuln();
        await updateScanStats('link', true);
      }

      return scanResult;
    } catch (e) {
      throw Exception('Error scanning URL: $e');
    }
  }

  Future<void> updateScanStats(String type, bool isVulnerable) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/content-scanning-stats/update-$type-stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _apiService.getAccessToken()}',
        },
        body: jsonEncode({'isVulnerable': isVulnerable}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update $type stats');
      }
    } catch (e) {
      debugPrint('updateScanStats error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAllStats() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/content-scanning-stats/all-stats'),
        headers: {
          'Authorization': 'Bearer ${await _apiService.getAccessToken()}',
        },
      );

      if (response.statusCode == 200) {
        print(response.body);
        return jsonDecode(response.body);
      }

      throw Exception('Failed to fetch stats');
    } catch (e) {
      debugPrint('getAllStats error: $e');
      rethrow;
    }
  }

  Future<ScanResult> scanFile(String hash) async {
    final uri = Uri.parse('https://www.virustotal.com/api/v3/files/$hash');
    final headers = {'x-apikey': AppConfig.virustotalApiKey};

    try {
      final response = await get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        ScanResult scanResult = ScanResult.fromJson(jsonResponse);
        if (scanResult.isSafe) {
          fileStats.recordSafe();
          await updateScanStats('file', false);
        } else {
          fileStats.recordVuln();
          await updateScanStats('file', true);
        }

        return scanResult;
      } else if (response.statusCode == 404) {
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

  Future<File> _compressImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final extension = imageFile.path.split('.').last.toLowerCase();

    const needsConversion = [
      'heic',
      'heif',
      'webp',
      'bmp',
      'tiff',
      'tif',
      'png',
    ];
    if (extension == 'heic' || extension == 'heif') {
      final jpgPath = await FlutterHeicToJpg.convert(imageFile.path);
      if (jpgPath != null) {
        imageFile = File(jpgPath);
      }
    }
    final image = img.decodeImage(bytes);

    if (image == null) {
      return imageFile;
    }

    img.Image processed = image;
    if (image.width > 1280 || image.height > 1280) {
      processed = img.copyResize(
        image,
        width: image.width > image.height ? 1280 : null,
        height: image.height >= image.width ? 1280 : null,
      );
    }

    final fileSizeKB = bytes.length / 1024;
    if (fileSizeKB < 500 && !needsConversion.contains(extension)) {
      return imageFile;
    }

    final converted = img.encodeJpg(processed, quality: 85);

    final tempDir = await Directory.systemTemp.createTemp();
    final tempFile = File('${tempDir.path}/processed.jpg');
    await tempFile.writeAsBytes(converted);

    return tempFile;
  }

  Future<Map<String, dynamic>?> scanImage(File? imageFile) async {
    if (imageFile == null) return null;

    try {
      final compressedFile = await _compressImage(imageFile);

      final bytes = await compressedFile.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      _uploadedWidth = decoded.width;
      _uploadedHeight = decoded.height;

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/content-scanning-stats/scan-image'),
      );

      request.headers['Authorization'] =
          'Bearer ${await _apiService.getAccessToken()}';

      request.files.add(
        await http.MultipartFile.fromPath('file', compressedFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);
        lastResult = jsonData;

        if (jsonData['annotated_image_base64'] != null) {
          try {
            annotatedImageBytes = base64Decode(
              jsonData['annotated_image_base64'],
            );
          } catch (e) {
            print('فشل فك تشفير الصورة: $e');
          }
        }

        return jsonData;
      } else {
        print('خطأ: ${response.statusCode} — ${response.body}');
        return null;
      }
    } catch (e) {
      print('scan error: $e');
      return null;
    }
  }

  int get uploadedWidth => _uploadedWidth;
  int get uploadedHeight => _uploadedHeight;
  // الحصول على الصورة مع البوكسات
  Uint8List? getAnnotatedImage() {
    return annotatedImageBytes;
  }

  // التحقق إذا الصورة آمنة
  bool isSafe() {
    if (lastResult!['status'] == 'error') return true;

    if (lastResult == null) return true;

    var summary = lastResult!['summary'];

    bool hasKeywords = (summary['total_keywords'] ?? 0) > 0;
    bool hasNames = (summary['total_names'] ?? 0) > 0;
    bool hasBarcodes = (summary['total_barcodes'] ?? 0) > 0;
    bool hasFaces = (summary['total_faces'] ?? 0) > 0;
    int sensitiveElementsCount = 0;

    const sensitiveDocTypes = {
      'id_card',
      'national_id',
      'passport',
      'driver_license',
      'residence_permit',
      'iqama',
      'birth_certificate',
      'health_card',
      'insurance_card',
      'credit_card',
      'bank_card',
      'car_plate',
      'credit_cards',
    };

    bool hasSensitiveDocs = false;
    if (lastResult!['yolo_objects'] != null) {
      for (var obj in lastResult!['yolo_objects']) {
        String cls = (obj['class'] ?? '').toLowerCase().replaceAll(' ', '_');
        if (sensitiveDocTypes.contains(cls)) {
          hasSensitiveDocs = true;
          sensitiveElementsCount++;
          break;
        }
      }
    }

    return !(hasKeywords ||
        hasNames ||
        hasBarcodes ||
        hasFaces ||
        hasSensitiveDocs);
  }

  // الحصول على قائمة البيانات المكتشفة
  List<Map<String, dynamic>> getDetectedItems() {
    if (lastResult == null) return [];

    List<Map<String, dynamic>> items = [];

    // تجميع الكلمات المفتاحية حسب النوع
    if (lastResult!['keywords'] != null && lastResult!['keywords'].length > 0) {
      Map<String, List<String>> keywordsByType = {};

      for (var kw in lastResult!['keywords']) {
        String type = kw['type'];
        if (!keywordsByType.containsKey(type)) {
          keywordsByType[type] = [];
        }
        keywordsByType[type]!.add(kw['text']);
      }

      // عرض كل نوع مع عدده
      keywordsByType.forEach((type, texts) {
        items.add({
          'icon': _getIconForType(type),
          'text': texts.length == 1
              ? '${_getTypeLabel(type)}: ${texts[0]}'
              : '${_getTypeLabel(type)} (${texts.length})',
          'type': type,
          'count': texts.length,
        });
      });
    }

    // تجميع الأسماء
    if (lastResult!['names'] != null && lastResult!['names'].length > 0) {
      int nameCount = lastResult!['names'].length;

      if (nameCount == 1) {
        // عرض الاسم إذا كان واحد فقط
        items.add({
          'icon': 'person',
          'text': 'اسم شخص: ${lastResult!['names'][0]['text']}',
          'type': 'NAME',
          'count': 1,
        });
      } else {
        // عرض العدد إذا كان أكثر من واحد
        items.add({
          'icon': 'person',
          'text': '$nameCount أسماء أشخاص مكتشفة',
          'type': 'NAME',
          'count': nameCount,
        });
      }
    }

    // تجميع الباركود
    if (lastResult!['barcodes'] != null) {
      List<dynamic> sensitiveBarcodes = lastResult!['barcodes']
          .where((bc) => bc['analysis']['sensitive'] == true)
          .toList();

      if (sensitiveBarcodes.isNotEmpty) {
        int barcodeCount = sensitiveBarcodes.length;
        items.add({
          'icon': 'qr_code',
          'text': barcodeCount == 1
              ? 'باركود/QR مكتشف'
              : '$barcodeCount باركود/QR مكتشفة',
          'type': 'BARCODE',
          'count': barcodeCount,
        });
      }
    }

    // تجميع الوجوه
    if (lastResult!['yolo_faces'] != null &&
        lastResult!['yolo_faces'].length > 0) {
      int faceCount = lastResult!['yolo_faces'].length;
      items.add({
        'icon': 'face',
        'text': faceCount == 1
            ? 'وجه بشري مكتشف'
            : '$faceCount وجوه بشرية مكتشفة',
        'type': 'FACE',
        'count': faceCount,
      });
    }

    // تجميع الوثائق (فقط الحساسة منها)
    if (lastResult!['yolo_objects'] != null &&
        lastResult!['yolo_objects'].length > 0) {
      Map<String, int> docsByType = {};

      List<String> sensitiveDocTypes = [
        'id_card',
        'national_id',
        'passport',
        'driver_license',
        'residence_permit',
        'iqama',
        'birth_certificate',
        'health_card',
        'insurance_card',
        'credit_card',
        'bank_card',
        'car_plate',
        'credit_cards',
      ];

      for (var doc in lastResult!['yolo_objects']) {
        String docClass = doc['class'] ?? 'document';
        String normalized = docClass.toLowerCase().replaceAll(' ', '_');

        if (sensitiveDocTypes.contains(normalized)) {
          String arabicName = _translateDocumentClass(docClass);
          docsByType[arabicName] = (docsByType[arabicName] ?? 0) + 1;
        }
      }

      docsByType.forEach((docClass, count) {
        String icon = docClass == 'لوحة سيارة' ? 'directions_car' : 'badge';
        String type = docClass == 'لوحة سيارة' ? 'CAR_PLATE' : 'DOCUMENT';

        items.add({
          'icon': icon,
          'text': count == 1 ? docClass : '$docClass ($count)',
          'type': type,
          'count': count,
        });
      });
    }

    return items;
  }

  // الحصول على إحداثيات البوكسات
  Map<String, List<Map<String, dynamic>>> getBoxes() {
    if (lastResult == null) {
      return {'faces': [], 'documents': [], 'barcodes': []};
    }

    return {
      'faces': List<Map<String, dynamic>>.from(lastResult!['yolo_faces'] ?? []),
      'documents': List<Map<String, dynamic>>.from(
        lastResult!['yolo_objects'] ?? [],
      ),
      'barcodes': List<Map<String, dynamic>>.from(
        lastResult!['barcodes'] ?? [],
      ),
    };
  }

  // ترجمة أسماء الوثائق من الإنجليزي للعربي
  String _translateDocumentClass(String docClass) {
    Map<String, String> translations = {
      'credit_card': 'بطاقة ائتمانية',
      'bank_card': 'بطاقة بنكية',
      'id_card': 'بطاقة هوية',
      'passport': 'جواز سفر',
      'car_plate': 'لوحة سيارة',
    };

    String normalized = docClass.toLowerCase().replaceAll(' ', '_');

    // تحويل الجمع إلى مفرد
    if (normalized.endsWith('s')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return translations[normalized] ?? docClass;
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
      'CAR_PLATE': 'car',
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
      'CAR_PLATE': 'لوحة سيارة',
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
    print(lastResult);

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
  ImageScanResult({required this.isClean});
}

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

class ScanStats {
  int safe;
  int vuln;
  int total;

  ScanStats({this.safe = 0, this.vuln = 0, this.total = 0});

  recordSafe() {
    safe++;
    total++;
  }

  recordVuln() {
    vuln++;
    total++;
  }
}
