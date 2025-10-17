import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'local_db/database_helper.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  final _storage = const FlutterSecureStorage();
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _deletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onStatusUpdate => _statusController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _deletedController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;
  String? _userId;

  // ✅ لمنع معالجة نفس الرسالة مرتين
  final Set<String> _processedMessages = {};

  Future<bool> connect() async {
    try {
      // ✅ إذا موجود socket نشط، أغلقه أولاً
      if (_socket != null && _socket!.connected) {
        print('⚠️ Socket already connected - skipping');
        return true;
      }

      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        print('❌ No token found');
        return false;
      }

      final userDataStr = await _storage.read(key: 'user_data');
      if (userDataStr == null) {
        print('❌ No user data found');
        return false;
      }
      
      final userData = jsonDecode(userDataStr);
      _userId = userData['id'];
      
      if (_userId == null || _userId!.isEmpty) {
        print('❌ Invalid user ID');
        return false;
      }

      String baseUrl;
      if (Platform.isAndroid) {
        baseUrl = 'http://10.0.2.2:3000';
      } else if (Platform.isIOS) {
        baseUrl = 'http://localhost:3000';
      } else {
        baseUrl = 'http://localhost:3000';
      }

      print('🔌 Connecting to: $baseUrl');
      print('👤 User ID: $_userId');

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionAttempts(5)
            .setAuth({'token': token})
            .build(),
      );

      _setupEventListeners();

      print('✅ Socket initialization complete');
      return true;

    } catch (e) {
      print('❌ Socket connection error: $e');
      return false;
    }
  }

  void _setupEventListeners() {
    // ✅ تنظيف الـ listeners القديمة
    _socket?.off('connect');
    _socket?.off('connected');
    _socket?.off('message:new');
    _socket?.off('message:sent');
    _socket?.off('message:status_update');
    _socket?.off('message:deleted');
    _socket?.off('typing');
    _socket?.off('disconnect');
    _socket?.off('error');
    _socket?.off('reconnect');

    _socket?.on('connect', (_) {
      print('✅ Socket connected!');
      _connectionController.add(true);
    });

    _socket?.on('connected', (data) {
      print('✅ Authenticated: ${data['userId']}');
    });

    // ✅ استقبال رسالة جديدة (مع منع التكرار)
    _socket?.on('message:new', (data) async {
      final messageId = data['messageId'] as String;
      
      // ✅ إذا سبق معالجة هذه الرسالة، تجاهلها
      if (_processedMessages.contains(messageId)) {
        print('⚠️ Message already processed: $messageId');
        return;
      }
      
      print('📨 New message received: $messageId');
      
      // ✅ تسجيل الرسالة
      _processedMessages.add(messageId);
      
      // إرسال للـ stream
      _messageController.add(Map<String, dynamic>.from(data));
      
      // ✅ إرسال تأكيد استلام مرة واحدة فقط
      _socket?.emit('message:delivered', {
        'messageId': data['messageId'],
        'senderId': data['senderId'],
        'encryptedType': data['encryptedType'],
        'encryptedBody': data['encryptedBody'],
        'createdAt': data['createdAt'],
      });
      
      print('✅ Delivery confirmation sent for: $messageId');
    });

    _socket?.on('message:sent', (data) async {
      final messageId = data['messageId'];
      final delivered = data['delivered'] ?? false;
      
      print('📤 Message sent confirmation: $messageId (delivered: $delivered)');
      
      try {
        await DatabaseHelper.instance.updateMessageStatus(
          messageId,
          delivered ? 'delivered' : 'sent',
        );
        print('✅ Updated local status: $messageId → ${delivered ? "delivered" : "sent"}');
      } catch (e) {
        print('❌ Failed to update local status: $e');
      }
    });

   _socket?.on('message:deleted', (data) async {
  print('🗑️ Message deleted: ${data['messageId']}');
  
  final deletedFor = data['deletedFor']; // 'recipient' or 'everyone'
  
  _deletedController.add(Map<String, dynamic>.from(data));

  try {
    if (deletedFor == 'everyone') {
      // ✅ حذف نهائي من SQLite
      await DatabaseHelper.instance.deleteMessage(data['messageId']);
      print('🗑️ Deleted locally from SQLite: ${data['messageId']}');
    } else {
      // ✅ تحديث الحالة لـ "deleted"
      await DatabaseHelper.instance.updateMessageStatus(
        data['messageId'],
        'deleted',
      );
      print('✅ Marked as deleted: ${data['messageId']}');
    }
  } catch (e) {
    print('⚠️ Local delete failed: $e');
  }
});

    _socket?.on('typing', (data) {
      _typingController.add(Map<String, dynamic>.from(data));
    });

    _socket?.on('disconnect', (_) {
      print('❌ Socket disconnected');
      _connectionController.add(false);
    });

    _socket?.on('error', (data) {
      print('❌ Socket error: $data');
    });

    _socket?.on('reconnect', (attempt) {
      print('🔄 Reconnected after $attempt attempts');
      _connectionController.add(true);
      // ✅ تنظيف الرسائل المعالجة بعد إعادة الاتصال
      _processedMessages.clear();
    });
  }

  void sendMessage({
    required String messageId,
    required String recipientId,
    required int encryptedType,
    required String encryptedBody,
  }) {
    if (_socket == null || !isConnected) {
      print('❌ Cannot send: Socket not connected');
      return;
    }

    _socket!.emit('message:send', {
      'messageId': messageId,
      'recipientId': recipientId,
      'encryptedType': encryptedType,
      'encryptedBody': encryptedBody,
      'createdAt': DateTime.now().toIso8601String(),
    });

    print('📤 Message sent via socket: $messageId');
  }

  void updateMessageStatus({
    required String messageId,
    required String status,
    required String recipientId,
  }) {
    if (!isConnected) {
      print('❌ Cannot update status: Socket not connected');
      return;
    }

    _socket?.emit('message:status', {
      'messageId': messageId,
      'status': status,
      'recipientId': recipientId,
    });

    print('📤 Sent status update: $messageId → $status');
  }

  void sendTypingIndicator({
    required String recipientId,
    required bool isTyping,
  }) {
    if (!isConnected) return;

    _socket?.emit('typing', {
      'recipientId': recipientId,
      'isTyping': isTyping,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _processedMessages.clear(); // ✅ تنظيف
    print('🔌 Socket disconnected manually');
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
    _deletedController.close();
    _typingController.close();
    _connectionController.close();
  }
}