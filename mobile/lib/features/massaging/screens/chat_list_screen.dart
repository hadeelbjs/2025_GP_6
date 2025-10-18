//lib/features/massaging/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/api_services.dart';
import '../../../services/messaging_service.dart';
import '../../../services/crypto/signal_protocol_manager.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _apiService = ApiService();
  final _messagingService = MessagingService();
  final _signalProtocolManager = SignalProtocolManager();
  
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = false;
  
  StreamSubscription? _newMessageSubscription;
  String? _currentOpenChatId; // ✅ لتتبع المحادثة المفتوحة

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _newMessageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _messagingService.initialize();
    await _loadChats();
    await _loadConversations();
    _listenToNewMessages();
  }

  // ✅ الاستماع للرسائل الجديدة مع إخفاء الإشعار إذا المحادثة مفتوحة
  void _listenToNewMessages() {
    _newMessageSubscription = _messagingService.onNewMessage.listen((data) {
      print('📨 New message notification');
      _loadConversations();
      
      final senderId = data['senderId'];
      
      // ✅ إذا المستخدم داخل نفس المحادثة، لا تظهر الإشعار
      if (_currentOpenChatId == senderId) {
        print('⚠️ User inside chat - no notification');
        return;
      }
      
      // ✅ إشعار أنيق ومفيد
      if (mounted) {
        final senderName = _chats.firstWhere(
          (c) => c['id'] == senderId,
          orElse: () => {'name': 'مستخدم'},
        )['name'];
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'رسالة جديدة من $senderName',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'اضغط لفتح المحادثة',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'فتح',
              textColor: Colors.white,
              onPressed: () {
                final contactId = data['senderId'];
                if (contactId != null) {
                  final chat = _chats.firstWhere(
                    (c) => c['id'] == contactId,
                    orElse: () => {},
                  );
                  if (chat.isNotEmpty) {
                    _openChat(chat);
                  }
                }
              },
            ),
          ),
        );
      }
    });
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
Future<void> _loadConversations() async {
  try {
    final conversations = await _messagingService.getAllConversations();
    
    if (mounted) {
      setState(() {
        _conversations = conversations;
      });
    }
    
    print('✅ Loaded ${conversations.length} conversations');
    
    // ✅ طباعة تفاصيل كل محادثة للتأكد
    for (var conv in conversations) {
      print('📊 ${conv['contactName']}: unread = ${conv['unreadCount']}');
    }
    
  } catch (e) {
    print('❌ Error loading conversations: $e');
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
                        : _buildChatList(),
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

Widget _buildChatList() {
  final Map<String, Map<String, dynamic>> mergedMap = {}; // ✅ استخدم Map بدل List
  
  // ✅ إضافة الـ conversations أولاً
  for (var conv in _conversations) {
    final contactId = conv['contactId'];
    final contact = _chats.firstWhere(
      (c) => c['id'] == contactId,
      orElse: () => {},
    );
    
    if (contact.isNotEmpty) {
      mergedMap[contactId] = { // ✅ استخدم contactId كـ key
        ...contact,
        'lastMessage': conv['lastMessage'],
        'lastMessageTime': conv['lastMessageTime'],
        'unreadCount': conv['unreadCount'] ?? 0,
      };
    }
  }
  
  for (var contact in _chats) {
    final contactId = contact['id'];
    if (!mergedMap.containsKey(contactId)) { // ✅ فقط إذا مو موجود
      mergedMap[contactId] = {
        ...contact,
        'lastMessage': null,
        'lastMessageTime': null,
        'unreadCount': 0,
      };
    }
  }

  final mergedList = mergedMap.values.toList();
  
  
  mergedList.sort((a, b) {
    final timeA = a['lastMessageTime'] ?? 0;
    final timeB = b['lastMessageTime'] ?? 0;
    return timeB.compareTo(timeA);
  });

  if (mergedList.isEmpty) {
    return _buildEmptyState();
  }

  return RefreshIndicator(
    onRefresh: () async {
      await _loadChats();
      await _loadConversations();
    },
    color: AppColors.primary,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 15),
      itemCount: mergedList.length,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Divider(
          color: AppColors.textHint.withOpacity(0.1),
          height: 1,
          thickness: 1,
        ),
      ),
      itemBuilder: (context, index) {
        final chat = mergedList[index];
        return _buildChatItem(chat);
      },
    ),
  );
}

  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final name = chat['name'] as String;
    final avatarColor = chat['avatarColor'] as Color;
    final userId = chat['id'] as String;
    final initial = name.isNotEmpty ? name[0] : '';
    
    final lastMessage = chat['lastMessage'];
    final unreadCount = chat['unreadCount'] ?? 0;
    final timestamp = chat['lastMessageTime'];
    final isLocked = lastMessage != null && lastMessage.contains('🔒');

    return InkWell(
      onTap: () => _openChat(chat),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: unreadCount > 0 
                                ? FontWeight.bold 
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          _formatTime(timestamp),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isLocked)
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.lock,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                        ),
                      
                     Expanded(
                      child: Text(
                      
                        '@${chat['username']}', 
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ✅ عداد الرسائل غير المقروءة
            if (unreadCount > 0)
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
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

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  // ✅ فتح المحادثة مع تسجيل الـ ID
  Future<void> _openChat(Map<String, dynamic> chat) async {
    final userId = chat['id'] as String;
    final name = chat['name'] as String;
    
    // ✅ تسجيل أن المستخدم داخل هذه المحادثة
    _currentOpenChatId = userId;
    
    try {
      await _signalProtocolManager.initialize();
      
      final hasSession = await _signalProtocolManager.hasSession(userId);
      
      if (!hasSession) {
        _showMessage('جاري إعداد التشفير...', true);
        
        final success = await _signalProtocolManager.createSession(userId);
        
        if (!success) {
          _showMessage('فشل إعداد التشفير', false);
          _currentOpenChatId = null;
          return;
        }
      }
      
      if (!mounted) return;
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userId: userId,
            name: name,
            username: chat['username'],
          ),
        ),
      );
      
      // ✅ عند الرجوع، إلغاء التسجيل
      _currentOpenChatId = null;
      
      await _loadConversations();
      
    } catch (e) {
      print('Error opening chat: $e');
      _currentOpenChatId = null;
      _showMessage('حدث خطأ', false);
    }
  }
}