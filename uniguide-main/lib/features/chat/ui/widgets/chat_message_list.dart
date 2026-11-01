import 'package:flutter/material.dart';

import '../../data/message_model.dart';
import 'chat_bubble.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    this.onEditUserMessage,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final ValueChanged<int>? onEditUserMessage;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ChatBubble(
            message: msg,
            onEdit: msg.isUser ? () => onEditUserMessage?.call(index) : null,
          ),
        );
      },
    );
  }
}
