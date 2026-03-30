import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/session_service.dart';

class HistoryApiService {
  final String baseUrl;

  HistoryApiService({required this.baseUrl});

  Future<List<dynamic>> fetchHistory() async {
    final studentId = await SessionService.getStudentId();

    if (studentId == null) {
      return [];
    }

    final response = await http.get(
      Uri.parse("$baseUrl/students/history/$studentId"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        return data;
      }

      if (data is Map<String, dynamic> && data["history"] is List) {
        return data["history"];
      }

      return [];
    } else {
      throw Exception("Failed to load history: ${response.statusCode}");
    }
  }

  Future<void> deleteHistory(int id) async {
    final studentId = await SessionService.getStudentId();

    if (studentId == null) {
      throw Exception("User not logged in");
    }

    final response = await http.delete(
      Uri.parse("$baseUrl/students/history/$studentId/$id"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete history");
    }
  }
}