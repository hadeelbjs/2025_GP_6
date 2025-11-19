import 'package:flutter/material.dart';
import '../widgets/contact_search_bar.dart';
import '../widgets/contact_card.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import 'add_contact_screen.dart';
import '../../../services/api_services.dart';
import '../../../services/messaging_service.dart';

class ContactsListScreen extends StatefulWidget {
  const ContactsListScreen({super.key});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> with WidgetsBindingObserver {
  final _apiService = ApiService();
  final _messagingService = MessagingService();
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  final _searchController = TextEditingController();
  String _query = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
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
    //  print('🔄 App resumed from ContactsList - reconnecting socket...');
      _ensureSocketConnection();
    } else if (state == AppLifecycleState.paused) {
    //  print('⏸️ App paused from ContactsList');
    }
  }

  //  التأكد من الاتصال بالـ Socket وطلب الحالة لجميع جهات الاتصال
  Future<void> _ensureSocketConnection() async {
    try {
      if (!_messagingService.isConnected) {
        print('🔌 Socket not connected - initializing...');
        final success = await _messagingService.initialize();
        if (success) {
         // print('✅ Socket connected after resume');
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

  // طلب الحالة لجميع جهات الاتصال
  Future<void> _requestAllContactsStatus() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!_messagingService.isConnected) {
        print('⚠️ Socket not connected, skipping status requests');
        return;
      }

      // جلب قائمة جهات الاتصال
      final result = await _apiService.getContactsList();
      
      if (result['success'] == true && result['contacts'] != null) {
        final contacts = result['contacts'] as List;
        print('Requesting status for ${contacts.length} contacts...');
        
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadContacts(),
      _loadPendingRequests(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContacts() async {
    try {
      final result = await _apiService.getContactsList();

      if (!mounted) return;

      if (result['success'] == true && result['contacts'] != null) {
        setState(() {
          _contacts = List<Map<String, dynamic>>.from(
            result['contacts'].map((contact) {
              return {
                'id': contact['id']?.toString() ?? '',
                'name': contact['name']?.toString() ?? 'غير معروف',
                'username': contact['username']?.toString() ?? '',
                'addedAt': contact['addedAt']?.toString() ?? '',
              };
            }),
          );
          _results = List.of(_contacts);
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final result = await _apiService.getPendingRequests();

      if (!mounted) return;

      if (result['success'] == true && result['requests'] != null) {
        setState(() {
          _pendingRequests = List<Map<String, dynamic>>.from(
            result['requests'].map((req) {
              return {
                'requestId': req['requestId']?.toString() ?? req['id']?.toString() ?? '',
                'userId': req['user']?['id']?.toString() ?? '',
                'fullName': req['user']?['fullName']?.toString() ?? 'مستخدم',
                'username': req['user']?['username']?.toString() ?? '',
                'createdAt': req['createdAt']?.toString() ?? '',
              };
            }),
          );
        });
      }
    } catch (e) {
      // Handle error silently
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

  Future<void> _acceptRequest(String? requestId, String? fullName) async {
    if (requestId == null || requestId.isEmpty) {
      _showMessage('خطأ: معرف الطلب غير صحيح', false);
      return;
    }

    try {
      final result = await _apiService.acceptContactRequest(requestId);

      if (!mounted) return;

      if (result['success']) {
        _showMessage('تم قبول طلب الصداقة من ${fullName ?? "المستخدم"}', true);
        await _loadData();
      } else {
        _showMessage(result['message'] ?? 'فشل قبول الطلب', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في قبول الطلب', false);
    }
  }

  Future<void> _rejectRequest(String? requestId, String? fullName) async {
    if (requestId == null || requestId.isEmpty) {
      _showMessage('خطأ: معرف الطلب غير صحيح', false);
      return;
    }

    try {
      final result = await _apiService.rejectContactRequest(requestId);

      if (!mounted) return;

      if (result['success']) {
        _showMessage('تم رفض طلب الصداقة من ${fullName ?? "المستخدم"}', true);
        setState(() {
          _pendingRequests.removeWhere((r) => r['requestId'] == requestId);
        });
      } else {
        _showMessage(result['message'] ?? 'فشل رفض الطلب', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في رفض الطلب', false);
    }
  }

  Future<void> _deleteContact(String contactId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'حذف صديق',
            style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
          content: Text(
            'هل أنت متأكد من حذف $name من جهات الاتصال؟',
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text(
                'حذف',
                style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
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
        _showMessage('تم حذف $name من جهات الاتصال', true);
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
        backgroundColor: AppColors.background,
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

              // ✅ Modern Pending Requests Section - Scrollable
              if (_pendingRequests.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.35,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.08),
                        AppColors.primary.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header (ثابت)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.notifications_active_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'طلبات الصداقة',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'لديك ${_pendingRequests.length} ${_pendingRequests.length == 1 ? "طلب جديد" : "طلبات جديدة"}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_pendingRequests.length}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // ✅ Scrollable List
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: 20,
                          ),
                          itemCount: _pendingRequests.length,
                          itemBuilder: (context, index) {
                            final req = _pendingRequests[index];
                            return _buildRequestCard(req);
                          },
                        ),
                      ),
                    ],
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
                            builder: (_) => const AddContactScreen(),
                          ),
                        );

                        if (result == true) {
                          _loadData();
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
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : _results.isEmpty
                            ? Center(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
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
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                        if (_contacts.isEmpty && _query.isEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'ابدأ بإضافة أصدقاء جدد',
                                            textAlign: TextAlign.center,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.textHint,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadData,
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

              isKeyboardVisible
                  ? const SizedBox.shrink()
                  : const BottomNavBar(currentIndex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final requestId = req['requestId'] as String?;
    final fullName = req['fullName'] as String? ?? 'مستخدم';
    final username = req['username'] as String? ?? 'غير معروف';

    if (requestId == null || requestId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primary,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '؟',
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(requestId, fullName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'قبول',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _rejectRequest(requestId, fullName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.close_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'رفض',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}