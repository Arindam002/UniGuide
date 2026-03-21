class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final String? source; // e.g., "Book", "PYQ", "Notes"

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.isLoading = false,
    this.source,
  }) : timestamp = timestamp ?? DateTime.now();
}