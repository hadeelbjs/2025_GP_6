/*import 'package:flutter/material.dart';
import '../widgets/contact_search_bar.dart';
import '../widgets/contact_card.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import 'add_contact_screen.dart';

class ContactsListScreen extends StatefulWidget {
  const ContactsListScreen({super.key});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  final List<Map<String, String>> _contacts = [
    {'name': 'عبد الرحمن الجابر'},
    {'name': 'ليلى الحسيني'},
    {'name': 'يوسف عبدالله'},
    {'name': 'سارة العتيبي'},
  ];

  late List<Map<String, String>> _results;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _results = List.of(_contacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String q) {
    setState(() {
      _query = q;
      final nq = _normalize(q);

      if (nq.isEmpty) {
        _results = List.of(_contacts);
      } else {
        _results = _contacts.where((c) {
          final name = c['name'] ?? '';
          return _normalize(name).contains(nq);
        }).toList();
      }
    });
  }

  void _deleteByName(String name) {
    setState(() {
      _contacts.removeWhere((c) => c['name'] == name);
      _results.removeWhere((c) => c['name'] == name);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم حذف $name',
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _normalize(String s) {
    var t = s.trim().toLowerCase();

    t = t
        .replaceAll('\u0640', '')
        .replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '');

    t = t
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');

    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (int i = 0; i < 10; i++) {
      t = t.replaceAll(arabicDigits[i], i.toString());
    }

    return t;
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false, 
        body: SafeArea(
          child: Column(
            children: [
              const HeaderWidget(
                title: 'جهات الاتصال',
                showBackground: true,
                alignTitleRight: true,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: ContactSearchBar(
                  controller: _searchController,
                  onChanged: _filter,
                  onSearch: _filter,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddContactScreen(),
                          ),
                        );

                        if (result != null && result['name'] != null) {
                          setState(() {
                            _contacts.insert(0, {
                              'name': result['name'] as String,
                            });
                            _filter(_query);
                          });

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تمت إضافة ${result['name']}',
                                textAlign: TextAlign.right,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('إضافة صديق', style: AppTextStyles.buttonMedium),
                          const SizedBox(width: 8),
                          const Icon(Icons.person_add, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                _contacts.isEmpty && _query.isEmpty
                                    ? 'لا توجد جهات اتصال'
                                    : 'لا توجد نتائج',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final contact = _results[index];
                              final name = contact['name'] ?? '';

                              return ContactCard(
                                name: name,
                                onDelete: () => _deleteByName(name),
                              );
                            },
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              isKeyboardVisible
                ? const SizedBox.shrink()
                : const BottomNavBar(currentIndex: 1)
            ],
          ),
        ),
        
      ),
    );
  }
}*/import 'package:flutter/material.dart';
import '../widgets/contact_search_bar.dart';
import '../widgets/contact_card.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import 'add_contact_screen.dart';
import '../../../services/api_services.dart';

class ContactsListScreen extends StatefulWidget {
  const ContactsListScreen({super.key});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _results = [];
  final _searchController = TextEditingController();
  String _query = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    try {
      final result = await _apiService.getContactsList();

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _contacts = List<Map<String, dynamic>>.from(
            result['contacts'].map((contact) => {
              'id': contact['id'],
              'name': contact['name'],
              'username': contact['username'],
              'addedAt': contact['addedAt'],
            }),
          );
          _results = List.of(_contacts);
        });
      } else {
        _showMessage(result['message'] ?? 'فشل تحميل جهات الاتصال', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في تحميل جهات الاتصال', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filter(String q) {
    setState(() {
      _query = q;
      final nq = _normalize(q);

      if (nq.isEmpty) {
        _results = List.of(_contacts);
      } else {
        _results = _contacts.where((c) {
          final name = c['name'] ?? '';
          return _normalize(name).contains(nq);
        }).toList();
      }
    });
  }

  Future<void> _deleteContact(String contactId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف صديق', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
          content: Text(
            'هل أنت متأكد من حذف $name من جهات الاتصال؟',
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _apiService.deleteContact(contactId);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _contacts.removeWhere((c) => c['id'] == contactId);
          _results.removeWhere((c) => c['id'] == contactId);
        });
        _showMessage(result['message'] ?? 'تم حذف $name', true);
      } else {
        _showMessage(result['message'] ?? 'فشل الحذف', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في الحذف', false);
    }
  }

  String _normalize(String s) {
    var t = s.trim().toLowerCase();
    t = t.replaceAll('\u0640', '').replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '');
    t = t.replaceAll(RegExp(r'[أإآ]'), 'ا').replaceAll('ى', 'ي').replaceAll('ة', 'ه').replaceAll('ؤ', 'و').replaceAll('ئ', 'ي');
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (int i = 0; i < 10; i++) {
      t = t.replaceAll(arabicDigits[i], i.toString());
    }
    return t;
  }

  void _showMessage(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              const HeaderWidget(
                title: 'جهات الاتصال',
                showBackground: true,
                alignTitleRight: true,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: ContactSearchBar(
                  controller: _searchController,
                  onChanged: _filter,
                  onSearch: _filter,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddContactScreen()),
                        );

                        if (result == true) {
                          _loadContacts();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('إضافة صديق', style: AppTextStyles.buttonMedium),
                          const SizedBox(width: 8),
                          const Icon(Icons.person_add, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : _results.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.contacts_outlined,
                                        size: 64,
                                        color: AppColors.textHint.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _contacts.isEmpty && _query.isEmpty
                                            ? 'لا توجد جهات اتصال'
                                            : 'لا توجد نتائج',
                                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                                      ),
                                      if (_contacts.isEmpty && _query.isEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'ابدأ بإضافة أصدقاء جدد',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadContacts,
                                color: AppColors.primary,
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  itemCount: _results.length,
                                  itemBuilder: (context, index) {
                                    final contact = _results[index];
                                    final name = contact['name'] ?? '';
                                    final contactId = contact['id'] ?? '';

                                    return ContactCard(
                                      name: name,
                                      onDelete: () => _deleteContact(contactId, name),
                                    );
                                  },
                                ),
                              ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              isKeyboardVisible ? const SizedBox.shrink() : const BottomNavBar(currentIndex: 1),
            ],
          ),
        ),
      ),
    );
  }
}