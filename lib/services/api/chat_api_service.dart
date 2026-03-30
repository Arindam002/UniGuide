import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/guest_service.dart';
import '../storage/session_service.dart';

class ChatApiService {
  final String baseUrl;

  ChatApiService({required this.baseUrl});

  Future<Map<String, dynamic>> sendMessage(String question) async {
    final int? studentId = await SessionService.getStudentId();
    final String? guestId =
        studentId == null ? await GuestService.getOrCreateGuestId() : null;

    final Map<String, dynamic> body = {
      "question": question,
    };

    if (studentId != null) {
      body["student_id"] = studentId;
    } else if (guestId != null) {
      body["guest_id"] = guestId;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/chat/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        throw Exception("Invalid response format from server");
      }
    } else {
      String errorMessage = "Failed to send message";

      try {
        final decodedError = jsonDecode(response.body);
        if (decodedError is Map<String, dynamic>) {
          errorMessage = decodedError["error"]?.toString() ??
              decodedError["message"]?.toString() ??
              response.body;
        } else {
          errorMessage = response.body;
        }
      } catch (_) {
        errorMessage = response.body;
      }

      throw Exception(errorMessage);
    }
  }
}