import 'package:hive/hive.dart';

class AuthSessionService {
  static const String boxName = 'auth_session';
  static const String rememberedUsernameKey = 'remembered_username';

  Box<dynamic> get _box => Hive.box<dynamic>(boxName);

  String? getRememberedUsername() {
    final value = _box.get(rememberedUsernameKey);
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  Future<void> saveRememberedUsername(String username) async {
    await _box.put(rememberedUsernameKey, username.trim());
  }

  Future<void> clearRememberedUsername() async {
    await _box.delete(rememberedUsernameKey);
  }
}
