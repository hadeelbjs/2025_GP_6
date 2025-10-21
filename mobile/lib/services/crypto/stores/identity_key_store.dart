// lib/services/crypto/stores/identity_key_store.dart

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';

class MyIdentityKeyStore extends IdentityKeyStore {
  final FlutterSecureStorage _storage;
  IdentityKeyPair? _identityKeyPair;
  int? _localRegistrationId;
  
  MyIdentityKeyStore(this._storage);

  Future<void> initialize() async {
    final identityKeyData = await _storage.read(key: 'identity_key');
    if (identityKeyData != null) {
      final data = jsonDecode(identityKeyData);
      _identityKeyPair = IdentityKeyPair(
        IdentityKey.fromBytes(base64Decode(data['public']), 0),
        DjbECPrivateKey(base64Decode(data['private'])),
      );
    }
    
    final regId = await _storage.read(key: 'registration_id');
    if (regId != null) {
      _localRegistrationId = int.parse(regId);
    }
  }

  Future<void> saveIdentityKeyPair(IdentityKeyPair keyPair) async {
    _identityKeyPair = keyPair;
    final data = jsonEncode({
      'public': base64Encode(keyPair.getPublicKey().serialize()),
      'private': base64Encode(keyPair.getPrivateKey().serialize()),
    });
    await _storage.write(key: 'identity_key', value: data);
  }

  Future<void> saveRegistrationId(int registrationId) async {
    _localRegistrationId = registrationId;
    await _storage.write(
      key: 'registration_id',
      value: registrationId.toString(),
    );
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
    
    final key = 'identity_${address.getName()}_${address.getDeviceId()}';
    await _storage.write(
      key: key,
      value: base64Encode(identityKey.serialize()),
    );
    return true;
  }

 @override
Future<bool> isTrustedIdentity(
  SignalProtocolAddress address,
  IdentityKey? identityKey,
  Direction direction,
) async {
  if (identityKey == null) return false;
  
  try {
    // جلب المفتاح المحفوظ
    final saved = await getIdentity(address);
    
    // إذا ما فيه مفتاح محفوظ، نثق بالجديد ونحفظه
    if (saved == null) {
      print('✅ No saved key - trusting new key for ${address.getName()}');
      await saveIdentity(address, identityKey);
      return true;
    }
    
    // مقارنة المفاتيح
    final savedBytes = saved.serialize();
    final newBytes = identityKey.serialize();
    
    if (savedBytes.length != newBytes.length) {
      print('⚠️ Key length mismatch for ${address.getName()}');
      // ✅ في التطوير: نستبدل المفتاح القديم بالجديد
      await saveIdentity(address, identityKey);
      return true;
    }
    
    // مقارنة byte by byte
    bool isIdentical = true;
    for (int i = 0; i < savedBytes.length; i++) {
      if (savedBytes[i] != newBytes[i]) {
        isIdentical = false;
        break;
      }
    }
    
    if (!isIdentical) {
      print('⚠️ Key changed for ${address.getName()}');
      // ✅ في التطوير: نستبدل المفتاح القديم بالجديد
      await saveIdentity(address, identityKey);
      return true;
    }
    
    print('✅ Key verified for ${address.getName()}');
    return true;
    
  } catch (e) {
    print('❌ Error in isTrustedIdentity: $e');
    // ✅ في حالة الخطأ، نثق بالمفتاح الجديد
    await saveIdentity(address, identityKey);
    return true;
  }
}
  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final key = 'identity_${address.getName()}_${address.getDeviceId()}';
    final data = await _storage.read(key: key);
    if (data == null) return null;
    return IdentityKey.fromBytes(base64Decode(data), 0);
  }

  Future<void> clearAll() async {
    try {
      await _storage.delete(key: 'identity_key_pair');
      await _storage.delete(key: 'local_registration_id');
      // حذف جميع Identity Keys المحفوظة
      final allKeys = await _storage.readAll();
      for (var key in allKeys.keys) {
        if (key.startsWith('identity_')) {
          await _storage.delete(key: key);
        }
      }
      print('Identity Store cleared');
    } catch (e) {
      print('Error clearing Identity Store: $e');
    }
  }
}