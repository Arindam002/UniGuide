import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ✅ Use your correct IP + port
  final String baseUrl = "http://10.199.157.23:5000";

  Future<String> getRAGResponse(String query) async {
    final uri = Uri.parse("$baseUrl/chat/");

    print("Calling API: $uri"); // 🔥 debug

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "question": query, // ✅ updated key
      }),
    );

    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // 🔥 handle flexible response
      return data["answer"] ??
             data["response"] ??
             data["result"] ??
             "⚠️ No valid response from backend";
    } else {
      throw Exception("Backend error: ${response.statusCode}");
    }
  }
}