import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class MediaService {
  static final MediaService instance = MediaService._internal();
  factory MediaService() => instance;
  MediaService._internal();

  final ImagePicker _picker = ImagePicker();


  static const int maxImageSizeKB = 500;      
  static const int imageQuality = 75;         
  static const int maxImageDimension = 1280;  
  static const int maxFileSizeMB = 10;        


  Future<MediaResult> captureFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, 
      );

      if (image == null) {
        return MediaResult.cancelled();
      }

      return await processImage(File(image.path));
    } catch (e) {
      debugPrint('❌ Camera error: $e');
      return MediaResult.error('فشل التقاط الصورة');
    }
  }


  Future<MediaResult> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) {
        return MediaResult.cancelled();
      }

      return await processImage(File(image.path));
    } catch (e) {
      debugPrint('❌ Gallery error: $e');
      return MediaResult.error('فشل اختيار الصورة');
    }
  }

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
        return MediaResult.error('تعذر قراءة محتوى الملف');
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

  Future<MediaResult> processImage(File imageFile) async {
    try {
      final originalSize = await imageFile.length();

      if (originalSize < maxImageSizeKB * 1024) {
        debugPrint('✅ Image already optimized, no compression needed');
        return MediaResult.success(
          file: imageFile,
          fileName: path.basename(imageFile.path),
          fileSize: originalSize,
          mediaType: MediaType.image,
        );
      }

      final compressedFile = await _compressImage(imageFile);
      final compressedSize = await compressedFile.length();

    

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

      if (!await compressedFile.exists() || await compressedFile.length() == 0) {
        print('⚠️ Invalid compressed file, using original');
        return file;
      }

      print('✅ Compression successful');
      return compressedFile;

    } catch (e) {
      print('❌ Compression failed: $e, using original');
      return file;
    }
  }

  Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      
      debugPrint('✅ File converted to Base64 (${(base64String.length / 1024).toStringAsFixed(1)} KB)');
      
      return base64String;
    } catch (e) {
      debugPrint('❌ Base64 encoding error: $e');
      rethrow;
    }
  }


  Future<File> base64ToFile(String base64String, String fileName) async {
    try {
      final bytes = base64Decode(base64String);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsBytes(bytes);
      
      debugPrint('✅ Base64 converted to file: ${file.path}');
      
      return file;
    } catch (e) {
      debugPrint('❌ Base64 decoding error: $e');
      rethrow;
    }
  }
}



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