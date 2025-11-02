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
  
  // قائمة جميع الخدمات
  final List<Map<String, dynamic>> _allServices = [
    {
      'title': ' التحقق من أمان المحتوى',
      'description': 'هذه الخدمة تسمح لك بالتحقق من أمان الروابط أو رموز الQR  أو الملفات',
      'icons': [Icons.link, Icons.file_copy_rounded, Icons.qr_code],
      'color': Color.fromARGB(198, 40, 27, 103),
      'route': '/content-scan'
    }
  ];
  
  // قائمة الخدمات المفلترة
  List<Map<String, dynamic>> _filteredServices = [];

  @override
  void initState() {
    super.initState();
    _filteredServices = _allServices; // عرض جميع الخدمات في البداية
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        // عرض جميع الخدمات
        _filteredServices = _allServices;
      } else {
        // تصفية الخدمات بناءً على النص المدخل
        _filteredServices = _allServices.where((service) {
          final title = service['title'].toString().toLowerCase();
          final description = service['description'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          
          return title.contains(searchLower) || description.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigationBar = BottomNavBar(currentIndex: 2);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Directionality(
          
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              const HeaderWidget(
                title: 'الخدمات',
                showBackground: true,
                alignTitleRight: true,
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
              
              // عرض عدد النتائج
              if (_searchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: Text(
                    'عدد النتائج: ${_filteredServices.length}',
                    style: const TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),

              const SizedBox(height: 15)
                ,
              
              // قائمة الخدمات المفلترة
              Expanded(
                child: _filteredServices.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 20),
                            Text(
                              'لا توجد خدمات مطابقة للبحث',
                              style: TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredServices.length,
                        itemBuilder: (context, index) {
                          final service = _filteredServices[index];
                          return _buildServiceCard(service);
                        },
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

  // بطاقة الخدمة
  Widget _buildServiceCard(Map<String, dynamic> service) {
    return GestureDetector(
      onTap: () {
      // الانتقال للصفحة
      Navigator.pushNamed(context, service['route']);
      
    },
      child: Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: service['color'],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: (service['icons'] as List<IconData>)
                .map((icon) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 40,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Text(
            service['title'],
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              service['description'],
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 14.5,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    )
    );
  }
}