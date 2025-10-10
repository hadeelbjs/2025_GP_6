// lib/services/crypto/signal_protocol_manager.dart
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'stores/identity_key_store.dart';
import 'stores/pre_key_store.dart';
import 'stores/signed_pre_key_store.dart';
import 'stores/session_store.dart';

class SignalProtocolManager {
  static final SignalProtocolManager _instance = 
      SignalProtocolManager._internal();
  factory SignalProtocolManager() => _instance;
  SignalProtocolManager._internal();

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

  // توليد المفاتيح (عند التسجيل)
  Future<Map<String, dynamic>> generateKeys() async {
    await initialize();

    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);

    // ✅ استخدام الدالة الجديدة
    await _identityStore.saveIdentityKeyPair(identityKeyPair);
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

    return {
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
  }

  // إنشاء Session
  Future<void> createSession(
    String recipientId,
    Map<String, dynamic> preKeyBundle,
  ) async {
    final recipientAddress = SignalProtocolAddress(recipientId, 1);
    
    // ✅ استخدام Curve.decodePoint بدل fromBytes
    ECPublicKey? preKeyPublic;
    if (preKeyBundle['preKey'] != null) {
      final preKeyBytes = base64Decode(preKeyBundle['preKey']['publicKey']);
      preKeyPublic = Curve.decodePoint(preKeyBytes, 0);
    }
    
    final signedPreKeyBytes = base64Decode(
      preKeyBundle['signedPreKey']['publicKey']
    );
    final signedPreKeyPublic = Curve.decodePoint(signedPreKeyBytes, 0);
    
    final identityKeyBytes = base64Decode(preKeyBundle['identityKey']);
    final identityKeyPublic = Curve.decodePoint(identityKeyBytes, 0);
    
    final bundle = PreKeyBundle(
      preKeyBundle['registrationId'],
      1, // deviceId
      preKeyBundle['preKey']?['keyId'],
      preKeyPublic,
      preKeyBundle['signedPreKey']['keyId'],
      signedPreKeyPublic,
      base64Decode(preKeyBundle['signedPreKey']['signature']),
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
  }

  // تشفير
  Future<Map<String, dynamic>> encryptMessage(
    String recipientId,
    String plaintext,
  ) async {
    final recipientAddress = SignalProtocolAddress(recipientId, 1);
    
    final sessionCipher = SessionCipher(
      _sessionStore,
      _preKeyStore,
      _signedPreKeyStore,
      _identityStore,
      recipientAddress,
    );
    
    final ciphertext = await sessionCipher.encrypt(
      Uint8List.fromList(utf8.encode(plaintext)),
    );
    
    // ✅ استخدام lowercase
    return {
      'type': ciphertext.getType() == CiphertextMessage.prekeyType
          ? 'PREKEY_MESSAGE'
          : 'SIGNAL_MESSAGE',
      'ciphertext': base64Encode(ciphertext.serialize()),
    };
  }

  // فك التشفير
  Future<String> decryptMessage(
    String senderId,
    String type,
    String ciphertextBase64,
  ) async {
    final senderAddress = SignalProtocolAddress(senderId, 1);
    
    final sessionCipher = SessionCipher(
      _sessionStore,
      _preKeyStore,
      _signedPreKeyStore,
      _identityStore,
      senderAddress,
    );
    
    final ciphertextBytes = base64Decode(ciphertextBase64);
    Uint8List plaintext;
    
    if (type == 'PREKEY_MESSAGE') {
      final preKeyMessage = PreKeySignalMessage(ciphertextBytes);
      plaintext = await sessionCipher.decryptFromSignal(preKeyMessage.getWhisperMessage());
    } else {
      final message = SignalMessage.fromSerialized(ciphertextBytes);
      plaintext = await sessionCipher.decryptFromSignal(message);
    }
    
    return utf8.decode(plaintext);
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
}