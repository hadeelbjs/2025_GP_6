import 'dart:math';

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class QRScreen extends StatefulWidget {
  const QRScreen({Key? key}) : super(key: key);
  
  State<QRScreen> createState() => _QRScreenState();

}

class _QRScreenState extends State<QRScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;

  

  // حذف الصورة
  void _removeImage() {
    setState(() {
      _selectedFile = null;
    });
  }
  void _handelScan() {
    // هنا تضع منطق الفحص
  }
  Future<void> pickImage() async {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر مصدر الصورة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
              const SizedBox(height: 20),
              
              // خيار الكاميرا
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary, size: 30),
                title: const Text(
                  'الكاميرا',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? pickedFile = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      _selectedFile = File(pickedFile.path);
                    });
                  }
                },
              ),
              
              const Divider(),
              
              // خيار المعرض
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary, size: 30),
                title: const Text(
                  'الألبوم',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      _selectedFile = File(pickedFile.path);
                    });
                  }
                },
              ),
              
              const SizedBox(height: 10),
              
              // زر الإلغاء
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
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
         Text("التقط صورة للرمز أو اختر صورة الرمز من ألبوم الصور:", textAlign: TextAlign.right, style: TextStyle(fontSize: 16, color: AppColors.primary, fontFamily: "IBMPlexSansArabic", fontWeight: FontWeight.w500),),
         const SizedBox(height: 15),
         ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
           foregroundColor: AppColors.background
          ),
          onPressed: () {
            pickImage();
         }, child: Row ( 
          mainAxisSize: MainAxisSize.min,
          children: [ 
          Text('اختر من هنا') , 
          SizedBox(width: 10) , 
          Icon( Icons.image)
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
