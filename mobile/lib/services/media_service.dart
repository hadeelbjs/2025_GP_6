// lib/services/media_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'api_services.dart';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class MediaService {
  static final MediaService instance = MediaService._internal();
  factory MediaService() => instance;
  MediaService._internal();

  final ImagePicker _picker = ImagePicker();
  final ApiService _api = ApiService();

  static const int maxImageSizeKB = 800;     
  static const int imageQuality = 85;        
  static const int maxImageDimension = 1920; 
  static const int maxFileSizeMB = 50;     

  //  التقاط صورة من الكاميرا
  Future<MediaResult> captureFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // جودة عالية ثم نضغطها
      );

      if (image == null) {
        return MediaResult.cancelled();
      }

      return await _processImage(File(image.path));
    } catch (e) {
      debugPrint('❌ Camera error: $e');
      return MediaResult.error('فشل التقاط الصورة');
    }
  }

  //  اختيار صورة من المعرض
  Future<MediaResult> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) {
        return MediaResult.cancelled();
      }

      return await _processImage(File(image.path));
    } catch (e) {
      debugPrint('❌ Gallery error: $e');
      return MediaResult.error('فشل اختيار الصورة');
    }
  }

  //  اختيار ملف
 Future<MediaResult> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,  
      );

      if (result == null || result.files.isEmpty) {
        return MediaResult.cancelled();
      }
      
      final pickedFile = result.files.single;

      if (pickedFile.bytes == null) {
          return MediaResult.error('تعذر قراءة محتوى الملف. حاول اختيار ملف مخزن محلياً.');
      }


    final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(tempDir.path, pickedFile.name);
      
      final file = await File(tempPath).writeAsBytes(pickedFile.bytes!);
      
      final fileSize = pickedFile.size;
      final fileName = pickedFile.name;


      if (fileSize > maxFileSizeMB * 1024 * 1024) {
        return MediaResult.error(
          'الملف كبير جداً (الحد الأقصى ${maxFileSizeMB}MB)',
        );
      }

     // debugPrint('📄 File selected: $fileName (${(fileSize / 1024).toStringAsFixed(1)} KB)');

      return MediaResult.success(
        file: file,
        fileName: fileName,
        fileSize: fileSize,
        mediaType: MediaType.file,
      );
    } catch (e) {
      debugPrint('❌ File picker error: $e');
      return MediaResult.error('فشل اختيار الملف');
    }
  }
  //  معالجة وضغط الصورة
  Future<MediaResult> _processImage(File imageFile) async {
    try {
      final originalSize = await imageFile.length();
      debugPrint('📊 Original size: ${(originalSize / 1024).toStringAsFixed(1)} KB');

      // إذا كانت الصورة صغيرة، لا حاجة للضغط
      if (originalSize < maxImageSizeKB * 1024) {
        debugPrint('✅ Image already optimized');
        return MediaResult.success(
          file: imageFile,
          fileName: path.basename(imageFile.path),
          fileSize: originalSize,
          mediaType: MediaType.image,
        );
      }

      // ضغط الصورة
      final compressedFile = await _compressImage(imageFile);
      final compressedSize = await compressedFile.length();
      
      final ratio = ((1 - compressedSize / originalSize) * 100);
      //debugPrint('✅ Compressed: ${(compressedSize / 1024).toStringAsFixed(1)} KB (${ratio.toStringAsFixed(1)}% saved)');

      return MediaResult.success(
        file: compressedFile,
        fileName: path.basename(compressedFile.path),
        fileSize: compressedSize,
        mediaType: MediaType.image,
      );
    } catch (e) {
      debugPrint('❌ Image processing error: $e');
      return MediaResult.error('فشل معالجة الصورة');
    }
  }

  
  Future<File> _compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

     
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: imageQuality,
        minWidth: maxImageDimension,
        minHeight: maxImageDimension,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (result == null) {
        debugPrint('⚠️ Compression returned null, using original');
        return file;
      }

      final compressedFile = File(result.path);
      
      if (!await compressedFile.exists()) {
        debugPrint('⚠️ Compressed file does not exist, using original');
        return file;
      }

      final compressedSize = await compressedFile.length();
      
      if (compressedSize == 0) {
        debugPrint('⚠️ Compressed file is empty, using original');
        return file;
      }

      return compressedFile;
      
    } catch (e) {
      debugPrint('❌ Compression failed: $e, using original file');
      return file;
    }
  }

  //  رفع الصورة عبر HTTPS
 
  Future<UploadResult> uploadImage(File imageFile) async {
    try {
      debugPrint(' Uploading image via HTTPS...');
      
      final response = await _api.uploadImage(imageFile);
      if (response.containsKey('statusCode') && response['statusCode'] != 200) {
        debugPrint('❌ HTTP Upload Failed: Status ${response['statusCode']}, Message: ${response['message']}');
      }

      if (response['success']) {
        final url = response['url'] as String;
        final fullUrl = ApiService.getFullUrl(url);
        
        debugPrint('✅ Image uploaded: $fullUrl');
        
        return UploadResult.success(
          url: fullUrl,
          fileName: response['filename'],
          fileSize: response['size'],
        );
      }

      return UploadResult.error(response['message'] ?? 'فشل الرفع');
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return UploadResult.error('حدث خطأ في رفع الصورة');
    }
  }

  //  رفع الملف عبر HTTPS
  Future<UploadResult> uploadFile(File file) async {
    try {
      debugPrint(' Uploading file via HTTPS...');
      
      final response = await _api.uploadFile(file);

      if (response['success']) {
        final url = response['url'] as String;
        final fullUrl = ApiService.getFullUrl(url);
        
        debugPrint('✅ File uploaded: $fullUrl');
        
        return UploadResult.success(
          url: fullUrl,
          fileName: response['filename'],
          fileSize: response['size'],
        );
      }

      return UploadResult.error(response['message'] ?? 'فشل الرفع');
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return UploadResult.error('حدث خطأ في رفع الملف');
    }
  }

  Future<UploadResult> pickAndUploadImage({
    required ImageSource source,
  }) async {
    // اختيار الصورة
    final MediaResult mediaResult = source == ImageSource.camera
        ? await captureFromCamera()
        : await pickFromGallery();

    if (!mediaResult.success) {
      return UploadResult.error(mediaResult.errorMessage ?? 'فشل اختيار الصورة');
    }

    // رفع الصورة
    return await uploadImage(mediaResult.file!);
  }

  Future<UploadResult> pickAndUploadFile() async {
    //اختيار الملف
    final mediaResult = await pickFile();

    if (!mediaResult.success) {
      return UploadResult.error(mediaResult.errorMessage ?? 'فشل اختيار الملف');
    }

    // رفع الملف
    return await uploadFile(mediaResult.file!);
  }
}

