import 'package:flutter/material.dart';
import '/shared/widgets/header_widget.dart';
import '../widgets/add_method_toggle.dart';
import '../widgets/username_field.dart';
import '../widgets/saudi_phone_field.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/api_services.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

enum AddMethod { username, phone }

class _AddContactScreenState extends State<AddContactScreen> {
  final _apiService = ApiService();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  AddMethod _method = AddMethod.username;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (_method == AddMethod.username) {
      final u = _usernameController.text.trim();
      return RegExp(
        r'^[\u0621-\u064A\u0660-\u0669\u06F0-\u06F9A-Za-z0-9._-]{3,}$',
      ).hasMatch(u);
    } else {
      final p = _phoneController.text.trim();
      return RegExp(r'^5\d{8}$').hasMatch(p);
    }
  }

  Future<void> _search() async {
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    final searchQuery = _method == AddMethod.username
        ? _usernameController.text.trim()
        : '+966${_phoneController.text.trim()}';

    try {
      final result = await _apiService.searchContact(searchQuery);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(result['users']);
        });

        if (_searchResults.isEmpty) {
          _showMessage('لم يتم العثور على نتائج', false);
        }
      } else {
        _showMessage(result['message'] ?? 'لم يتم العثور على نتائج', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في الاتصال بالسيرفر', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendRequest(String userId, String fullName) async {
    setState(() => _isLoading = true);

    try {
      final result = await _apiService.sendContactRequest(userId);

      if (!mounted) return;

      if (result['success']) {
        _showMessage(result['message'] ?? 'تم إرسال الطلب بنجاح', true);

        setState(() {
          final index = _searchResults.indexWhere((u) => u['id'] == userId);
          if (index != -1) {
            _searchResults[index]['relationshipStatus'] = 'pending';
            _searchResults[index]['isSentByMe'] = true;
          }
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showMessage(result['message'] ?? 'فشل إرسال الطلب', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في الاتصال', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const HeaderWidget(
                title: 'إضافة صديق جديد',
                showBackButton: true,
                showBackground: false,
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AddMethodToggle(
                          phoneSelected: _method == AddMethod.phone,
                          onSelectPhone: () => setState(() {
                            _method = AddMethod.phone;
                            _searchResults.clear();
                          }),
                          onSelectUsername: () => setState(() {
                            _method = AddMethod.username;
                            _searchResults.clear();
                          }),
                        ),

                        const SizedBox(height: 16),

                        if (_method == AddMethod.username)
                          UsernameField(
                            controller: _usernameController,
                            onChanged: (_) => setState(() {}),
                          )
                        else
                          SaudiPhoneField(
                            controller: _phoneController,
                            onChanged: (_) => setState(() {}),
                          ),

                        const SizedBox(height: 16),

                        ElevatedButton(
                          onPressed: _isValid && !_isLoading ? _search : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary
                                .withOpacity(0.4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text('بحث', style: AppTextStyles.buttonLarge),
                        ),

                        if (_searchResults.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),

                          ...List.generate(_searchResults.length, (index) {
                            final user = _searchResults[index];
                            final status = user['relationshipStatus'];
                            final isSentByMe = user['isSentByMe'] ?? false;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(
                                  user['fullName'],
                                  style: AppTextStyles.bodyLarge,
                                ),
                                subtitle: Text(
                                  '@${user['username']}',
                                  style: AppTextStyles.bodySmall,
                                ),
                                trailing: _buildActionButton(
                                  user['id'],
                                  user['fullName'],
                                  status,
                                  isSentByMe,
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String userId,
    String fullName,
    String? status,
    bool isSentByMe,
  ) {
    if (status == 'accepted') {
      return const Chip(
        label: Text('صديق بالفعل', style: TextStyle(fontSize: 12)),
        backgroundColor: Colors.green,
        labelStyle: TextStyle(color: Colors.white),
      );
    } else if (status == 'pending') {
      return Chip(
        label: Text(
          isSentByMe ? 'طلب معلق' : 'طلب وارد',
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: Colors.orange,
        labelStyle: const TextStyle(color: Colors.white),
      );
    } else {
      return ElevatedButton(
        onPressed: () => _sendRequest(userId, fullName),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('إضافة', style: TextStyle(fontSize: 12)),
      );
    }
  }
}
