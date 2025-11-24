import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'stores/identity_key_store.dart';
import 'stores/pre_key_store.dart';
import 'stores/signed_pre_key_store.dart';
import 'stores/session_store.dart';
import '../api_services.dart';

class SignalProtocolManager {
  static final SignalProtocolManager _instance = 
      SignalProtocolManager._internal();
  factory SignalProtocolManager() => _instance;
  SignalProtocolManager._internal();

  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  final Map<String, int> _sessionVersions = {};
  final Map<String, DateTime> _lastSessionReset = {};

  
  late MyIdentityKeyStore _identityStore;
  late MyPreKeyStore _preKeyStore;
  late MySignedPreKeyStore _signedPreKeyStore;
  late MySessionStore _sessionStore;
  
  bool _isInitialized = false;
  String? _currentUserId;

  // ===================================
  // تهيئة مع معرّف المستخدم
  // ===================================
  Future<void> initialize({String? userId}) async {
    if (userId == null) {
      final userData = await _storage.read(key: 'user_data');
      if (userData != null) {
        userId = jsonDecode(userData)['id'];
      }
    }

    if (_isInitialized && _currentUserId == userId) {
      return;
    }

    _currentUserId = userId;

    _identityStore = MyIdentityKeyStore(_storage, userId: userId);
    _preKeyStore = MyPreKeyStore(_storage, userId: userId);
    _signedPreKeyStore = MySignedPreKeyStore(_storage, userId: userId);
    _sessionStore = MySessionStore(_storage, userId: userId);

    await _identityStore.initialize();
    await _preKeyStore.initialize();
    await _signedPreKeyStore.initialize();
    await _sessionStore.initialize();

    _isInitialized = true;
  }

  bool _canResetSession(String userId) {
  final lastReset = _lastSessionReset[userId];
  
  // السماح بإعادة الإنشاء مرة واحدة كل دقيقتين فقط
  if (lastReset != null) {
    final timeSince = DateTime.now().difference(lastReset);
    if (timeSince.inMinutes < 2) {
      print('Session reset blocked - too soon (${timeSince.inSeconds}s ago)');
      return false;
    }
  }
  
  return true;
}



  // ===================================
  //  التحقق من حالة المفاتيح
  // ===================================
  Future<KeysStatus> checkKeysStatus() async {
    try {
      await initialize();

      final hasLocalKeys = await hasKeys();
      
      if (!hasLocalKeys) {
        return KeysStatus(
          hasLocalKeys: false,
          needsGeneration: true,
          needsSync: false,
        );
      }

      final serverVersion = await _getServerKeysVersion();
      final localVersion = await _getLocalKeysVersion();

      final needsSync = serverVersion != null && 
                        localVersion != null && 
                        serverVersion != localVersion;

      return KeysStatus(
        hasLocalKeys: true,
        needsGeneration: false,
        needsSync: needsSync,
        localVersion: localVersion,
        serverVersion: serverVersion,
      );

    } catch (e) {
      print('Error checking keys status: $e');
      return KeysStatus(
        hasLocalKeys: false,
        needsGeneration: true,
        needsSync: false,
      );
    }
  }

  // ===================================
  //  مزامنة المفاتيح مع السيرفر
  // ===================================
  Future<bool> syncKeysWithServer() async {
    try {
      print('Syncing keys with server...');
      
      await clearLocalKeys();
      final success = await generateAndUploadKeys();
      
      if (success) {
        print('Keys synced successfully');
      }
      
      return success;
    } catch (e) {
      print('❌ Error syncing keys: $e');
      return false;
    }
  }