//(Data Models)

enum MediaType { image, file }

class MediaResult {
  final bool success;
  final File? file;
  final String? fileName;
  final int? fileSize;
  final MediaType? mediaType;
  final String? errorMessage;

  MediaResult._({
    required this.success,
    this.file,
    this.fileName,
    this.fileSize,
    this.mediaType,
    this.errorMessage,
  });

  factory MediaResult.success({
    required File file,
    required String fileName,
    required int fileSize,
    required MediaType mediaType,
  }) {
    return MediaResult._(
      success: true,
      file: file,
      fileName: fileName,
      fileSize: fileSize,
      mediaType: mediaType,
    );
  }

  factory MediaResult.cancelled() {
    return MediaResult._(success: false);
  }

  factory MediaResult.error(String message) {
    return MediaResult._(success: false, errorMessage: message);
  }
}

/// نتيجة رفع الملف
class UploadResult {
  final bool success;
  final String? url;
  final String? fileName;
  final int? fileSize;
  final String? errorMessage;

  UploadResult._({
    required this.success,
    this.url,
    this.fileName,
    this.fileSize,
    this.errorMessage,
  });

  factory UploadResult.success({
    required String url,
    required String fileName,
    required int fileSize,
  }) {
    return UploadResult._(
      success: true,
      url: url,
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  factory UploadResult.error(String message) {
    return UploadResult._(success: false, errorMessage: message);
  }
}