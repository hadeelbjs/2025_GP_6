import 'package:flutter/material.dart';
import '../widgets/header_widget.dart';
import '../widgets/add_method_toggle.dart';
import '../widgets/username_field.dart';
import '../widgets/saudi_phone_field.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

enum AddMethod { username, phone }

class _AddContactScreenState extends State<AddContactScreen> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  AddMethod _method = AddMethod.username;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (_method == AddMethod.username) {
      final u = _usernameController.text.trim();
      // يدعم عربية/إنجليزية
      return RegExp(
        r'^[\u0621-\u064A\u0660-\u0669\u06F0-\u06F9A-Za-z0-9._-]{3,}$',
      ).hasMatch(u);
    } else {
      final p = _phoneController.text.trim();
      // رقم سعودي محلي بعد +966: يبدأ بـ 5 ثم 8 أرقام = 9 خانات
      return RegExp(r'^5\d{8}$').hasMatch(p);
    }
  }

  void _submit() {
    if (!_isValid) return;

    final msg = (_method == AddMethod.username)
        ? 'تم إرسال طلب إضافة @${_usernameController.text.trim()}'
        : 'تم إرسال طلب إضافة الرقم +966${_phoneController.text.trim()}';

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
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
                          onSelectPhone: () =>
                              setState(() => _method = AddMethod.phone),
                          onSelectUsername: () =>
                              setState(() => _method = AddMethod.username),
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

                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _isValid ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary
                                .withOpacity(0.4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'إضافة',
                            style: AppTextStyles.buttonLarge,
                          ),
                        ),
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
}
