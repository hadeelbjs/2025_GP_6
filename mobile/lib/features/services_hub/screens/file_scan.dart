import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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


  
  void _handelScan() {
    // هنا تضع منطق الفحص
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
