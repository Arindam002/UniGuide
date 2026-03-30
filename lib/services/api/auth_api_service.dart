import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/session_service.dart';

class AuthApiService {
  final String baseUrl;

  AuthApiService({required this.baseUrl});

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/students/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data["student"] != null && data["token"] != null) {
        await SessionService.saveLogin(
          data["student"]["id"],
          data["token"],
        );
      }

      return data;
    } else {
      return null;
    }
  }

  Future<Map<String, dynamic>?> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/students/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      // If backend returns token + student on signup, auto-save session
      if (data["student"] != null && data["token"] != null) {
        await SessionService.saveLogin(
          data["student"]["id"],
          data["token"],
        );
      }

      return data;
    } else {
      return null;
    }
  }

  Future<void> logout() async {
    await SessionService.logout();
  }
}