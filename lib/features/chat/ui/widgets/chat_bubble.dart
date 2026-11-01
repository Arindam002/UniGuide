import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/message_model.dart';
import 'chat_diagram_cart.dart';
import 'formatted_answer_text.dart';
import '../../../../theme/app_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/uniguide_logo.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onEdit,
    this.isImportant = false,
  });

  final ChatMessage message;
  final VoidCallback? onEdit;
  final bool isImportant;

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
    final isUser = message.isUser;
    final important = isImportant || (!isUser && message.source == 'System');
    final showBubble = isUser || important;
    final timestamp = TimeOfDay.fromDateTime(message.timestamp).format(context);
    final sourceLabel = (message.source ?? 'UNIGUIDE').toUpperCase();

    return _HoverReveal(
      builder: (isHovered, supportsHover) => LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isUser
                    ? constraints.maxWidth * 0.75
                    : constraints.maxWidth.clamp(0, 760),
              ),
              child: GestureDetector(
                onTap: () => _showMessageActions(context),
                onLongPress: () => _showMessageActions(context),
                child: Container(
                  decoration: isUser
                      ? BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        )
                      : important
                          ? BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                              border: const Border(
                                left: BorderSide(
                                  color: AppColors.primary,
                                  width: 4,
                                ),
                              ),
                            )
                          : null,
                  padding: EdgeInsets.all(showBubble ? 12 : 0),
                  child: Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (important) ...[
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUser || sourceLabel != 'UNIGUIDE')
                              Text(
                                isUser ? 'YOU' : sourceLabel,
                                style: AppFonts.messageLabel(
                                  color: AppColors.muted,
                                  isUser: isUser,
                                ),
                                textAlign:
                                    isUser ? TextAlign.right : TextAlign.left,
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const UniGuideLogo(size: 22),
                                  const SizedBox(width: 6),
                                  Text(
                                    sourceLabel,
                                    style: AppFonts.messageLabel(
                                      color: AppColors.muted,
                                      isUser: false,
                                    ),
                                  ),
                                ],
                              ),
                            if (!isUser &&
                                (message.diagram?.hasContent ?? false)) ...[
                              const SizedBox(height: 8),
                              ChatDiagramCard(diagram: message.diagram!),
                              if (message.text.trim().isNotEmpty)
                                const SizedBox(height: 14),
                            ],
                            if (message.text.trim().isNotEmpty)
                              isUser
                                  ? SelectableText(
                                      message.text,
                                      textAlign: TextAlign.right,
                                      style: AppFonts.userMessage(
                                        color: AppColors.userText,
                                      ).copyWith(
                                        fontWeight: important
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    )
                                  : FormattedAnswerText(
                                      text: message.text,
                                      important: important,
                                    ),
                            const SizedBox(height: 6),
                            _HoverMetadata(
                              isUser: isUser,
                              timestamp: timestamp,
                              isVisible: !supportsHover || isHovered,
                              onCopy: message.text.trim().isEmpty
                                  ? null
                                  : () => _copyText(context),
                              onEdit: isUser ? onEdit : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showMessageActions(BuildContext context) async {
    final hasText = message.text.trim().isNotEmpty;
    if (!hasText && onEdit == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
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
      ),
    );

    if (!context.mounted) return;
    if (action == 'copy') {
      await _copyText(context);
    } else if (action == 'edit') {
      onEdit?.call();
    }
  }
}

class _HoverReveal extends StatefulWidget {
  const _HoverReveal({required this.builder});

  final Widget Function(bool isHovered, bool supportsHover) builder;

  @override
  State<_HoverReveal> createState() => _HoverRevealState();
}

class _HoverRevealState extends State<_HoverReveal> {
  bool _hovered = false;

  bool get _supportsHover =>
      kIsWeb ||
      {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered, _supportsHover),
    );
  }
}

class _HoverMetadata extends StatelessWidget {
  const _HoverMetadata({
    required this.isUser,
    required this.timestamp,
    required this.isVisible,
    this.onCopy,
    this.onEdit,
  });

  final bool isUser;
  final String timestamp;
  final bool isVisible;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      key: const ValueKey('message-metadata-opacity'),
      duration: const Duration(milliseconds: 140),
      opacity: isVisible ? 1 : 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timestamp,
            style: AppFonts.timestamp(
              color: AppColors.muted,
              isUser: isUser,
            ),
          ),
          if (onCopy != null)
            _ActionIcon(
              tooltip: 'Copy',
              icon: Icons.content_copy_rounded,
              onPressed: onCopy!,
            ),
          if (onEdit != null)
            _ActionIcon(
              tooltip: 'Edit',
              icon: Icons.edit_rounded,
              onPressed: onEdit!,
            ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 15, color: AppColors.muted),
    );
  }
}
