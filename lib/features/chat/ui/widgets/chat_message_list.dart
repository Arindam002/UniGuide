import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../data/message_model.dart';
import 'chat_bubble.dart';
import 'typing_indicator.dart';

class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final bool isLoading;
  final ValueChanged<int>? onEditUserMessage;
  final GlobalKey? latestAssistantMessageKey;
  final VoidCallback? onUserScroll;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.isLoading,
    this.onEditUserMessage,
    this.latestAssistantMessageKey,
    this.onUserScroll,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) {
          onUserScroll?.call();
        }
        if (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle) {
          onUserScroll?.call();
        }
        return false;
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            itemCount: messages.length + (isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: TypingIndicator(),
                );
              }
              final msg = messages[index];
              final isLatestAssistant =
                  index == messages.length - 1 && !msg.isUser;
              return Padding(
                key: isLatestAssistant ? latestAssistantMessageKey : null,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: ChatBubble(
                    message: msg,
                    isImportant: !msg.isUser && msg.source == 'System',
                    onEdit: msg.isUser
                        ? () => onEditUserMessage?.call(index)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
