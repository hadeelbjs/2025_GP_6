import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';

class MySessionStore extends SessionStore {
  final FlutterSecureStorage _storage;
  final Map<String, SessionRecord> _sessions = {};
  final String? _userId;

  MySessionStore(this._storage, {String? userId}) : _userId = userId;

  Future<void> initialize() async {
    final allKeys = await _storage.readAll();
    
    for (var entry in allKeys.entries) {
      if (entry.key.startsWith('session_')) {
        try {
          final sessionBytes = base64Decode(entry.value);
          _sessions[entry.key.substring(8)] = SessionRecord.fromSerialized(sessionBytes);
        } catch (e) {
          print('Error loading session ${entry.key}: $e');
        }
      }
    }
  }

  String _getKey(SignalProtocolAddress address) {
    return '${address.getName()}.${address.getDeviceId()}';
  }

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final key = _getKey(address);
    
    if (_sessions.containsKey(key)) {
      return _sessions[key]!;
    }
    
    return SessionRecord();
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final devices = <int>[];
    
    for (var key in _sessions.keys) {
      if (key.startsWith('$name.')) {
        final deviceId = int.parse(key.split('.')[1]);
        devices.add(deviceId);
      }
    }
    
    return devices;
  }

  @override
  Future<void> storeSession(SignalProtocolAddress address, SessionRecord record) async {
    final key = _getKey(address);
    _sessions[key] = record;
    
    await _storage.write(
      key: 'session_$key',
      value: base64Encode(record.serialize()),
    );
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final key = _getKey(address);
    return _sessions.containsKey(key);
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    final key = _getKey(address);
    _sessions.remove(key);
    await _storage.delete(key: 'session_$key');
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    final keysToDelete = _sessions.keys
        .where((key) => key.startsWith('$name.'))
        .toList();
    
    for (var key in keysToDelete) {
      _sessions.remove(key);
      await _storage.delete(key: 'session_$key');
    }
  }
  Future<void> clearAll() async {
    try {
      final allKeys = await _storage.readAll();
      for (var key in allKeys.keys) {
        if (key.startsWith('session_')) {
          await _storage.delete(key: key);
        }
      }
      print('Session Store cleared');
    } catch (e) {
      print('Error clearing Session Store: $e');
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
    _sessions.clear();
    
    final allKeys = await _storage.readAll();
    final prefix = _userId != null ? '${_userId}_session_' : 'session_';
    
    for (var entry in allKeys.entries) {
      if (entry.key.startsWith(prefix)) {
        try {
          // استخراج مفتاح الـ session
          final sessionKey = entry.key.replaceFirst(prefix, '');
          
          final sessionBytes = base64Decode(entry.value);
          _sessions[sessionKey] = SessionRecord.fromSerialized(sessionBytes);
        } catch (e) {
          print('Error loading session ${entry.key}: $e');
        }
      }
    }
    
    print('✅ Loaded ${_sessions.length} Sessions for user: $_userId');
  }
  
  /// دالة محسّنة لحفظ Session مع دعم userId
  Future<void> storeSessionWithUserId(
    SignalProtocolAddress address,
    SessionRecord record,
  ) async {
    final key = _getKey(address);
    _sessions[key] = record;
    
    await _storage.write(
      key: _getStorageKey('session_$key'),
      value: base64Encode(record.serialize()),
    );
  }
  
  /// دالة محسّنة لحذف Session مع دعم userId
  Future<void> deleteSessionWithUserId(SignalProtocolAddress address) async {
    final key = _getKey(address);
    _sessions.remove(key);
    await _storage.delete(key: _getStorageKey('session_$key'));
  }
  
  /// دالة محسّنة لحذف جميع Sessions لمستخدم معين مع دعم userId
  Future<void> deleteAllSessionsWithUserId(String name) async {
    final keysToDelete = _sessions.keys
        .where((key) => key.startsWith('$name.'))
        .toList();
    
    for (var key in keysToDelete) {
      _sessions.remove(key);
      await _storage.delete(key: _getStorageKey('session_$key'));
    }
  }
  
  /// دالة محسّنة لحذف جميع Sessions مع دعم userId
  Future<void> clearAllWithUserId() async {
    try {
      _sessions.clear();
      
      final allKeys = await _storage.readAll();
      final prefix = _userId != null ? '${_userId}_session_' : 'session_';
      
      for (var key in allKeys.keys) {
        if (key.startsWith(prefix)) {
          await _storage.delete(key: key);
        }
      }
      
      print('🗑️ Session Store cleared for user: $_userId');
    } catch (e) {
      print('❌ Error clearing Session Store: $e');
    }
  }
  
  /// دالة للحصول على عدد Sessions المحفوظة
  int getSessionsCount() {
    return _sessions.length;
  }
  
  /// دالة للحصول على userId الحالي
  String? get currentUserId => _userId;
  
  /// دالة للحصول على جميع Sessions لمستخدم معين
  Future<List<String>> getAllSessionsForContact(String contactName) async {
    return _sessions.keys
        .where((key) => key.startsWith('$contactName.'))
        .toList();
  }
}