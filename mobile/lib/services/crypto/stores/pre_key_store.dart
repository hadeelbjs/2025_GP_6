import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class MyPreKeyStore extends PreKeyStore {
  final FlutterSecureStorage _storage;
  final Map<int, PreKeyRecord> _preKeysCache = {};

  MyPreKeyStore(this._storage);

  Future<void> initialize() async {
    // قراءة جميع المفاتيح من التخزين الآمن
    final allKeys = await _storage.readAll();
    
    for (var entry in allKeys.entries) {
      if (entry.key.startsWith('prekey_')) {
        try {
          //تحويل البيانات المخزنة إلى PreKeyRecord
          final id = int.parse(entry.key.split('_')[1]);
          final data = jsonDecode(entry.value);
          
          //فك ترميز المفاتيح
          final publicKeyBytes = base64Decode(data['public']);
          final privateKeyBytes = base64Decode(data['private']);

          // تحويل إلى ECKey لتقبلها المكتبة
          final publicKey = Curve.decodePoint(publicKeyBytes, 0);
          final privateKey = Curve.decodePrivatePoint(privateKeyBytes);
          
          final keyPair = ECKeyPair(publicKey, privateKey);
          
          // تخزين المفاتيح في الذاكرة المؤقتة
          _preKeysCache[id] = PreKeyRecord(id, keyPair);
        } catch (e) {
          print('Error loading prekey ${entry.key}: $e');
        }
      }
    }
  }

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    if (!_preKeysCache.containsKey(preKeyId)) {
      throw InvalidKeyIdException('PreKey $preKeyId not found');
    }
    return _preKeysCache[preKeyId]!;
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    _preKeysCache[preKeyId] = record;
    
    // تخزين المفتاح في التخزين الآمن بعد ترميزه إلى نص ليقبله التخزين الآمن
    final data = jsonEncode({
      'public': base64Encode(record.getKeyPair().publicKey.serialize()),
      'private': base64Encode(record.getKeyPair().privateKey.serialize()),
    });
    
    await _storage.write(key: 'prekey_$preKeyId', value: data);
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    return _preKeysCache.containsKey(preKeyId);
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    _preKeysCache.remove(preKeyId);
    await _storage.delete(key: 'prekey_$preKeyId');
  }

  Future<void> clearAll() async {
    try {
      final allKeys = await _storage.readAll();
      for (var key in allKeys.keys) {
        if (key.startsWith('prekey_')) {
          await _storage.delete(key: key);
        }
      }
      print('PreKey Store cleared');
    } catch (e) {
      print('Error clearing PreKey Store: $e');
    }
  }
}