  // ============================================
//  دالة مساعدة موحدة لتوليد مفاتيح التخزين
// ============================================
String _getStorageKey(String userId, String key) {
  return '${userId}_$key';
}

// ============================================
//  Generate and upload keys 
// ============================================
Future<bool> generateAndUploadKeys() async {
  try {
    
    final userId = await _getCurrentUserId();

    // Generate keys
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    final preKeys = generatePreKeys(1, 100);
    final signedPreKey = generateSignedPreKey(identityKeyPair, 1);

    await initialize(userId: userId);

    // Save local keys version
    final version = DateTime.now().millisecondsSinceEpoch;
    await _saveLocalKeysVersion(version, userId);

    // Prepare bundle for upload
    final bundle = {
      'registrationId': registrationId,
      'identityKey': base64Encode(
        identityKeyPair.getPublicKey().serialize()
      ),
      'signedPreKey': {
        'keyId': signedPreKey.id,
        'publicKey': base64Encode(
          signedPreKey.getKeyPair().publicKey.serialize()
        ),
        'signature': base64Encode(signedPreKey.signature),
      },
      'preKeys': preKeys.map((pk) => {
        'keyId': pk.id,
        'publicKey': base64Encode(
          pk.getKeyPair().publicKey.serialize()
        ),
      }).toList(),
      'version': version,
    };

    // Upload public keys to server
    print('Uploading keys to server...');
    final result = await _apiService.uploadKeyBundle(bundle);

    if (!result['success']) {
      throw Exception(result['message']);
    }
    
    print('Keys uploaded to server successfully');

    // Save in the Stores
    await _identityStore.saveIdentityKeyPairWithUserId(identityKeyPair);
    await _identityStore.saveRegistrationIdWithUserId(registrationId);
    
    // Save PreKeys

    for (var preKey in preKeys) {
      await _preKeyStore.storePreKey(preKey.id, preKey);
    }

    // Save SignedPreKey
    await _signedPreKeyStore.storeSignedPreKey(
      signedPreKey.id,
      signedPreKey,
    );

    // Save first rotation date
    await _storage.write(
      key: _getStorageKey(userId, 'signed_prekey_last_rotated'),
      value: DateTime.now().toIso8601String(),
    );
    print('Initial SignedPreKey rotation date saved');

    print('Keys generated and uploaded successfully for user: $userId');
    return true;
    
  } catch (e) {
    print('Error generating keys: $e');
    return false;
  }
}

  // ===================================
  // التحقق من SignedPreKey وتدويره إذا لزم 
  // ===================================
  Future<void> ensureSignedPreKeyRotation(String userId) async {
    try {

      print('Checking SignedPreKey rotation for $userId');
      
      final shouldRotate = await _shouldRotateSignedPreKey(userId);
      
      if (shouldRotate) {
        await _rotateSignedPreKey(userId);
      } else {
        print('SignedPreKey still valid for $userId');
      }
    } catch (e) {
      print('❌ Error in SignedPreKey rotation check: $e');
    }
  }

  Future<bool> _shouldRotateSignedPreKey(String userId) async {
    final key = 'signed_prekey_last_rotated_$userId';
    final lastRotatedStr = await _storage.read(key: key);
    
    if (lastRotatedStr == null) return true;

    try {
      final lastRotated = DateTime.parse(lastRotatedStr);
      final daysSince = DateTime.now().difference(lastRotated).inDays;
      return daysSince >= 7;
    } catch (e) {
      print('⚠️ Error parsing rotation date: $e');
      return true; // في حالة الخطأ، نعتبر أنه يحتاج تدوير
    }
  }

  Future<void> _rotateSignedPreKey(String userId) async {
    try {
      print('Rotating SignedPreKey for $userId');

      final identityKeyPair = await _identityStore.getIdentityKeyPair();
      if (identityKeyPair == null) {
        print('❌ No identity key pair found');
        return;
      }

      final newId = DateTime.now().millisecondsSinceEpoch % 100000;
      final newSignedPreKey = generateSignedPreKey(identityKeyPair, newId);

      await _signedPreKeyStore.storeSignedPreKey(newId, newSignedPreKey);

      // رفع SignedPreKey الجديد للسيرفر
      final bundle = {
        'signedPreKey': {
          'keyId': newSignedPreKey.id,
          'publicKey': base64Encode(
            newSignedPreKey.getKeyPair().publicKey.serialize()
          ),
          'signature': base64Encode(newSignedPreKey.signature),
        },
      };

      await _apiService.uploadKeyBundle(bundle);

      // تحديث وقت التدوير
      await _storage.write(
        key: 'signed_prekey_last_rotated_$userId',
        value: DateTime.now().toIso8601String(),
      );

      print('SignedPreKey rotated successfully for $userId');
    } catch (e) {
      print('Error rotating SignedPreKey: $e');
    }
  }

