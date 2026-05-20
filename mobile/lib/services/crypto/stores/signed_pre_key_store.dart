// lib/services/crypto/stores/signed_pre_key_store.dart

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:fixnum/fixnum.dart';

class MySignedPreKeyStore extends SignedPreKeyStore {
  final FlutterSecureStorage _storage;
  final Map<int, SignedPreKeyRecord> _signedPreKeysCache = {};
  final String? _userId;

  MySignedPreKeyStore(this._storage, {String? userId}) : _userId = userId;

  // ========================================
  //  دالة موحّدة لإنشاء مفاتيح التخزين
  // ========================================
  String _getStorageKey(String key) {
    if (_userId != null) {
      return '${_userId}_$key';
    }
    return key;
  }

  // ========================================
  // التهيئة - موحّدة ومُصلحة
  // ========================================
  Future<void> initialize() async {
    print('🔧 Initializing SignedPreKey Store for user: $_userId');

    _signedPreKeysCache.clear();

    final allKeys = await _storage.readAll();
    int loadedCount = 0;

    for (var entry in allKeys.entries) {
      if (entry.key.contains('signed_prekey_')) {
        bool isForCurrentUser = false;
        int? signedPreKeyId;

        if (_userId != null) {
          // مثال: user456_signed_prekey_1
          if (entry.key.startsWith('${_userId}_signed_prekey_')) {
            final parts = entry.key.split('_');
            if (parts.length >= 4) {
              signedPreKeyId = int.tryParse(parts[3]);
              isForCurrentUser = true;
            }
          }
        } else {
          // بدون userId: signed_prekey_1
          final parts = entry.key.split('_');
          if (parts.length == 3) {
            signedPreKeyId = int.tryParse(parts[2]);
            isForCurrentUser = true;
          }
        }

        if (!isForCurrentUser || signedPreKeyId == null) continue;

        try {
          final data = jsonDecode(entry.value);

          final publicKeyBytes = base64Decode(data['public']);
          final privateKeyBytes = base64Decode(data['private']);
          final signatureBytes = base64Decode(data['signature']);

          //  معالجة timestamp - يدعم int و Int64
          final timestampValue = data['timestamp'];
          final timestamp = timestampValue is Int64
              ? timestampValue
              : Int64(timestampValue as int);

          final publicKey = Curve.decodePoint(publicKeyBytes, 0);
          final privateKey = Curve.decodePrivatePoint(privateKeyBytes);

          final keyPair = ECKeyPair(publicKey, privateKey);

          _signedPreKeysCache[signedPreKeyId] = SignedPreKeyRecord(
            signedPreKeyId,
            timestamp,
            keyPair,
            signatureBytes,
          );
          loadedCount++;
        } catch (e) {
          print(' Error loading signed prekey ${entry.key}: $e');
        }
      }
    }

    print('Loaded $loadedCount SignedPreKeys for user: $_userId');
  }

