// lib/services/crypto/stores/session_store.dart

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class MySessionStore extends SessionStore {
  final FlutterSecureStorage _storage;
  final Map<String, SessionRecord> _sessionsCache = {};
  final String? _userId;

  MySessionStore(this._storage, {String? userId}) : _userId = userId;

  // ========================================
  // ✅ دالة موحّدة لإنشاء مفاتيح التخزين
  // ========================================
  String _getStorageKey(String baseKey) {
    if (_userId != null) {
      return '${baseKey}_$_userId';
    }
    return baseKey;
  }
  
  // ========================================
  // ✅ دالة لإنشاء session key من address
  // ========================================
  String _getSessionKey(SignalProtocolAddress address) {
    return 'session_${address.getName()}_${address.getDeviceId()}';
  }

  // ========================================
  // ✅ التهيئة - موحّدة
  // ========================================
  Future<void> initialize() async {
    print('🔧 Initializing Session Store for user: $_userId');
    
    _sessionsCache.clear();
    
    final allKeys = await _storage.readAll();
    int loadedCount = 0;
    
    for (var entry in allKeys.entries) {
      if (entry.key.startsWith('session_')) {
        bool isForCurrentUser = false;
        String? sessionKey;
        
        if (_userId != null) {
          // مثال: session_alice_1_user456
          if (entry.key.endsWith('_$_userId')) {
            // استخراج session key الأصلي
            sessionKey = entry.key.substring(0, entry.key.lastIndexOf('_$_userId'));
            isForCurrentUser = true;
          }
        } else {
          // بدون userId: session_alice_1
          if (entry.key.split('_').length == 3) {
            sessionKey = entry.key;
            isForCurrentUser = true;
          }
        }
        
        if (!isForCurrentUser || sessionKey == null) continue;
        
        try {
          final recordBytes = base64Decode(entry.value);
          final record = SessionRecord.fromSerialized(recordBytes);
          
          _sessionsCache[sessionKey] = record;
          loadedCount++;
        } catch (e) {
          print('❌ Error loading session ${entry.key}: $e');
        }
      }
    }
    
    print('✅ Loaded $loadedCount Sessions for user: $_userId');
  }

  // ========================================
  // ✅ تحميل Session
  // ========================================
  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final sessionKey = _getSessionKey(address);
    
    // ✅ إذا موجود في الـ cache، نرجعه
    if (_sessionsCache.containsKey(sessionKey)) {
      return _sessionsCache[sessionKey]!;
    }
    
    // ✅ إذا مو موجود، نرجع session جديد فاضي
    return SessionRecord();
  }

  // ========================================
  // ✅ تحميل جميع Sub-Device Sessions
  // ========================================
  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final deviceIds = <int>[];
    
    for (var key in _sessionsCache.keys) {
      if (key.startsWith('session_$name')) {
        final parts = key.split('_');
        if (parts.length >= 3) {
          final deviceId = int.tryParse(parts[2]);
          if (deviceId != null) {
            deviceIds.add(deviceId);
          }
        }
      }
    }
    
    return deviceIds;
  }

  // ========================================
  // ✅ حفظ Session - موحّدة
  // ========================================
  @override
  Future<void> storeSession(
    SignalProtocolAddress address,
    SessionRecord record,
  ) async {
    final sessionKey = _getSessionKey(address);
    _sessionsCache[sessionKey] = record;
    
    final serialized = record.serialize();
    final base64Value = base64Encode(serialized);
    
    final storageKey = _getStorageKey(sessionKey);
    await _storage.write(key: storageKey, value: base64Value);
    
    print('✅ Session saved: ${address.getName()} (device ${address.getDeviceId()}) -> $storageKey');
  }

  // ========================================
  // ✅ التحقق من وجود Session
  // ========================================
  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final sessionKey = _getSessionKey(address);
    return _sessionsCache.containsKey(sessionKey);
  }

  // ========================================
  // ✅ حذف Session - موحّدة
  // ========================================
  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    final sessionKey = _getSessionKey(address);
    _sessionsCache.remove(sessionKey);
    
    final storageKey = _getStorageKey(sessionKey);
    await _storage.delete(key: storageKey);
    
    print('🗑️ Session deleted: ${address.getName()} (device ${address.getDeviceId()}) from $storageKey');
  }

  // ========================================
  // ✅ حذف جميع Sessions لمستخدم معين
  // ========================================
  @override
  Future<void> deleteAllSessions(String name) async {
    final keysToRemove = <String>[];
    
    for (var key in _sessionsCache.keys) {
      if (key.startsWith('session_$name')) {
        keysToRemove.add(key);
      }
    }
    
    for (var key in keysToRemove) {
      _sessionsCache.remove(key);
      
      final storageKey = _getStorageKey(key);
      await _storage.delete(key: storageKey);
    }
    
    print('🗑️ Deleted ${keysToRemove.length} sessions for: $name');
  }

  // ========================================
  // ✅ حذف جميع Sessions
  // ========================================
  Future<void> clearAll() async {
    try {
      print('🗑️ Clearing Session Store for user: $_userId');
      
      _sessionsCache.clear();
      
      final allKeys = await _storage.readAll();
      int deletedCount = 0;
      
      for (var key in allKeys.keys) {
        if (key.startsWith('session_')) {
          if (_userId != null && key.endsWith('_$_userId')) {
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
      
      print('✅ Session Store cleared (deleted $deletedCount sessions)');
    } catch (e) {
      print('❌ Error clearing Session Store: $e');
      rethrow;
    }
  }

  // ========================================
  // ✅ دوال مساعدة
  // ========================================
  
  int getSessionsCount() {
    return _sessionsCache.length;
  }
  
  String? get currentUserId => _userId;
  
  List<String> getSessionKeys() {
    return _sessionsCache.keys.toList()..sort();
  }
  
  /// الحصول على قائمة بجميع المستخدمين الذين لديهم sessions
  List<String> getSessionUserNames() {
    final names = <String>{};
    
    for (var key in _sessionsCache.keys) {
      final parts = key.split('_');
      if (parts.length >= 3) {
        names.add(parts[1]); // اسم المستخدم
      }
    }
    
    return names.toList()..sort();
  }
  
  Future<void> debugPrintAllKeys() async {
    print('\n🔍 === DEBUG: All Sessions for User $_userId ===');
    
    final allKeys = await _storage.readAll();
    int count = 0;
    
    print('📦 Cached Sessions (in memory):');
    final sortedKeys = getSessionKeys();
    for (var key in sortedKeys) {
      print('  ✅ $key');
    }
    print('  Total in cache: ${_sessionsCache.length}');
    
    print('\n💾 Stored Sessions (on disk):');
    for (var key in allKeys.keys) {
      if (key.startsWith('session_')) {
        if (_userId != null && key.endsWith('_$_userId')) {
          print('  ✅ $key');
          count++;
        } else if (_userId == null) {
          final parts = key.split('_');
          if (parts.length == 3) {
            print('  ✅ $key');
            count++;
          }
        }
      }
    }
    print('  Total on disk: $count');
    
    if (_sessionsCache.length != count) {
      print('\n⚠️ WARNING: Cache and disk counts do not match!');
    }
    
    print('\n👥 Users with sessions:');
    final users = getSessionUserNames();
    for (var user in users) {
      final devices = await getSubDeviceSessions(user);
      print('  📱 $user: ${devices.length} device(s)');
    }
    
    print('===============================================\n');
  }
  
  /// التحقق من وجود session صالح مع مستخدم معين
  Future<bool> hasValidSessionWith(String userName) async {
    final devices = await getSubDeviceSessions(userName);
    return devices.isNotEmpty;
  }
  
  /// الحصول على تفاصيل session
  Future<Map<String, dynamic>?> getSessionInfo(SignalProtocolAddress address) async {
    final record = await loadSession(address);
    if (record == null) return null;
    
    // ✅ التحقق من وجود session صالح عن طريق محاولة الوصول للـ session state
    bool hasValidSession = false;
    try {
      final sessionState = record.sessionState;
      hasValidSession = sessionState != null;
    } catch (e) {
      hasValidSession = false;
    }
    
    return {
      'name': address.getName(),
      'deviceId': address.getDeviceId(),
      'hasValidSession': hasValidSession,
    };
  }
}