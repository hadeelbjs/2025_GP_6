import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:qr_code_tools/qr_code_tools.dart';

class QRScreen extends StatefulWidget {
  const QRScreen({Key? key}) : super(key: key);
  
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;
  bool _isScanning = false;
  String? _scannedResult;

  void _removeImage() {
    setState(() {
      _selectedFile = null;
      _scannedResult = null;
    });
  }
  Future<BarcodeCapture?> analyzeImage(String path) {
    return MobileScannerPlatform.instance.analyzeImage(path);
  }

  // دالة فحص الصورة من الألبوم
  Future<void> _scanImageFromGallery() async {
    if (_selectedFile == null) return;

    setState(() {
      _isScanning = true;
      _scannedResult = null;
    });

    try {
     _scannedResult = await QrCodeToolsPlugin.decodeFrom(_selectedFile!.path);
      if (_scannedResult != null) {
        
        _handleScannedCode(_scannedResult!);
      } else {
        _showErrorDialog('لم يتم العثور على رمز QR في الصورة.');
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء المسح: ${e.toString()}');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // دالة فتح الكاميرا مباشرة (Mobile Scanner)
  Future<void> _openCameraScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraScannerScreen(),
      ),
    );

    if (result != null && result is String) {
      _handleScannedCode(result);
    }
  }

  // معالجة الكود الممسوح (مشتركة بين الطريقتين)
  void _handleScannedCode(String code) {
    if (_isValidUrl(code)) {
      setState(() {
        _scannedResult = code;
      });
      _showResultDialog(code, isUrl: true);
    } else {
      setState(() {
        _scannedResult = code;
      });
      _showResultDialog(code, isUrl: false);
    }
  }

  bool _isValidUrl(String text) {
    final uri = Uri.tryParse(text);
    return uri != null && 
           uri.hasScheme && 
           (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _openUrl(String url) async {
    try {
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

  void _showResultDialog(String result, {required bool isUrl}) {
    showDialog(
      context: context,
      builder: (context) => Directionality( textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(
              isUrl ? Icons.check_circle : Icons.info,
              color: isUrl ? Colors.green : Colors.orange,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                isUrl ? 'تم العثور على رابط' : 'محتوى الرمز',
                style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUrl)
              Text(
                'الرابط آمن ✓',
                style: TextStyle(
                  color: Colors.green,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                ),
              ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                result,
                style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          if (isUrl)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openUrl(result);
              },
              icon: Icon(Icons.open_in_browser),
              label: Text('فتح الرابط', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: AppColors.primary),
            ),
          ),
        ],
      ),
    )
    );
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

  Future<void> pickImageSource() async {
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
                
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primary, size: 30),
                  title: const Text(
                    'الكاميرا',
                    style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openCameraScanner();
                  },
                ),
                
                const Divider(),
                
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppColors.primary, size: 30),
                  title: const Text(
                    'الألبوم',
                    style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16),
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
                        _scannedResult = null;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 10),
                
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Text(
              "التقط صورة للرمز أو اختر صورة الرمز من ألبوم الصور:",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primary,
                fontFamily: "IBMPlexSansArabic",
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
              ),
              onPressed: pickImageSource,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('اختر من هنا'),
                  SizedBox(width: 10),
                  Icon(Icons.qr_code_scanner),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            if (_selectedFile != null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _selectedFile!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 5,
                      left: 5,
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: _removeImage,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            if (_selectedFile != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: Size(double.infinity, 45),
                ),
                onPressed: _isScanning ? null : _scanImageFromGallery,
                child: _isScanning
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'جاري المسح...',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: "IBMPlexSansArabic",
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'إرسال',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: "IBMPlexSansArabic",
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

// شاشة الكاميرا المباشرة (Mobile Scanner)
class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({Key? key}) : super(key: key);

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'مسح رمز QR',
          style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_isScanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() {
                    _isScanned = true;
                  });
                  
                  Navigator.pop(context, barcode.rawValue);
                  return;
                }
              }
            },
          ),
          
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              'ضع رمز QR داخل الإطار',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}