  // ===================================
  // التحقق من عدد المفاتيح وإضافة المزيد إذا لزم
  // ===================================
  Future<void> checkAndRefreshPreKeys() async {
    try {
      final result = await _apiService.checkPreKeysCount();
      
      if (result['success']) {
        final count = result['count'] ?? 0;
        print('Available PreKeys: $count');
        
        if (count < 20) {
          print('Low on PreKeys ($count), generating more...');
          await uploadAdditionalPreKeysOnly();
        } else {
          print('PreKeys count is sufficient ($count)');
        }
      }
    } catch (e) {
      print('Error checking PreKeys: $e');
    }
  }

  // ===================================
  // دالة مساعدة: جلب userId
  // ===================================
  Future<String> _getCurrentUserId() async {
    try {
      final userDataStr = await _storage.read(key: 'user_data');
      
      if (userDataStr == null) {
        throw Exception('User not logged in - no user_data found');
      }
      
      final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
      final userId = userData['id'];
      
      if (userId == null) {
        throw Exception('User ID not found in user_data');
      }
      
      return userId as String;
      
    } catch (e) {
      print('Error getting current user ID: $e');
      rethrow;
    }
  }

  // ===================================
  // فك التشفير 
  // ===================================
  Future<String?> decryptMessage(
    String senderId,
    int type,
    String body,
  ) async {
    try {
      final address = SignalProtocolAddress(senderId, 1);
      
      final cipher = SessionCipher(
        _sessionStore, 
        _preKeyStore, 
        _signedPreKeyStore, 
        _identityStore, 
        address
      );
      
      Uint8List plaintext;
      final bodyBytes = base64Decode(body);
      
      if (type == CiphertextMessage.prekeyType) {
        final message = PreKeySignalMessage(bodyBytes);
        plaintext = await cipher.decrypt(message);
      } else if (type == CiphertextMessage.whisperType) {
        final message = SignalMessage.fromSerialized(bodyBytes);
        plaintext = await cipher.decryptFromSignal(message);
      } else {
        throw Exception('Unknown message type: $type');
      }
      
      return utf8.decode(plaintext);
    } catch (e) {
      print('❌ Decryption error: $e');
      return null;
    }
  }

  // ===================================
  // تشفير رسالة
  // ===================================
  Future<Map<String, dynamic>?> encryptMessage(
    String recipientId,
    String message,
  ) async {
    try {
      final address = SignalProtocolAddress(recipientId, 1);
      
      if (!await _sessionStore.containsSession(address)) {
        throw Exception('No session exists with user');
      }

      final cipher = SessionCipher(
        _sessionStore, 
        _preKeyStore, 
        _signedPreKeyStore, 
        _identityStore, 
        address
      );
      
      final ciphertext = await cipher.encrypt(
        Uint8List.fromList(utf8.encode(message))
      );
      
      return {
        'type': ciphertext.getType(),
        'body': base64Encode(ciphertext.serialize()),
      };
    } catch (e) {
      print('Encryption error: $e');
      return null;
    }
  }

