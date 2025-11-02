import 'package:flutter/material.dart';
import 'package:waseed/shared/widgets/bottom_nav_bar.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/search_bar.dart' as custom;
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({Key? key}) : super(key: key);

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    // filtering logic 
    print('Filtering with: $query');
  }

  @override
  Widget build(BuildContext context) {
    final navigationBar = BottomNavBar(currentIndex: 2);
    
    return Scaffold(
      backgroundColor: Colors.white,
      
      body: 
      SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
        child: Column(
          
          children: [
            Directionality(
              
              textDirection: TextDirection.rtl,
              child: const HeaderWidget(
                title: 'الخدمات',
                showBackground: true,
                alignTitleRight: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              child: custom.SearchBar(
                controller: _searchController,
                onChanged: _filter,
                onSearch: _filter,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 20),
              height: 220,
              width: 370,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: const Color.fromARGB(198, 40, 27, 103),
              ), 
              child: 
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [ 
                  SizedBox(height: 30),
                  Row (
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.link,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(width: 20)
                      ,
                      Icon(
                        Icons.file_copy_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(width: 20),
                      Icon(
                        Icons.qr_code,
                        color: Colors.white,
                        size: 40,
                      ),
                      
                
                ]
                ),
                SizedBox(height: 20)
                ,
                
                Text(
                  'فحص المحتوى',
                  style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 255, 255, 255), fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 30),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'هذه الخدمة تسمح لك بالتحقق من أمان الروابط أو رموز الQR  أو الملفات',
                  style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 14.5, color: Color.fromARGB(255, 255, 255, 255), fontWeight: FontWeight.w400), 
                  textAlign: TextAlign.center,
                  
                ),
                )
                


                ],
              ),
            ),
          ],
        ),
      ),
      
    ),
    bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: navigationBar,
      ),
    );
  }
}