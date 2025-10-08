import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';


class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  // جلب قائمة الأصدقاء من Backend
  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // استبدلي بـ IP السيرفر والتوكن
      final response = await http.get(
        Uri.parse('http://YOUR_SERVER_IP:3000/api/contacts/list'),
        headers: {
          'Authorization': 'Bearer YOUR_TOKEN', // أو: await AuthService.getToken()
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(
            data['contacts'].map((contact) => {
              'id': contact['id'],
              'name': contact['name'],
              'username': contact['username'],
              'avatarColor': _getRandomColor(contact['name']),
            }),
          );
        });
      }
    } catch (e) {
      _showMessage('خطأ في تحميل المحادثات', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // توليد لون عشوائي بناءً على الاسم (ثابت لنفس الشخص)
  Color _getRandomColor(String name) {
    final colors = [
      const Color(0xFFB39DDB), // بنفسجي
      const Color(0xFF81C784), // أخضر
      const Color(0xFFFF8A65), // برتقالي
      const Color(0xFFF06292), // وردي
      const Color(0xFF64B5F6), // أزرق
      const Color(0xFFFFD54F), // أصفر
    ];
    
    // استخدام hash code للاسم لإعطاء لون ثابت
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }

  void _showMessage(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
              // Header
              const HeaderWidget(
                title: 'المحادثات',
                showBackground: true,
                alignTitleRight: true,
              ),

              const SizedBox(height: 10),

              // قائمة المحادثات
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
                        ? const Center(child: CircularProgressIndicator())
                        : _chats.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 64,
                                        color: AppColors.textHint.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'لا توجد محادثات',
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'أضف أصدقاء من جهات الاتصال لبدء المحادثة',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadChats,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  itemCount: _chats.length,
                                  separatorBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Divider(
                                      color: AppColors.textHint.withOpacity(0.1),
                                      height: 1,
                                      thickness: 1,
                                    ),
                                  ),
                                  itemBuilder: (context, index) {
                                    final chat = _chats[index];
                                    return _buildChatItem(chat);
                                  },
                                ),
                              ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Navigation Bar
              const BottomNavBar(currentIndex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final name = chat['name'] as String;
    final avatarColor = chat['avatarColor'] as Color;
    final userId = chat['id'] as String;

    final initial = name.isNotEmpty ? name[0] : '';

    return InkWell(
      onTap: () {
       _showMessage('سيتم فتح المحادثة مع $name', true);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // الصورة الرمزية
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: avatarColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: AppTextStyles.h3.copyWith(
                    color: avatarColor,
                    fontSize: 24,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 15),

            // الاسم
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${chat['username']}',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),

            // السهم
            Icon(
              Icons.chevron_left,
              color: AppColors.textHint.withOpacity(0.5),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}