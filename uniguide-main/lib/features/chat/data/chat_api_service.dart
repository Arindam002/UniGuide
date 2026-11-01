import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatApiService {
  static const String _apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '10.234.183.23:5000',
  );

  static String get baseUrl => 'http://$_apiHost';

  Future<String> getRAGResponse(
    String query, {
    String guestId = "guest_001",
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/chat/');

      final response = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "question": query,
              "guest_id": guestId,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return data['answer'] ??
            data['response'] ??
            data['result'] ??
            "⚠️ Backend returned empty response.";
      }

      if (response.statusCode == 400) {
        return "❌ Bad Request (400)\nCheck backend JSON keys and route.";
      }

      if (response.statusCode >= 500) {
        return "❌ Backend Server Error (${response.statusCode})";
      }

      return "❌ Request Failed (${response.statusCode})";
    } on http.ClientException catch (e) {
      return "❌ Client Error:\n$e";
    } on FormatException {
      return "❌ Invalid JSON returned from backend.";
    } catch (e) {
      return "❌ Cannot connect to backend.\n\n"
          "Backend URL: $baseUrl\n\n"
          "✔ Ensure Flask is running\n"
          "✔ Run Flask with host='0.0.0.0'\n"
          "✔ Check IP address\n"
          "✔ Check firewall\n\n"
          "Error: $e";
    }
  }
}