  // ===================================
  // إنشاء Session
  // ===================================
  Future<bool> createSession(String recipientId) async {
  try {
    await initialize();
  //  نقطة التحقق الإجباري:
    final hasOwnKeys = await hasKeys();
    if (!hasOwnKeys) {
      print(' No local keys found');
      print('Generating keys first...');
      
      // توليد وحفظ المفاتيح إذا كانت مفقودة
      final generated = await generateAndUploadKeys(); 
      if (!generated) {
        throw Exception('Failed to generate keys for user $currentUserId'); 
      }
    }
    final userData = await _storage.read(key: 'user_data');
    if (userData != null) {
      final currentUserId = jsonDecode(userData)['id'];
      if (recipientId == currentUserId) {
        return false;
      }
    }

    final response = await _apiService.getPreKeyBundle(recipientId);
    
    if (!response['success']) {
      throw Exception(response['message']);
    }

    final bundleData = response['bundle'];
    final recipientAddress = SignalProtocolAddress(recipientId, 1);
    
    ECPublicKey? preKeyPublic;
    int? preKeyId;
    
    if (bundleData['preKey'] != null) {
      final preKeyBytes = base64Decode(bundleData['preKey']['publicKey']);
      preKeyPublic = Curve.decodePoint(preKeyBytes, 0);
      preKeyId = bundleData['preKey']['keyId'];
    }
    
    final signedPreKeyBytes = base64Decode(
      bundleData['signedPreKey']['publicKey']
    );
    final signedPreKeyPublic = Curve.decodePoint(signedPreKeyBytes, 0);
    
    final identityKeyBytes = base64Decode(bundleData['identityKey']);
    final identityKeyPublic = Curve.decodePoint(identityKeyBytes, 0);
    
    final bundle = PreKeyBundle(
      bundleData['registrationId'],
      1,
      preKeyId,
      preKeyPublic,
      bundleData['signedPreKey']['keyId'],
      signedPreKeyPublic,
      base64Decode(bundleData['signedPreKey']['signature']),
      IdentityKey(identityKeyPublic),
    );
    
    final sessionBuilder = SessionBuilder(
      _sessionStore,
      _preKeyStore,
      _signedPreKeyStore,
      _identityStore,
      recipientAddress,
    );

    await sessionBuilder.processPreKeyBundle(bundle);
    
    //  حفظ معلومات الـ session
    _sessionVersions[recipientId] = DateTime.now().millisecondsSinceEpoch;
    _lastSessionReset[recipientId] = DateTime.now();
    
    await _storage.write(
      key: 'session_version_$recipientId',
      value: _sessionVersions[recipientId].toString(),
    );
    
    print('Session created successfully with recipient: $recipientId');
    print('Session version: ${_sessionVersions[recipientId]}');
    
    return true;
    
  } catch (e) {
    print('❌ Error creating session: $e');
    return false;
  }
}

  // ===================================
  //  حذف المفاتيح المحلية فقط
  // ===================================
  Future<void> clearLocalKeys() async {
    try {
      await _identityStore.clearAll();
      await _preKeyStore.clearAll();
      await _signedPreKeyStore.clearAll();
      await _sessionStore.clearAll();
      
      // حذف المفتاح العام المحفوظ
      await _storage.delete(key: 'identity_public_key_$_currentUserId');
      await _storage.delete(key: 'registration_id_$_currentUserId');
      await _storage.delete(key: 'keys_version_$_currentUserId');
      await _storage.delete(key: 'signed_prekey_last_rotated_$_currentUserId');
      
      _isInitialized = false;
      
      print('Local keys cleared');
    } catch (e) {
      print('Error clearing local keys: $e');
      rethrow;
    }
  }

  // ===================================
  // حذف كل شيء (محلي + سيرفر)
  // ===================================
  Future<void> clearAllKeys() async {
    try {
      await clearLocalKeys();
      
      // يمكنك تفعيل هذا لحذف المفاتيح من السيرفر أيضاً
      // await _apiService.deletePreKeyBundle();
      
      print('✅ All keys cleared');
    } catch (e) {
      print('❌ Error clearing all keys: $e');
      rethrow;
    }
  }

