import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_contentScanning.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LinksScreen extends StatefulWidget {
  const LinksScreen({Key? key}) : super(key: key);
  
  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _linkController = TextEditingController();
  File? _selectedFile;
  bool _isScanning = false;
  String? _scannedResult;
  ScanResult? _urlScanResult;
  ApiContentService _apiService = ApiContentService();

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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 10),
            Text('خطأ', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
          ],
        ),
        content: Text(message, style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً', style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: AppColors.primary)),
          ),
        ],
      ),
    );
  }


  // منطق الفحص
   Future<void>  _handleScan() async {
    String code = _linkController.text;
    if (code.isNotEmpty || _selectedFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري فحص الرابط...'),
          backgroundColor: Colors.green,
        ),
      );

      if (_selectedFile != null ) {

      await extractLinkFromImage(_selectedFile);
      code = _linkController.text;
      _linkController.text = '';

      }

      if (_isValidUrl(code)) {
      setState(() {
        _isScanning = true;
        _scannedResult = code;
        _urlScanResult = null;
      });
      
      try {
        final scanResult = await _apiService.scanURL(code);
        setState(() {
          _urlScanResult = scanResult;
          _isScanning = false;
        });
        _showResultDialog(code, isUrl: true);
      } catch (e) {
        setState(() {
          _isScanning = false;
        });
        _showErrorDialog('فشل فحص الرابط: ${e.toString()}');
      }
    } else {
      setState(() {
        _scannedResult = code;
        _urlScanResult = null;
      });
     // _showResultDialog(code, isUrl: false);
    }

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

  void _showResultDialog(String result, {required bool isUrl}) {
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
                  child: isUrl && _urlScanResult != null
                      ? Icon(
                          _urlScanResult!.isSafe 
                              ? Icons.verified 
                              : Icons.warning,
                          size: 60,
                          color: _urlScanResult!.isSafe 
                              ? Color(0xFF4CAF50) 
                              : Color(0xFFE53935),
                        )
                      : Icon(
                          Icons.info_outline,
                          size: 60,
                          color: Colors.orange,
                        ),
                ),
              ),
              SizedBox(height: 30),

              // Message
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (isUrl && _urlScanResult != null)
                        Text(
                          _urlScanResult!.isSafe
                              ? 'لم يتم تسجيل هذا الرابط حتى الآن كرابط\nخبيث وبإمكانك المتابعة مع الحذر من\nمشاركة معلومات شخصية لمن لا يحق\nله ذلك'
                              : 'تم تسجيل هذا الرمز كرابط خبيث\nيرجى الحذر وتجنب استخدامه',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 16,
                            color: Colors.white,
                            height: 1.8,
                          ),
                        )
                      else
                        Text(
                          'محتوى الرابط:\n$result',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 16,
                            color: Colors.white,
                            height: 1.8,
                          ),
                        ),
                      
                      // URL Display
                      if (isUrl) ...[
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: SelectableText(
                            result,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 30),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  
                  // Open Link Button (only for safe URLs)
                  if (isUrl && _urlScanResult?.isSafe == true) ...[
                    SizedBox(width: 15),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openUrl(result);
                      },
                      icon: Icon(Icons.open_in_browser, size: 18),
                      label: Text(
                        'فتح الرابط',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

bool _isValidUrl(String text) {
  // إزالة المسافات من البداية والنهاية
  text = text.trim();
  
  // إذا كان يحتوي على بروتوكول، تحقق منه
  if (text.contains('://')) {
    final uri = Uri.tryParse(text);
    return uri != null && 
           uri.hasScheme && 
           (uri.scheme == 'http' || uri.scheme == 'https');
  }
  
  final uri = Uri.tryParse('http://$text');
  if (uri == null) return false;
  
  // تحقق من وجود نقطة (.) للتأكد أنه domain صحيح
  // وأن لديه host صالح
  return uri.hasAuthority && 
         uri.host.isNotEmpty && 
         uri.host.contains('.');
}

  Future<void> _openUrl(String url) async {
  try {
    // إضافة https:// إذا لم يكن موجود
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorDialog('لا يمكن فتح الرابط');
    }
  } catch (e) {
    _showErrorDialog('خطأ في فتح الرابط');
  }
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
  
  Future<void> extractLinkFromImage(File? file) async {
  if (file == null) return;

  try {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(file);

    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    final String fullText = recognizedText.text;

    // Regex لاستخراج الروابط من النص
    final urlRegex = RegExp(
      r'((https?:\/\/)?[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}(\/\S*)?)',
      caseSensitive: false,
    );

    final match = urlRegex.firstMatch(fullText);

    if (match != null) {
      String foundUrl = match.group(0)!;

      // إذا الرابط ما فيه http نضيفه
      if (!foundUrl.startsWith("http")) {
        foundUrl = "http://$foundUrl";
      }

      setState(() {
        _linkController.text = foundUrl;
      });

      print("URL FOUND IN IMAGE: $foundUrl");
    } else {
      _showErrorDialog("لم يتم العثور على أي رابط داخل الصورة.");
    }

    await textRecognizer.close();
  } catch (e) {
    print("❌ Error extracting text: $e");
    _showErrorDialog("فشل استخراج الرابط من الصورة.");
  }

  setState(() {
    _isScanning = false;
  });
}

}