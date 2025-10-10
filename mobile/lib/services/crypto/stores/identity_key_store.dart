import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';

class MyIdentityKeyStore extends IdentityKeyStore {
  final FlutterSecureStorage _storage;
  IdentityKeyPair? _identityKeyPair;
  int? _localRegistrationId;
  final Map<String, Map<String, dynamic>> _trustedIdentities = {};

  MyIdentityKeyStore(this._storage);

  Future<void> initialize() async {
    // تحميل Identity Key
    final identityKeyData = await _storage.read(key: 'identity_key');
    if (identityKeyData != null) {
      final data = jsonDecode(identityKeyData);
      
      final publicKeyBytes = base64Decode(data['public']);
      final privateKeyBytes = base64Decode(data['private']);
      
      final publicKey = Curve.decodePoint(publicKeyBytes, 0);
      final privateKey = Curve.decodePrivatePoint(privateKeyBytes);
      
      _identityKeyPair = IdentityKeyPair(
        IdentityKey(publicKey),
        privateKey,
      );
    }

    // تحميل Registration ID
    final regId = await _storage.read(key: 'registration_id');
    if (regId != null) {
      _localRegistrationId = int.parse(regId);
    }
    
    // تحميل Trusted Identities
    await _loadTrustedIdentities();
  }

  Future<void> _loadTrustedIdentities() async {
    final data = await _storage.read(key: 'trusted_identities');
    if (data != null) {
      final Map<String, dynamic> decoded = jsonDecode(data);
      decoded.forEach((userId, trustData) {
        _trustedIdentities[userId] = Map<String, dynamic>.from(trustData);
      });
    }
  }

  Future<void> _saveTrustedIdentities() async {
    await _storage.write(
      key: 'trusted_identities',
      value: jsonEncode(_trustedIdentities),
    );
  }

  // حفظ Identity Key Pair المحلي (مختلف عن override)
  Future<void> saveIdentityKeyPair(IdentityKeyPair keyPair) async {
    _identityKeyPair = keyPair;
    
    final data = jsonEncode({
      'public': base64Encode(keyPair.getPublicKey().serialize()),
      'private': base64Encode(keyPair.getPrivateKey().serialize()),
    });
    
    await _storage.write(key: 'identity_key', value: data);
  }

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    if (_identityKeyPair == null) {
      throw Exception('Identity key not initialized');
    }
    return _identityKeyPair!;
  }

  @override
  Future<int> getLocalRegistrationId() async {
    if (_localRegistrationId == null) {
      throw Exception('Registration ID not initialized');
    }
    return _localRegistrationId!;
  }

  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    if (identityKey == null) return false;
    
    final userId = address.getName();
    final key = 'identity_${userId}_${address.getDeviceId()}';
    
    await _storage.write(
      key: key,
      value: base64Encode(identityKey.serialize()),
    );
    
    if (!_trustedIdentities.containsKey(userId)) {
      _trustedIdentities[userId] = {
        'identityKey': base64Encode(identityKey.serialize()),
        'fingerprint': _generateFingerprint(identityKey),
        'isTrusted': false,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await _saveTrustedIdentities();
    }
    
    return true;
  }

  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
    Direction direction,
  ) async {
    if (identityKey == null) return false;
    
    final userId = address.getName();
    final savedKey = await getIdentity(address);
    
    if (savedKey == null) {
      // في الاتجاه الصادر: نقبل المفتاح الجديد (سيتم التحقق لاحقاً)
      if (direction == Direction.sending) {
        return true;
      }
      // في الاتجاه الوارد: نرفض
      return false;
    }
    
    final keysMatch = _keysMatch(savedKey, identityKey);
    
    if (!keysMatch) {
      print('⚠️ WARNING: Identity key changed for $userId');
      await _handleKeyChange(userId, savedKey, identityKey);
      return false;
    }
    
    final trustData = _trustedIdentities[userId];
    if (trustData == null) {
      return direction == Direction.sending;
    }
    
    return trustData['isTrusted'] == true;
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final key = 'identity_${address.getName()}_${address.getDeviceId()}';
    final data = await _storage.read(key: key);
    
    if (data == null) return null;
    
    final keyBytes = base64Decode(data);
    final publicKey = Curve.decodePoint(keyBytes, 0);
    
    return IdentityKey(publicKey);
  }

  String _generateFingerprint(IdentityKey key) {
    final bytes = key.serialize();
    final hash = sha256.convert(bytes);
    
    final fingerprint = hash.bytes
        .take(30)
        .map((b) => b.toString().padLeft(2, '0'))
        .join();
    
    return _formatFingerprint(fingerprint);
  }

  String _formatFingerprint(String fp) {
    final chunks = <String>[];
    for (int i = 0; i < fp.length; i += 5) {
      chunks.add(fp.substring(i, i + 5 > fp.length ? fp.length : i + 5));
    }
    return chunks.join(' ');
  }

  Future<bool> verifyIdentity(String userId, String expectedFingerprint) async {
    final trustData = _trustedIdentities[userId];
    if (trustData == null) return false;
    
    final actualFingerprint = trustData['fingerprint'] as String?;
    if (actualFingerprint == null) return false;
    
    if (actualFingerprint == expectedFingerprint) {
      final userTrustData = _trustedIdentities[userId];
      if (userTrustData != null) {
        userTrustData['isTrusted'] = true;
        userTrustData['verifiedAt'] = DateTime.now().toIso8601String();
        await _saveTrustedIdentities();
        return true;
      }
    }
    
    return false;
  }

  Future<void> _handleKeyChange(
    String userId,
    IdentityKey oldKey,
    IdentityKey newKey,
  ) async {
    _trustedIdentities[userId] = {
      'identityKey': base64Encode(newKey.serialize()),
      'fingerprint': _generateFingerprint(newKey),
      'isTrusted': false,
      'keyChangedAt': DateTime.now().toIso8601String(),
      'oldFingerprint': _generateFingerprint(oldKey),
    };
    await _saveTrustedIdentities();
  }

  bool _keysMatch(IdentityKey key1, IdentityKey key2) {
    final bytes1 = key1.serialize();
    final bytes2 = key2.serialize();
    
    if (bytes1.length != bytes2.length) return false;
    
    for (int i = 0; i < bytes1.length; i++) {
      if (bytes1[i] != bytes2[i]) return false;
    }
    
    return true;
  }

  String? getFingerprint(String userId) {
    return _trustedIdentities[userId]?['fingerprint'];
  }

  bool isUserTrusted(String userId) {
    return _trustedIdentities[userId]?['isTrusted'] ?? false;
  }

  Future<String> getSafetyNumber(String userId) async {
    final myKey = await getIdentityKeyPair();
    final theirKey = await getIdentity(SignalProtocolAddress(userId, 1));
    
    if (theirKey == null) {
      throw Exception('No identity key found for user');
    }
    
    final myFingerprint = _generateFingerprint(myKey.getPublicKey());
    final theirFingerprint = _generateFingerprint(theirKey);
    
    return '$myFingerprint\n\n$theirFingerprint';
  }
}
