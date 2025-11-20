
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
import 'media_service.dart';

class MessagingService {
  static bool _hasStartedTimer = false; 
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;

  MessagingService._internal();

  final _socketService = SocketService();
  final _apiService = ApiService();
  final _db = DatabaseHelper.instance;
  final _signalProtocol = SignalProtocolManager();
  final _storage = const FlutterSecureStorage();
   final _mediaService = MediaService.instance; 

  final _uuid = const Uuid();
  String? _userIdCache;
  String? _currentOpenChatUserId;

  final Set<String> _processedMessageIds = {};
  bool _listenersSetup = false;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _deleteSubscription;
  Timer? _cleanupTimer;
  Timer? _expiryTimer;
  static int decryptionFailure = 0;

  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageExpiredController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final _uploadProgressController = StreamController<UploadProgress>.broadcast();



  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted =>
      _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onMessageStatusUpdate =>
      _messageStatusController.stream;
         Stream<Map<String, dynamic>> get onMessageExpired => 
      _messageExpiredController.stream;
        Stream<UploadProgress> get onUploadProgress => _uploadProgressController.stream;



  bool get isConnected => _socketService.isConnected;
  Stream<Map<String, dynamic>> get onUserStatusChange =>
      _socketService.onUserStatusChange;

  void requestUserStatus(String userId) {
    _socketService.requestUserStatus(userId);
  }

  Future<bool> initialize() async {
    try {
      await _cacheUserId();
      await SignalProtocolManager().initialize();

      if (!_socketService.isConnected) {
        final socketConnected = await _socketService.connect();
        if (!socketConnected) {
          return false;
        }
      } else {}
        print('🔍 Checking for expired messages on app start...');
    await deleteExpiredMessages(); 
    
      if (!_hasStartedTimer) {
        startLocalExpiryTimer();
        _hasStartedTimer = true;
        print('⏱️ Global expiry timer started');
      }

      _setupSocketListeners();
      _startMessageCacheCleanup();

      return true;
    } catch (e) {
      return false;
    }
  }

  void _setupSocketListeners() {
    if (_listenersSetup) {
      return;
    }

    _messageSubscription = _socketService.onNewMessage.listen((data) async {
      await _handleIncomingMessage(data);
    });

    _statusSubscription = _socketService.onStatusUpdate.listen((data) async {
      await _handleStatusUpdate(data);
    });

    _deleteSubscription = _socketService.onMessageDeleted.listen((data) async {
       final deletedMessageId = data['messageId'];
  
  await _db.deleteMessage(deletedMessageId);
  _messageDeletedController.add(data);
    });

  _socketService.onMessageExpired.listen((data) async {
    final messageId = data['messageId'] as String;
    print('⏱️ Message expired from backend: $messageId');
    
    await _db.deleteMessage(messageId);
    
    _messageExpiredController.add({'messageId': messageId});
  });

    _listenersSetup = true;
  }

