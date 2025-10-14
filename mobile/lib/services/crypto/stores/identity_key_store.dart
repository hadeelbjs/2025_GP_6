//لتنظيم واستخراج مفاتيح الهوية المستخدمة في بروتوكول Signal Public & Private Keys
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class MyIdentityKeyStore extends IdentityKeyStore {
  final FlutterSecureStorage _storage;
  IdentityKeyPair? _identityKeyPair;
  int? _localRegistrationId;
  MyIdentityKeyStore(this._storage);

  Future<void> initialize() async {
    final identityKeyData = await _storage.read(key: 'identity_key');
    if (identityKeyData != null) {
      final data = jsonDecode(identityKeyData);
      _identityKeyPair = IdentityKeyPair(
        IdentityKey.fromBytes(base64Decode(data['public']), 0),
        DjbECPrivateKey(base64Decode(data['private'])),
      );
    }
    final regId = await _storage.read(key: 'registration_id');
    if (regId != null) {
      _localRegistrationId = int.parse(regId);
    }
  }

  Future<void> saveIdentityKeyPair(IdentityKeyPair keyPair) async {
    _identityKeyPair = keyPair;
    final data = jsonEncode({
      'public': base64Encode(keyPair.getPublicKey().serialize()),
      'private': base64Encode(keyPair.getPrivateKey().serialize()),
    });
    await _storage.write(key: 'identity_key', value: data);
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
    if (identityKey == null) return false;
    final key = 'identity_${address.getName()}_${address.getDeviceId()}';
    await _storage.write(
      key: key,
      value: base64Encode(identityKey.serialize()),
    );
    return true;
  }

  @override
Future<bool> isTrustedIdentity(
  SignalProtocolAddress address,
  IdentityKey? identityKey,
  Direction direction,
) async {
  if (identityKey == null) return false;
  
  // جلب المفتاح المحفوظ مسبقاً
  final saved = await getIdentity(address);
  
  // إذا ما فيه مفتاح محفوظ، نستخدم الجديد
  if (saved == null) return true;
  
  // مقارنة المفاتيح للانتباه في حال تغير المفتاح
  return saved.serialize().toString() == identityKey.serialize().toString();
}

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final key = 'identity_${address.getName()}_${address.getDeviceId()}';
    final data = await _storage.read(key: key);
    if (data == null) return null;
    return IdentityKey.fromBytes(base64Decode(data), 0);
  }
}
