// lib/services/crypto/stores/pre_key_store.dart

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class MyPreKeyStore extends PreKeyStore {
  final FlutterSecureStorage _storage;
  final Map<int, PreKeyRecord> _preKeysCache = {};
  final String? _userId;

  MyPreKeyStore(this._storage, {String? userId}) : _userId = userId;

  // ========================================
  // ✅ دالة موحّدة لإنشاء مفاتيح التخزين
  // ========================================
  String _getStorageKey(String key) {
    if (_userId != null) {
      return '${_userId}_$key';
    }
    return key;
  }

  // ========================================
  // ✅ التهيئة - موحّدة ومُصلحة
  // ========================================
  Future<void> initialize() async {
    print('🔧 Initializing PreKey Store for user: $_userId');
    
    _preKeysCache.clear();
    
    final allKeys = await _storage.readAll();
    int loadedCount = 0;
    
    for (var entry in allKeys.entries) {
      // ✅ البحث عن المفاتيح التي تبدأ بـ prekey_
      if (entry.key.contains('prekey_')) {
        bool isForCurrentUser = false;
        int? preKeyId;
        
        if (_userId != null) {
          // مثال: user456_prekey_123
          if (entry.key.startsWith('${_userId}_prekey_')) {
            final parts = entry.key.split('_');
            if (parts.length >= 3) {
              preKeyId = int.tryParse(parts[2]); // ✅ تصحيح: parts[2] بدلاً من parts[1]
              isForCurrentUser = true;
            }
          }
        } else {
          // بدون userId: prekey_123
          final parts = entry.key.split('_');
          if (parts.length == 2) {
            preKeyId = int.tryParse(parts[1]);
            isForCurrentUser = true;
          }
        }
        
        if (!isForCurrentUser || preKeyId == null) continue;
        
        try {
          final data = jsonDecode(entry.value);
          
          final publicKeyBytes = base64Decode(data['public']);
          final privateKeyBytes = base64Decode(data['private']);

          final publicKey = Curve.decodePoint(publicKeyBytes, 0);
          final privateKey = Curve.decodePrivatePoint(privateKeyBytes);
          
          final keyPair = ECKeyPair(publicKey, privateKey);
          
          _preKeysCache[preKeyId] = PreKeyRecord(preKeyId, keyPair);
          loadedCount++;
        } catch (e) {
          print('❌ Error loading prekey ${entry.key}: $e');
        }
      }
    }
    
    print('✅ Loaded $loadedCount PreKeys for user: $_userId');
  }

  // ========================================
  // ✅ تحميل PreKey
  // ========================================
  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    if (!_preKeysCache.containsKey(preKeyId)) {
      throw InvalidKeyIdException('PreKey $preKeyId not found for user: $_userId');
    }
    return _preKeysCache[preKeyId]!;
  }

  // ========================================
  // ✅ حفظ PreKey - موحّدة
  // ========================================
  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    _preKeysCache[preKeyId] = record;
    
    final data = jsonEncode({
      'public': base64Encode(record.getKeyPair().publicKey.serialize()),
      'private': base64Encode(record.getKeyPair().privateKey.serialize()),
    });
    
    final storageKey = _getStorageKey('prekey_$preKeyId');
    await _storage.write(key: storageKey, value: data);
    
    print('✅ PreKey $preKeyId saved to: $storageKey');
  }

  // ========================================
  // ✅ التحقق من وجود PreKey
  // ========================================
  @override
  Future<bool> containsPreKey(int preKeyId) async {
    return _preKeysCache.containsKey(preKeyId);
  }

  // ========================================
  // ✅ حذف PreKey - موحّدة
  // ========================================
  @override
  Future<void> removePreKey(int preKeyId) async {
    _preKeysCache.remove(preKeyId);
    
    final storageKey = _getStorageKey('prekey_$preKeyId');
    await _storage.delete(key: storageKey);
    
    print('🗑️ PreKey $preKeyId removed from: $storageKey');
  }

  // ========================================
  // ✅ حذف جميع PreKeys - مُصلحة
  // ========================================
  Future<void> clearAll() async {
    try {
      print('🗑️ Clearing PreKey Store for user: $_userId');
      
      _preKeysCache.clear();
      
      final allKeys = await _storage.readAll();
      int deletedCount = 0;
      
      for (var key in allKeys.keys) {
        if (key.startsWith('prekey_')) {
          if (_userId != null && key.startsWith('${_userId}_prekey_')) {
            await _storage.delete(key: key);
            deletedCount++;
          } else if (_userId == null) {
            final parts = key.split('_');
            if (parts.length == 2) {
              await _storage.delete(key: key);
              deletedCount++;
            }
          }
        }
      }
      
      print('✅ PreKey Store cleared (deleted $deletedCount keys)');
    } catch (e) {
      print('❌ Error clearing PreKey Store: $e');
      rethrow;
    }
  }

  // ========================================
  // ✅ دوال مساعدة
  // ========================================
  
  int getPreKeysCount() {
    return _preKeysCache.length;
  }
  
  String? get currentUserId => _userId;
  
  List<int> getPreKeyIds() {
    return _preKeysCache.keys.toList()..sort();
  }
  
  Future<void> debugPrintAllKeys() async {
    print('\n🔍 === DEBUG: All PreKeys for User $_userId ===');
    
    final allKeys = await _storage.readAll();
    int count = 0;
    
    print('📦 Cached PreKeys (in memory):');
    final sortedIds = getPreKeyIds();
    for (var id in sortedIds) {
      print('  ✅ PreKey $id');
    }
    print('  Total in cache: ${_preKeysCache.length}');
    
    print('\n💾 Stored PreKeys (on disk):');
    for (var key in allKeys.keys) {
      if (key.startsWith('prekey_')) {
        if (_userId != null && key.startsWith('${_userId}_prekey_')) {
          print('  ✅ $key');
          count++;
        } else if (_userId == null) {
          final parts = key.split('_');
          if (parts.length == 2) {
            print('  ✅ $key');
            count++;
          }
        }
      }
    }
    print('  Total on disk: $count');
    
    if (_preKeysCache.length != count) {
      print('\n⚠️ WARNING: Cache and disk counts do not match!');
    }
    
    print('================================================\n');
  }
  
  /// حفظ PreKeys بشكل جماعي (batch save)
  Future<void> storePreKeys(List<PreKeyRecord> records) async {
    for (var record in records) {
      await storePreKey(record.id, record);
    }
    print('✅ Stored ${records.length} PreKeys for user: $_userId');
  }
  
  /// حذف PreKeys بشكل جماعي (batch delete)
  Future<void> removePreKeys(List<int> preKeyIds) async {
    for (var id in preKeyIds) {
      await removePreKey(id);
    }
    print('🗑️ Removed ${preKeyIds.length} PreKeys for user: $_userId');
  }
  
  /// التحقق من وجود PreKeys كافية
  Future<bool> hasEnoughPreKeys({int minRequired = 20}) async {
    return _preKeysCache.length >= minRequired;
  }
  
  /// الحصول على PreKey IDs المتاحة
  Future<List<int>> getAvailablePreKeyIds() async {
    return getPreKeyIds();
  }
}