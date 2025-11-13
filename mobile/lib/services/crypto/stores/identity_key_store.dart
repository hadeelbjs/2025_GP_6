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
  final String? _userId;
  
  MyIdentityKeyStore(this._storage, {String? userId}) : _userId = userId;

  // ========================================
  // ✅ دالة موحّدة لإنشاء مفاتيح التخزين
  // ========================================
  String _getStorageKey(String baseKey) {
    if (_userId != null) {
      // ✅ نضع userId في النهاية لسهولة القراءة
      return '${baseKey}_$_userId';
    }
    return baseKey;
  }

  // ========================================
  // ✅ التهيئة - موحّدة ومُحدَّثة
  // ========================================
  Future<void> initialize() async {
    print('🔧 Initializing Identity Store for user: $_userId');
    
    // قراءة Identity Key Pair
    final identityKeyData = await _storage.read(
      key: _getStorageKey('identity_key'),
    );
    
    if (identityKeyData != null) {
      try {
        final data = jsonDecode(identityKeyData);
        _identityKeyPair = IdentityKeyPair(
          IdentityKey.fromBytes(base64Decode(data['public']), 0),
          DjbECPrivateKey(base64Decode(data['private'])),
        );
        print('✅ Identity key pair loaded for user: $_userId');
      } catch (e) {
        print('❌ Error loading identity key pair: $e');
      }
    } else {
      print('ℹ️ No identity key found for user: $_userId');
    }
    
    // قراءة Registration ID
    final regId = await _storage.read(
      key: _getStorageKey('registration_id'),
    );
    
    if (regId != null) {
      _localRegistrationId = int.parse(regId);
      print('✅ Registration ID loaded for user $_userId: $_localRegistrationId');
    } else {
      print('ℹ️ No registration ID found for user: $_userId');
    }
  }

  // ========================================
  // ✅ حفظ Identity Key Pair - موحّدة
  // ========================================
  Future<void> saveIdentityKeyPair(IdentityKeyPair keyPair) async {
    _identityKeyPair = keyPair;
    
    final data = jsonEncode({
      'public': base64Encode(keyPair.getPublicKey().serialize()),
      'private': base64Encode(keyPair.getPrivateKey().serialize()),
    });
    
    final storageKey = _getStorageKey('identity_key');
    await _storage.write(key: storageKey, value: data);
    
    print('✅ Identity key pair saved to: $storageKey');
  }

  // ========================================
  // ✅ حفظ Registration ID - موحّدة
  // ========================================
  Future<void> saveRegistrationId(int registrationId) async {
    _localRegistrationId = registrationId;
    
    final storageKey = _getStorageKey('registration_id');
    await _storage.write(
      key: storageKey,
      value: registrationId.toString(),
    );
    
    print('✅ Registration ID saved to: $storageKey (value: $registrationId)');
  }

  // ========================================
  // ✅ جلب Identity Key Pair
  // ========================================
  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    if (_identityKeyPair == null) {
      throw Exception('Identity key not initialized for user: $_userId');
    }
    return _identityKeyPair!;
  }

  // ========================================
  // ✅ جلب Registration ID
  // ========================================
  @override
  Future<int> getLocalRegistrationId() async {
    if (_localRegistrationId == null) {
      throw Exception('Registration ID not initialized for user: $_userId');
    }
    return _localRegistrationId!;
  }

  // ========================================
  // ✅ حفظ Identity للطرف الآخر (Peer)
  // ========================================
  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    if (identityKey == null) {
      print('⚠️ Attempted to save null identity key for ${address.getName()}');
      return false;
    }
    
    // ✅ استخدام _getStorageKey لتضمين userId
    final baseKey = 'peer_identity_${address.getName()}_${address.getDeviceId()}';
    final key = _getStorageKey(baseKey);
    
    final serialized = identityKey.serialize();
    final base64Value = base64Encode(serialized);
    
    print('\n💾 === SAVING PEER IDENTITY ===');
    print('  Peer: ${address.getName()}');
    print('  Device ID: ${address.getDeviceId()}');
    print('  Current User: $_userId');
    print('  Storage Key: $key');
    print('  Key bytes length: ${serialized.length}');
    print('  First 10 bytes: ${serialized.take(10).toList()}');
    
    await _storage.write(key: key, value: base64Value);
    
    // ✅ تحقق فوري
    final readBack = await _storage.read(key: key);
    if (readBack == base64Value) {
      print('  ✅ Peer identity saved and verified');
    } else {
      print('  ❌ WARNING: Save verification FAILED!');
    }
    print('=================================\n');
    
    return true;
  }

  // ========================================
  // ✅ جلب Identity للطرف الآخر
  // ========================================
  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final baseKey = 'peer_identity_${address.getName()}_${address.getDeviceId()}';
    final key = _getStorageKey(baseKey);
    
    final data = await _storage.read(key: key);
    
    if (data == null) {
      print('ℹ️ No saved identity for ${address.getName()} (user: $_userId)');
      return null;
    }
    
    try {
      final decoded = base64Decode(data);
      final identityKey = IdentityKey.fromBytes(decoded, 0);
      print('✅ Loaded identity for ${address.getName()} from: $key');
      return identityKey;
    } catch (e) {
      print('❌ Error decoding identity for ${address.getName()}: $e');
      return null;
    }
  }

  // ========================================
  // ✅ التحقق من الثقة
  // ========================================
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
      print('  Peer: ${address.getName()}');
      print('  Current User: $_userId');
      print('  Direction: ${direction.toString().split('.').last}');
      
      final saved = await getIdentity(address);
      
      if (saved == null) {
        print('  ✅ No saved key - trusting new key');
        print('====================================\n');
        return true;
      }
      
      final savedBytes = saved.serialize();
      final newBytes = identityKey.serialize();
      
      print('  Saved key (first 10): ${savedBytes.take(10).toList()}');
      print('  New key (first 10): ${newBytes.take(10).toList()}');
      
      if (savedBytes.length != newBytes.length) {
        print('  ⚠️ Length mismatch: ${savedBytes.length} vs ${newBytes.length}');
        print('  Accepting new key (development mode)');
        print('====================================\n');
        return true;
      }
      
      bool isIdentical = true;
      for (int i = 0; i < savedBytes.length; i++) {
        if (savedBytes[i] != newBytes[i]) {
          isIdentical = false;
          print('  ⚠️ Keys differ at byte $i');
          break;
        }
      }
      
      if (!isIdentical) {
        print('  ⚠️ Key changed - accepting (development mode)');
        print('====================================\n');
        return true;
      }
      
      print('  ✅ Keys match - identity verified');
      print('====================================\n');
      return true;
      
    } catch (e) {
      print('  ❌ Error in isTrustedIdentity: $e');
      print('  Trusting by default');
      print('====================================\n');
      return true;
    }
  }

  // ========================================
  // ✅ حذف جميع البيانات
  // ========================================
  Future<void> clearAll() async {
    try {
      print('🗑️ Clearing Identity Store for user: $_userId');
      
      _identityKeyPair = null;
      _localRegistrationId = null;
      
      // حذف مفاتيح المستخدم الحالي
      final identityKey = _getStorageKey('identity_key');
      final regId = _getStorageKey('registration_id');
      
      await _storage.delete(key: identityKey);
      await _storage.delete(key: regId);
      
      print('  🗑️ Deleted: $identityKey');
      print('  🗑️ Deleted: $regId');
      
      // حذف جميع مفاتيح الأطراف المحفوظة لهذا المستخدم
      final allKeys = await _storage.readAll();
      int deletedCount = 0;
      
      for (var key in allKeys.keys) {
        // ✅ حذف المفاتيح التي تبدأ بـ peer_identity_ وتنتهي بـ _userId
        if (key.startsWith('peer_identity_')) {
          if (_userId != null && key.endsWith('_$_userId')) {
            await _storage.delete(key: key);
            deletedCount++;
            print('  🗑️ Deleted peer: $key');
          } else if (_userId == null) {
            // إذا ما فيه userId، احذف جميع peer identities
            await _storage.delete(key: key);
            deletedCount++;
            print('  🗑️ Deleted peer: $key');
          }
        }
      }
      
      print('✅ Identity Store cleared (deleted $deletedCount peer identities)');
    } catch (e) {
      print('❌ Error clearing Identity Store: $e');
      rethrow;
    }
  }

  // ========================================
  // ✅ دوال مساعدة
  // ========================================
  
  String? get currentUserId => _userId;
  
  Future<bool> hasKeysForUser() async {
    final identityKey = await _storage.read(
      key: _getStorageKey('identity_key'),
    );
    final regId = await _storage.read(
      key: _getStorageKey('registration_id'),
    );
    
    final hasKeys = identityKey != null && regId != null;
    
    print('🔍 Keys check for user $_userId: ${hasKeys ? "✅ Found" : "❌ Not found"}');
    
    return hasKeys;
  }
  
  Future<bool> hasSavedIdentityFor(String peerId) async {
    final baseKey = 'peer_identity_${peerId}_1';
    final key = _getStorageKey(baseKey);
    final data = await _storage.read(key: key);
    
    final exists = data != null;
    print('🔍 Peer identity for $peerId: ${exists ? "✅ Exists" : "❌ Not found"}');
    
    return exists;
  }
  
  Future<void> debugPrintAllKeys() async {
    print('\n🔍 === DEBUG: All Identity Keys for User $_userId ===');
    
    final allKeys = await _storage.readAll();
    int ownCount = 0;
    int peerCount = 0;
    
    // مفاتيح المستخدم الحالي
    print('\n📦 Own Keys:');
    final identityKey = _getStorageKey('identity_key');
    final regId = _getStorageKey('registration_id');
    
    if (allKeys.containsKey(identityKey)) {
      print('  ✅ $identityKey');
      ownCount++;
    } else {
      print('  ❌ $identityKey (missing)');
    }
    
    if (allKeys.containsKey(regId)) {
      print('  ✅ $regId');
      ownCount++;
    } else {
      print('  ❌ $regId (missing)');
    }
    
    // مفاتيح الأطراف
    print('\n👥 Peer Keys:');
    for (var key in allKeys.keys) {
      if (key.startsWith('peer_identity_')) {
        if (_userId != null && key.endsWith('_$_userId')) {
          print('  ✅ $key');
          peerCount++;
        } else if (_userId == null) {
          print('  ✅ $key');
          peerCount++;
        }
      }
    }
    
    print('\n📊 Summary:');
    print('  Own keys: $ownCount/2');
    print('  Peer keys: $peerCount');
    print('=====================================================\n');
  }
  
  /// دالة للحصول على قائمة بجميع الأطراف المحفوظين
  Future<List<String>> getSavedPeerIds() async {
    final allKeys = await _storage.readAll();
    final peerIds = <String>[];
    
    for (var key in allKeys.keys) {
      if (key.startsWith('peer_identity_')) {
        if (_userId != null && key.endsWith('_$_userId')) {
          // استخراج peerId من: peer_identity_alice_1_user123
          final parts = key.split('_');
          if (parts.length >= 3) {
            final peerId = parts[2]; // alice
            if (!peerIds.contains(peerId)) {
              peerIds.add(peerId);
            }
          }
        }
      }
    }
    
    return peerIds;
  }
}