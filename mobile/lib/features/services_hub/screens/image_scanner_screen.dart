import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/colors.dart';

class ImageScannerScreen extends StatefulWidget {
  const ImageScannerScreen({Key? key}) : super(key: key);

  @override
  State<ImageScannerScreen> createState() => _ImageScannerScreenState();
}

enum _ScanState { initial, preview, scanning, result }

class _ImageScannerScreenState extends State<ImageScannerScreen> {
  File? _selectedImage;
  _ScanState _currentState = _ScanState.initial;
  final ImagePicker _picker = ImagePicker();
  bool _isSafe = true;

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _currentState = _ScanState.preview;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _currentState = _ScanState.preview;
        });
      }
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  void _startScan() {
    setState(() {
      _currentState = _ScanState.scanning;
    });
    
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _currentState = _ScanState.result;
        _isSafe = true; // غيري لـ false لاختبار الحالة غير الآمنة
      });
    });
  }

  void _changeImage() {
    setState(() {
      _selectedImage = null;
      _currentState = _ScanState.initial;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: true,
          title: Text(
            _getTitle(),
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  String _getTitle() {
    switch (_currentState) {
      case _ScanState.initial:
        return 'كشف البيانات الحساسة';
      case _ScanState.preview:
        return 'معاينة الصورة';
      case _ScanState.scanning:
        return 'جاري الفحص...';
      case _ScanState.result:
        return 'نتيجة الفحص';
    }
  }

  Widget _buildBody() {
    switch (_currentState) {
      case _ScanState.initial:
        return _buildInitialState();
      case _ScanState.preview:
        return _buildPreviewState();
      case _ScanState.scanning:
        return _buildScanningState();
      case _ScanState.result:
        return _buildResultState();
    }
  }

Widget _buildInitialState() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          size: 50,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'اختر مصدر الصورة',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تنسيقات JPG و PNG مدعومة',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // زر المعرض (Primary)
                InkWell(
                  onTap: _pickFromGallery,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'من المعرض',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // الخط الفاصل
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text(
                        'أو',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                  ],
                ),

                const SizedBox(height: 15),

                InkWell(
                  onTap: _pickFromCamera,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'التقط صورة جديدة',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewState() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "الصورة المحددة:",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontFamily: "IBMPlexSansArabic",
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 15),
                
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: 300,
                    maxHeight: 400,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                Center(
                  child: TextButton.icon(
                    onPressed: _changeImage,
                    icon: Icon(Icons.refresh, size: 18),
                    label: Text(
                      'تغيير الصورة',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        Container(
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 3,
            ),
            onPressed: _startScan,
            icon: Icon(Icons.search_rounded, size: 22),
            label: Text(
              'ابدأ الفحص الآن',
              style: TextStyle(
                color: Colors.white,
                fontFamily: "IBMPlexSansArabic",
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(50),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 5,
              ),
            ),
          ),
          SizedBox(height: 35),
          Text(
            'جاري فحص الصورة',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'الرجاء الانتظار...',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildResultState() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "الصورة المفحوصة:",
          style: TextStyle(
            fontSize: 16,
            color: AppColors.primary,
            fontFamily: "IBMPlexSansArabic",
            fontWeight: FontWeight.w500,
          ),
        ),
        
        SizedBox(height: 15),
        
        Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        
        SizedBox(height: 30),
        
        // نتيجة الفحص - Alert Style
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isSafe ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _isSafe ? Colors.green[300]! : Colors.red[300]!,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isSafe ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSafe ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSafe ? 'آمنة للمشاركة' : 'معلومات حساسة!',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isSafe ? Colors.green[800] : Colors.red[800],
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      _isSafe
                          ? 'لم يتم اكتشاف معلومات حساسة'
                          : 'يُنصح بعدم مشاركة هذه الصورة',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 14,
                        color: _isSafe ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 25),
        
        if (!_isSafe) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red[200]!,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[700], size: 22),
                    SizedBox(width: 10),
                    Text(
                      'المعلومات المكتشفة:',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                _buildDetectedItem(Icons.credit_card, 'رقم بطاقة ائتمانية'),
                _buildDetectedItem(Icons.account_balance, 'رقم حساب بنكي (IBAN)'),
                _buildDetectedItem(Icons.badge, 'رقم هوية وطنية'),
              ],
            ),
          ),
          SizedBox(height: 25),
        ],
        
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 3,
          ),
          onPressed: _changeImage,
          icon: Icon(Icons.refresh_rounded, size: 22),
          label: Text(
            'فحص صورة أخرى',
            style: TextStyle(
              color: Colors.white,
              fontFamily: "IBMPlexSansArabic",
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildDetectedItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.red[700]),
          SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 15,
              color: Colors.red[800],
            ),
          ),
        ],
      ),
    );
  }
}