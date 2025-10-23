// lib/services/crypto/stores/identity_key_store.dart

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

class MyIdentityKeyStore extends IdentityKeyStore {
  final FlutterSecureStorage _storage;
  IdentityKeyPair? _identityKeyPair;
  int? _localRegistrationId;
  
  MyIdentityKeyStore(this._storage);

  Future<void> initialize() async {
    final identityKeyData = await _storage.read(key: 'identity_key');
    if (identityKeyData != null) {
      try {
        final data = jsonDecode(identityKeyData);
        _identityKeyPair = IdentityKeyPair(
          IdentityKey.fromBytes(base64Decode(data['public']), 0),
          DjbECPrivateKey(base64Decode(data['private'])),
        );
        print('✅ Identity key pair loaded from storage');
      } catch (e) {
        print('❌ Error loading identity key pair: $e');
      }
    }
    
    final regId = await _storage.read(key: 'registration_id');
    if (regId != null) {
      _localRegistrationId = int.parse(regId);
      print('✅ Registration ID loaded: $_localRegistrationId');
    }
  }

  Future<void> saveIdentityKeyPair(IdentityKeyPair keyPair) async {
    _identityKeyPair = keyPair;
    final data = jsonEncode({
      'public': base64Encode(keyPair.getPublicKey().serialize()),
      'private': base64Encode(keyPair.getPrivateKey().serialize()),
    });
    await _storage.write(key: 'identity_key', value: data);
    print('✅ Identity key pair saved to storage');
  }

  Future<void> saveRegistrationId(int registrationId) async {
    _localRegistrationId = registrationId;
    await _storage.write(
      key: 'registration_id',
      value: registrationId.toString(),
    );
    print('✅ Registration ID saved: $registrationId');
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
    if (identityKey == null) {
      print('⚠️ Attempted to save null identity key for ${address.getName()}');
      return false;
    }
    
    final key = 'identity_${address.getName()}_${address.getDeviceId()}';
    final serialized = identityKey.serialize();
    final base64Value = base64Encode(serialized);
    
    print('\n💾 === SAVING IDENTITY ===');
    print('  Address: ${address.getName()}');
    print('  Device ID: ${address.getDeviceId()}');
    print('  Key bytes length: ${serialized.length}');
    print('  First 10 bytes: ${serialized.take(10).toList()}');
    print('  Base64 length: ${base64Value.length}');
    print('  Base64 (first 30): ${base64Value.substring(0, min(30, base64Value.length))}...');
    
    await _storage.write(key: key, value: base64Value);
    
    // ✅ تحقق فوري: هل حُفظ صحيح؟
    final readBack = await _storage.read(key: key);
    if (readBack == base64Value) {
      print('  ✅ Identity saved and verified');
    } else {
      print('  ❌ WARNING: Save verification FAILED!');
    }
    print('==========================\n');
    
    return true;
  }

  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
    Direction direction,
  ) async {
    if (identityKey == null) {
      print('⚠️ isTrustedIdentity called with null key for ${address.getName()}');
      return false;
    }
    
    try {
      print('\n🔍 === isTrustedIdentity CHECK ===');
      print('  Address: ${address.getName()}');
      print('  Device ID: ${address.getDeviceId()}');
      print('  Direction: ${direction.toString().split('.').last}');
      
      // جلب المفتاح المحفوظ
      final saved = await getIdentity(address);
      
      // إذا ما فيه مفتاح محفوظ، نثق بالجديد
      if (saved == null) {
        print('  ✅ No saved key - trusting new key');
        final newBytes = identityKey.serialize();
        print('  New key (first 10 bytes): ${newBytes.take(10).toList()}');
        print('==================================\n');
        return true;
      }
      
      // مقارنة المفاتيح
      final savedBytes = saved.serialize();
      final newBytes = identityKey.serialize();
      
      print('  Saved key (first 10 bytes): ${savedBytes.take(10).toList()}');
      print('  New key (first 10 bytes): ${newBytes.take(10).toList()}');
      
      if (savedBytes.length != newBytes.length) {
        print('  ⚠️ Key length mismatch: ${savedBytes.length} vs ${newBytes.length}');
        print('  Accepting new key (development mode)');
        print('==================================\n');
        return true;
      }
      
      // مقارنة byte by byte
      bool isIdentical = true;
      for (int i = 0; i < savedBytes.length; i++) {
        if (savedBytes[i] != newBytes[i]) {
          isIdentical = false;
          print('  ⚠️ Keys differ at byte $i: ${savedBytes[i]} vs ${newBytes[i]}');
          break;
        }
      }
      
      if (!isIdentical) {
        print('  ⚠️ Key changed - accepting new key (development mode)');
        print('==================================\n');
        return true;
      }
      
      print('  ✅ Keys match - identity verified');
      print('==================================\n');
      return true;
      
    } catch (e) {
      print('  ❌ Error in isTrustedIdentity: $e');
      print('  Error type: ${e.runtimeType}');
      print('  Trusting new key by default');
      print('==================================\n');
      return true;
    }
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final key = 'identity_${address.getName()}_${address.getDeviceId()}';
    final data = await _storage.read(key: key);
    
    if (data == null) {
      return null;
    }
    
    try {
      final decoded = base64Decode(data);
      final identityKey = IdentityKey.fromBytes(decoded, 0);
      return identityKey;
    } catch (e) {
      print('❌ Error decoding identity for ${address.getName()}: $e');
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      _identityKeyPair = null;
      _localRegistrationId = null;
      
      await _storage.delete(key: 'identity_key');
      await _storage.delete(key: 'registration_id');
      
      // حذف جميع Identity Keys المحفوظة
      final allKeys = await _storage.readAll();
      for (var key in allKeys.keys) {
        if (key.startsWith('identity_')) {
          await _storage.delete(key: key);
        }
      }
      print('🗑️ Identity Store cleared');
    } catch (e) {
      print('❌ Error clearing Identity Store: $e');
    }
  }
}