  // ===================================
  // التحقق من وجود مفاتيح
  // ===================================
  Future<bool> hasKeys() async {
    try {
      await initialize();
      final identityKeyPair = await _identityStore.getIdentityKeyPair();
      final regId = await _identityStore.getLocalRegistrationId();
      return identityKeyPair != null && regId != null;
    } catch (e) {
      return false;
    }
  }

  // ===================================
  // رفع PreKeys إضافية فقط
  // ===================================
  Future<void> uploadAdditionalPreKeysOnly() async {
    try {
      await initialize();
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final startId = timestamp % 100000;
      final newPreKeys = generatePreKeys(startId, 100);
      
      for (var preKey in newPreKeys) {
        await _preKeyStore.storePreKey(preKey.id, preKey);
      }
      
      final bundle = {
        'preKeys': newPreKeys.map((pk) => {
          'keyId': pk.id,
          'publicKey': base64Encode(
            pk.getKeyPair().publicKey.serialize()
          ),
        }).toList(),
      };
      
      final result = await _apiService.uploadKeyBundle(bundle);
      
      if (result['success']) {
        print('Uploaded ${newPreKeys.length} additional PreKeys');
      }
    } catch (e) {
      print('Error uploading additional PreKeys: $e');
      rethrow;
    }
  }

  // ===================================
  // إدارة نسخة المفاتيح
  // ===================================
  Future<void> _saveLocalKeysVersion(int version, String userId) async {
    try {
      await _storage.write(
        key: 'keys_version_$userId',
        value: version.toString(),
      );
      print('Saved keys version $version for user');
    } catch (e) {
      print('Error saving keys version: $e');
    }
  }

  Future<int?> _getLocalKeysVersion() async {
    final versionStr = await _storage.read(
      key: 'keys_version_$_currentUserId'
    );
    return versionStr != null ? int.tryParse(versionStr) : null;
  }

  Future<int?> _getServerKeysVersion() async {
    try {
      final result = await _apiService.getKeysVersion();
      if (result['success']) {
        return result['version'];
      }
    } catch (e) {
      print('❌ Error getting server version: $e');
    }
    return null;
  }

  Future<DecryptionResult> decryptMessageSafe(
  String senderId,
  int type,
  String body,
) async {
  try {
    final plaintext = await decryptMessage(senderId, type, body);

    if (plaintext != null) {
      return DecryptionResult(
        success: true,
        message: plaintext,
      );
    }

    return DecryptionResult(
      success: false,
      needsKeySync: true,
      error: 'Failed to decrypt - keys may be outdated',
    );
  } catch (e) {
    final errorStr = e.toString();

    if (errorStr.contains('DuplicateMessageException')) {
      print('⚠️ Duplicate message detected from $senderId, ignoring.');
      return DecryptionResult(
        success: false,
        needsKeySync: false,
        error: 'Duplicate message, ignored.',
      );
    }

    if (errorStr.contains('InvalidKeyException') ||
        errorStr.contains('InvalidMessageException') ||
        errorStr.contains('Bad Mac')) {
      print('⚠️ Session corruption detected from $senderId');

      // حذف session القديم وإنشاء جديد
      await deleteSession(senderId);
      final resetResult = await createSession(senderId);

      return DecryptionResult(
        success: false,
        needsSessionReset: true,
        needsKeySync: true,
        error: 'Session reset. Please resend message. '
               '${resetResult ? "New session created." : "Failed to create session."}',
      );
    }

    return DecryptionResult(
      success: false,
      needsKeySync: false,
      error: errorStr,
    );
  }
}
Future<bool> sessionExists(String userId) async {
  final address = SignalProtocolAddress(userId, 1);
  return await _sessionStore.containsSession(address);
}

// =======================================
// محاولة فك التشفير مع استرجاع تلقائي
// =======================================
Future<DecryptionResult> decryptMessageWithAutoRecovery(
  String senderId,
  int type,
  String body,
) async {
  try {
    print('Attempting to decrypt message from $senderId');
    
    final result = await decryptMessageSafe(senderId, type, body);

    if (result.success) {
      print('Decryption successful');
      return result;
    }

    if (result.needsSessionReset) {
      print('Attempting to recover session with $senderId');
      final resetResult = await resetSessionWithUser(senderId);

      return DecryptionResult(
        success: false,
        needsSessionReset: true,
        needsKeySync: true,
        error: 'Session reset. Please resend message. '
               '${resetResult.success ? "New session created." : resetResult.error}',
      );
    }

    return result;
  } catch (e) {
    print('Unexpected error in auto-recovery: $e');
    return DecryptionResult(
      success: false,
      error: 'خطأ غير متوقع في فك التشفير',
    );
  }
}


