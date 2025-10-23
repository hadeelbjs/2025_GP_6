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
  final _connectionController = StreamController<bool>.broadcast();
  final _userStatusController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onStatusUpdate => _statusController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _deletedController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;
  Stream<Map<String, dynamic>> get onUserStatusChange => _userStatusController.stream;

  bool get isConnected => _socket?.connected ?? false;
  String? _userId;

  final Set<String> _processedMessages = {};
  bool _isConnecting = false; 

  Future<bool> connect() async {
    try {
      print('🔌 Connecting to Socket.IO...');

      if (_socket != null && _socket!.connected) {
        print('Socket already connected');
        return true;
      }

      if (_isConnecting) {
        print('Connection in progress, waiting...');
        await Future.delayed(Duration(seconds: 2));
        return _socket?.connected ?? false;
      }

      _isConnecting = true;

      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        print('❌ No token found');
        _isConnecting = false;
        return false;
      }

      final userDataStr = await _storage.read(key: 'user_data');
      if (userDataStr == null) {
        print('❌ No user data found');
        _isConnecting = false;
        return false;
      }
      
      final userData = jsonDecode(userDataStr);
      _userId = userData['id'];
      
      if (_userId == null || _userId!.isEmpty) {
        print('❌ Invalid user ID');
        _isConnecting = false;
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


      // ✅ إنشاء Socket مع خيارات محسّنة
      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling']) // كلاهما
            .enableForceNew() // إجبار اتصال جديد
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionAttempts(10)
            .setAuth({'token': token})
            .setTimeout(10000)
            .disableMultiplex() // تعطيل multiplexing
            .setExtraHeaders({'Authorization': 'Bearer $token'}) // header إضافي
            .build(),
      );


      // إضافة listener للأخطاء قبل الاتصال
      _socket!.onConnectError((data) {
        print('❌ [ERROR] Connection error: $data');
      });

      _socket!.onError((data) {
        print('❌ [ERROR] Socket error: $data');
      });

      _setupEventListeners();

      _socket!.connect();
      
      // انتظار 3 ثواني للاتصال
      print('⏳ [9/10] Waiting 3 seconds for connection...');
      await Future.delayed(Duration(seconds: 3));
      
      if (_socket!.connected) {
        print('✅ [10/10] Socket connected successfully! 🎉');
        _isConnecting = false;
        return true;
      } else {
        print('❌ [10/10] Socket NOT connected after 3 seconds');
        print('❌ Socket state: ${_socket!.connected ? "connected" : "disconnected"}');
        _isConnecting = false;
        return false;
      }

    } catch (e, stackTrace) {
      print('❌ Socket connection error: $e');
      print('❌ Stack trace: $stackTrace');
      _isConnecting = false;
      return false;
    }
  }

  void _setupEventListeners() {
    if (_socket == null) {
      print('❌ Cannot setup listeners - socket is null');
      return;
    }
    
    print('🔧 Clearing old listeners...');
    _socket!.off('connect');
    _socket!.off('connected');
    _socket!.off('message:new');
    _socket!.off('message:sent');
    _socket!.off('message:status_update');
    _socket!.off('message:deleted');
    _socket!.off('user:status');
    _socket!.off('disconnect');
    _socket!.off('error');
    _socket!.off('reconnect');
    _socket!.off('connect_error');
    _socket!.off('connect_timeout');

    print('🔧 Setting up new listeners...');

    _socket!.on('connect', (_) {
      print('✅✅✅ SOCKET CONNECTED! ✅✅✅');
      print('✅ Socket ID: ${_socket!.id}');
      _connectionController.add(true);
    });

    _socket!.on('connect_error', (error) {
      print('❌ Connect error: $error');
    });

    _socket!.on('connect_timeout', (data) {
      print('❌ Connect timeout: $data');
    });

    _socket!.on('error', (data) {
      print('❌ Socket error: $data');
    });

    _socket!.on('connected', (data) {
      print('✅ Server confirmed connection: $data');
    });

    _socket!.on('message:new', (data) async {
      print('📥 New message received: ${data['messageId']}');
      final messageId = data['messageId'] as String;
      
      if (_processedMessages.contains(messageId)) {
        print('⚠️ Duplicate message, skipping');
        return;
      }
      
      _processedMessages.add(messageId);
      _messageController.add(Map<String, dynamic>.from(data));
      
      _socket?.emit('message:delivered', {
        'messageId': data['messageId'],
        'senderId': data['senderId'],
        'encryptedType': data['encryptedType'],
        'encryptedBody': data['encryptedBody'],
        'attachmentData': data['attachmentData'],
        'attachmentType': data['attachmentType'],
        'attachmentName': data['attachmentName'],
        'createdAt': data['createdAt'],
      });
    });

    _socket!.on('message:sent', (data) async {
      print('✅ Message sent confirmation: ${data['messageId']}');
      final messageId = data['messageId'];
      final delivered = data['delivered'] ?? false;
      
      try {
        await DatabaseHelper.instance.updateMessageStatus(
          messageId,
          delivered ? 'delivered' : 'sent',
        );
      } catch (e) {
        print('❌ Error updating message status: $e');
      }
    });

    _socket!.on('message:status_update', (data) {
      print('📊 Status update: ${data['messageId']} → ${data['status']}');
      _statusController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message:deleted', (data) async {
      print('🗑️ Message deleted: ${data['messageId']}');
      
      final messageId = data['messageId'];
      final deletedFor = data['deletedFor'];
      
      if (!_deletedController.isClosed) {
        _deletedController.add(Map<String, dynamic>.from(data));
      }
      
      try {
        await Future.delayed(Duration(milliseconds: 30));
        
        if (deletedFor == 'everyone') {
          await DatabaseHelper.instance.deleteMessage(messageId);
        } else if (deletedFor == 'recipient') {
          await DatabaseHelper.instance.deleteMessage(messageId);
        }
      } catch (e) {
        print('❌ Error deleting message: $e');
      }
    });

    _socket!.on('user:status', (data) {
      print('👤 User status: ${data['userId']} → ${data['isOnline'] ? "online" : "offline"}');
      _userStatusController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('disconnect', (reason) {
      print('❌ Socket disconnected: $reason');
      _connectionController.add(false);
    });

    _socket!.on('reconnect', (attempt) {
      print('🔄 Reconnected after $attempt attempts');
      _connectionController.add(true);
      _processedMessages.clear();
    });

    print('✅ All listeners configured');
  }

  void sendMessageWithAttachment({
    required String messageId,
    required String recipientId,
    required int encryptedType,
    required String encryptedBody,
    String? attachmentData,
    String? attachmentType,
    String? attachmentName,
    String? attachmentMimeType,
  }) {
    if (_socket == null || !isConnected) {
      print('❌ Cannot send: Socket not connected');
      return;
    }

    print('📤 Sending message: $messageId → $recipientId');

    _socket!.emit('message:send', {
      'messageId': messageId,
      'recipientId': recipientId,
      'encryptedType': encryptedType,
      'encryptedBody': encryptedBody,
      'attachmentData': attachmentData,
      'attachmentType': attachmentType,
      'attachmentName': attachmentName,
      'attachmentMimeType': attachmentMimeType,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  void updateMessageStatus({
    required String messageId,
    required String status,
    required String recipientId,
  }) {
    if (!isConnected) {
      return;
    }

    _socket?.emit('message:status', {
      'messageId': messageId,
      'status': status,
      'recipientId': recipientId,
    });
  }

  void deleteMessage({
    required String messageId,
    required String deleteFor,
  }) {
    if (!isConnected) {
      return;
    }

    _socket?.emit('message:delete', {
      'messageId': messageId,
      'deleteFor': deleteFor,
    });
  }

  void requestUserStatus(String userId) {
    if (_socket == null) {
      return;
    }
    
    if (!_socket!.connected) {
      Future.delayed(Duration(seconds: 1), () {
        requestUserStatus(userId);
      });
      return;
    }

    _socket!.emit('request:user_status', {
      'targetUserId': userId,
    });
  }

  void disconnectOnLogout() {
    print('👋 Disconnecting on logout');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _processedMessages.clear();
    _isConnecting = false;
  }

  void dispose() {
    disconnectOnLogout(); 
    _messageController.close();
    _statusController.close();
    _deletedController.close();
    _connectionController.close();
    _userStatusController.close();
  }
}