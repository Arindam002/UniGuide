import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _studentIdKey = 'student_id';
  static const _tokenKey = 'token';

  /// ✅ Save session (used by API)
  static Future<void> saveSession(int studentId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_studentIdKey, studentId);
    await prefs.setString(_tokenKey, token);
  }

  /// ✅ Keep old method (optional, backward compatibility)
  static Future<void> saveLogin(int studentId, String token) async {
    await saveSession(studentId, token);
  }

  /// ✅ Get student ID
  static Future<int?> getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_studentIdKey);
  }

  /// ✅ Get token (useful for future APIs)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// ✅ Check login status
  static Future<bool> isLoggedIn() async {
    final studentId = await getStudentId();
    return studentId != null;
  }

  /// ✅ Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_studentIdKey);
    await prefs.remove(_tokenKey);
  }
}