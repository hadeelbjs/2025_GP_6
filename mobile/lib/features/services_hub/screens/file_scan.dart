import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert'; 
import '../services/api_contentScanning.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({Key? key}) : super(key: key);
  @override
  State<FilesScreen> createState() => _FileScreenState();

}

class _FileScreenState extends State<FilesScreen> {
  final FilePicker _picker = FilePicker.platform;
  File? _selectedFile;
  String? _fileName;
  int? _fileSize;
  bool _isScanning = false;
  String? _scannedResult;
  final ApiContentService _apiService = ApiContentService();



  
  Future<void> _handelScan() async{
    if(_selectedFile != null){
      setState(() {
        _isScanning = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري فحص الملف...'),
          backgroundColor: Colors.green,
        ),
      );
      try {
      String hash = await createFileHash(_selectedFile);

      final scanResult = await _apiService.scanFile(hash);

      setState(() {
        _isScanning = false;
      });
      
      _showFileResultDialog(scanResult);

      } catch (e) {
      setState(() {
        _isScanning = false;
      });
      print('فشل فحص الملف: ${e.toString()}');
    }

    }
  }

  Future<String> createFileHash(File? file) async{
    if (file == null)
    return 'null';
    try {
    //قراءة الملف
    final bytes = await file.readAsBytes();

    //حساب الهاش  
    final digest = sha256.convert(bytes);

    //تحويل الهاش لنص
    String hash = digest.toString();

    return hash; 
    } catch (e) {
    throw Exception('فشل في حساب hash للملف: $e');
  }
  }
  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'png', 'jpeg'], // ✅ حدد الأنواع المسموحة
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = File(result.files.first.path!);
          _fileName = result.files.first.name;
          _fileSize = result.files.first.size;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    }
  }

  void _showFileResultDialog(FileScanResult result) {
  showDialog(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF3D2B5F),
                Color(0xFF2D1B4E),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                'نتائج التحليل',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 30),

              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    result.isSafe ? Icons.verified : Icons.warning,
                    size: 60,
                    color: result.isSafe 
                        ? Color(0xFF4CAF50) 
                        : Color(0xFFE53935),
                  ),
                ),
              ),
              SizedBox(height: 30),

              // Message
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        result.isSafe
                            ? 'لم يتم تسجيل هذا الملف حتى الآن كملف\nخبيث'
                            : 'تم تسجيل هذا الملف كملف خبيث\nيرجى الحذر ويتجنب استخدامه',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.8,
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // File info
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'اسم الملف: ${_selectedFile!.path.split('/').last}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            if (result.maliciousCount > 0 || 
                                result.suspiciousCount > 0 || 
                                result.harmlessCount > 0) ...[
                              SizedBox(height: 10),
                              Divider(color: Colors.white30),
                              SizedBox(height: 10),
                              _buildStatRow('خبيث', result.maliciousCount, Colors.red),
                              _buildStatRow('مشبوه', result.suspiciousCount, Colors.orange),
                              _buildStatRow('آمن', result.harmlessCount, Colors.green),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 30),

              // Close Button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
                child: Text(
                  'إغلاق',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildStatRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return  Directionality ( 
      textDirection: TextDirection.rtl  ,
      child: Padding ( 
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20), 
         Text("ادخل الملف: ", textAlign: TextAlign.right, style: TextStyle(fontSize: 16, color: AppColors.primary, fontFamily: "IBMPlexSansArabic", fontWeight: FontWeight.w500),),
         const SizedBox(height: 15),
         ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
           foregroundColor: AppColors.background
          ),
          onPressed: () {
            pickFile();
         }, child: Row ( 
          mainAxisSize: MainAxisSize.min,
          children: [ 
          Text('اختر من هنا') , 
          SizedBox(width: 10) , 
          Icon( Icons.file_open)
          ] 
         )
         ),
          const SizedBox(height: 40),

          _selectedFile != null ? ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: Size(double.infinity, 45),
            ),
            onPressed:() {_handelScan();} , 
            
            child: Text(' إرسال ', style: TextStyle(color: Colors.white, fontFamily: "IBMPlexSansArabic", fontWeight: FontWeight.w700, fontSize: 18),) ): Container(),
        ],
      
    )
    
    )
    );
  }

  
}
