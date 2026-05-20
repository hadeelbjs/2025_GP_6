// lib/services/socket_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'local_db/database_helper.dart';
import 'messaging_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:waseed/config/appConfig.dart';

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
  final _userStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageExpiredController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onStatusUpdate => _statusController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted =>
      _deletedController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;
  Stream<Map<String, dynamic>> get onUserStatusChange =>
      _userStatusController.stream;
  Stream<Map<String, dynamic>> get onMessageExpired =>
      _messageExpiredController.stream;

  bool get isConnected => _socket?.connected ?? false;
  String? _userId;
  IO.Socket? get socket => _socket;

  final Set<String> _processedMessages = {};
  bool _isConnecting = false;

  // لمنع الطلبات المكررة للحالة
  final Map<String, DateTime> _lastStatusRequest = {};
  static const Duration _statusRequestCooldown = Duration(seconds: 2);

  static String? get baseUrl => AppConfig.socketUrl;

  Future<bool> connect() async {
    try {
      if (_socket != null && _socket!.connected) {
        return true;
      }

      if (_isConnecting) {
        await Future.delayed(Duration(seconds: 2));
        return _socket?.connected ?? false;
      }

      _isConnecting = true;

      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        _isConnecting = false;
        return false;
      }

      final userDataStr = await _storage.read(key: 'user_data');
      if (userDataStr == null) {
        _isConnecting = false;
        return false;
      }

      final userData = jsonDecode(userDataStr);
      _userId = userData['id'];

      if (_userId == null || _userId!.isEmpty) {
        _isConnecting = false;
        return false;
      }

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling']) // كلاهما
            .enableForceNew() // إجبار اتصال جديد
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionAttempts(3)
            .setAuth({'token': token})
            .setTimeout(10000)
            .disableMultiplex() // تعطيل multiplexing
            .setExtraHeaders({'Authorization': 'Bearer $token'}) // header إضافي
            .build(),
      );

      _socket!.onConnectError((data) {
        if (data.toString().contains('host lookup') ||
            data.toString().contains('No address')) {
          return;
        }
      });

      _socket!.onError((data) {
        if (data.toString().contains('host lookup') ||
            data.toString().contains('No address')) {
          return;
        }
      });

      _setupEventListeners();

      _socket!.connect();

      await Future.delayed(Duration(seconds: 3));

      if (_socket!.connected) {
        _isConnecting = false;
        return true;
      } else {
       
        _isConnecting = false;
        return false;
      }
    } catch (e, stackTrace) {
   
      _isConnecting = false;
      return false;
    }
  }

  void _setupEventListeners() {
    if (_socket == null) {
      return;
    }

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

    _socket!.on('connect', (_) {
      _connectionController.add(true);
      MessagingService().resendPendingMessages(); 

    });
    _socket!.on('connect_error', (error) {
      final errorStr = error.toString();
      if (errorStr.contains('host lookup') ||
          errorStr.contains('No address') ||
          errorStr.contains('Failed host lookup')) {
        return;
      }
    });


    _socket!.on('error', (data) {
      final errorStr = data.toString();
      if (errorStr.contains('host lookup') ||
          errorStr.contains('No address') ||
          errorStr.contains('Failed host lookup')) {
        return;
      }
    });

    

   _socket!.on('message:new', (data) async {
  final messageId = data['messageId'] as String;

  if (_processedMessages.contains(messageId)) {
    return;
  }

  _processedMessages.add(messageId);
  _messageController.add(Map<String, dynamic>.from(data));

  // أرسل تأكيد الاستلام للسيرفر ليحذف من MongoDB
  _socket?.emit('message:delivered', {'messageId': messageId});
});

    _socket!.on('message:sent', (data) async {
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

    _socket!.on('message:status_update', (data) {
      _statusController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message:deleted', (data) async {

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
        print('Error deleting message: $e');
      }
    });

    _socket!.on('user:status', (data) {
      _userStatusController.add(Map<String, dynamic>.from(data));
    });
 
    _socket!.on('conversation:recipient_failed_verification', (data) async {
      final recipientId = data['recipientId'];
      final Database db = await DatabaseHelper.instance.database;
      await db.rawUpdate(
        '''
    UPDATE messages 
    SET failedVerificationAtRecipient = 1 
    WHERE receiverId = ? AND isMine = 1
  ''',
        [recipientId],
      );

      _statusController.add({
        'type': 'recipient_failed_verification',
        'recipientId': recipientId,
      });
    });

    _socket!.on('contact:emergency_mode_activated', (data) {
      _statusController.add({
        'type': 'peer_emergency_mode',
        'userId': data['userId'],
        'at': data['at'],
      });
    });

    _socket!.on('disconnect', (reason) {
     
      _connectionController.add(false);
    });

    _socket!.on('reconnect', (attempt) async {
      _connectionController.add(true);
      _processedMessages.clear();

    });

    _socket!.on('privacy:screenshots:changed', (data) {

      // تمرير الحدث للـ Controller
      if (!_statusController.isClosed) {
        _statusController.add({
          'type': 'privacy_changed',
          'peerUserId': data['peerUserId'],
          'allowScreenshots': data['allowScreenshots'],
        });
      }
    });

  
    _socket!.on('screenshot:notification', (data) {

      final takenBy = data['takenBy'];
      final timestamp = data['timestamp'];

      //  عرض رسالة للمستخدم
      if (!_statusController.isClosed) {
        _statusController.add({
          'type': 'screenshot_taken',
          'takenBy': takenBy,
          'timestamp': timestamp,
          'message': data['message'],
        });
      }
    });

    _socket?.on('message:expired', (data) {

      if (data != null && data is Map) {
        final messageId = data['messageId'];
        if (messageId != null) {
          _messageExpiredController.add({
            'messageId': messageId,
            'reason': data['reason'] ?? 'duration_ended',
          });
        }
      }
    });

   
  }

  void sendMessageWithAttachment({
    required String messageId,
    required String recipientId,
    required int encryptedType,
    required String encryptedBody,
    String? attachmentData,
    String? attachmentType,
    String? attachmentName,
    String? attachmentEncryptionType,
    int? visibilityDuration,
    String? expiresAt,
    String? createdAt,
  }) {
    if (_socket == null || !isConnected) {
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
      'attachmentEncryptionType': attachmentEncryptionType,
      'visibilityDuration': visibilityDuration,
      'expiresAt': expiresAt,
      'createdAt': createdAt, // ✅ إرسال createdAt الصحيح
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

  void deleteMessage({required String messageId, required String deleteFor}) {
    if (!isConnected) {
      return;
    }

    _socket?.emit('message:delete', {
      'messageId': messageId,
      'deleteFor': deleteFor,
    });
  }

  void updateConversationDuration(String conversationId, int duration) {
    if (_socket == null || !_socket!.connected) {
      return;
    }

    _socket!.emit('conversation:duration:update', {
      'conversationId': conversationId,
      'duration': duration,
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

    // منع الطلبات المكررة لنفس المستخدم في فترة قصيرة
    final now = DateTime.now();
    final lastRequest = _lastStatusRequest[userId];

    if (lastRequest != null) {
      final timeSinceLastRequest = now.difference(lastRequest);
      if (timeSinceLastRequest < _statusRequestCooldown) {
        // تم طلب الحالة مؤخراً، تجاهل هذا الطلب
        return;
      }
    }

    // تحديث وقت آخر طلب
    _lastStatusRequest[userId] = now;

    _socket!.emit('request:user_status', {'targetUserId': userId});
  }

  void disconnectOnLogout() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _processedMessages.clear();
    _isConnecting = false;
  }

  void emitEvent(String event, Map<String, dynamic> data) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, data);
    }
  }

  void dispose() {
    disconnectOnLogout();
    _messageController.close();
    _statusController.close();
    _deletedController.close();
    _connectionController.close();
    _userStatusController.close();
    _messageExpiredController.close();
  }
}