  // إرسال رسالة مع Base64
  Future<Map<String, dynamic>> sendMessage({
    required String recipientId,
    required String recipientName,
    required String messageText,
    File? imageFile,
    File? attachmentFile,
    String? fileName,
  }) async {
    try {
      resendPendingMessages();
      final messageId = _uuid.v4();
      final conversationId = _generateConversationId(recipientId);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      
    final duration = await _db.getUserDuration(conversationId);
    
    if (duration == null) {
      throw Exception('يجب تحديد مدة الرسالة أولاً');
    }

    final now = DateTime.now();
    final expiresAt = now.add(Duration(seconds: duration));

        String? attachmentData;
      String? attachmentType;
      String? attachmentName;

      if (imageFile != null) {
        _emitProgress(UploadProgress(
          stage: UploadStage.compressing,
          progress: 0.1,
          message: 'جاري ضغط الصورة...',
        ));

        //  ضغط الصورة
        final mediaResult = await _mediaService.processImage(imageFile);

        if (!mediaResult.success || mediaResult.file == null) {
          throw Exception(mediaResult.errorMessage ?? 'فشل معالجة الصورة');
        }

        _emitProgress(UploadProgress(
          stage: UploadStage.encoding,
          progress: 0.4,
          message: 'جاري تحويل الصورة...',
        ));

        //  تحويل ل Base64
        attachmentData = await _mediaService.fileToBase64(mediaResult.file!);
        attachmentType = 'image';
        attachmentName = mediaResult.fileName;


      } else if (attachmentFile != null) {
        _emitProgress(UploadProgress(
          stage: UploadStage.validating,
          progress: 0.2,
          message: 'جاري التحقق من الملف...',
        ));

        //  التحقق من الحجم
        final fileSize = await attachmentFile.length();
        if (fileSize > MediaService.maxFileSizeMB * 1024 * 1024) {
          throw Exception('الملف كبير جداً (الحد الأقصى ${MediaService.maxFileSizeMB}MB)');
        }

        _emitProgress(UploadProgress(
          stage: UploadStage.encoding,
          progress: 0.5,
          message: 'جاري تحويل الملف...',
        ));

        //  تحويل ل Base64
        attachmentData = await _mediaService.fileToBase64(attachmentFile);
        attachmentType = 'file';
        attachmentName = fileName ?? attachmentFile.path.split('/').last;

      }

      final hasSession = await _signalProtocol.sessionExists(recipientId);
      if (!hasSession) {
        print('⚠️ No session found with $recipientId. Creating one...');
        final sessionCreated = await createNewSession(recipientId);
        if (!sessionCreated) {
          throw Exception('Failed to create new session with $recipientId');
        }
      }

      //  تشفير الرسالة
      final encrypted = await _signalProtocol.encryptMessage(
        recipientId,
        messageText,
      );

      if (encrypted == null) {
        throw Exception('Encryption failed');
      }
      //تشفير الملف 
      String? encryptedAttachmentData;
      if (attachmentData != null) {
        final encryptedAttachment = await _signalProtocol.encryptMessage(recipientId, attachmentData);
        if (encryptedAttachment == null) {
          throw Exception('Failed to encrypt attachment');
        }
        encryptedAttachmentData = encryptedAttachment['body'];
        print('✅ Attachment encrypted');
      }


      //  حفظ في SQLite
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
        'visibilityDuration': duration,
        'expiresAt': expiresAt?.millisecondsSinceEpoch,
        'isExpired': 0,
      });

      // حفظ المحادثة
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
       _emitProgress(UploadProgress(
        stage: UploadStage.sending,
        progress: 0.9,
        message: 'جاري الإرسال...',
      ));

      //  إرسال عبر Socket مع المرفقات
      _socketService.sendMessageWithAttachment(
        messageId: messageId,
        recipientId: recipientId,
        encryptedType: encrypted['type'],
        encryptedBody: encrypted['body'],
        attachmentData: encryptedAttachmentData,
        attachmentType: attachmentType,
        attachmentName: attachmentName,
        visibilityDuration: duration,                 
        expiresAt: expiresAt.toUtc().toIso8601String(),
        

      );
     _emitProgress(UploadProgress(
        stage: UploadStage.complete,
        progress: 1.0,
        message: 'تم الإرسال بنجاح',
      ));
      print('✅ Message sent with encrypted Base64 attachment');
      Future.delayed(Duration(seconds: 1), () {
      });

