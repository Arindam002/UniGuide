import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:uniguide/core/app_config.dart';
import 'package:uniguide/features/chat/data/chat_storage_service.dart';

class ApiService {
  final String baseUrl = AppConfig.baseUrl;
  final ChatStorageService _chatStorageService = ChatStorageService();

  Future<String> getRAGResponse(String query) async {
    final uri = Uri.parse("$baseUrl/chat/");
    final anonymousClientId =
        await _chatStorageService.getOrCreateAnonymousClientId();

    final body = {
      "question": query,
      "guest_id": anonymousClientId,
    };

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["answer"] ??
          data["response"] ??
          data["result"] ??
          "⚠️ No valid response from backend";
    } else {
      throw Exception(
        "Backend error: ${response.statusCode} ${response.body}",
      );
    }
  }
}
