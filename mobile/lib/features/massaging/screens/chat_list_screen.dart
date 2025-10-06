import 'package:flutter/material.dart';
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

  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'عبد الرحمن الجابر',
      'avatarColor': const Color(0xFFB39DDB),
    },
    {
      'name': 'ليلى الحسيني',
      'avatarColor': const Color(0xFF81C784),
    },
    {
      'name': 'يوسف عبدالله',
      'avatarColor': const Color(0xFFFF8A65),
    },
    {
      'name': 'سارة العتيبي',
      'avatarColor': const Color(0xFFF06292),
    },
  ];

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
                    child: _chats.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'لا توجد محادثات',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
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

              const SizedBox(height: 20),

              // Bottom Navigation Bar
           BottomNavBar(currentIndex: 3)

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final name = chat['name'] as String;
    final avatarColor = chat['avatarColor'] as Color;
    
    final initial = name.isNotEmpty ? name[0] : '';

    return InkWell(
      onTap: () {
        // Navigator.push(context, MaterialPageRoute(builder: (context) => ChatDetailScreen(name: name)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
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

            Expanded(
              child: Text(
                name,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            
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