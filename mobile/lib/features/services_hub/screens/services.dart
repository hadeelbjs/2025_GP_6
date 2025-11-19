import 'package:flutter/material.dart';
import 'package:waseed/shared/widgets/bottom_nav_bar.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/search_bar.dart' as custom;
import '../../../services/messaging_service.dart';
import '../../../services/api_services.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({Key? key}) : super(key: key);

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final _messagingService = MessagingService();
  final _apiService = ApiService();
  
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
    WidgetsBinding.instance.addObserver(this);
    _filteredServices = _allServices; // عرض جميع الخدمات في البداية
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  //  مراقبة lifecycle للتطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed from Services - reconnecting socket...');
      _ensureSocketConnection();
    } else if (state == AppLifecycleState.paused) {
      print('⏸️ App paused from Services');
    }
  }

  //  التأكد من الاتصال بالـ Socket وطلب الحالة لجميع جهات الاتصال
  Future<void> _ensureSocketConnection() async {
    try {
      if (!_messagingService.isConnected) {
        print('🔌 Socket not connected - initializing...');
        final success = await _messagingService.initialize();
        if (success) {
          print('✅ Socket connected after resume');
          //  طلب الحالة لجميع جهات الاتصال بعد الاتصال
          await _requestAllContactsStatus();
        } else {
          print('❌ Failed to connect socket after resume');
        }
      } else {
        print('✅ Socket already connected');
        //  حتى لو كان متصل، نطلب الحالة عند العودة للتطبيق
        await _requestAllContactsStatus();
      }
    } catch (e) {
      print('❌ Error ensuring socket connection: $e');
    }
  }

  //  طلب الحالة لجميع جهات الاتصال
  Future<void> _requestAllContactsStatus() async {
    try {
      // انتظر قليلاً للتأكد من اكتمال الاتصال
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!_messagingService.isConnected) {
        print('⚠️ Socket not connected, skipping status requests');
        return;
      }

      // جلب قائمة جهات الاتصال
      final result = await _apiService.getContactsList();
      
      if (result['success'] == true && result['contacts'] != null) {
        final contacts = result['contacts'] as List;
        print(' Requesting status for ${contacts.length} contacts...');
        
        // طلب الحالة لكل جهة اتصال
        for (var contact in contacts) {
          final contactId = contact['id']?.toString();
          if (contactId != null) {
            _messagingService.requestUserStatus(contactId);
          }
        }
        
        print('✅ Status requests sent for all contacts');
      }
    } catch (e) {
      print('❌ Error requesting contacts status: $e');
    }
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
  return InkWell(
    onTap: () {
      // الانتقال للصفحة
      Navigator.pushNamed(context, service['route']);
    },
    borderRadius: BorderRadius.circular(15),
    child: Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: service['color'],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 230,
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
            const SizedBox(height: 20),
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
            const SizedBox(height: 25),
            // نص "انقر هنا للبدء"
            
             Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'انقر هنا للبدء',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.start,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
             )]
             )
             )
        
    ),
  );
}
}