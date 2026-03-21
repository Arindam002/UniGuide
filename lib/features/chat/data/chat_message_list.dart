import 'package:flutter/material.dart';
import '../../data/message_model.dart';
import 'chat_bubble.dart';
import 'typing_indicator.dart';

class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isLoading) {
      return const Center(
        child: Text(
          "Ask something about your books, notes, or syllabus",
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TypingIndicator(),
            ),
          );
        }

        final msg = messages[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ChatBubble(message: msg),
        );
      },
    );
  }
}