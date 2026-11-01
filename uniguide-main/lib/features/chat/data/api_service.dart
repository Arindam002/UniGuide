import 'dart:async';
import 'dart:convert';
import '../../../services/storage/guest_service.dart';
import 'package:http/http.dart' as http;
import '../../../services/storage/session_service.dart';
import '../../../core/app_config.dart';
import 'message_model.dart';

class ChatApiResponse {
  final String answer;
  final List<String> sources;
  final ChatDiagram? diagram;

  const ChatApiResponse({
    required this.answer,
    required this.sources,
    this.diagram,
  });
}

class ApiService {
  String get baseUrl => AppConfig.baseUrl;

  Future<ChatApiResponse> getRAGResponse(String query) async {
    final uri = Uri.parse('$baseUrl/chat/');

    try {
      final studentId = await SessionService.getStudentId();

      final guestId =
          studentId == null ? await GuestService.getOrCreateGuestId() : null;

      final body = {
        'question': query,
        'student_id': studentId,
        'guest_id': guestId,
      };

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'Backend response must be a JSON object.',
          );
        }
        final data = decoded;

        final rawSources = data['sources'];
        final rawDiagram = data['diagram'];

        return ChatApiResponse(
          answer: data['answer'] is String
              ? data['answer'] as String
              : data['response'] is String
                  ? data['response'] as String
                  : data['result'] is String
                      ? data['result'] as String
                      : 'No valid response from backend',
          sources: rawSources is List
              ? rawSources.map((source) => source.toString()).toList()
              : const [],
          diagram: rawDiagram is Map<String, dynamic>
              ? ChatDiagram.fromJson(rawDiagram)
              : rawDiagram is Map
                  ? ChatDiagram.fromJson(Map<String, dynamic>.from(rawDiagram))
                  : null,
        );
      }

      throw Exception(
        'Backend returned ${response.statusCode} at $uri.\n'
        'Response body: ${response.body}',
      );
    } on http.ClientException {
      throw Exception(
        'Cannot reach backend at $baseUrl.\n\n'
        'Run Flask like this:\n'
        'flask run --host=0.0.0.0 --port=5000\n\n'
        'Then run Flutter:\n'
        'flutter run --dart-define=API_HOST=10.234.183.23:5000',
      );
    } on TimeoutException {
      throw Exception(
        'Backend request timed out at $uri.\n'
        'Flask may be running but taking too long to answer.',
      );
    } on FormatException {
      throw Exception(
        'Backend response was not valid JSON from $uri.',
      );
    } catch (e) {
      throw Exception(
        'Unexpected API error:\n$e',
      );
    }
  }
}
