import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app_config.dart';
import 'message_model.dart';

class ChatStorageService {
  static const String _sessionsKey = 'chat_sessions';
  static const String _activeChatIdKey = 'active_chat_id';
  static const String _anonymousClientIdKey = 'anonymous_client_id';

  List<ChatSession> limitSessions(List<ChatSession> sessions) {
    final ordered = List<ChatSession>.from(sessions)
      ..sort((a, b) {
        final updatedComparison = b.updatedAt.compareTo(a.updatedAt);
        if (updatedComparison != 0) return updatedComparison;
        return b.createdAt.compareTo(a.createdAt);
      });
    return ordered.take(kMaxStoredChats).toList();
  }

  Future<List<ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        await prefs.remove(_sessionsKey);
        await prefs.remove(_activeChatIdKey);
        return [];
      }

      final sessions = decoded
          .whereType<Map>()
          .map(
            (session) => ChatSession.fromJson(
              Map<String, dynamic>.from(session),
            ),
          )
          .toList();
      final limitedSessions = limitSessions(sessions);
      if (limitedSessions.length != sessions.length) {
        await saveSessions(
          sessions: limitedSessions,
          activeChatId: prefs.getString(_activeChatIdKey),
        );
      }
      return limitedSessions;
    } on FormatException {
      await prefs.remove(_sessionsKey);
      await prefs.remove(_activeChatIdKey);
      return [];
    } catch (_) {
      await prefs.remove(_sessionsKey);
      await prefs.remove(_activeChatIdKey);
      return [];
    }
  }

  Future<String?> loadActiveChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeChatIdKey);
  }

  Future<void> saveSessions({
    required List<ChatSession> sessions,
    required String? activeChatId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final limitedSessions = limitSessions(sessions);
    final storedActiveChatId = limitedSessions.any(
      (session) => session.id == activeChatId,
    )
        ? activeChatId
        : limitedSessions.isEmpty
            ? null
            : limitedSessions.first.id;

    await prefs.setString(
      _sessionsKey,
      jsonEncode(
        limitedSessions.map((session) => session.toJson()).toList(),
      ),
    );

    if (storedActiveChatId == null) {
      await prefs.remove(_activeChatIdKey);
    } else {
      await prefs.setString(_activeChatIdKey, storedActiveChatId);
    }
  }

  Future<String> getOrCreateAnonymousClientId() async {
    final prefs = await SharedPreferences.getInstance();
    final existingId = prefs.getString(_anonymousClientIdKey);
    if (existingId != null && existingId.isNotEmpty) return existingId;

    final id = const Uuid().v4();
    await prefs.setString(_anonymousClientIdKey, id);
    return id;
  }
}