  // ===================================
  // معالجة فشل فك التشفير التلقائية
  // ===================================
  Future<DecryptionResult> handleDecryptionFailure(
    String senderId,
    String errorMessage,
  ) async {
    try {
      print('Handling decryption failure for sender: $senderId');
      
      await deleteSession(senderId);
      print('Old session deleted');
      
      return DecryptionResult(
        success: false,
        needsKeySync: true,
        needsSessionReset: true,
        error: 'يرجى إعادة المحاولة - تم إعادة تعيين المفاتيح',
      );
      
    } catch (e) {
      print('Error handling decryption failure: $e');
      return DecryptionResult(
        success: false,
        error: 'فشل معالجة خطأ التشفير',
      );
    }
  }
 /// إنشاء Session جديد مع المستخدم (بعد حذف القديم)
  Future<SessionResetResult> resetSessionWithUser(String userId) async {
  try {
    print('Attempting to reset session with user: $userId');
    
    // التحقق من إمكانية إعادة الإنشاء
    if (!_canResetSession(userId)) {
      return SessionResetResult(
        success: false,
        error: 'يرجى الانتظار قبل إعادة المحاولة',
      );
    }
    
    // حذف الـ session القديم
    await deleteSession(userId);
    print('Old session deleted');
    
    // إنشاء session جديد
    final success = await createSession(userId);
    
    if (success) {
      print('New session created successfully');
      return SessionResetResult(
        success: true,
        message: 'تم إعادة إنشاء المفاتيح بنجاح',
      );
    } else {
      print('Failed to create new session');
      return SessionResetResult(
        success: false,
        error: 'فشل إنشاء مفاتيح جديدة',
      );
    }
    
  } catch (e) {
    print('Error resetting session: $e');
    return SessionResetResult(
      success: false,
      error: 'خطأ في إعادة تعيين المفاتيح',
    );
  }
}

  // ===================================
  // دوال مساعدة أخرى
  // ===================================
  Future<bool> hasSession(String userId) async {
    final address = SignalProtocolAddress(userId, 1);
    return await _sessionStore.containsSession(address);
  }

  Future<void> deleteSession(String userId) async {
    final address = SignalProtocolAddress(userId, 1);
    await _sessionStore.deleteSession(address);
  }

  String? get currentUserId => _currentUserId;
}

// ===================================
// Models للنتائج
// ===================================
class KeysStatus {
  final bool hasLocalKeys;
  final bool needsGeneration;
  final bool needsSync;
  final int? localVersion;
  final int? serverVersion;

  KeysStatus({
    required this.hasLocalKeys,
    required this.needsGeneration,
    required this.needsSync,
    this.localVersion,
    this.serverVersion,
  });
}

class DecryptionResult {
  final bool success;
  final String? message;
  final bool needsKeySync;
  final bool needsSessionReset;  
  final String? error;

  DecryptionResult({
    required this.success,
    this.message,
    this.needsKeySync = false,
    this.needsSessionReset = false, 
    this.error,
  });
}

class SessionResetResult {
  final bool success;
  final String? message;
  final String? error;

  SessionResetResult({
    required this.success,
    this.message,
    this.error,
  });
}