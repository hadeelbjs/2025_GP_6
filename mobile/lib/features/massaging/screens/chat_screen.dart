// lib/features/massaging/screens/chat_screen.dart
import 'package:flutter/material.dart';
import '/shared/widgets/header_widget.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/crypto/signal_protocol_manager.dart';

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
  final _messageController = TextEditingController();
  final _signalManager = SignalProtocolManager();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    
    try {
      // التحقق من وجود Session
      final hasSession = await _signalManager.hasSession(widget.userId);
      
      if (!hasSession) {
        print('No session found, creating new session...');
        final success = await _signalManager.createSession(widget.userId);
        
        if (!success) {
          _showMessage('فشل إنشاء الاتصال الآمن', false);
        } else {
          print('Session created successfully');
        }
      } else {
        print('Session already exists');
      }
      
      // هنا يمكنك جلب الرسائل السابقة من السيرفر
      
    } catch (e) {
      print('Error initializing chat: $e');
      _showMessage('حدث خطأ في تهيئة المحادثة', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    
    if (text.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      // تشفير الرسالة
      final encrypted = await _signalManager.encryptMessage(
        widget.userId,
        text,
      );
      
      if (encrypted == null) {
        _showMessage('فشل تشفير الرسالة', false);
        setState(() => _isLoading = false);
        return;
      }
      
      // هنا يمكنك إرسال الرسالة المشفرة للسيرفر
      // await _apiService.sendMessage(widget.userId, encrypted);
      
      // إضافة الرسالة محلياً للعرض
      setState(() {
        _messages.add({
          'text': text,
          'isSent': true,
          'time': DateTime.now(),
        });
        _messageController.clear();
      });
      
      print('Message encrypted and sent successfully');
      
    } catch (e) {
      print('Error sending message: $e');
      _showMessage('فشل إرسال الرسالة', false);
    } finally {
      setState(() => _isLoading = false);
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
              Text(
                '@${widget.username}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // منطقة الرسائل
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
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _buildMessageBubble(message);
                          },
                        ),
            ),
            
            // حقل إدخال الرسالة
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
                      enabled: !_isLoading,
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
                      icon: _isLoading
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
                      onPressed: _isLoading ? null : _sendMessage,
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

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isSent = message['isSent'] as bool;
    final text = message['text'] as String;
    final time = message['time'] as DateTime;
    
    return Align(
      alignment: isSent ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSent ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSent ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
              style: AppTextStyles.bodySmall.copyWith(
                color: isSent
                    ? Colors.white.withOpacity(0.7)
                    : AppColors.textHint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}