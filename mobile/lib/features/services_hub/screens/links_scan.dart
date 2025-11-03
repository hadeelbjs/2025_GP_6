import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class LinksScreen extends StatefulWidget {
  const LinksScreen({Key? key}) : super(key: key);
  
  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _linkController = TextEditingController();
  File? _selectedFile;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  // حذف الصورة
  void _removeImage() {
    setState(() {
      _selectedFile = null;
    });
  }

  // منطق الفحص
  void _handleScan() {
    if (_linkController.text.isNotEmpty || _selectedFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري فحص الرابط...'),
          backgroundColor: Colors.green,
        ),
      );
      // هنا تضع منطق الفحص الفعلي
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال رابط أو اختيار صورة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // اختيار صورة
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              
              // العنوان الأول
              const Text(
                "ادخل/الصق الرابط هنا:",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.primary,
                  fontFamily: "IBMPlexSansArabic",
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 15),
              
              // حقل إدخال الرابط
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8F0),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _linkController,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 15,
                  ),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // النص الثاني
              const Text(
                "أو ادخل صورة تحتوي على الرابط مكتوباً بها:",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.primary,
                  fontFamily: "IBMPlexSansArabic",
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 15),
              
              // عرض الصورة المختارة
              if (_selectedFile != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _selectedFile!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 5,
                        left: 5,
                        child: IconButton(
                          onPressed: _removeImage,
                          icon: const Icon(Icons.close, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // زر اختيار الصورة
              SizedBox(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: pickImage,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(width: 10),
                      Text(
                        'اختر من هنا',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.image, size: 24),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),

              // زر الإرسال
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _handleScan,
                  child: const Text(
                    'إرسال',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: "IBMPlexSansArabic",
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}