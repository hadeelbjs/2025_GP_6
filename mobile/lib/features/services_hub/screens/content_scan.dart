import 'dart:math';

import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'qr_scan.dart';
import 'file_scan.dart';
import 'links_scan.dart';
class ContentScanScreen extends StatelessWidget {
  const ContentScanScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return 
        DefaultTabController(
      length: 3,
       child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: true,

          title: const Text(
            'التحقق من أمان المحتوى',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(120),
            child: Column(
              children: [
                SizedBox(
                  height: 1,
                ),  
                // النص التوضيحي
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Align (
                      alignment: Alignment.centerRight,
                      child: Text(
                    'اختر نوع المحتوى المراد فحصه:',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      
                    ),))

                  ),
                ), Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                
                // الـ Indicator (الخلفية المتحركة)
                indicator: BoxDecoration(
                  color:  AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),

                indicatorPadding: const EdgeInsets.symmetric(horizontal: -20, vertical: 0),
                
                // الألوان
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                
                // النصوص
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'IBMPlexSansArabic',
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                
                // إخفاء الخط الافتراضي
                dividerColor: Colors.transparent,
                
                // التابات
                tabs: const [
                  Tab(
                    icon: Icon(Icons.link, size: 22),
                    text: 'رابط',
                    height: 50,
                  ),
                  Tab(
                    icon: Icon(Icons.file_copy_rounded, size: 22),
                    text: 'ملف',
                    height: 50,
                  ),
                  Tab(
                    icon: Icon(Icons.qr_code, size: 22),
                    text: ' رمز QR',
                    height: 50,
                  ),
                ],
              ),
            ),])
          ),
        ),
        body: 
        Column(
          children: [
            
            const SizedBox(height: 10),
            Expanded(
              child:
                const TabBarView(
                  children: [
                    LinksScreen(),
                    FilesScreen(),
                    QRScreen(),
                  ],
                ),
            ),
          ]
         )
         )
      )
    );
  }
}
