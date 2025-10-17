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

  Future<void> initialize() async {
    if (_isInitialized) return;

    _identityStore = MyIdentityKeyStore(_storage);
    _preKeyStore = MyPreKeyStore(_storage);
    _signedPreKeyStore = MySignedPreKeyStore(_storage);
    _sessionStore = MySessionStore(_storage);

    await _identityStore.initialize();
    await _preKeyStore.initialize();
    await _signedPreKeyStore.initialize();
    await _sessionStore.initialize();

    _isInitialized = true;
    
  }

  // توليد المفاتيح ورفعها للسيرفر (عند التسجيل)
  Future<bool> generateAndUploadKeys() async {
    try {
      await initialize();

      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);

      await _identityStore.saveIdentityKeyPair(identityKeyPair);
      await _identityStore.saveRegistrationId(registrationId);

      await _storage.write(
        key: 'registration_id',
        value: registrationId.toString(),
      );

      final preKeys = generatePreKeys(0, 100);
      for (var preKey in preKeys) {
        await _preKeyStore.storePreKey(preKey.id, preKey);
      }

      final signedPreKey = generateSignedPreKey(identityKeyPair, 1);
      await _signedPreKeyStore.storeSignedPreKey(
        signedPreKey.id,
        signedPreKey,
      );

      // تجهيز البيانات للرفع
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
      };

      // رفع المفاتيح للسيرفر
      final result = await _apiService.uploadPreKeyBundle(bundle);
      
      if (!result['success']) {
        throw Exception(result['message']);
      }

      return true;
    } catch (e) {
      print('Error generating keys: $e');
      return false;
    }
  }

  // إنشاء Session مع مستخدم آخر
  Future<bool> createSession(String recipientId) async {
    
    try {
      await initialize();

       final userData = await FlutterSecureStorage().read(key: 'user_data');
    if (userData != null) {
      final currentUserId = jsonDecode(userData)['id'];
      if (recipientId == currentUserId) {
        return false;
      }
    }
    

    // جلب PreKey Bundle من السيرفر
    final response = await _apiService.getPreKeyBundle(recipientId);
    
    if (!response['success']) {
      throw Exception(response['message']);
    }

    final bundleData = response['bundle'];
      
      // بناء SignalProtocolAddress
      final recipientAddress = SignalProtocolAddress(recipientId, 1);
      
      // معالجة PreKey (اختياري) لأنه يستخدم مرة واحدة فقط لإنشاء الجلسة
      ECPublicKey? preKeyPublic;
      int? preKeyId;
      
      if (bundleData['preKey'] != null) {
        final preKeyBytes = base64Decode(bundleData['preKey']['publicKey']);
        preKeyPublic = Curve.decodePoint(preKeyBytes, 0);
        preKeyId = bundleData['preKey']['keyId'];
      }
      
      // معالجة SignedPreKey (إجباري) لأنه يستخدم للتحقق من المفاتيح
      final signedPreKeyBytes = base64Decode(
        bundleData['signedPreKey']['publicKey']
      );
      final signedPreKeyPublic = Curve.decodePoint(signedPreKeyBytes, 0);
      
      // معالجة IdentityKey (إجباري) لأنه يمثل هوية المستخدم
      final identityKeyBytes = base64Decode(bundleData['identityKey']);
      final identityKeyPublic = Curve.decodePoint(identityKeyBytes, 0);
      
      
      // بناء PreKeyBundle
      final bundle = PreKeyBundle(
        bundleData['registrationId'],
        1, // deviceId fixed to 1 since we don't support multiple devices
        preKeyId,
        preKeyPublic,
        bundleData['signedPreKey']['keyId'],
        signedPreKeyPublic,
        base64Decode(bundleData['signedPreKey']['signature']),
        IdentityKey(identityKeyPublic),
      );
      
      // إنشاء SessionBuilder
      final sessionBuilder = SessionBuilder(
        _sessionStore,
        _preKeyStore,
        _signedPreKeyStore,
        _identityStore,
        recipientAddress,
      );
      
      // معالجة Bundle وإنشاء Session
      await sessionBuilder.processPreKeyBundle(bundle);
      
      print('Session created successfully with recipent : $recipientId');
      return true;
      
    } catch (e) {
      print('Error creating session: $e');
      return false;
    }
  }

  // تشفير رسالة
  Future<Map<String, dynamic>?> encryptMessage(
    String recipientId,
    String message,
  ) async {
    try {
      final address = SignalProtocolAddress(recipientId, 1);
      
      // التحقق من وجود Session
      if (!await _sessionStore.containsSession(address)) {
        throw Exception('No session exists with user');
      }

      final cipher = SessionCipher(_sessionStore, _preKeyStore, 
                                   _signedPreKeyStore, _identityStore, address);
      
      final ciphertext = await cipher.encrypt(Uint8List.fromList(utf8.encode(message)));
      
      return {
        'type': ciphertext.getType(),
        'body': base64Encode(ciphertext.serialize()),
      };
    } catch (e) {
      print('Encryption error: $e');
      return null;
    }
  }

  // فك تشفير رسالة
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
    print('Decryption error: $e');
    return null;
  }
}
  // التحقق من وجود Session
  Future<bool> hasSession(String userId) async {
    final address = SignalProtocolAddress(userId, 1);
    return await _sessionStore.containsSession(address);
  }

  // حذف Session
  Future<void> deleteSession(String userId) async {
    final address = SignalProtocolAddress(userId, 1);
    await _sessionStore.deleteSession(address);
  }

  // التحقق من عدد PreKeys المتبقية
  Future<void> checkAndRefreshPreKeys() async {
    try {
      final result = await _apiService.checkPreKeysCount();
      
      if (result['success']) {
        final count = result['count'] ?? 0;
        print('Available PreKeys: $count');
        
        if (count < 20) {
          print('Low on PreKeys ($count), generating more...');
          await _generateAndUploadMorePreKeys();
        }
      } else {
        print('Failed to check PreKeys count: ${result['message']}');
      }
    } catch (e) {
      print('Error checking PreKeys: $e');
    }
  }

  // توليد ورفع مفاتيح إضافية 
  Future<void> _generateAndUploadMorePreKeys() async {
    try {
      final identityKeyPair = await _identityStore.getIdentityKeyPair();
      
      // توليد 100 مفتاح جديد بدءاً من ID عالي لتجنب التضارب
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
        print('Uploaded ${newPreKeys.length} new PreKeys successfully');
        print('Total keys: ${result['totalKeys']}, Available: ${result['availableKeys']}');
      } else {
        print('Failed to upload PreKeys: ${result['message']}');
      }
    } catch (e) {
      print('Error generating more PreKeys: $e');
    }
  }
}