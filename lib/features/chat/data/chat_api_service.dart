import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ChatApiService {

  /// 🔥 BASE URL HANDLING
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Emulator uses special localhost mapping
      return "http://10.0.2.2:5000";
    }
    // Physical device / desktop
    return "http://10.188.239.23:5000";
  }

  /// 🔥 MAIN API CALL
  Future<String> getRAGResponse(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/ask');

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "question": query,   // ✅ IMPORTANT: match backend key
        }),
      ).timeout(const Duration(seconds: 30));

      /// ✅ SUCCESS
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 🔥 Handle multiple possible keys safely
        return data['answer'] ??
               data['response'] ??
               data['result'] ??
               "⚠️ No valid response from backend.";
      }

      /// ❌ SERVER ERROR
      return "❌ Server Error (${response.statusCode}). Check backend logs.";

    } on SocketException {
      return "❌ Connection Error: Backend not reachable.\n"
             "✔ Ensure FastAPI is running on 0.0.0.0:5000\n"
             "✔ Check IP address";

    } on HttpException {
      return "❌ HTTP Error occurred.";

    } on FormatException {
      return "❌ Invalid JSON response from backend.";

    } catch (e) {
      return "❌ Unexpected error: $e";
    }
  }
}