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
  
  late MyIdentityKeyStore _identityStore;
  late MyPreKeyStore _preKeyStore;
  late MySignedPreKeyStore _signedPreKeyStore;
  late MySessionStore _sessionStore;
  
  bool _isInitialized = false;
  String? _currentUserId;

  // ===================================
  // 🔑 تهيئة مع معرّف المستخدم
  // ===================================
  Future<void> initialize({String? userId}) async {
    // إذا لم يتم تمرير userId، نحاول جلبه من التخزين
    if (userId == null) {
      final userData = await _storage.read(key: 'user_data');
      if (userData != null) {
        userId = jsonDecode(userData)['id'];
      }
    }

    // إذا تغير المستخدم، نحتاج إعادة تهيئة
    if (_isInitialized && _currentUserId == userId) {
      return;
    }

    _currentUserId = userId;

    // ✅ تمرير userId للـ Stores لاستخدامه كـ prefix في المفاتيح
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

  // ===================================
  // 📊 التحقق من حالة المفاتيح
  // ===================================
  Future<KeysStatus> checkKeysStatus() async {
    try {
      await initialize();

      // 1. التحقق من وجود مفاتيح محلية
      final hasLocalKeys = await hasKeys();
      
      if (!hasLocalKeys) {
        return KeysStatus(
          hasLocalKeys: false,
          needsGeneration: true,
          needsSync: false,
        );
      }

      // 2. جلب نسخة المفاتيح من السيرفر
      final serverVersion = await _getServerKeysVersion();
      final localVersion = await _getLocalKeysVersion();

      // 3. المقارنة
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
      print('❌ Error checking keys status: $e');
      return KeysStatus(
        hasLocalKeys: false,
        needsGeneration: true,
        needsSync: false,
      );
    }
  }

  // ===================================
  // 🔄 مزامنة المفاتيح مع السيرفر
  // ===================================
  Future<bool> syncKeysWithServer() async {
    try {
      print('🔄 Syncing keys with server...');
      
      // 1. حذف المفاتيح المحلية القديمة
      await clearLocalKeys();
      
      // 2. توليد مفاتيح جديدة
      final success = await generateAndUploadKeys();
      
      if (success) {
        print('✅ Keys synced successfully');
      }
      
      return success;
    } catch (e) {
      print('❌ Error syncing keys: $e');
      return false;
    }
  }

  // ===================================
  // 🆕 توليد ورفع المفاتيح
  // ===================================
  Future<bool> generateAndUploadKeys() async {
  try {
    await initialize();
    
    // ✅ 1. جلب userId في البداية
    final userId = await _getCurrentUserId();
    print('🔑 Generating keys for user: $userId');

    // 2. توليد المفاتيح
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    final preKeys = generatePreKeys(1, 100);
    final signedPreKey = generateSignedPreKey(identityKeyPair, 1);

    // 3. حفظ النسخة المحلية (التاريخ كـ version)
    final version = DateTime.now().millisecondsSinceEpoch;
    await _saveLocalKeysVersion(version, userId);  // ✅ إضافة userId

    // 4. تجهيز البيانات للرفع
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

    // 5. رفع المفاتيح للسيرفر
    print('📤 Uploading keys to server...');
    final result = await _apiService.uploadPreKeyBundle(bundle);

    if (!result['success']) {
      throw Exception(result['message']);
    }
    
    print('✅ Keys uploaded to server successfully');

    // ✅ 6. حفظ محلياً مع userId
    await _identityStore.saveIdentityKeyPair(identityKeyPair);
    await _identityStore.saveRegistrationId(registrationId);
    
    // ✅ حفظ registration_id مع userId
    await _storage.write(
      key: 'registration_id_$userId',  // ✅ مع userId
      value: registrationId.toString(),
    );
    
    // ✅ حفظ identity_key_pair مع userId (للفحص السريع)
    await _storage.write(
      key: 'identity_key_$userId',  // ✅ مع userId
      value: base64Encode(identityKeyPair.serialize()),
    );

    // 7. حفظ PreKeys
    for (var preKey in preKeys) {
      await _preKeyStore.storePreKey(preKey.id, preKey);
    }

    // 8. حفظ SignedPreKey
    await _signedPreKeyStore.storeSignedPreKey(
      signedPreKey.id,
      signedPreKey,
    );

    print('✅ Keys generated and uploaded successfully for user: $userId');
    return true;
    
  } catch (e) {
    print('❌ Error generating keys: $e');
    return false;
  }
}


// ========================================
// ✅ دالة مساعدة: جلب userId
// ========================================

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
    print('❌ Error getting current user ID: $e');
    rethrow;
  }
}


  // ===================================
  // 🔓 فك تشفير مع معالجة الأخطاء
  // ===================================
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
      
      // فشل فك التشفير - قد تكون المفاتيح قديمة
      return DecryptionResult(
        success: false,
        needsKeySync: true,
        error: 'Failed to decrypt - keys may be outdated',
      );
      
    } catch (e) {
      // التحقق من نوع الخطأ
      if (e.toString().contains('InvalidKeyException') || 
          e.toString().contains('InvalidMessageException') ||
          e.toString().contains('DuplicateMessageException')) {
        
        print('⚠️ Decryption failed - Keys may need sync');
        
        return DecryptionResult(
          success: false,
          needsKeySync: true,
          error: 'Decryption failed: ${e.toString()}',
        );
      }
      
      return DecryptionResult(
        success: false,
        needsKeySync: false,
        error: e.toString(),
      );
    }
  }

  // ===================================
  // 🔐 فك التشفير (الطريقة الأصلية)
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
  // 🔒 تشفير رسالة
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
      print('❌ Encryption error: $e');
      return null;
    }
  }

  // ===================================
  // 🤝 إنشاء Session
  // ===================================
  Future<bool> createSession(String recipientId) async {
    try {
      await initialize();

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
      
      print('✅ Session created successfully with recipient: $recipientId');
      return true;
      
    } catch (e) {
      print('❌ Error creating session: $e');
      return false;
    }
  }

  // ===================================
  // 🧹 حذف المفاتيح المحلية فقط
  // ===================================
  Future<void> clearLocalKeys() async {
  try {
    await _identityStore.clearAll();
    await _preKeyStore.clearAll();
    await _signedPreKeyStore.clearAll();
    await _sessionStore.clearAll();
    
    // ✅ أضف هذا السطر
    await _storage.delete(key: 'identity_key_$_currentUserId');
    
    // الموجود حالياً
    await _storage.delete(key: 'registration_id_$_currentUserId');
    await _storage.delete(key: 'keys_version_$_currentUserId');
    
    _isInitialized = false;
    
    print('✅ Local keys cleared');
  } catch (e) {
    print('❌ Error clearing local keys: $e');
    rethrow;
  }
}
  // ===================================
  // 🗑️ حذف كل شيء (محلي + سيرفر)
  // ===================================
  Future<void> clearAllKeys() async {
    try {
      await clearLocalKeys();
      
      // حذف من السيرفر أيضاً إذا لزم الأمر
      // await _apiService.deletePreKeyBundle();
      
      print('✅ All keys cleared');
    } catch (e) {
      print('❌ Error clearing all keys: $e');
      rethrow;
    }
  }

  // ===================================
  // ✅ التحقق من وجود مفاتيح
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

  Future<bool> hasKeysForCurrentUser() async {
  try {
    final userId = await _getCurrentUserId();
    final identityKey = await _storage.read(key: 'identity_key_$userId');
    
    if (identityKey != null) {
      print('✅ Keys exist for user: $userId');
      return true;
    } else {
      print('❌ No keys found for user: $userId');
      return false;
    }
  } catch (e) {
    print('❌ Error checking keys: $e');
    return false;
  }
}

  // ===================================
  // 🔢 التحقق من عدد PreKeys
  // ===================================
  Future<void> checkAndRefreshPreKeys() async {
    try {
      final result = await _apiService.checkPreKeysCount();
      
      if (result['success']) {
        final count = result['count'] ?? 0;
        print('📊 Available PreKeys: $count');
        
        if (count < 20) {
          print('⚠️ Low on PreKeys ($count), generating more...');
          await uploadAdditionalPreKeysOnly();
        }
      }
    } catch (e) {
      print('❌ Error checking PreKeys: $e');
    }
  }

  // ===================================
  // ➕ رفع PreKeys إضافية فقط
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
      
      final result = await _apiService.uploadPreKeyBundle(bundle);
      
      if (result['success']) {
        print('✅ Uploaded ${newPreKeys.length} additional PreKeys');
      }
    } catch (e) {
      print('❌ Error uploading additional PreKeys: $e');
      rethrow;
    }
  }

  // ===================================
  // 📝 إدارة نسخة المفاتيح
  // ===================================
  Future<void> _saveLocalKeysVersion(int version, String userId) async {
  try {
    await _storage.write(
      key: 'keys_version_$userId',  // ✅ مع userId
      value: version.toString(),
    );
    print('💾 Saved keys version $version for user: $userId');
  } catch (e) {
    print('❌ Error saving keys version: $e');
  }
}

  Future<int?> _getLocalKeysVersion() async {
    final versionStr = await _storage.read(
      key: 'keys_version_${_currentUserId}'
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

  // ===================================
  // 🔍 دوال مساعدة أخرى
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
// 📊 Models للنتائج
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
  final String? error;

  DecryptionResult({
    required this.success,
    this.message,
    this.needsKeySync = false,
    this.error,
  });
}