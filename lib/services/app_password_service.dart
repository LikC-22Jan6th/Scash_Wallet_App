import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppPasswordService {
  static const String kSecPwdSalt = 'security_app_lock_salt';
  static const String kSecPwdHash = 'security_app_lock_hash';

  final FlutterSecureStorage _secure;

  AppPasswordService({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  Future<bool> hasPassword() async {
    final salt = await _secure.read(key: kSecPwdSalt);
    final hash = await _secure.read(key: kSecPwdHash);
    return (salt != null && salt.isNotEmpty && hash != null && hash.isNotEmpty);
  }

  /// 与 SetAppPasswordPage 完全一致：sha256(salt + utf8(password)) -> hex
  String hashPassword(String password, List<int> salt) {
    final bytes = <int>[...salt, ...utf8.encode(password)];
    return sha256.convert(bytes).toString(); // hex string
  }

  Future<bool> verify(String inputPassword) async {
    if (inputPassword.isEmpty) return false;

    final saltB64 = await _secure.read(key: kSecPwdSalt);
    final storedHash = await _secure.read(key: kSecPwdHash);
    if (saltB64 == null || storedHash == null) return false;

    final salt = base64Decode(saltB64);
    final inputHash = hashPassword(inputPassword, salt);

    return _constantTimeEquals(inputHash, storedHash);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= (a.codeUnitAt(i) ^ b.codeUnitAt(i));
    }
    return diff == 0;
  }
}
