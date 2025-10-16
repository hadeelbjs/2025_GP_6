//lib/features/massaging/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/api_services.dart';
import '../../../services/crypto/signal_protocol_manager.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _apiService = ApiService();
  final _signalProtocolManager = SignalProtocolManager();
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);

    try {
      final result = await _apiService.getContactsList();

      if (!mounted) return;

      if (result['code'] == 'SESSION_EXPIRED' || 
          result['code'] == 'TOKEN_EXPIRED' ||
          result['code'] == 'NO_TOKEN') {
        _handleSessionExpired();
        return;
      }

      if (result['success']) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(
            result['contacts'].map(
              (contact) => {
                'id': contact['id'],
                'name': contact['name'],
                'username': contact['username'],
                'avatarColor': _getRandomColor(contact['name']),
              },
            ),
          );
        });
      } else {
        _showMessage(result['message'] ?? 'فشل تحميل المحادثات', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في تحميل المحادثات', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleSessionExpired() {
    _showMessage('انتهت صلاحية الجلسة، الرجاء تسجيل الدخول مرة أخرى', false);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    });
  }

  Color _getRandomColor(String name) {
    final colors = [
      const Color(0xFFB39DDB),
      const Color(0xFF81C784),
      const Color(0xFFFF8A65),
      const Color(0xFFF06292),
      const Color(0xFF64B5F6),
      const Color(0xFFFFD54F),
    ];

    final index = name.hashCode.abs() % colors.length;
    return colors[index];
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
              const HeaderWidget(
                title: 'المحادثات',
                showBackground: true,
                alignTitleRight: true,
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
                                color: AppColors.primary,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  itemCount: _chats.length,
                                  separatorBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
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
      onTap: () async {
        final signalManager = SignalProtocolManager();
        
        // 1. تهيئة أولاً
        await signalManager.initialize();
        
        //  2. تحقق من وجود Keys
        try {
          await signalManager.generateAndUploadKeys();
          print('✅ Keys ready');
        } catch (e) {
          print('⚠️ Keys might already exist: $e');
        }
        
        // 3. التحقق من وجود Session
        final hasSession = await signalManager.hasSession(userId);
        
        if (!hasSession) {
          // 4. إنشاء Session جديد
          if (mounted) {
            _showMessage('جاري إعداد التشفير...', true);
          }
          
          final success = await signalManager.createSession(userId);
          
          if (!success) {
            if (mounted) {
              _showMessage('فشل إعداد التشفير مع $name', false);
            }
            return;
          }
          
          if (mounted) {
            _showMessage('تم إعداد التشفير بنجاح ✅', true);
          }
        }
        
        //الانتقال لشاشة المحادثة
        if (!mounted) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              userId: userId,
              name: name,
              username: chat['username'],
            ),
          ),
        );
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