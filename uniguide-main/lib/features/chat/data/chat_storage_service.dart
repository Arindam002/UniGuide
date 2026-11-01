import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'message_model.dart';

class ChatStorageService {
  static const String _sessionsKey = 'chat_sessions';
  static const String _activeChatIdKey = 'active_chat_id';
  static const String _accountsKey = 'chat_accounts';
  static const String _currentUserKey = 'chat_current_user';
  static const String guestUserId = 'guest';

  String _userSessionsKey(String userId) => '${_sessionsKey}_$userId';
  String _userActiveChatIdKey(String userId) => '${_activeChatIdKey}_$userId';

  String userIdForName(String name) {
    final cleaned = name.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '_',
        );
    return cleaned.isEmpty ? guestUserId : cleaned;
  }

  Future<ChatUser> loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentUserKey);
    if (raw == null || raw.isEmpty) {
      return const ChatUser.guest();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ChatUser.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      await prefs.remove(_currentUserKey);
    } on TypeError {
      await prefs.remove(_currentUserKey);
    }

    if (prefs.getString(_currentUserKey) == raw) {
      await prefs.remove(_currentUserKey);
    }
    return const ChatUser.guest();
  }

  Future<void> saveCurrentUser(ChatUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _currentUserKey,
      jsonEncode(const ChatUser.guest().toJson()),
    );
  }

  Future<LoginResult> loginOrCreateUser({
    required String name,
    required String password,
  }) async {
    final trimmedName = name.trim();
    final trimmedPassword = password.trim();
    if (trimmedName.isEmpty || trimmedPassword.isEmpty) {
      return const LoginResult(
        success: false,
        message: 'Name and password are required',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = await _loadAccounts(prefs);
    final userId = userIdForName(trimmedName);
    final passwordKey = _passwordKey(trimmedPassword);
    final existingAccount = accounts[userId];

    if (existingAccount != null &&
        existingAccount['passwordKey'] != passwordKey) {
      return const LoginResult(
        success: false,
        message: 'Incorrect password for this login name',
      );
    }

    final user = ChatUser(
      id: userId,
      name: trimmedName,
      isGuest: false,
    );
    accounts[userId] = {
      'id': user.id,
      'name': user.name,
      'passwordKey': passwordKey,
    };

    await prefs.setString(_accountsKey, jsonEncode(accounts));
    await saveCurrentUser(user);

    return LoginResult(
      success: true,
      message: existingAccount == null
          ? 'Account created. You are logged in.'
          : 'Login successful',
      user: user,
    );
  }

  Future<Map<String, dynamic>> _loadAccounts(SharedPreferences prefs) async {
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      await prefs.remove(_accountsKey);
    } on TypeError {
      await prefs.remove(_accountsKey);
    }
    return {};
  }

  String _passwordKey(String password) {
    var hash = 5381;
    for (final codeUnit in password.codeUnits) {
      hash = ((hash << 5) + hash) ^ codeUnit;
    }
    return hash.toUnsigned(32).toString();
  }

  Future<List<ChatSession>> loadSessions({String userId = guestUserId}) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_userSessionsKey(userId));
    if (raw == null && userId == guestUserId) {
      raw = prefs.getString(_sessionsKey);
    }
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (session) => ChatSession.fromJson(
                Map<String, dynamic>.from(session),
              ),
            )
            .toList();
      }
    } on FormatException {
      await prefs.remove(_userSessionsKey(userId));
      await prefs.remove(_userActiveChatIdKey(userId));
      if (userId == guestUserId) {
        await prefs.remove(_sessionsKey);
        await prefs.remove(_activeChatIdKey);
      }
    } on TypeError {
      await prefs.remove(_userSessionsKey(userId));
      await prefs.remove(_userActiveChatIdKey(userId));
      if (userId == guestUserId) {
        await prefs.remove(_sessionsKey);
        await prefs.remove(_activeChatIdKey);
      }
    }

    if (prefs.getString(_userSessionsKey(userId)) == raw) {
      await prefs.remove(_userSessionsKey(userId));
      await prefs.remove(_userActiveChatIdKey(userId));
    }
    return [];
  }

  Future<String?> loadActiveChatId({String userId = guestUserId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userActiveChatIdKey(userId)) ??
        (userId == guestUserId ? prefs.getString(_activeChatIdKey) : null);
  }

  Future<void> saveSessions({
    required List<ChatSession> sessions,
    required String? activeChatId,
    String userId = guestUserId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userSessionsKey(userId),
      jsonEncode(sessions.map((session) => session.toJson()).toList()),
    );

    if (activeChatId == null) {
      await prefs.remove(_userActiveChatIdKey(userId));
    } else {
      await prefs.setString(_userActiveChatIdKey(userId), activeChatId);
    }
  }
}

class ChatUser {
  final String id;
  final String name;
  final bool isGuest;

  const ChatUser({
    required this.id,
    required this.name,
    required this.isGuest,
  });

  const ChatUser.guest()
      : id = ChatStorageService.guestUserId,
        name = 'Guest',
        isGuest = true;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isGuest': isGuest,
    };
  }

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] as String? ?? ChatStorageService.guestUserId,
      name: json['name'] as String? ?? 'Guest',
      isGuest: json['isGuest'] as bool? ?? true,
    );
  }
}

class LoginResult {
  final bool success;
  final String message;
  final ChatUser? user;

  const LoginResult({
    required this.success,
    required this.message,
    this.user,
  });
}
