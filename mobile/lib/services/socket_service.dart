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
      if (_socket != null && _socket!.connected) {
        print('✅ Socket already connected');
        return true;
      }

      if (_isConnecting) {
        print('⏳ Connection in progress, waiting...');
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
      //deplyment base url
      //baseUrl = 'https://waseed-team-production.up.railway.app';

      // ============================
      // Base URL بحسب المنصة
      // ============================
      
      if (Platform.isAndroid) {
        baseUrl = 'http://10.0.2.2:3000';
      } else if (Platform.isIOS) {
        baseUrl = 'http://localhost:3000';
      } else {
        baseUrl = 'http://localhost:3000';
      }



      print('🔌 Connecting to: $baseUrl');

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
      _isConnecting = false;
      return true;

    } catch (e) {
      print('❌ Socket connection error: $e');
      _isConnecting = false;
      return false;
    }
  }

  void _setupEventListeners() {
        if (_socket == null) return;
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

   _socket?.on('connect', (_) {
  print('✅ Socket connected!');
  _connectionController.add(true);
  
  // 🆕 إعادة طلب الحالة بعد الاتصال
  Future.delayed(Duration(milliseconds: 500), () {
  });
});

    _socket?.on('connected', (data) {
    });

    // استقبال رسالة مع Base64
    _socket?.on('message:new', (data) async {
      final messageId = data['messageId'] as String;
      
      if (_processedMessages.contains(messageId)) {
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

    _socket?.on('message:sent', (data) async {
      final messageId = data['messageId'];
      final delivered = data['delivered'] ?? false;
      
      
      try {
        await DatabaseHelper.instance.updateMessageStatus(
          messageId,
          delivered ? 'delivered' : 'sent',
        );
      } catch (e) {
      }
    });

    _socket?.on('message:status_update', (data) {
      _statusController.add(Map<String, dynamic>.from(data));
    });

    _socket?.on('message:deleted', (data) async {
 
  
  final messageId = data['messageId'];
  final deletedFor = data['deletedFor'];
  
  //  1. إشعار الواجهة أولاً (أعلى أولوية)
  if (!_deletedController.isClosed) {
    _deletedController.add(Map<String, dynamic>.from(data));
  }
  
  // 2. ثم حذف من SQLite
  try {
    await Future.delayed(Duration(milliseconds: 30)); // تأخير صغير
    
    if (deletedFor == 'everyone') {
      await DatabaseHelper.instance.deleteMessage(messageId);
    } else if (deletedFor == 'recipient') {
      await DatabaseHelper.instance.deleteMessage(messageId);
    }
  } catch (e) {
  }
});

   _socket?.on('user:status', (data) {
      _userStatusController.add(Map<String, dynamic>.from(data));
    });

    _socket?.on('disconnect', (_) {
      _connectionController.add(false);
    });

    _socket?.on('error', (data) {
      print('❌ Socket error: $data');
    });

    _socket?.on('reconnect', (attempt) {
      _connectionController.add(true);
      _processedMessages.clear();
    });
  }

  // إرسال رسالة مع Base64
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
      print('Cannot send: Socket not connected');
      return;
    }

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

  //  حذف رسالة - مُحدَّث
  void deleteMessage({
    required String messageId,
    required String deleteFor, // 'everyone' or 'recipient'
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
      requestUserStatus(userId); // إعادة المحاولة
    });
    return;
  }

  _socket!.emit('request:user_status', {
    'targetUserId': userId,
  });

}
  void disconnectOnLogout() {
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