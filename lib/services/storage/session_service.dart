import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _studentIdKey = 'student_id';
  static const _tokenKey = 'token';

  static Future<void> saveLogin(int studentId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_studentIdKey, studentId);
    await prefs.setString(_tokenKey, token);
  }

  static Future<int?> getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_studentIdKey);
  }

  static Future<bool> isLoggedIn() async {
    final studentId = await getStudentId();
    return studentId != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_studentIdKey);
    await prefs.remove(_tokenKey);
  }
}