      return {'success': true, 'messageId': messageId};
    } catch (e) {
      _emitProgress(UploadProgress(
        stage: UploadStage.error,
        progress: 0.0,
        message: 'فشل الإرسال: $e',
      ));      return {'success': false, 'message': 'فشل إرسال الرسالة: $e'};
    }
  }

   void _emitProgress(UploadProgress progress) {
    if (!_uploadProgressController.isClosed) {
      _uploadProgressController.add(progress);
    }
  }

  // استقبال رسالة مع Base64
  Future<void> _handleIncomingMessage(Map data) async {
    try {
      final messageId = data['messageId'] as String;

      if (_processedMessageIds.contains(messageId)) {
        return;
      }

      final existing = await _db.getMessage(messageId);
      if (existing != null) {
        _processedMessageIds.add(messageId);
        return;
      }

      _processedMessageIds.add(messageId);

      final senderId = data['senderId'] as String;
      final encryptedType = data['encryptedType'] as int;
      final encryptedBody = data['encryptedBody'] as String;
      final encryptedAttachmentData  = data['attachmentData'] as String?;
      final attachmentType = data['attachmentType'] as String?;
      final attachmentName = data['attachmentName'] as String?;
      final visibilityDuration = data['visibilityDuration'] as int?;
      final expiresAtStr = data['expiresAt'] as String?;


      int? expiresAt;
      if (expiresAtStr != null) {
        try {
          expiresAt = DateTime.parse(expiresAtStr).toUtc().millisecondsSinceEpoch;
        } catch (e) {
        }
      }
     
      //  فك تشفير 
      String? decryptedAttachmentData;
      if (encryptedAttachmentData != null) {
        try {
          decryptedAttachmentData = await _signalProtocol.decryptMessage(
            senderId,
            3, // نفس الـ encryptionType
            encryptedAttachmentData,
          );
          if (decryptedAttachmentData == null) {
            print('❌ Failed to decrypt attachment');
            decryptedAttachmentData = encryptedAttachmentData; // نحفظ المشفر
          } else {
            print('✅ Attachment decrypted');
          }
        } catch (e) {
          print('❌ Error decrypting attachment: $e');
          decryptedAttachmentData = encryptedAttachmentData;
        }
      }


      final timestamp = data['createdAt'] != null
          ? DateTime.parse(data['createdAt']).millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch;

      final conversationId = _generateConversationId(senderId);

      final bool isCurrentChat = _currentOpenChatUserId == senderId;

      // حفظ الرسالة المشفرة مع المرفقات
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
        // ✅ نضع isDecrypted = 0 بغض النظر
        'isDecrypted': 0,
        'attachmentData': decryptedAttachmentData,
        'attachmentType': attachmentType,
        'attachmentName': attachmentName,
        'visibilityDuration': visibilityDuration,
        'expiresAt': expiresAt,
        'isExpired': 0,
      });

      if (!isCurrentChat) {
        await _db.incrementUnreadCount(conversationId);
      } else {
        await _db.markConversationAsRead(conversationId);
      }

      _newMessageController.add({
        'messageId': messageId,
        'conversationId': conversationId,
        'senderId': senderId,
        'isLocked': true,
      });
    } catch (e) {
    print('❌ Error in _handleIncomingMessage: $e');

    }

    Future<void> updateConversationPrivacyPolicy({
      required String peerUserId,
      required bool allowScreenshots,
    }) async {
      try {
        await ApiService.instance.putJson('/contacts/$peerUserId/screenshots', {
          'allowScreenshots': allowScreenshots,
        });
      } catch (e) {
        debugPrint('❌ Failed to update privacy policy: $e');
      }
    }
  }

  Future<void> _handleStatusUpdate(Map<String, dynamic> data) async {
    try {
      if (data['type'] == 'recipient_failed_verification') {
        final recipientId = data['recipientId'];
        print('⚠️ Handling failed verification for recipient: $recipientId');

        if (!_messageStatusController.isClosed) {
          _messageStatusController.add({
            'type': 'recipient_failed_verification',
            'recipientId': recipientId,
          });
        }
        return;
      }

      final messageId = data['messageId'];
      final newStatus = data['status'];
      final visibilityDuration = data['visibilityDuration'] as int?;
      final expiresAtStr = data['expiresAt'] as String?;

   
    int? expiresAt;
    if (expiresAtStr != null) {
      try {
        expiresAt = DateTime.parse(expiresAtStr).millisecondsSinceEpoch;
      } catch (e) {
        print('⚠️ Failed to parse expiresAt from status_update: $expiresAtStr');
      }
    }

    final updateData = <String, dynamic>{
      'status': newStatus,
    };

    if (visibilityDuration != null) {
      updateData['visibilityDuration'] = visibilityDuration;
    }

    /*
    if (expiresAt != null) {
      updateData['expiresAt'] = expiresAt;
    }
    */

    await _db.updateMessage(messageId, updateData);

      if (!_messageStatusController.isClosed) {
        _messageStatusController.add({
          'messageId': messageId,
          'status': newStatus,
        });
      }
    } catch (e) {
      print('❌ Error in _handleStatusUpdate: $e');
    }
  }

  Future<void> resendPendingMessages() async {
    final db = DatabaseHelper.instance;
    final pending = await db.getPendingMessages();

    for (final msg in pending) {
      try {
        print('🔁 Re-sending pending message ${msg['id']}');
        _socketService.sendMessageWithAttachment(
          messageId: msg['id'],
          recipientId: msg['receiverId'],
          encryptedType: msg['encryptionType'],
          encryptedBody: msg['ciphertext'],
          attachmentData: msg['attachmentData'],
          attachmentType: msg['attachmentType'],
          attachmentName: msg['attachmentName'],
        );
        await db.updateMessageStatus(msg['id'], 'sent');
      } catch (e) {
        print('⚠️ Failed to resend ${msg['id']}: $e');
      }
    }
  }

  Future<void> _handleMessageDeleted(Map<String, dynamic> data) async {
    try {
      final messageId = data['messageId'];
      final deletedFor = data['deletedFor'];
      print('🗑️ Received delete notification: $messageId (deletedFor: $deletedFor)');


      if (!_messageDeletedController.isClosed) {
        _messageDeletedController.add({
          'messageId': messageId,
          'deletedFor': deletedFor,
        });
      }

      // ثم حذف من SQLite
      await Future.delayed(Duration(milliseconds: 50));

      if (deletedFor == 'everyone') {
        await _db.deleteMessage(messageId);
       print('✅ Deleted message for everyone: $messageId');

      } else if (deletedFor == 'recipient') {
        await _db.deleteMessage(messageId);
      print('✅ Deleted message at recipient: $messageId');

      }
    } catch (e) {
    print('❌ Error handling delete: $e');

    }
  }

  Future<Map<String, dynamic>> decryptAllConversationMessages(
    String conversationId,
  ) async {
    try {
      print('Starting decryption for conversation: $conversationId');

      // نجلب الرسائل المشفرة غير المفكوكة للمحادثة
      final encryptedMessages = await _db.getEncryptedMessages(conversationId);

      if (encryptedMessages.isEmpty) {
        print('No encrypted messages to decrypt');
        return {
          'success': true,
          'message': 'لا توجد رسائل تحتاج فك تشفير',
          'count': 0,
        };
      }

      print('Found ${encryptedMessages.length} encrypted messages');

      // نفك التشفير لكل رسالة ونحدثها بقاعدة البيانات
      int successCount = 0;
      String? lastError;
      String? lastErrorType;

      for (final message in encryptedMessages) {
        try {
          final messageId = message['id'];
          final senderId = message['senderId'];

          print('Decrypting message $messageId from $senderId');

          final decrypted = await _signalProtocol.decryptMessage(
            senderId,
            message['encryptionType'],
            message['ciphertext'],
          );

          if (decrypted != null) {
            await _db.updateMessage(messageId, {
              'plaintext': decrypted,
              'isDecrypted': 1,
              'requiresBiometric': 1,
              'status': 'read',
              'readAt': DateTime.now().millisecondsSinceEpoch,
            });

            // إرسال حالة القراءة للمرسل
            _socketService.updateMessageStatus(
              messageId: messageId,
              status: 'verified',
              recipientId: senderId,
            );

            successCount++;
            print('Message $messageId decrypted successfully');
          } else {
            lastError = 'Decryption returned null';
            decryptionFailure++;
            if (decryptionFailure >= 1) {
              await _signalProtocol.deleteSession(senderId);
              await deleteConversation(conversationId);
              return {
                'success': false,
                'error': 'SessionReset',
                'message': 'Session reset due to decryption errors',
              };
              print ('session reset due to decryption failuer');
            }
            lastErrorType = 'DecryptionFailure';
            print('Decryption returned null for message $messageId');
          }
        } catch (e) {
          lastError = e.toString();

          decryptionFailure++;

          // استخراج نوع الخطأ بشكل أفضل
          if (e.toString().contains('InvalidKeyException')) {
            lastErrorType = 'InvalidKeyException';
          } else if (e.toString().contains('InvalidMessageException')) {
            lastErrorType = 'InvalidMessageException';
          } else if (e.toString().contains('InvalidSessionException') ||
              e.toString().contains('NoSessionException')) {
            lastErrorType = 'InvalidSessionException';
          } else if (e.toString().contains('UntrustedIdentityException')) {
            lastErrorType = 'UntrustedIdentityException';
          } else if (e.toString().contains('session') ||
              e.toString().contains('Session')) {
            lastErrorType = 'InvalidSessionException';
          } else {
            lastErrorType = 'UnknownError';
          }

          print('Failed to decrypt message: $lastErrorType - $e');
        }
      }

      //  إذا نجحت جميع الرسائل
      if (successCount == encryptedMessages.length) {
        print(
          'All messages decrypted successfully ($successCount/${encryptedMessages.length})',
        );
        return {
          'success': true,
          'message': 'تم فك تشفير $successCount رسائل',
          'count': successCount,
        };
      }

      //  إذا فشلت جميع الرسائل
      if (successCount == 0) {
        print('All messages failed to decrypt. Error: $lastErrorType');
        return {
          'success': false,
          'message': 'فشل فك تشفير جميع الرسائل',
          'count': 0,
          'error': lastErrorType,
          'errorMessage': lastError,
        };
      }

      //  إذا نجح البعض وفشل البعض
      print(
        'Partial success: $successCount/${encryptedMessages.length} decrypted',
      );
      return {
        'success': true, // نعتبره نجاح جزئي
        'message':
            'تم فك تشفير $successCount من ${encryptedMessages.length} رسائل',
        'count': successCount,
        'error': lastErrorType, // نرجع آخر خطأ حدث
        'errorMessage': lastError,
      };
    } catch (e) {
      print('Critical error in decryptAllConversationMessages: $e');

      //  تحديد نوع الخطأ
      String errorType = 'UnknownError';

      if (e.toString().contains('InvalidKeyException')) {
        errorType = 'InvalidKeyException';
      } else if (e.toString().contains('InvalidSessionException') ||
          e.toString().contains('NoSessionException')) {
        errorType = 'InvalidSessionException';
      } else if (e.toString().contains('session') ||
          e.toString().contains('Session')) {
        errorType = 'InvalidSessionException';
      }

      return {
        'success': false,
        'message': 'فشل فك تشفير الرسائل',
        'count': 0,
        'error': errorType,
        'errorMessage': e.toString(),
      };
    }
  }

  //فك تشفير رسالة واحدة (يطلب التحقق كل مرة) - نبقي هذه الدالة كاحتياط
  Future<Map<String, dynamic>> decryptMessage(String messageId) async {
    try {
      // التحقق البيومتري - كل مرة تُفتح رسالة
      final authenticated = await BiometricService.authenticateWithBiometrics(
        reason: 'تحقق من هويتك لقراءة الرسالة',
      );

      if (!authenticated) {
        return {'success': false, 'message': 'فشل التحقق بالبايومتركس'};
      }

      final message = await _db.getMessage(messageId);
      if (message == null) {
        throw Exception('Message not found');
      }

      // فك التشفير
      final decrypted = await _signalProtocol.decryptMessage(
        message['senderId'],
        message['encryptionType'],
        message['ciphertext'],
      );

      if (decrypted == null) {
        throw Exception('Decryption failed');
      }

      // تحديث الرسالة
      await _db.updateMessage(messageId, {
        'plaintext': decrypted,
        'isDecrypted': 1,
        'requiresBiometric': 1,
        'status': 'read',
        'readAt': DateTime.now().millisecondsSinceEpoch,
      });

      _socketService.updateMessageStatus(
        messageId: messageId,
        status: 'verified',
        recipientId: message['senderId'],
      );

      return {'success': true, 'plaintext': decrypted};
    } catch (e) {
      return {'success': false, 'message': 'فشل فك التشفير: $e'};
    }
  }

  //  جلب الرسائل
  Future<List<Map<String, dynamic>>> getConversationMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    try {
      return await _db.getMessages(conversationId, limit: limit);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllConversations() async {
    try {
      return await _db.getConversations();
    } catch (e) {
      return [];
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _db.markConversationAsRead(conversationId);
    } catch (e) {}
  }

  // حذف رسالة - مُحدَّث
  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    required bool deleteForEveryone,
  }) async {
    try {
      final message = await _db.getMessage(messageId);

      if (message == null) {
        return {'success': false, 'message': 'الرسالة غير موجودة'};
      }

      final String otherUserId;
    final bool isMine = (message['isMine'] as int?) == 1;
    
    if (isMine) {
      otherUserId = message['receiverId'] as String;
    } else {
      otherUserId = message['senderId'] as String;
    }

    print('🗑️ Delete request:');
    print('   messageId: $messageId');
    print('   otherUserId: $otherUserId');
    print('   deleteForEveryone: $deleteForEveryone');


      if (deleteForEveryone) {
        await _db.deleteMessage(messageId);
        _socketService.socket?.emit('message:delete_local', {
        'messageId': messageId,
        'deleteFor': 'everyone',
        'recipientId': otherUserId,
      });

      print('✅ Deleted for everyone');

        return {'success': true, 'message': 'تم الحذف للجميع'};
      } else {
     
        await _db.updateMessage(messageId, {'deletedForRecipient': 1});
                print('✅ Updated deletedForRecipient = 1 for message: $messageId');


      _socketService.socket?.emit('message:delete_local', {
        'messageId': messageId,
        'deleteFor': 'recipient',
        'recipientId': otherUserId,
      });

  final updatedMessage = await _db.getMessage(messageId);
  print('🔍 Message after update: $updatedMessage');



        return {'success': true, 'message': 'تم الحذف من عند المستقبل'};
      }
      } catch (e, stackTrace) {
    print('❌ Delete error: $e');
    print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'فشل الحذف: $e'};
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _db.deleteConversation(conversationId);
    } catch (e) {}
  }

  Future<void> logout() async {
    try {
      _socketService.disconnectOnLogout();
      await _db.clearAllData();
    } catch (e) {}
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
        final toKeep = _processedMessageIds
            .skip(_processedMessageIds.length - 50)
            .toList();
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
     _messageExpiredController.close();
     _uploadProgressController.close();
    _expiryTimer?.cancel();
    _cleanupTimer?.cancel();
  }

  String getConversationId(String otherUserId) {
    return _generateConversationId(otherUserId);
  }

  void setCurrentOpenChat(String? userId) {
    _currentOpenChatUserId = userId;
  }

  /// حذف Session مع مستخدم معين
  Future<void> deleteSession(String userId) async {
    try {
      print('🗑️ Deleting session for $userId');
      await _signalProtocol.deleteSession(userId);
      print('✅ Session deleted successfully');
    } catch (e) {
      print('❌ Error deleting session: $e');
      rethrow;
    }
  }

  /// إنشاء Session جديد مع مستخدم معين
  Future<bool> createNewSession(String userId) async {
    try {
      print('🔄 Creating new session for $userId');

      // تهيئة SignalProtocol إذا لم يكن مهيئاً
      await _signalProtocol.initialize();

      final success = await _signalProtocol.createSession(userId);

      if (success) {
        print('✅ New session created successfully for $userId');
      } else {
        print('❌ Failed to create new session for $userId');
      }

      return success;
    } catch (e) {
      print('❌ Error creating new session: $e');
      return false;
    }
  }

  
