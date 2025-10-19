// lib/features/massaging/screens/chat_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
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
  final _messageController = TextEditingController();
  final _messagingService = MessagingService();
  final _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _conversationId;
  
  File? _pendingImageFile;
  PlatformFile? _pendingFile;
  
  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _deleteSubscription;
  StreamSubscription? _statusSubscription;

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
    _deleteSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    
    try {
      final initialized = await _messagingService.initialize();
      
      if (!initialized) {
        _showMessage('فشل الاتصال بالخادم', false);
        return;
      }

      _conversationId = _messagingService.getConversationId(widget.userId);

      await _loadMessagesFromDatabase();
      _subscribeToRealtimeUpdates();
      await _messagingService.markConversationAsRead(_conversationId!);

    } catch (e) {
      _showMessage('حدث خطأ في تهيئة المحادثة', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        }
      });

    } catch (e) {
      print('❌ Error loading messages: $e');
    }
  }

  void _subscribeToRealtimeUpdates() {
    _newMessageSubscription = _messagingService.onNewMessage.listen((data) {
      if (data['conversationId'] == _conversationId) {
        _loadMessagesFromDatabase();
      }
    });

    _deleteSubscription = _messagingService.onMessageDeleted.listen((data) {
      final messageId = data['messageId'];
      final deletedFor = data['deletedFor'];
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            _messages.removeAt(index);

            if (deletedFor == 'everyone') {
              _messages.removeAt(index);
               _showMessage('تم الحذف للجميع', true);

            } else if (deletedFor == 'recipient') {
             _messages.removeAt(index);
               _showMessage('تم حذف رسالة', false);
              _messages[index]['status'] = 'deleted';
              _messages[index]['deletedForRecipient'] = 1;
            }
          }
        });
      }
    });

    _statusSubscription = _messagingService.onMessageStatusUpdate.listen((data) {
      final messageId = data['messageId'];
      final newStatus = data['status'];
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            _messages[index]['status'] = newStatus;
          }
        });
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      
      if (picked == null) return;
      
      setState(() {
        _pendingImageFile = File(picked.path);
      });
      
    } catch (e) {
      _showMessage('تعذر اختيار الصورة', false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      setState(() {
        _pendingFile = result.files.single;
      });
      
    } catch (e) {
      _showMessage('تعذر اختيار الملف', false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              ListTile(
                leading: Icon(Icons.image_outlined, color: AppColors.primary),
                title: Text('صورة من المعرض', style: AppTextStyles.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: Text('التقاط صورة', style: AppTextStyles.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              
              ListTile(
                leading: Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
                title: Text('اختيار ملف', style: AppTextStyles.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
              
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    
    if (text.isEmpty && _pendingImageFile == null && _pendingFile == null) return;
    if (_isSending) return;
    
    setState(() => _isSending = true);
    
    try {
      File? attachmentFile;
      String? fileName;
      
      if (_pendingFile != null && _pendingFile!.path != null) {
        attachmentFile = File(_pendingFile!.path!);
        fileName = _pendingFile!.name;
      }

      final result = await _messagingService.sendMessage(
        recipientId: widget.userId,
        recipientName: widget.name,
        messageText: text.isEmpty ? (_pendingImageFile != null ? 'صورة' : 'ملف') : text,
        imageFile: _pendingImageFile,
        attachmentFile: attachmentFile,
        fileName: fileName,
      );

      if (result['success']) {
        _messageController.clear();
        setState(() {
          _pendingImageFile = null;
          _pendingFile = null;
        });
        await _loadMessagesFromDatabase();
      } else {
        _showMessage(result['message'] ?? 'فشل الإرسال', false);
      }

    } catch (e) {
      _showMessage('فشل إرسال الرسالة', false);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _decryptMessage(String messageId) async {
    try {
      final result = await _messagingService.decryptMessage(messageId);

      if (result['success']) {
        await _loadMessagesFromDatabase();
        _showMessage('تم فك التشفير بنجاح', true);
      } else {
        _showMessage(result['message'] ?? 'فشل فك التشفير', false);
      }

    } catch (e) {
      _showMessage('حدث خطأ أثناء فك التشفير', false);
    }
  }

  void _showDeleteOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('خيارات الحذف', style: AppTextStyles.h3),
            ),
            
            SizedBox(height: 20),
            
            _buildDeleteOption(
              icon: Icons.person_remove_outlined,
              iconColor: Colors.orange,
              title: 'حذف من عند المستقبل',
              subtitle: 'ستبقى الرسالة عندك فقط',
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteForRecipient(message['id']);
              },
            ),
            
            Divider(height: 1),
            
            _buildDeleteOption(
              icon: Icons.delete_forever_outlined,
              iconColor: Colors.red,
              title: 'حذف للجميع',
              subtitle: 'سيتم حذف الرسالة نهائياً',
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteForEveryone(message['id']);
              },
            ),
            
            SizedBox(height: 10),
            
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              child: Text('إلغاء', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary)),
            ),
            
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteForRecipient(String messageId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('حذف من عند المستقبل؟', style: AppTextStyles.h3),
          content: Text('سيتم حذف هذه الرسالة من عند المستقبل فقط. ستبقى الرسالة عندك.', style: AppTextStyles.bodyMedium),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteForRecipient(messageId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteForEveryone(String messageId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('حذف للجميع؟', style: AppTextStyles.h3),
          content: Text('سيتم حذف هذه الرسالة من محادثتك ومحادثة المستلم نهائياً. لا يمكن التراجع عن هذا الإجراء.', style: AppTextStyles.bodyMedium),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteForEveryone(messageId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteForRecipient(String messageId) async {
    try {
      final result = await _messagingService.deleteMessage(
        messageId: messageId,
        deleteForEveryone: false,
      );
      
      if (result['success']) {
        _showMessage('تم الحذف من عند المستقبل', true);
        await _loadMessagesFromDatabase();
      } else {
        _showMessage(result['message'], false);
      }
    } catch (e) {
      _showMessage('فشل الحذف', false);
    }
  }

  Future<void> _deleteForEveryone(String messageId) async {
    try {
      final result = await _messagingService.deleteMessage(
        messageId: messageId,
        deleteForEveryone: true,
      );
      
      if (result['success']) {
        _showMessage('تم الحذف للجميع', true);
        await _loadMessagesFromDatabase();
      } else {
        _showMessage(result['message'], false);
      }
    } catch (e) {
      _showMessage('فشل الحذف', false);
    }
  }

  void _showMessage(String message, bool isSuccess) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAttachment = _pendingImageFile != null || _pendingFile != null;
    
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
              Text(widget.name, style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _messagingService.isConnected ? Colors.greenAccent : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _messagingService.isConnected ? 'متصل' : 'غير متصل',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withOpacity(0.8)),
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
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline, size: 64, color: AppColors.textHint.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text('محادثة مشفرة من طرف لطرف', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                              const SizedBox(height: 8),
                              Text('ابدأ محادثة آمنة مع ${widget.name}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
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
            
            if (hasAttachment) _buildAttachmentPreview(),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  IconButton(onPressed: _showAttachmentOptions, icon: Icon(Icons.attach_file), color: AppColors.primary),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isSending,
                      maxLines: null,
                      textDirection: TextDirection.rtl,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, color: Colors.white),
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

  Widget _buildAttachmentPreview() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (_pendingImageFile != null)
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_pendingImageFile!, width: 60, height: 60, fit: BoxFit.cover))
          else if (_pendingFile != null)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.insert_drive_file, color: AppColors.primary),
            ),
          
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _pendingImageFile != null ? p.basename(_pendingImageFile!.path) : _pendingFile!.name,
              style: AppTextStyles.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              setState(() {
                _pendingImageFile = null;
                _pendingFile = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = message['isMine'] == 1;
    final isLocked = message['requiresBiometric'] == 1 && message['isDecrypted'] == 0;
    final isDeleted = message['status'] == 'deleted';
    final isDeletedForRecipient = message['deletedForRecipient'] == 1;
    final text = message['plaintext'] ?? '';
    final status = message['status'] ?? 'sent';
    
    final attachmentData = message['attachmentData'];
    final attachmentType = message['attachmentType'];
    final attachmentName = message['attachmentName'];
    final hasAttachment = attachmentData != null && attachmentType != null;
    
    final timestamp = message['createdAt'];
    final time = timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : DateTime.now();

    return GestureDetector(
      onLongPress: () {
        if (isMine && !isLocked && !isDeleted) {
          _showDeleteOptions(message);
        }
      },
      
      onTap: () {
        if (isLocked && !isMine) {
          _decryptMessage(message['id']);
        } else if (hasAttachment && !isLocked) {
          _openAttachment(attachmentData, attachmentType, attachmentName);
        }
      },
      
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: isMine ? Radius.circular(4) : Radius.circular(18),
              bottomRight: isMine ? Radius.circular(18) : Radius.circular(4),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ عرض المرفقات (صور/ملفات)
              if (hasAttachment && !isLocked) ...[
                if (attachmentType == 'image')
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(attachmentData),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey.shade300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('فشل عرض الصورة', style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else if (attachmentType == 'file')
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMine ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file, color: isMine ? Colors.white : AppColors.primary),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            attachmentName ?? 'ملف',
                            style: AppTextStyles.bodySmall.copyWith(color: isMine ? Colors.white : AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 8),
              ],
              
              if (text.isNotEmpty || isLocked)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLocked) ...[
                      Icon(Icons.lock, size: 16, color: isMine ? Colors.white : AppColors.textPrimary),
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
              
              // ✅ رسالة "تم الحذف لدى المستقبل"
              if (isDeletedForRecipient && isMine) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 11, color: Colors.white.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(
                      'تم الحذف لدى المستقبل',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 6),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(time),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isMine ? Colors.white.withOpacity(0.7) : AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _getStatusIcon(status),
                      size: 14,
                      color: status == 'verified' ? Colors.lightBlueAccent : Colors.white.withOpacity(0.7),
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

  void _openAttachment(String base64Data, String type, String? name) async {
    if (type == 'image') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ImageViewerScreen(base64Data: base64Data),
        ),
      );
    } else if (type == 'file') {
      try {
        // ✅ تحويل Base64 إلى ملف مؤقت
        final bytes = base64Decode(base64Data);
        final tempDir = await getTemporaryDirectory();
        final fileName = name ?? 'file_${DateTime.now().millisecondsSinceEpoch}';
        final tempFile = File('${tempDir.path}/$fileName');
        
        await tempFile.writeAsBytes(bytes);
        
        // ✅ فتح الملف
        final result = await OpenFilex.open(tempFile.path);
        
        if (result.type != ResultType.done) {
          _showMessage('تعذر فتح الملف: ${result.message}', false);
        }
        
      } catch (e) {
        _showMessage('فشل فتح الملف', false);
      }
    }
  }
}

// ✅ عارض الصور (Base64)
class _ImageViewerScreen extends StatelessWidget {
  final String base64Data;
  
  const _ImageViewerScreen({required this.base64Data});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('صورة', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.memory(
              base64Decode(base64Data),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.white),
                      SizedBox(height: 16),
                      Text('فشل عرض الصورة', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}