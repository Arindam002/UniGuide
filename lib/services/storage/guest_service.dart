import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class GuestService {
  static const String _guestIdKey = 'guest_id';

  static Future<String> getOrCreateGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    String? guestId = prefs.getString(_guestIdKey);

    if (guestId == null || guestId.isEmpty) {
      guestId = const Uuid().v4();
      await prefs.setString(_guestIdKey, guestId);
    }

    return guestId;
  }

  static Future<String?> getGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_guestIdKey);
  }
}