Future<int?> getUserDuration(String conversationId) async {
  return await _db.getUserDuration(conversationId);
}

Future<void> setUserDuration(String conversationId, int duration) async {
  await _db.setUserDuration(conversationId, duration);

  
}

Future<void> deleteExpiredMessages() async {
  final now = DateTime.now();
  
  final expiredIds = await _db.deleteExpiredMessages();
  
  
  for (final messageId in expiredIds) {
    _messageExpiredController.add({'messageId': messageId});
  }
 
}

 void startLocalExpiryTimer() {
    
    // _expiryTimer?.cancel();
    
    if (_expiryTimer != null && _expiryTimer!.isActive) {
      return;
    }
    
    _expiryTimer = Timer.periodic(
      const Duration(seconds: 5), 
      (timer) async {
        await deleteExpiredMessages();
      },
    );
  }

}
enum UploadStage {
  idle,
  validating,
  compressing,
  encoding,
  encrypting,
  saving,
  sending,
  complete,
  error,
}

class UploadProgress {
  final UploadStage stage;
  final double progress; //حسبناها على اساس من صفر لواحد 
  final String message;

  UploadProgress({
    required this.stage,
    required this.progress,
    required this.message,
  });

  factory UploadProgress.idle() {
    return UploadProgress(
      stage: UploadStage.idle,
      progress: 0.0,
      message: '',
    );
  }

  bool get isIdle => stage == UploadStage.idle;
  bool get isComplete => stage == UploadStage.complete;
  bool get isError => stage == UploadStage.error;
  bool get isProcessing => !isIdle && !isComplete && !isError;
}
