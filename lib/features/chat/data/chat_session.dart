import 'message_model.dart';

class ChatSession {
  /// Local frontend session id
  final String id;

  /// Backend chat_id returned by Flask
  final String? backendChatId;

  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    this.backendChatId,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.create({
    required String id,
    required List<ChatMessage> messages,
  }) {
    final now = DateTime.now();

    return ChatSession(
      id: id,
      backendChatId: null,
      title: 'New chat',
      messages: messages,
      createdAt: now,
      updatedAt: now,
    );
  }

  String get previewText {
    if (messages.isEmpty) return 'No messages yet';
    return messages.last.text;
  }

  ChatSession copyWith({
    String? backendChatId,
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) {
    return ChatSession(
      id: id,
      backendChatId: backendChatId ?? this.backendChatId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'backend_chat_id': backendChatId,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      backendChatId: json['backend_chat_id'] as String?,
      title: json['title'] as String? ?? 'New chat',
      messages: (json['messages'] as List? ?? [])
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}