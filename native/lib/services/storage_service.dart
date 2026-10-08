import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static const _browserIdKey = 'browserId';

  static Future<String> getBrowserId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_browserIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_browserIdKey, id);
    }
    return id;
  }
}
