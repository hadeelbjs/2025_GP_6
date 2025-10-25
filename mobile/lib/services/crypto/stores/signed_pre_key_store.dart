import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:fixnum/fixnum.dart'; 

class MySignedPreKeyStore extends SignedPreKeyStore {
  final FlutterSecureStorage _storage;
  final Map<int, SignedPreKeyRecord> _signedPreKeys = {};
  final String? _userId;

  MySignedPreKeyStore(this._storage, {String? userId}) : _userId = userId;

  Future<void> initialize() async {
    final allKeys = await _storage.readAll();
    
    for (var entry in allKeys.entries) {
      if (entry.key.startsWith('signed_prekey_')) {
        try {
          final id = int.parse(entry.key.split('_')[2]);
          final data = jsonDecode(entry.value);
          
          final publicKeyBytes = base64Decode(data['public']);
          final privateKeyBytes = base64Decode(data['private']);
          
          final publicKey = Curve.decodePoint(publicKeyBytes, 0);
          final privateKey = Curve.decodePrivatePoint(privateKeyBytes);
          
          final keyPair = ECKeyPair(publicKey, privateKey);
          
          // تحويل timestamp من int إلى Int64
          final timestamp = data['timestamp'];
          final timestampInt64 = timestamp is Int64 
              ? timestamp 
              : Int64(timestamp as int);
          
          _signedPreKeys[id] = SignedPreKeyRecord(
            id,
            timestampInt64, // استخدام Int64
            keyPair,
            base64Decode(data['signature']),
          );
        } catch (e) {
          print('Error loading signed prekey ${entry.key}: $e');
        }
      }
    }
  }

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    if (!_signedPreKeys.containsKey(signedPreKeyId)) {
      throw InvalidKeyIdException('SignedPreKey $signedPreKeyId not found');
    }
    return _signedPreKeys[signedPreKeyId]!;
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    return _signedPreKeys.values.toList();
  }

  @override
  Future<void> storeSignedPreKey(int signedPreKeyId, SignedPreKeyRecord record) async {
    _signedPreKeys[signedPreKeyId] = record;
    
    // تحويل Int64 إلى int عند الحفظ
    final data = jsonEncode({
      'public': base64Encode(record.getKeyPair().publicKey.serialize()),
      'private': base64Encode(record.getKeyPair().privateKey.serialize()),
      'signature': base64Encode(record.signature),
      'timestamp': record.timestamp.toInt(), // Int64 → int
    });
    
    await _storage.write(key: 'signed_prekey_$signedPreKeyId', value: data);
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    return _signedPreKeys.containsKey(signedPreKeyId);
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    _signedPreKeys.remove(signedPreKeyId);
    await _storage.delete(key: 'signed_prekey_$signedPreKeyId');
  }

  Future<void> clearAll() async {
    try {
      final allKeys = await _storage.readAll();
      for (var key in allKeys.keys) {
        if (key.startsWith('signed_prekey_')) {
          await _storage.delete(key: key);
        }
      }
      print('Signed PreKey Store cleared');
    } catch (e) {
      print('Error clearing Signed PreKey Store: $e');
    }
  }

  /// دالة مساعدة لإنشاء مفتاح فريد لكل مستخدم
  String _getStorageKey(String key) {
    if (_userId != null) {
      return '${_userId}_$key';
    }
    return key;
  }
  
  /// دالة محسّنة للتهيئة مع دعم userId
  Future<void> initializeWithUserId() async {
    _signedPreKeys.clear();
    
    final allKeys = await _storage.readAll();
    final prefix = _userId != null ? '${_userId}_signed_prekey_' : 'signed_prekey_';
    
    for (var entry in allKeys.entries) {
      if (entry.key.startsWith(prefix)) {
        try {
          // استخراج ID من المفتاح
          final parts = entry.key.split('_');
          final id = int.parse(parts.last);
          
          final data = jsonDecode(entry.value);
          
          final publicKeyBytes = base64Decode(data['public']);
          final privateKeyBytes = base64Decode(data['private']);
          
          final publicKey = Curve.decodePoint(publicKeyBytes, 0);
          final privateKey = Curve.decodePrivatePoint(privateKeyBytes);
          
          final keyPair = ECKeyPair(publicKey, privateKey);
          
          final timestamp = data['timestamp'];
          final timestampInt64 = timestamp is Int64 
              ? timestamp 
              : Int64(timestamp as int);
          
          _signedPreKeys[id] = SignedPreKeyRecord(
            id,
            timestampInt64,
            keyPair,
            base64Decode(data['signature']),
          );
        } catch (e) {
          print('Error loading signed prekey ${entry.key}: $e');
        }
      }
    }
    
    print('✅ Loaded ${_signedPreKeys.length} SignedPreKeys for user: $_userId');
  }
  
  /// دالة محسّنة لحفظ SignedPreKey مع دعم userId
  Future<void> storeSignedPreKeyWithUserId(
    int signedPreKeyId,
    SignedPreKeyRecord record,
  ) async {
    _signedPreKeys[signedPreKeyId] = record;
    
    final data = jsonEncode({
      'public': base64Encode(record.getKeyPair().publicKey.serialize()),
      'private': base64Encode(record.getKeyPair().privateKey.serialize()),
      'signature': base64Encode(record.signature),
      'timestamp': record.timestamp.toInt(),
    });
    
    await _storage.write(
      key: _getStorageKey('signed_prekey_$signedPreKeyId'),
      value: data,
    );
  }
  
  /// دالة محسّنة لحذف SignedPreKey مع دعم userId
  Future<void> removeSignedPreKeyWithUserId(int signedPreKeyId) async {
    _signedPreKeys.remove(signedPreKeyId);
    await _storage.delete(
      key: _getStorageKey('signed_prekey_$signedPreKeyId')
    );
  }
  
  /// دالة محسّنة لحذف جميع SignedPreKeys مع دعم userId
  Future<void> clearAllWithUserId() async {
    try {
      _signedPreKeys.clear();
      
      final allKeys = await _storage.readAll();
      final prefix = _userId != null ? '${_userId}_signed_prekey_' : 'signed_prekey_';
      
      for (var key in allKeys.keys) {
        if (key.startsWith(prefix)) {
          await _storage.delete(key: key);
        }
      }
      
      print('🗑️ Signed PreKey Store cleared for user: $_userId');
    } catch (e) {
      print('❌ Error clearing Signed PreKey Store: $e');
    }
  }
  
  /// دالة للحصول على عدد SignedPreKeys المحفوظة
  int getSignedPreKeysCount() {
    return _signedPreKeys.length;
  }
  
  /// دالة للحصول على userId الحالي
  String? get currentUserId => _userId;
}