  // ========================================
  //  تحميل SignedPreKey
  // ========================================
  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    if (!_signedPreKeysCache.containsKey(signedPreKeyId)) {
      throw InvalidKeyIdException(
        'SignedPreKey $signedPreKeyId not found for user: $_userId',
      );
    }
    return _signedPreKeysCache[signedPreKeyId]!;
  }

  // ========================================
  // تحميل جميع SignedPreKeys
  // ========================================
  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    return _signedPreKeysCache.values.toList();
  }

  // ========================================
  //  حفظ SignedPreKey - موحّدة
  // ========================================
  @override
  Future<void> storeSignedPreKey(
    int signedPreKeyId,
    SignedPreKeyRecord record,
  ) async {
    _signedPreKeysCache[signedPreKeyId] = record;

    //  تحويل Int64 إلى int عند الحفظ
    final data = jsonEncode({
      'public': base64Encode(record.getKeyPair().publicKey.serialize()),
      'private': base64Encode(record.getKeyPair().privateKey.serialize()),
      'signature': base64Encode(record.signature),
      'timestamp': record.timestamp.toInt(), // Int64 → int
    });

    final storageKey = _getStorageKey('signed_prekey_$signedPreKeyId');
    await _storage.write(key: storageKey, value: data);

    print(' SignedPreKey $signedPreKeyId saved to: $storageKey');
  }

  // ========================================
  //  التحقق من وجود SignedPreKey
  // ========================================
  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    return _signedPreKeysCache.containsKey(signedPreKeyId);
  }

  // ========================================
  //  حذف SignedPreKey - موحّدة
  // ========================================
  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    _signedPreKeysCache.remove(signedPreKeyId);

    final storageKey = _getStorageKey('signed_prekey_$signedPreKeyId');
    await _storage.delete(key: storageKey);

    print(' SignedPreKey $signedPreKeyId removed from: $storageKey');
  }

  // ========================================
  //  حذف جميع SignedPreKeys - مُصلحة
  // ========================================
  Future<void> clearAll() async {
    try {
      print(' Clearing SignedPreKey Store for user: $_userId');

      _signedPreKeysCache.clear();

      final allKeys = await _storage.readAll();
      int deletedCount = 0;

      for (var key in allKeys.keys) {
        if (key.startsWith('signed_prekey_')) {
          if (_userId != null && key.startsWith('${_userId}_signed_prekey_')) {
            await _storage.delete(key: key);
            deletedCount++;
          } else if (_userId == null) {
            final parts = key.split('_');
            if (parts.length == 3) {
              await _storage.delete(key: key);
              deletedCount++;
            }
          }
        }
      }

      print(' SignedPreKey Store cleared (deleted $deletedCount keys)');
    } catch (e) {
      print(' Error clearing SignedPreKey Store: $e');
      rethrow;
    }
  }

  // ========================================
  //  دوال مساعدة
  // ========================================

  int getSignedPreKeysCount() {
    return _signedPreKeysCache.length;
  }

  String? get currentUserId => _userId;

  List<int> getSignedPreKeyIds() {
    return _signedPreKeysCache.keys.toList()..sort();
  }

  Future<void> debugPrintAllKeys() async {
    print('\n === DEBUG: All SignedPreKeys for User $_userId ===');

    final allKeys = await _storage.readAll();
    int count = 0;

    print(' Cached SignedPreKeys (in memory):');
    final sortedIds = getSignedPreKeyIds();
    for (var id in sortedIds) {
      final record = _signedPreKeysCache[id]!;
      print('   SignedPreKey $id (timestamp: ${record.timestamp})');
    }
    print('  Total in cache: ${_signedPreKeysCache.length}');

    print('\nStored SignedPreKeys (on disk):');
    for (var key in allKeys.keys) {
      if (key.startsWith('signed_prekey_')) {
        if (_userId != null && key.startsWith('${_userId}_signed_prekey_')) {
          print('   $key');
          count++;
        } else if (_userId == null) {
          final parts = key.split('_');
          if (parts.length == 3) {
            print('   $key');
            count++;
          }
        }
      }
    }
    print('  Total on disk: $count');

    if (_signedPreKeysCache.length != count) {
      print('\n WARNING: Cache and disk counts do not match!');
    }

    print('======================================================\n');
  }

  /// الحصول على أحدث SignedPreKey
  SignedPreKeyRecord? getLatestSignedPreKey() {
    if (_signedPreKeysCache.isEmpty) return null;

    return _signedPreKeysCache.values.reduce((a, b) {
      return a.timestamp > b.timestamp ? a : b;
    });
  }

  /// حذف SignedPreKeys القديمة (الاحتفاظ بآخر N)
  Future<void> cleanupOldSignedPreKeys({int keepLast = 3}) async {
    final sortedRecords = _signedPreKeysCache.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (sortedRecords.length <= keepLast) {
      print(' No old SignedPreKeys to cleanup');
      return;
    }

    final toRemove = sortedRecords.skip(keepLast).toList();

    for (var record in toRemove) {
      await removeSignedPreKey(record.id);
    }

    print(' Cleaned up ${toRemove.length} old SignedPreKeys');
  }
}
