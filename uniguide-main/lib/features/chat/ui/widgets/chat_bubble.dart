import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/message_model.dart';
import 'chat_code_viewer.dart';
import 'chat_diagram_card.dart';
import 'formatted_answer_text.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onEdit,
  });

  final ChatMessage message;
  final VoidCallback? onEdit;

  Future<void> _copyText(BuildContext context) async {
    if (message.text.trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text available to copy')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: message.text));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.isUser ? 'Message copied' : 'Answer copied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    final textColor = const Color(0xFF1B2430);
    const textStyle = TextStyle(
      color: Color(0xFF1B2430),
      height: 1.6,
      fontSize: 18.0,
    );
    final codeBlocks = isUser
        ? const <ChatCodeBlock>[]
        : ChatCodeBlockParser.extract(message.text);
    final displayText = codeBlocks.isEmpty
        ? message.text
        : ChatCodeBlockParser.withoutCodeBlocks(message.text);

    final timestamp = TimeOfDay.fromDateTime(message.timestamp).format(context);

    return GestureDetector(
      onTap: () => _showMessageActions(context),
      onLongPress: () => _showMessageActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Builder(builder: (context) {
            final content = Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender label aligned with the start of the text block
                Text(
                  isUser ? 'YOU' : 'UNIGUIDE',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'sans-serif',
                  ),
                  textAlign: isUser ? TextAlign.right : TextAlign.left,
                ),
                if (!isUser && (message.diagram?.hasContent ?? false)) ...[
                  const SizedBox(height: 6),
                  ChatDiagramCard(diagram: message.diagram!),
                  if (displayText.trim().isNotEmpty) const SizedBox(height: 16),
                ],
                if (displayText.trim().isNotEmpty)
                  isUser
                      ? SelectableText(
                          displayText,
                          textAlign: TextAlign.right,
                          style: textStyle,
                        )
                      : FormattedAnswerText(text: displayText),
                if (codeBlocks.isNotEmpty) ...[
                  if (displayText.trim().isNotEmpty) const SizedBox(height: 16),
                  ChatInlineCodeBlocks(blocks: codeBlocks),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timestamp,
                      textAlign: isUser ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        height: 1.6,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (message.text.trim().isNotEmpty)
                      InkWell(
                        onTap: () => _copyText(context),
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.content_copy_rounded,
                            size: 16,
                            color: Color(0xFF5E6B7D),
                          ),
                        ),
                      ),
                    if (isUser && onEdit != null) ...[
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: Color(0xFF5E6B7D),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );

            // Constrain all messages to 75% of screen width so text never
            // expands fully and leaves a wide gutter on the opposite side.
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: content,
            );
          }),
        ),
      ),
    );
  }

  Future<void> _showMessageActions(BuildContext context) async {
    final hasText = message.text.trim().isNotEmpty;
    if (!hasText && onEdit == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                ListTile(
                  leading: const Icon(Icons.content_copy_rounded),
                  title: const Text('Copy'),
                  onTap: () => Navigator.pop(context, 'copy'),
                ),
              if (message.isUser && onEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Edit'),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (action == 'copy') {
      await _copyText(context);
    } else if (action == 'edit') {
      onEdit?.call();
    }
  }
}
