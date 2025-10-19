// lib/services/messaging_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import 'socket_service.dart';
import 'api_services.dart';
import 'biometric_service.dart';
import 'local_db/database_helper.dart';
import 'crypto/signal_protocol_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  
  MessagingService._internal();

  final _socketService = SocketService();
  final _apiService = ApiService();
  final _db = DatabaseHelper.instance;
  final _signalProtocol = SignalProtocolManager();
  final _storage = const FlutterSecureStorage();
  
  final _uuid = const Uuid();
  String? _userIdCache;

  final Set<String> _processedMessageIds = {};
  bool _listenersSetup = false;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _deleteSubscription;
  Timer? _cleanupTimer;
  
  final _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageStatusController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onMessageStatusUpdate => _messageStatusController.stream;

  bool get isConnected => _socketService.isConnected;
   Stream<Map<String, dynamic>> get onUserStatusChange => _socketService.onUserStatusChange;
  
  void requestUserStatus(String userId) {
    _socketService.requestUserStatus(userId);
  }

  Future<bool> initialize() async {
    try {
      print('🔧 Initializing MessagingService...');
      
      await _cacheUserId();
      await SignalProtocolManager().initialize();

       if (!_socketService.isConnected) {
      final socketConnected = await _socketService.connect();
      if (!socketConnected) {
        print('❌ Socket connection failed');
        return false;
      }
    } else {
      print('✅ Socket already connected, reusing connection');
    }

      _setupSocketListeners();
      _startMessageCacheCleanup();

      print('✅ MessagingService initialized successfully');
      return true;

    } catch (e) {
      print('❌ MessagingService initialization error: $e');
      return false;
    }
  }

  void _setupSocketListeners() {
    if (_listenersSetup) {
      print('⚠️ Listeners already setup - skipping');
      return;
    }

    _messageSubscription = _socketService.onNewMessage.listen((data) async {
      await _handleIncomingMessage(data);
    });

    _statusSubscription = _socketService.onStatusUpdate.listen((data) async {
      await _handleStatusUpdate(data);
    });

    _deleteSubscription = _socketService.onMessageDeleted.listen((data) async {
      await _handleMessageDeleted(data);
    });

    _listenersSetup = true;
    print('✅ Socket listeners setup complete');
  }
  
  // ✅ إرسال رسالة مع Base64
  Future<Map<String, dynamic>> sendMessage({
    required String recipientId,
    required String recipientName,
    required String messageText,
    File? imageFile,
    File? attachmentFile,
    String? fileName,
  }) async {
    try {
      final messageId = _uuid.v4();
      final conversationId = _generateConversationId(recipientId);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // ✅ تحويل الملفات إلى Base64
      String? attachmentData;
      String? attachmentType;
      String? attachmentName;
      String? attachmentMimeType;

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        attachmentData = base64Encode(bytes);
        attachmentType = 'image';
        attachmentName = imageFile.path.split('/').last;
        attachmentMimeType = 'image/${attachmentName.split('.').last}';
        print('📷 Image encoded: ${attachmentName} (${bytes.length} bytes)');
      } else if (attachmentFile != null) {
        final bytes = await attachmentFile.readAsBytes();
        attachmentData = base64Encode(bytes);
        attachmentType = 'file';
        attachmentName = fileName ?? attachmentFile.path.split('/').last;
        attachmentMimeType = 'application/octet-stream';
        print('📎 File encoded: ${attachmentName} (${bytes.length} bytes)');
      }

      // 1️⃣ تشفير الرسالة
      final encrypted = await _signalProtocol.encryptMessage(
        recipientId,
        messageText,
      );

      if (encrypted == null) {
        throw Exception('Encryption failed');
      }

      // 2️⃣ حفظ في SQLite
      await _db.saveMessage({
        'id': messageId,
        'conversationId': conversationId,
        'senderId': await _getCurrentUserId(),
        'receiverId': recipientId,
        'ciphertext': encrypted['body'],
        'encryptionType': encrypted['type'],
        'plaintext': messageText,
        'status': 'sending',
        'createdAt': timestamp,
        'isMine': 1,
        'requiresBiometric': 0,
        'isDecrypted': 1,
        'attachmentData': attachmentData,
        'attachmentType': attachmentType,
        'attachmentName': attachmentName,
      });

      print('✅ Message saved to SQLite with attachment');

      // 3️⃣ حفظ المحادثة
      await _db.saveConversation({
        'id': conversationId,
        'contactId': recipientId,
        'contactName': recipientName,
        'lastMessage': attachmentType == 'image' 
            ? '📷 صورة' 
            : attachmentType == 'file' 
              ? '📎 $attachmentName' 
              : messageText,
        'lastMessageTime': timestamp,
        'unreadCount': 0,
        'updatedAt': timestamp,
      });

      // 4️⃣ إرسال عبر Socket مع المرفقات
      _socketService.sendMessageWithAttachment(
        messageId: messageId,
        recipientId: recipientId,
        encryptedType: encrypted['type'],
        encryptedBody: encrypted['body'],
        attachmentData: attachmentData,
        attachmentType: attachmentType,
        attachmentName: attachmentName,
        attachmentMimeType: attachmentMimeType,
      );

      print('✅ Message sent via Socket with attachments');

      return {
        'success': true,
        'messageId': messageId,
      };

    } catch (e) {
      print('❌ Send message error: $e');
      return {
        'success': false,
        'message': 'فشل إرسال الرسالة: $e',
      };
    }
  }

  // ✅ استقبال رسالة مع Base64
  Future<void> _handleIncomingMessage(Map data) async {
    try {
      final messageId = data['messageId'] as String;
      
      print('📨 Processing incoming message: $messageId');

      if (_processedMessageIds.contains(messageId)) {
        print('⚠️ Already processed: $messageId');
        return;
      }

      final existing = await _db.getMessage(messageId);
      if (existing != null) {
        print('⚠️ Already exists in DB: $messageId');
        _processedMessageIds.add(messageId);
        return;
      }

      _processedMessageIds.add(messageId);
      
      final senderId = data['senderId'] as String;
      final encryptedType = data['encryptedType'] as int;
      final encryptedBody = data['encryptedBody'] as String;
      final attachmentData = data['attachmentData'] as String?;
      final attachmentType = data['attachmentType'] as String?;
      final attachmentName = data['attachmentName'] as String?;
      
      final timestamp = data['createdAt'] != null 
          ? DateTime.parse(data['createdAt']).millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch;

      final conversationId = _generateConversationId(senderId);

      // ✅ حفظ الرسالة المشفرة مع المرفقات
      await _db.saveMessage({
        'id': messageId,
        'conversationId': conversationId,
        'senderId': senderId,
        'receiverId': await _getCurrentUserId(),
        'ciphertext': encryptedBody,
        'encryptionType': encryptedType,
        'plaintext': null,
        'status': 'delivered',
        'createdAt': timestamp,
        'deliveredAt': DateTime.now().millisecondsSinceEpoch,
        'isMine': 0,
        'requiresBiometric': 1,
        'isDecrypted': 0,
        'attachmentData': attachmentData,
        'attachmentType': attachmentType,
        'attachmentName': attachmentName,
      });

      print('✅ Incoming message saved with attachment: $attachmentType');

      await _db.incrementUnreadCount(conversationId);

      if (!_newMessageController.isClosed) {
        _newMessageController.add({
          'messageId': messageId,
          'conversationId': conversationId,
          'senderId': senderId,
          'isLocked': true,
        });
      }

    } catch (e) {
      print('❌ Handle incoming message error: $e');
    }
  }
  
  Future<void> _handleStatusUpdate(Map<String, dynamic> data) async {
    try {
      final messageId = data['messageId'];
      final newStatus = data['status'];

      await _db.updateMessageStatus(messageId, newStatus);
      
      if (!_messageStatusController.isClosed) {
        _messageStatusController.add({
          'messageId': messageId,
          'status': newStatus,
        });
      }

    } catch (e) {
      print('❌ Handle status update error: $e');
    }
  }

 Future<void> _handleMessageDeleted(Map<String, dynamic> data) async {
  try {
    final messageId = data['messageId'];
    final deletedFor = data['deletedFor'];


    if (!_messageDeletedController.isClosed) {
      _messageDeletedController.add({
        'messageId': messageId,
        'deletedFor': deletedFor,
      });
      print('✅ UI notified about deletion');
    }

    // ✅ ثم حذف من SQLite
    await Future.delayed(Duration(milliseconds: 50)); 
    
    if (deletedFor == 'everyone') {
      await _db.deleteMessage(messageId);
    } else if (deletedFor == 'recipient') {
      await _db.deleteMessage(messageId);
    }

  } catch (e) {
   
}
 }

  // ✅ فك تشفير رسالة واحدة (يطلب التحقق كل مرة)
  Future<Map<String, dynamic>> decryptMessage(String messageId) async {
    try {
      print('🔓 Decrypting message: $messageId');

      // ✅ التحقق البيومتري - كل مرة تُفتح رسالة
      final authenticated = await BiometricService.authenticateWithBiometrics(
        reason: 'تحقق من هويتك لقراءة الرسالة',
      );
      
      if (!authenticated) {
        return {
          'success': false,
          'message': 'فشل التحقق بالبايومتركس',
        };
      }

      final message = await _db.getMessage(messageId);
      if (message == null) {
        throw Exception('Message not found');
      }

      // ✅ فك التشفير
      final decrypted = await _signalProtocol.decryptMessage(
        message['senderId'],
        message['encryptionType'],
        message['ciphertext'],
      );

      if (decrypted == null) {
        throw Exception('Decryption failed');
      }

      // ✅ تحديث الرسالة
      await _db.updateMessage(messageId, {
        'plaintext': decrypted,
        'isDecrypted': 1,
        'requiresBiometric': 1, // ✅ يبقى يطلب تحقق كل مرة
        'status': 'read',
        'readAt': DateTime.now().millisecondsSinceEpoch,
      });

      _socketService.updateMessageStatus(
        messageId: messageId,
        status: 'verified',
        recipientId: message['senderId'],
      );

      print('✅ Message decrypted: $messageId');

      return {
        'success': true,
        'plaintext': decrypted,
      };

    } catch (e) {
      print('❌ Decrypt message error: $e');
      return {
        'success': false,
        'message': 'فشل فك التشفير: $e',
      };
    }
  }

  // ✅ جلب الرسائل
  Future<List<Map<String, dynamic>>> getConversationMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    try {
      return await _db.getMessages(conversationId, limit: limit);
    } catch (e) {
      print('❌ Get messages error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllConversations() async {
    try {
      return await _db.getConversations();
    } catch (e) {
      print('❌ Get conversations error: $e');
      return [];
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _db.markConversationAsRead(conversationId);
    } catch (e) {
      print('❌ Mark as read error: $e');
    }
  }

  // ✅ حذف رسالة - مُحدَّث
  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    required bool deleteForEveryone,
  }) async {
    try {
      final message = await _db.getMessage(messageId);
      
      if (message == null) {
        return {'success': false, 'message': 'الرسالة غير موجودة'};
      }

      if (deleteForEveryone) {
        // ✅ حذف للجميع
        _socketService.deleteMessage(
          messageId: messageId,
          deleteFor: 'everyone',
        );
        
        // ✅ حذف محلي فوري
        await _db.deleteMessage(messageId);
        print('✅ Message deleted for everyone (local)');
        
        return {'success': true, 'message': 'تم الحذف للجميع'};
      } else {
        // ✅ حذف من عند المستقبل فقط
        _socketService.deleteMessage(
          messageId: messageId,
          deleteFor: 'recipient',
        );
        
        // ✅ تحديث محلي - إضافة علامة "تم الحذف لدى المستقبل"
        await _db.updateMessage(messageId, {
          'deletedForRecipient': 1,
        });
        print('✅ Message marked as deleted for recipient');
        
        return {'success': true, 'message': 'تم الحذف من عند المستقبل'};
      }

    } catch (e) {
      print('❌ Delete message error: $e');
      return {
        'success': false,
        'message': 'فشل الحذف: $e',
      };
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _db.deleteConversation(conversationId);
    } catch (e) {
      print('❌ Delete conversation error: $e');
    }
  }

  Future<void> logout() async {
    try {
    _socketService.disconnectOnLogout();  
         await _db.clearAllData();
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  String _generateConversationId(String otherUserId) {
    final currentUserId = _getCurrentUserIdSync(); 
    final ids = [currentUserId, otherUserId]..sort();
    return '${ids[0]}-${ids[1]}';
  }

  Future<String> _getCurrentUserId() async {
    final userDataStr = await _storage.read(key: 'user_data');
    
    if (userDataStr != null) {
      final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
      return userData['id'] as String;
    }
    
    throw Exception('User not logged in');
  }

  String _getCurrentUserIdSync() {
    if (_userIdCache != null) {
      return _userIdCache!;
    }
    throw Exception('User ID not cached');
  }

  Future<void> _cacheUserId() async {
    _userIdCache = await _getCurrentUserId();
  }

  void _startMessageCacheCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_processedMessageIds.length > 100) {
        final toKeep = _processedMessageIds.skip(_processedMessageIds.length - 50).toList();
        _processedMessageIds.clear();
        _processedMessageIds.addAll(toKeep);
      }
    });
  }
  
  void dispose() {
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    _deleteSubscription?.cancel();
    _cleanupTimer?.cancel();
    _processedMessageIds.clear();
    _listenersSetup = false;
    _socketService.dispose();
    _newMessageController.close();
    _messageDeletedController.close();
    _messageStatusController.close();
  }

  String getConversationId(String otherUserId) {
    return _generateConversationId(otherUserId);
  }
}