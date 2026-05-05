// LocaleStorage — persists the chosen language code so the user's pick survives app restart.
// Backed by SharedPreferences (low-sensitivity setting; no need for the secure keystore used by JWT tokens).
import 'package:shared_preferences/shared_preferences.dart';


class LocaleStorage {
  static const _key = 'app_locale';

  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);
  Future<void> write(String code) async => (await SharedPreferences.getInstance()).setString(_key, code);
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}
