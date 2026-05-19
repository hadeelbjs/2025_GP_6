// lib/services/messaging_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'socket_service.dart';
import 'api_services.dart';
import 'biometric_service.dart';
import 'local_db/database_helper.dart';
import 'crypto/signal_protocol_manager.dart';
import 'media_service.dart';

class MessagingService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final _socket = SocketService();
  final _api = ApiService();
  final _db = DatabaseHelper.instance;
  final _signal = SignalProtocolManager();
  final _media = MediaService.instance;
  final _storage = const FlutterSecureStorage();
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  static bool _expiryTimerStarted = false;
  static int _decryptionFailureCount = 0;

  String? _cachedUserId;
  String? _currentOpenChatUserId;
  bool _listenersSetup = false;

  final Set<String> _processedMessageIds = {};
  final Map<String, Timer> _messageTimers = {};

  StreamSubscription? _msgSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _deleteSub;
  Timer? _cleanupTimer;
  Timer? _expiryTimer;

  // ---------------------------------------------------------------------------
  // Public streams
  // ---------------------------------------------------------------------------

  final _newMessageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _deletedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _statusCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _expiredCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _uploadProgressCtrl = StreamController<UploadProgress>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _deletedCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageStatusUpdate => _statusCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageExpired => _expiredCtrl.stream;
  Stream<UploadProgress> get onUploadProgress => _uploadProgressCtrl.stream;

  bool get isConnected => _socket.isConnected;
  Stream<Map<String, dynamic>> get onUserStatusChange => _socket.onUserStatusChange;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<bool> initialize() async {
    try {
      await _cacheUserId();
      await _signal.initialize();

      if (!_socket.isConnected) {
        final connected = await _socket.connect();
        if (!connected) return false;
      }

      await deleteExpiredMessages();
      await _loadMessageTimers();

      if (!_expiryTimerStarted) {
        _startGlobalExpiryTimer();
        _expiryTimerStarted = true;
      }

      _setupSocketListeners();
      _startCacheCleanupTimer();

      return true;
    } catch (_) {
      return false;
    }
  }

  void _setupSocketListeners() {
    if (_listenersSetup) return;

    _msgSub = _socket.onNewMessage.listen(_handleIncomingMessage);
    _statusSub = _socket.onStatusUpdate.listen(_handleStatusUpdate);
    _deleteSub = _socket.onMessageDeleted.listen((data) async {
      final messageId = data['messageId'] as String;
      await _db.deleteMessage(messageId);
      _deletedCtrl.add(data);
    });

    _socket.onMessageExpired.listen((data) async {
      final messageId = data['messageId'] as String;
      await _db.deleteMessage(messageId);
      _expiredCtrl.add({'messageId': messageId});
    });

    _listenersSetup = true;
  }

  // ---------------------------------------------------------------------------
  // Send message
  // ---------------------------------------------------------------------------

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
      final conversationId = _conversationId(recipientId);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final duration = await _db.getUserDuration(conversationId);
      if (duration == null) {
        throw Exception('يجب تحديد مدة الرسالة أولاً');
      }

      final expiresAt = DateTime.now().add(Duration(seconds: duration));

      // ── Attachment processing ────────────────────────────────────────────
      String? attachmentData;
      String? attachmentType;
      String? attachmentName;

      if (imageFile != null) {
        _emitProgress(UploadProgress(stage: UploadStage.compressing, progress: 0.1, message: 'جاري ضغط الصورة...'));
        final result = await _media.processImage(imageFile);
        if (!result.success || result.file == null) {
          throw Exception(result.errorMessage ?? 'فشل معالجة الصورة');
        }
        _emitProgress(UploadProgress(stage: UploadStage.encoding, progress: 0.4, message: 'جاري تحويل الصورة...'));
        attachmentData = await _media.fileToBase64(result.file!);
        attachmentType = 'image';
        attachmentName = result.fileName;
      } else if (attachmentFile != null) {
        _emitProgress(UploadProgress(stage: UploadStage.validating, progress: 0.2, message: 'جاري التحقق من الملف...'));
        final fileSize = await attachmentFile.length();
        if (fileSize > MediaService.maxFileSizeMB * 1024 * 1024) {
          throw Exception('الملف كبير جداً (الحد الأقصى ${MediaService.maxFileSizeMB}MB)');
        }
        _emitProgress(UploadProgress(stage: UploadStage.encoding, progress: 0.5, message: 'جاري تحويل الملف...'));
        attachmentData = await _media.fileToBase64(attachmentFile);
        attachmentType = 'file';
        attachmentName = fileName ?? attachmentFile.path.split('/').last;
      }

      // ── Session checks ───────────────────────────────────────────────────
      final peerCheck = await _api.getPeerKeysVersion(recipientId);
      final peerKeysExist = peerCheck['success'] == true && peerCheck['exists'] == true;

      if (peerCheck['success'] == true && !peerKeysExist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rekey_required_$recipientId', true);
        return {'success': false, 'code': 'REKEY_REQUIRED', 'message': 'الطرف الآخر لم يرفع مفاتيح التشفير الجديدة بعد'};
      }

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('rekey_required_$recipientId') ?? false) {
        if (!await createNewSession(recipientId)) {
          return {'success': false, 'code': 'REKEY_REQUIRED', 'message': 'تعذر إنشاء جلسة تشفير جديدة حالياً'};
        }
        await prefs.remove('rekey_required_$recipientId');
      }

      if (!await _signal.sessionExists(recipientId)) {
        if (!await createNewSession(recipientId)) {
          return {'success': false, 'code': 'REKEY_REQUIRED', 'message': 'تعذر إنشاء جلسة تشفير جديدة مع الطرف الآخر'};
        }
      }

      // ── Encrypt ──────────────────────────────────────────────────────────
      final encrypted = await _signal.encryptMessage(recipientId, messageText);
      if (encrypted == null) throw Exception('Encryption failed');

      String? encryptedAttachment;
      String? attachmentEncType;
      if (attachmentData != null) {
        final enc = await _signal.encryptMessage(recipientId, attachmentData);
        if (enc == null) throw Exception('Failed to encrypt attachment');
        encryptedAttachment = enc['body'] as String;
        attachmentEncType = enc['type']?.toString();
      }

      // ── Persist ──────────────────────────────────────────────────────────
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
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'isExpired': 0,
      });

      _scheduleMessageExpiry(messageId, expiresAt.millisecondsSinceEpoch);

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

      // ── Send over socket ─────────────────────────────────────────────────
      _emitProgress(UploadProgress(stage: UploadStage.sending, progress: 0.9, message: 'جاري الإرسال...'));

      _socket.sendMessageWithAttachment(
        messageId: messageId,
        recipientId: recipientId,
        encryptedType: encrypted['type'],
        encryptedBody: encrypted['body'],
        attachmentData: encryptedAttachment,
        attachmentType: attachmentType,
        attachmentName: attachmentName,
        attachmentEncryptionType: attachmentEncType,
        visibilityDuration: duration,
        expiresAt: expiresAt.toUtc().toIso8601String(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc().toIso8601String(),
      );

      _emitProgress(UploadProgress(stage: UploadStage.complete, progress: 1.0, message: 'تم الإرسال بنجاح'));

      return {'success': true, 'messageId': messageId};
    } catch (e) {
      _emitProgress(UploadProgress(stage: UploadStage.error, progress: 0.0, message: 'فشل الإرسال: $e'));
      return {'success': false, 'message': 'فشل إرسال الرسالة: $e'};
    }
  }

  void _emitProgress(UploadProgress p) {
    if (!_uploadProgressCtrl.isClosed) _uploadProgressCtrl.add(p);
  }

  // ---------------------------------------------------------------------------
  // Receive message
  // ---------------------------------------------------------------------------

  Future<void> _handleIncomingMessage(Map data) async {
    try {
      final messageId = data['messageId'] as String;

      if (_processedMessageIds.contains(messageId)) return;
      if (await _db.getMessage(messageId) != null) {
        _processedMessageIds.add(messageId);
        return;
      }
      _processedMessageIds.add(messageId);

      final senderId = data['senderId'] as String;
      final encryptedType = data['encryptedType'] as int;
      final encryptedBody = data['encryptedBody'] as String;
      final encryptedAttachment = data['attachmentData'] as String?;
      final attachmentType = data['attachmentType'] as String?;
      final attachmentName = data['attachmentName'] as String?;
      final attachmentEncType = data['attachmentEncryptionType'] as String?;
      final visibilityDuration = data['visibilityDuration'] as int?;
      final expiresAtStr = data['expiresAt'] as String?;

      final timestamp = data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String).millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch;

      // Receiver always gets a fresh window starting from now
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final int? expiresAt = visibilityDuration != null
          ? now + (visibilityDuration * 1000)
          : null;

      final conversationId = _conversationId(senderId);
      final isCurrentChat = _currentOpenChatUserId == senderId;

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
        'deliveredAt': now,
        'isMine': 0,
        'requiresBiometric': 1,
        'isDecrypted': 0,
        'attachmentData': encryptedAttachment,
        'attachmentType': attachmentType,
        'attachmentName': attachmentName,
        'visibilityDuration': visibilityDuration,
        'expiresAt': expiresAt,
        'isExpired': 0,
      });

      if (expiresAt != null) _scheduleMessageExpiry(messageId, expiresAt);

      if (isCurrentChat) {
        await _db.markConversationAsRead(conversationId);
      } else {
        await _db.incrementUnreadCount(conversationId);
      }

      _newMessageCtrl.add({
        'messageId': messageId,
        'conversationId': conversationId,
        'senderId': senderId,
        'isLocked': true,
      });
    } catch (e) {
      debugPrint('❌ _handleIncomingMessage: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Status update
  // ---------------------------------------------------------------------------

  Future<void> _handleStatusUpdate(Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String?;

      if (type == 'peer_emergency_mode') {
        final peerId = data['userId'] as String?;
        if (peerId != null && peerId.isNotEmpty) {
          await _signal.deleteSession(peerId);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('rekey_required_$peerId', true);
        }
        _emit(_statusCtrl, Map<String, dynamic>.from(data));
        return;
      }

      if (type == 'recipient_failed_verification') {
        _emit(_statusCtrl, {
          'type': 'recipient_failed_verification',
          'recipientId': data['recipientId'],
        });
        return;
      }

      final messageId = data['messageId'] as String;
      final newStatus = data['status'] as String;
      final visibilityDuration = data['visibilityDuration'] as int?;

      final updateData = <String, dynamic>{'status': newStatus};
      if (visibilityDuration != null) updateData['visibilityDuration'] = visibilityDuration;

      await _db.updateMessage(messageId, updateData);
      _emit(_statusCtrl, {'messageId': messageId, 'status': newStatus});
    } catch (e) {
      debugPrint('❌ _handleStatusUpdate: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Resend pending
  // ---------------------------------------------------------------------------

  Future<void> resendPendingMessages() async {
    final pending = await _db.getPendingMessages();
    for (final msg in pending) {
      try {
        String? expiresAtStr;
        String? createdAtStr;

        if (msg['createdAt'] != null) {
          final createdAt = DateTime.fromMillisecondsSinceEpoch(msg['createdAt'] as int);
          createdAtStr = createdAt.toUtc().toIso8601String();

          if (msg['expiresAt'] != null) {
            expiresAtStr = DateTime.fromMillisecondsSinceEpoch(msg['expiresAt'] as int).toUtc().toIso8601String();
          } else if (msg['visibilityDuration'] != null) {
            expiresAtStr = createdAt.add(Duration(seconds: msg['visibilityDuration'] as int)).toUtc().toIso8601String();
          }
        }

        _socket.sendMessageWithAttachment(
          messageId: msg['id'] as String,
          recipientId: msg['receiverId'] as String,
          encryptedType: msg['encryptionType'],
          encryptedBody: msg['ciphertext'] as String,
          attachmentData: msg['attachmentData'] as String?,
          attachmentType: msg['attachmentType'] as String?,
          attachmentName: msg['attachmentName'] as String?,
          visibilityDuration: msg['visibilityDuration'] as int?,
          expiresAt: expiresAtStr,
          createdAt: createdAtStr,
        );

        await _db.updateMessageStatus(msg['id'] as String, 'sent');
      } catch (e) {
        debugPrint('⚠️ Failed to resend ${msg['id']}: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Decryption
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> decryptAllConversationMessages(String conversationId) async {
    try {
      final encrypted = await _db.getEncryptedMessages(conversationId);
      if (encrypted.isEmpty) {
        return {'success': true, 'message': 'لا توجد رسائل تحتاج فك تشفير', 'count': 0};
      }

      int successCount = 0;
      String? lastError;
      String? lastErrorType;

      for (final message in encrypted) {
        try {
          final messageId = message['id'] as String;
          final senderId = message['senderId'] as String;
          final encryptionType = message['encryptionType'] as int;

          final decrypted = await _signal.decryptMessage(senderId, encryptionType, message['ciphertext'] as String);

          if (decrypted == null) {
            _decryptionFailureCount++;
            lastError = 'Decryption returned null';
            lastErrorType = 'DecryptionFailure';

            if (_decryptionFailureCount >= 1) {
              await _signal.deleteSession(senderId);
              await deleteConversation(conversationId);
              return {'success': false, 'error': 'SessionReset', 'message': 'Session reset due to decryption errors'};
            }
            continue;
          }

          // Decrypt attachment if present
          String? decryptedAttachment = message['attachmentData'] as String?;
          if (decryptedAttachment != null && message['attachmentType'] != null) {
            try {
              decryptedAttachment = await _signal.decryptMessage(senderId, encryptionType, decryptedAttachment)
                  ?? decryptedAttachment;
            } catch (_) {
              // Keep the stored value; decryption will be reattempted next session.
            }
          }

          await _db.updateMessage(messageId, {
            'plaintext': decrypted,
            'attachmentData': decryptedAttachment,
            'isDecrypted': 1,
            'requiresBiometric': 1,
            'status': 'read',
            'readAt': DateTime.now().millisecondsSinceEpoch,
          });

          _socket.updateMessageStatus(messageId: messageId, status: 'verified', recipientId: senderId);
          successCount++;
        } catch (e) {
          _decryptionFailureCount++;
          lastError = e.toString();
          lastErrorType = _classifyDecryptionError(e.toString());
          debugPrint('Failed to decrypt: $lastErrorType – $e');
        }
      }

      if (successCount == encrypted.length) {
        return {'success': true, 'message': 'تم فك تشفير $successCount رسائل', 'count': successCount};
      }

      if (successCount == 0) {
        return {'success': false, 'message': 'فشل فك تشفير جميع الرسائل', 'count': 0, 'error': lastErrorType, 'errorMessage': lastError};
      }

      return {'success': true, 'message': 'تم فك تشفير $successCount من ${encrypted.length} رسائل', 'count': successCount, 'error': lastErrorType, 'errorMessage': lastError};
    } catch (e) {
      return {'success': false, 'message': 'فشل فك تشفير الرسائل', 'count': 0, 'error': _classifyDecryptionError(e.toString()), 'errorMessage': e.toString()};
    }
  }

  /// Single-message decrypt with biometric gate (fallback / on-demand use).
  Future<Map<String, dynamic>> decryptMessage(String messageId) async {
    try {
      final authenticated = await BiometricService.authenticateWithBiometrics(
        reason: 'تحقق من هويتك لقراءة الرسالة',
      );
      if (!authenticated) return {'success': false, 'message': 'فشل التحقق بالبايومتركس'};

      final message = await _db.getMessage(messageId);
      if (message == null) throw Exception('Message not found');

      final decrypted = await _signal.decryptMessage(
        message['senderId'] as String,
        message['encryptionType'] as int,
        message['ciphertext'] as String,
      );
      if (decrypted == null) throw Exception('Decryption failed');

      await _db.updateMessage(messageId, {
        'plaintext': decrypted,
        'isDecrypted': 1,
        'requiresBiometric': 1,
        'status': 'read',
        'readAt': DateTime.now().millisecondsSinceEpoch,
      });

      _socket.updateMessageStatus(
        messageId: messageId,
        status: 'verified',
        recipientId: message['senderId'] as String,
      );

      return {'success': true, 'plaintext': decrypted};
    } catch (e) {
      return {'success': false, 'message': 'فشل فك التشفير: $e'};
    }
  }

  String _classifyDecryptionError(String msg) {
    if (msg.contains('InvalidKeyException'))      return 'InvalidKeyException';
    if (msg.contains('InvalidMessageException'))  return 'InvalidMessageException';
    if (msg.contains('InvalidSessionException') ||
        msg.contains('NoSessionException') ||
        msg.contains('session') ||
        msg.contains('Session'))                  return 'InvalidSessionException';
    if (msg.contains('UntrustedIdentityException')) return 'UntrustedIdentityException';
    return 'UnknownError';
  }

  // ---------------------------------------------------------------------------
  // Message expiry
  // ---------------------------------------------------------------------------

  void _scheduleMessageExpiry(String messageId, int expiresAtMillis) {
    _messageTimers[messageId]?.cancel();
    _messageTimers.remove(messageId);

    final delay = DateTime.fromMillisecondsSinceEpoch(expiresAtMillis, isUtc: true)
        .difference(DateTime.now().toUtc());

    if (delay.isNegative || delay.inMilliseconds <= 0) {
      _deleteSingleExpiredMessage(messageId);
      return;
    }

    _messageTimers[messageId] = Timer(delay, () {
      _deleteSingleExpiredMessage(messageId);
      _messageTimers.remove(messageId);
    });
  }

  Future<void> _deleteSingleExpiredMessage(String messageId) async {
    try {
      if (await _db.getMessage(messageId) == null) return;
      await _db.deleteMessage(messageId);
      _expiredCtrl.add({'messageId': messageId});
    } catch (e) {
      debugPrint('❌ Error expiring message $messageId: $e');
    }
  }

  Future<void> deleteExpiredMessages() async {
    final expiredIds = await _db.deleteExpiredMessages();
    for (final id in expiredIds) {
      _expiredCtrl.add({'messageId': id});
    }
  }

  Future<void> _loadMessageTimers() async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      final rows = await db.query(
        'messages',
        columns: ['id', 'expiresAt'],
        where: 'expiresAt IS NOT NULL AND CAST(expiresAt AS INTEGER) > ?',
        whereArgs: [now],
      );

      for (final row in rows) {
        _scheduleMessageExpiry(row['id'] as String, row['expiresAt'] as int);
      }
    } catch (e) {
      debugPrint('⚠️ Error loading message timers: $e');
    }
  }

  /// Fallback sweep every 5 s to catch any messages whose timers were missed.
  void _startGlobalExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 5), (_) => deleteExpiredMessages());
  }

  // ---------------------------------------------------------------------------
  // Delete message
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    required bool deleteForEveryone,
  }) async {
    try {
      final message = await _db.getMessage(messageId);
      if (message == null) return {'success': false, 'message': 'الرسالة غير موجودة'};

      final isMine = (message['isMine'] as int?) == 1;
      final otherUserId = isMine
          ? message['receiverId'] as String
          : message['senderId'] as String;

      _messageTimers[messageId]?.cancel();
      _messageTimers.remove(messageId);

      if (deleteForEveryone) {
        await _db.deleteMessage(messageId);
        _socket.socket?.emit('message:delete_local', {
          'messageId': messageId,
          'deleteFor': 'everyone',
          'recipientId': otherUserId,
        });
        return {'success': true, 'message': 'تم الحذف للجميع'};
      } else {
        await _db.updateMessage(messageId, {'deletedForRecipient': 1});
        _socket.socket?.emit('message:delete_local', {
          'messageId': messageId,
          'deleteFor': 'recipient',
          'recipientId': otherUserId,
        });
        return {'success': true, 'message': 'تم الحذف من عند المستقبل'};
      }
    } catch (e) {
      debugPrint('❌ deleteMessage: $e');
      return {'success': false, 'message': 'فشل الحذف: $e'};
    }
  }

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getConversationMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    try {
      return await _db.getMessages(conversationId, limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllConversations() async {
    try {
      return await _db.getConversations();
    } catch (_) {
      return [];
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _db.markConversationAsRead(conversationId);
    } catch (_) {}
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _db.deleteConversation(conversationId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Session management
  // ---------------------------------------------------------------------------

  Future<void> deleteSession(String userId) async {
    await _signal.deleteSession(userId);
  }

  Future<bool> createNewSession(String userId) async {
    try {
      await _signal.initialize();
      return await _signal.createSession(userId);
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Duration / visibility
  // ---------------------------------------------------------------------------

  Future<int?> getUserDuration(String conversationId) => _db.getUserDuration(conversationId);

  Future<void> setUserDuration(String conversationId, int duration) =>
      _db.setUserDuration(conversationId, duration);

  // ---------------------------------------------------------------------------
  // Privacy policy
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Misc helpers
  // ---------------------------------------------------------------------------

  void requestUserStatus(String userId) => _socket.requestUserStatus(userId);

  void setCurrentOpenChat(String? userId) => _currentOpenChatUserId = userId;

  String getConversationId(String otherUserId) => _conversationId(otherUserId);

  Future<void> logout() async {
    try {
      _socket.disconnectOnLogout();
      await _db.clearAllData();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  String _conversationId(String otherUserId) {
    final ids = [_getCurrentUserIdSync(), otherUserId]..sort();
    return '${ids[0]}-${ids[1]}';
  }

  Future<String> _getCurrentUserId() async {
    final raw = await _storage.read(key: 'user_data');
    if (raw == null) throw Exception('User not logged in');
    return (jsonDecode(raw) as Map<String, dynamic>)['id'] as String;
  }

  String _getCurrentUserIdSync() {
    if (_cachedUserId == null) throw Exception('User ID not cached');
    return _cachedUserId!;
  }

  Future<void> _cacheUserId() async => _cachedUserId = await _getCurrentUserId();

  void _startCacheCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_processedMessageIds.length > 100) {
        final keep = _processedMessageIds.skip(_processedMessageIds.length - 50).toList();
        _processedMessageIds..clear()..addAll(keep);
      }
    });
  }

  void _emit(StreamController<Map<String, dynamic>> ctrl, Map<String, dynamic> data) {
    if (!ctrl.isClosed) ctrl.add(data);
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void dispose() {
    _msgSub?.cancel();
    _statusSub?.cancel();
    _deleteSub?.cancel();
    _cleanupTimer?.cancel();
    _expiryTimer?.cancel();

    for (final t in _messageTimers.values) t.cancel();
    _messageTimers.clear();
    _processedMessageIds.clear();

    _listenersSetup = false;
    _socket.dispose();

    _newMessageCtrl.close();
    _deletedCtrl.close();
    _statusCtrl.close();
    _expiredCtrl.close();
    _uploadProgressCtrl.close();
  }
}

// ---------------------------------------------------------------------------
// Upload progress model
// ---------------------------------------------------------------------------

enum UploadStage { idle, validating, compressing, encoding, encrypting, saving, sending, complete, error }

class UploadProgress {
  final UploadStage stage;
  final double progress; // 0.0 – 1.0
  final String message;

  const UploadProgress({
    required this.stage,
    required this.progress,
    required this.message,
  });

  factory UploadProgress.idle() =>
      const UploadProgress(stage: UploadStage.idle, progress: 0.0, message: '');

  bool get isIdle => stage == UploadStage.idle;
  bool get isComplete => stage == UploadStage.complete;
  bool get isError => stage == UploadStage.error;
  bool get isProcessing => !isIdle && !isComplete && !isError;
}