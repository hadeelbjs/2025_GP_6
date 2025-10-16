// lib/services/messaging_service.dart

import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

// Services
import 'socket_service.dart';
import 'api_services.dart';
import 'biometric_service.dart';
import 'local_db/database_helper.dart';
import 'crypto/signal_protocol_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MessagingService {
  // Singleton Pattern
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  
  MessagingService._internal();

  // Services
  final _socketService = SocketService();
  final _apiService = ApiService();
  final _db = DatabaseHelper.instance;
  final _signalProtocol = SignalProtocolManager();
  final _storage = const FlutterSecureStorage();
  
  final _uuid = const Uuid();
  String? _userIdCache;

  // Streams
  final _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;

  bool get isConnected => _socketService.isConnected;

  // ============================================
  // التهيئة
  // ============================================
  Future<bool> initialize() async {
    try {
      print('🔧 Initializing MessagingService...');
      
      // 1. Cache User ID
      await _cacheUserId();
      
      // 2. Initialize Signal Protocol
      await SignalProtocolManager().initialize();

      // 3. Connect Socket
      final socketConnected = await _socketService.connect();
      if (!socketConnected) {
        print('❌ Socket connection failed');
        return false;
      }

      // 4. Setup Socket Listeners
      _setupSocketListeners();

      print('✅ MessagingService initialized successfully');
      return true;

    } catch (e) {
      print('❌ MessagingService initialization error: $e');
      return false;
    }
  }

  // ============================================
  // Socket Listeners
  // ============================================
  void _setupSocketListeners() {
    // ✅ استقبال رسائل جديدة
    _socketService.onNewMessage.listen((data) async {
      await _handleIncomingMessage(data);
    });

    // ✅ تحديث حالة الرسالة
    _socketService.onStatusUpdate.listen((data) async {
      await _handleStatusUpdate(data);
    });

    // ✅ حذف رسالة
    _socketService.onMessageDeleted.listen((data) async {
      await _handleMessageDeleted(data);
    });
  }

  // ============================================
  // ✅ إرسال رسالة (مُحسّن)
  // ============================================
  Future<Map<String, dynamic>> sendMessage({
    required String recipientId,
    required String recipientName,
    required String messageText,
  }) async {
    try {
      final messageId = _uuid.v4();
      final conversationId = _generateConversationId(recipientId);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      print('📤 Sending message: $messageId');

      // 1️⃣ تشفير الرسالة
      final encrypted = await _signalProtocol.encryptMessage(
        recipientId,
        messageText,
      );

      if (encrypted == null) {
        throw Exception('Encryption failed');
      }

      print('✅ Message encrypted: type=${encrypted['type']}');

      // 2️⃣ حفظ في SQLite (status: sending)
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
      });

      print('✅ Message saved to SQLite');

      // 3️⃣ حفظ/تحديث المحادثة
      await _db.saveConversation({
        'id': conversationId,
        'contactId': recipientId,
        'contactName': recipientName,
        'lastMessage': messageText,
        'lastMessageTime': timestamp,
        'unreadCount': 0,
        'updatedAt': timestamp,
      });

      print('✅ Conversation updated');

      // 4️⃣ ✅ إرسال عبر Socket فقط (لا API!)
      _socketService.sendMessage(
        messageId: messageId,
        recipientId: recipientId,
        encryptedType: encrypted['type'],
        encryptedBody: encrypted['body'],
      );

      print('✅ Message sent via Socket');

      // ✅ Socket سيحدث status تلقائياً عند استلام message:sent

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

  // ============================================
  // ✅ معالجة الرسائل الواردة
  // ============================================
  Future<void> _handleIncomingMessage(Map data) async {
    try {
      print('📨 Processing incoming message: ${data['messageId']}');

      final messageId = data['messageId'] as String;
      final senderId = data['senderId'] as String; 
      final encryptedType = data['encryptedType'] as int;
      final encryptedBody = data['encryptedBody'] as String;
      
      final timestamp = data['createdAt'] != null 
          ? DateTime.parse(data['createdAt']).millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch;

      final conversationId = _generateConversationId(senderId);

      // ✅ حفظ في SQLite (مشفرة، تحتاج biometric)
      await _db.saveMessage({
        'id': messageId,
        'conversationId': conversationId,
        'senderId': senderId,
        'receiverId': await _getCurrentUserId(),
        'ciphertext': encryptedBody,
        'encryptionType': encryptedType,
        'plaintext': null, // ✅ null = locked
        'status': 'delivered',
        'createdAt': timestamp,
        'deliveredAt': DateTime.now().millisecondsSinceEpoch,
        'isMine': 0,
        'requiresBiometric': 1, // ✅ يحتاج بايومتركس
        'isDecrypted': 0,
      });

      print('✅ Incoming message saved to SQLite');

      // ✅ زيادة عداد غير المقروءة
      await _db.incrementUnreadCount(conversationId);

      // ✅ إرسال notification للـ UI
      _newMessageController.add({
        'messageId': messageId,
        'conversationId': conversationId,
        'senderId': senderId,
        'isLocked': true,
      });

      print('✅ Incoming message processed');

    } catch (e) {
      print('❌ Handle incoming message error: $e');
    }
  }

  // ============================================
  // ✅ معالجة تحديث Status
  // ============================================
  Future<void> _handleStatusUpdate(Map<String, dynamic> data) async {
    try {
      final messageId = data['messageId'];
      final newStatus = data['status'];

      print('📊 Status update: $messageId → $newStatus');

      await _db.updateMessageStatus(messageId, newStatus);

    } catch (e) {
      print('❌ Handle status update error: $e');
    }
  }

  // ============================================
  // ✅ معالجة حذف رسالة
  // ============================================
  Future<void> _handleMessageDeleted(Map<String, dynamic> data) async {
    try {
      final messageId = data['messageId'];
      final deletedFor = data['deletedFor'];

      print('🗑️ Message deleted: $messageId ($deletedFor)');

      // ✅ حذف من SQLite
      final deletedCount = await _db.deleteMessage(messageId);
      
      if (deletedCount > 0) {
        print('🗑️ Message $messageId removed from SQLite');
      } else {
        print('⚠️ Message $messageId not found locally');
      }

    } catch (e) {
      print('❌ Handle message deleted error: $e');
    }
  }

  // ============================================
  // ✅ فك تشفير رسالة (Biometric)
  // ============================================
  Future<Map<String, dynamic>> decryptMessage(String messageId) async {
    try {
      print('🔓 Decrypting message: $messageId');

      // 1. التحقق بالبايومتركس
      final authenticated = await BiometricService.authenticateWithBiometrics(
        reason: 'تحقق من هويتك لقراءة الرسالة',
      );
      
      if (!authenticated) {
        return {
          'success': false,
          'message': 'فشل التحقق بالبايومتركس',
        };
      }

      // 2. جلب الرسالة من SQLite
      final message = await _db.getMessage(messageId);
      if (message == null) {
        throw Exception('Message not found');
      }

      // 3. فك التشفير
      final decrypted = await _signalProtocol.decryptMessage(
        message['senderId'],
        message['encryptionType'],
        message['ciphertext'],
      );

      if (decrypted == null) {
        throw Exception('Decryption failed');
      }

      print('✅ Message decrypted successfully');

      // 4. تحديث في SQLite
      await _db.updateMessage(messageId, {
        'plaintext': decrypted,
        'isDecrypted': 1,
        'requiresBiometric': 0,
        'status': 'read',
        'readAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 5. ✅ إرسال status update للمرسل
      _socketService.updateMessageStatus(
        messageId: messageId,
        status: 'verified',
        recipientId: message['senderId'],
      );

      print('✅ Message marked as verified');

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

  // ============================================
  // ✅ جلب رسائل المحادثة
  // ============================================
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

  // ============================================
  // ✅ جلب كل المحادثات
  // ============================================
  Future<List<Map<String, dynamic>>> getAllConversations() async {
    try {
      return await _db.getConversations();
    } catch (e) {
      print('❌ Get conversations error: $e');
      return [];
    }
  }

  // ============================================
  // ✅ تحديث المحادثة كـ "مقروءة"
  // ============================================
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _db.markConversationAsRead(conversationId);
      print('✅ Conversation marked as read: $conversationId');
    } catch (e) {
      print('❌ Mark as read error: $e');
    }
  }

  // ============================================
  // ✅ حذف رسالة
  // ============================================
  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    required bool deleteForEveryone,
  }) async {
    try {
      final result = deleteForEveryone
          ? await _apiService.deleteMessageForEveryone(messageId)
          : await _apiService.deleteMessageForRecipient(messageId);

      if (result['success']) {
        if (deleteForEveryone) {
          await _db.deleteMessage(messageId);
        } else {
          await _db.updateMessageStatus(messageId, 'deleted');
        }
      }

      return result;

    } catch (e) {
      print('❌ Delete message error: $e');
      return {
        'success': false,
        'message': 'فشل الحذف: $e',
      };
    }
  }

  // ============================================
  // ✅ حذف محادثة
  // ============================================
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _db.deleteConversation(conversationId);
      print('✅ Conversation deleted: $conversationId');
    } catch (e) {
      print('❌ Delete conversation error: $e');
    }
  }

  // ============================================
  // ✅ تسجيل خروج
  // ============================================
  Future<void> logout() async {
    try {
      _socketService.disconnect();
      await _db.clearAllData();
      print('✅ Logged out successfully');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  // ============================================
  // Helper Functions
  // ============================================
  
  // ✅ توليد Conversation ID
  String _generateConversationId(String otherUserId) {
    final currentUserId = _getCurrentUserIdSync(); 
    final ids = [currentUserId, otherUserId]..sort();
    return '${ids[0]}-${ids[1]}';
  }

  // ✅ جلب User ID (async)
  Future<String> _getCurrentUserId() async {
    final userDataStr = await _storage.read(key: 'user_data');
    
    if (userDataStr != null) {
      final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
      return userData['id'] as String;
    }
    
    throw Exception('User not logged in');
  }

  // ✅ جلب User ID (sync - من Cache)
  String _getCurrentUserIdSync() {
    if (_userIdCache != null) {
      return _userIdCache!;
    }
    throw Exception('User ID not cached. Call _cacheUserId() first');
  }

  // ✅ تخزين User ID في Cache
  Future<void> _cacheUserId() async {
    _userIdCache = await _getCurrentUserId();
    print('✅ User ID cached: $_userIdCache');
  }

  // ✅ Dispose
  void dispose() {
    _socketService.dispose();
    _newMessageController.close();
  }

  String getConversationId(String otherUserId) {
  return _generateConversationId(otherUserId);
}
}