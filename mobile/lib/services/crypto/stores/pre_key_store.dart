// lib/services/crypto/stores/pre_key_store.dart
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';

class MyPreKeyStore extends PreKeyStore {
  final FlutterSecureStorage _storage;
  final Map<int, PreKeyRecord> _preKeys = {};

  MyPreKeyStore(this._storage);

  Future<void> initialize() async {
    // تحميل جميع PreKeys من التخزين
    final allKeys = await _storage.readAll();
    
    for (var entry in allKeys.entries) {
      if (entry.key.startsWith('prekey_')) {
        try {
          final id = int.parse(entry.key.split('_')[1]);
          final data = jsonDecode(entry.value);
          
          // استخدام Curve لإنشاء المفاتيح
          final publicKeyBytes = base64Decode(data['public']);
          final privateKeyBytes = base64Decode(data['private']);
          
          final publicKey = Curve.decodePoint(publicKeyBytes, 0);
          final privateKey = Curve.decodePrivatePoint(privateKeyBytes);
          
          final keyPair = ECKeyPair(publicKey, privateKey);
          
          _preKeys[id] = PreKeyRecord(id, keyPair);
        } catch (e) {
          print('Error loading prekey ${entry.key}: $e');
        }
      }
    }
  }

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    if (!_preKeys.containsKey(preKeyId)) {
      throw InvalidKeyIdException('PreKey $preKeyId not found');
    }
    return _preKeys[preKeyId]!;
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    _preKeys[preKeyId] = record;
    
    final data = jsonEncode({
      'public': base64Encode(record.getKeyPair().publicKey.serialize()),
      'private': base64Encode(record.getKeyPair().privateKey.serialize()),
    });
    
    await _storage.write(key: 'prekey_$preKeyId', value: data);
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    return _preKeys.containsKey(preKeyId);
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    _preKeys.remove(preKeyId);
    await _storage.delete(key: 'prekey_$preKeyId');
  }
}