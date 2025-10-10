import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';

class MySessionStore extends SessionStore {
  final FlutterSecureStorage _storage;
  final Map<String, SessionRecord> _sessions = {};

  MySessionStore(this._storage);

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
}