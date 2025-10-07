import 'package:flutter/material.dart';
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
}