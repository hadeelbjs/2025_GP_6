import 'package:flutter/material.dart';
import 'package:waseed/shared/widgets/bottom_nav_bar.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/search_bar.dart' as custom;
import '../../../services/messaging_service.dart';
import '../../../services/api_services.dart';
import 'breach_lookup.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({Key? key}) : super(key: key);

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final _messagingService = MessagingService();
  final _apiService = ApiService();

  final List<Map<String, dynamic>> _allServices = [
    {
      'title': ' التحقق من أمان المحتوى',
      'description': 'التحقق من أمان الروابط أو رموز الـ QR أو الملفات',
      'icons': [Icons.link, Icons.file_copy_rounded, Icons.qr_code],
      'color': const Color.fromARGB(198, 40, 27, 103),
      'route': '/content-scan',
    },
    {
      'title': 'كشف البيانات الحساسة في الصور',
      'description': 'افحص صورك قبل المشاركة للتأكد من خصوصيتك',
      'icons': [Icons.image],
      'color': const Color.fromARGB(198, 40, 27, 103),
      'route': '/image-scanner',
    },
    {
      'title': 'مساعدك الذكي',
      'description': 'تحدث مع المساعد للحصول على نصائح أمنية وإرشادات',
      'icons': [Icons.chat_bubble],
      'color': const Color.fromARGB(198, 40, 27, 103),
      'route': '/chatbot',
    },
    {
      'title': 'مولّد كلمات المرور',
      'description': 'أنشئ كلمات مرور قوية وعشوائية تساعدك على حماية حساباتك',
      'icons': [Icons.key_rounded],
      'color': const Color.fromARGB(198, 40, 27, 103),
      'route': '/password_generator',
    },
    {
      'title': 'كشف تسريب بياناتك',
      'description': 'تحقق إذا تم تسريب بريدك أو كلمة مرورك',
      'icons': [Icons.manage_search_rounded],
      'color': const Color.fromARGB(198, 40, 27, 103),
      'route': '/breach-lookup',
    },
  ];

  List<Map<String, dynamic>> _filteredServices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _filteredServices = _allServices;
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
          await _requestAllContactsStatus();
        } else {
          print('❌ Failed to connect socket after resume');
        }
      } else {
        print('✅ Socket already connected');
        await _requestAllContactsStatus();
      }
    } catch (e) {
      print('❌ Error ensuring socket connection: $e');
    }
  }

  //  طلب الحالة لجميع جهات الاتصال
  Future<void> _requestAllContactsStatus() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_messagingService.isConnected) {
        print('⚠️ Socket not connected, skipping status requests');
        return;
      }

      final result = await _apiService.getContactsList();

      if (result['success'] == true && result['contacts'] != null) {
        final contacts = result['contacts'] as List;
        print(' Requesting status for ${contacts.length} contacts...');

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
        _filteredServices = _allServices;
      } else {
        final searchLower = query.trim().toLowerCase();

        final matches = _allServices.where((service) {
          final title = service['title'].toString().toLowerCase();
          final description = service['description'].toString().toLowerCase();
          return title.contains(searchLower) ||
              description.contains(searchLower);
        }).toList();

        _filteredServices = matches;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _filteredServices.isEmpty
                      ? _buildNoResults()
                      : ListView.builder(
                          key: ValueKey(_filteredServices.length),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          itemCount: _filteredServices.length,
                          itemBuilder: (context, index) =>
                              _buildServiceCard(_filteredServices[index]),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: BottomNavBar(currentIndex: 2),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, service['route']),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 155,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: service['color'],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (service['icons'] as List<IconData>)
                    .map(
                      (icon) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text(
                service['title'],
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  service['description'],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ابدأ الخدمة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off_rounded, size: 70, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        const Text(
          'لم يتم العثور على هذه الخدمة',
          style: TextStyle(color: Colors.grey, fontFamily: 'IBMPlexSansArabic'),
        ),
      ],
    );
  }
}
