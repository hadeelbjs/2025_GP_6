// lib/features/massaging/screens/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/messaging_service.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String username;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.username,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Controllers & Services
  final _messageController = TextEditingController();
  final _messagingService = MessagingService();
  final _scrollController = ScrollController();
  
  // State
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _conversationId;
  
  // Socket Subscription
  StreamSubscription? _newMessageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _newMessageSubscription?.cancel();
    super.dispose();
  }

  // ============================================
  // تهيئة الشات
  // ============================================
  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔧 Initializing chat with: ${widget.name}');

      // 1. تهيئة MessagingService
      final initialized = await _messagingService.initialize();
      
      if (!initialized) {
        _showMessage('فشل الاتصال بالخادم', false);
        return;
      }

      // 2. ✅ حساب conversationId (استخدام الـ method العامة)
      _conversationId = _messagingService.getConversationId(widget.userId);
      print('💬 Conversation ID: $_conversationId');

      // 3. جلب الرسائل من SQLite
      await _loadMessagesFromDatabase();

      // 4. الاستماع للرسائل الجديدة من Socket
      _subscribeToNewMessages();

      // 5. تحديث المحادثة كـ "مقروءة"
      await _messagingService.markConversationAsRead(_conversationId!);

      print('✅ Chat initialized successfully');

    } catch (e) {
      print('❌ Error initializing chat: $e');
      _showMessage('حدث خطأ في تهيئة المحادثة', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================
  // جلب الرسائل من Database
  // ============================================
  Future<void> _loadMessagesFromDatabase() async {
    try {
      final messages = await _messagingService.getConversationMessages(
        _conversationId!,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
        });
      }

      print('✅ Loaded ${messages.length} messages');

      //  Auto-scroll للأسفل
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        }
      });

    } catch (e) {
      print('❌ Error loading messages: $e');
    }
  }

  // ============================================
  // الاستماع للرسائل الجديدة (Socket)
  // ============================================
  void _subscribeToNewMessages() {
    _newMessageSubscription = _messagingService.onNewMessage.listen((data) {
      if (data['conversationId'] == _conversationId) {
        print('📨 New message in current chat');
        _loadMessagesFromDatabase();
      }
    });
  }

  // ============================================
  // ✅ إرسال رسالة
  // ============================================
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    
    if (text.isEmpty || _isSending) return;
    
    setState(() => _isSending = true);
    
    try {
      print('📤 Sending message: $text');

      final result = await _messagingService.sendMessage(
        recipientId: widget.userId,
        recipientName: widget.name,
        messageText: text,
      );

      if (result['success']) {
        _messageController.clear();
        await _loadMessagesFromDatabase();
        print('✅ Message sent successfully');
      } else {
        _showMessage(result['message'] ?? 'فشل الإرسال', false);
      }

    } catch (e) {
      print('❌ Error sending message: $e');
      _showMessage('فشل إرسال الرسالة', false);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // ============================================
  // ✅ فك تشفير رسالة
  // ============================================
  Future<void> _decryptMessage(String messageId) async {
    try {
      setState(() => _isLoading = true);

      print('🔓 Decrypting message: $messageId');

      final result = await _messagingService.decryptMessage(messageId);

      if (result['success']) {
        await _loadMessagesFromDatabase();
        _showMessage('تم فك التشفير بنجاح', true);
      } else {
        _showMessage(result['message'] ?? 'فشل فك التشفير', false);
      }

    } catch (e) {
      print('❌ Error decrypting message: $e');
      _showMessage('حدث خطأ أثناء فك التشفير', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================
  // Helper Functions
  // ============================================
  
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

  // ============================================
  // UI Build
  // ============================================
  
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _messagingService.isConnected 
                          ? Colors.greenAccent 
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _messagingService.isConnected ? 'متصل' : 'غير متصل',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        body: Column(
          children: [
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 64,
                                color: AppColors.textHint.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'محادثة مشفرة من طرف لطرف',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ابدأ محادثة آمنة مع ${widget.name}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          reverse: true,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[_messages.length - 1 - index];
                            return _buildMessageBubble(message);
                          },
                        ),
            ),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isSending,
                      maxLines: null,
                      textDirection: TextDirection.rtl,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHint,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                            ),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // Message Bubble Widget
  // ============================================
  
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = message['isMine'] == 1;
    final isLocked = message['requiresBiometric'] == 1;
    final text = message['plaintext'] ?? '';
    final status = message['status'] ?? 'sent';
    
    final timestamp = message['createdAt'];
    final time = timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();

    return GestureDetector(
      onTap: isLocked ? () => _decryptMessage(message['id']) : null,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMine 
                ? AppColors.primary 
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLocked) ...[
                    Icon(
                      Icons.lock,
                      size: 16,
                      color: isMine ? Colors.white : AppColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      isLocked ? 'اضغط للمشاهدة' : text,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isMine ? Colors.white : AppColors.textPrimary,
                        fontStyle: isLocked ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 6),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(time),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isMine 
                          ? Colors.white.withOpacity(0.7)
                          : AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _getStatusIcon(status),
                      size: 14,
                      color: status == 'verified' 
                          ? Colors.lightBlueAccent 
                          : Colors.white.withOpacity(0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // Helper UI Functions
  // ============================================
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.day}/${time.month}';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sending':
        return Icons.access_time;
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      case 'verified':
        return Icons.verified;
      default:
        return Icons.access_time;
    }
  }
}

