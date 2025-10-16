// lib/services/socket_service.dart

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

  //  الاتصال بالسيرفر
  Future<bool> connect() async {
    try {
      // 1. جلب التوكن
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        print('❌ No token found');
        return false;
      }

      // 2.  جلب userId (مع validation)
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

      // 3. تحديد Base URL حسب المنصة
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

      // 4. إنشاء Socket
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

      // 5. إعداد Event Listeners
      _setupEventListeners();

      print('✅ Socket initialization complete');
      return true;

    } catch (e) {
      print('❌ Socket connection error: $e');
      return false;
    }
  }

  // ✅ إعداد Event Listeners
  void _setupEventListeners() {
    // ✅ عند الاتصال
    _socket?.on('connect', (_) {
      print('✅ Socket connected!');
      _connectionController.add(true);
    });

    // ✅ تأكيد Authentication
    _socket?.on('connected', (data) {
      print('✅ Authenticated: ${data['userId']}');
    });

    // ✅ استقبال رسالة جديدة
    _socket?.on('message:new', (data) async {
      print('📨 New message received: ${data['messageId']}');
      
      // إرسال للـ stream
      _messageController.add(Map<String, dynamic>.from(data));
      
      // ✅ إرسال تأكيد استلام للسيرفر
      _socket?.emit('message:delivered', {
        'messageId': data['messageId'],
        'senderId': data['senderId'],
        'encryptedType': data['encryptedType'],
        'encryptedBody': data['encryptedBody'],
        'createdAt': data['createdAt'],
      });
      
      print('✅ Delivery confirmation sent for: ${data['messageId']}');
    });

    // ✅ تأكيد إرسال الرسالة
    _socket?.on('message:sent', (data) async {
      final messageId = data['messageId'];
      final delivered = data['delivered'] ?? false;
      
      print('📤 Message sent confirmation: $messageId (delivered: $delivered)');
      
      // ✅ تحديث status في SQLite
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

    // ✅ تحديث حالة الرسالة
    _socket?.on('message:status_update', (data) {
      print('📊 Status update: ${data['messageId']} → ${data['status']}');
      _statusController.add(Map<String, dynamic>.from(data));
    });

    // ✅ حذف رسالة
    _socket?.on('message:deleted', (data) async {
      print('🗑️ Message deleted: ${data['messageId']}');
      _deletedController.add(Map<String, dynamic>.from(data));

      // ✅ حذف من التخزين المحلي
      try {
        await DatabaseHelper.instance.deleteMessage(data['messageId']);
        print('🗑️ Deleted locally from SQLite: ${data['messageId']}');
      } catch (e) {
        print('⚠️ Local delete failed: $e');
      }
    });

    // ✅ مؤشر الكتابة
    _socket?.on('typing', (data) {
      _typingController.add(Map<String, dynamic>.from(data));
    });

    // ✅ قطع الاتصال
    _socket?.on('disconnect', (_) {
      print('❌ Socket disconnected');
      _connectionController.add(false);
    });

    // ✅ خطأ
    _socket?.on('error', (data) {
      print('❌ Socket error: $data');
    });

    // ✅ إعادة الاتصال
    _socket?.on('reconnect', (attempt) {
      print('🔄 Reconnected after $attempt attempts');
      _connectionController.add(true);
    });
  }

  // ============================================
  // ✅ إرسال رسالة
  // ============================================
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

  // ============================================
  // ✅ تحديث حالة الرسالة
  // ============================================
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

  // ============================================
  // ✅ إرسال مؤشر الكتابة
  // ============================================
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

  // ============================================
  // ✅ قطع الاتصال
  // ============================================
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    print('🔌 Socket disconnected manually');
  }

  // ============================================
  // ✅ Dispose
  // ============================================
  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
    _deletedController.close();
    _typingController.close();
    _connectionController.close();
  }
}