import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatInputField extends StatefulWidget {
  const ChatInputField({
    super.key,
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  bool showHint = true;

  KeyEventResult _handleKeyPress(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _sendMessage();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _sendMessage() {
    setState(() {
      showHint = false;
    });

    widget.onSend();
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final pastedText = clipboardData?.text?.trim();

    if (pastedText == null || pastedText.isEmpty) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard is empty'),
        ),
      );
      return;
    }

    final updatedText =
        '${widget.controller.text}${widget.controller.text.isEmpty ? '' : '\n'}$pastedText';

    widget.controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(
        offset: updatedText.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final isPhoneWidth = width < 520;

    final inputRadius = isPhoneWidth ? 22.0 : 28.0;
    final sendButtonSize = isPhoneWidth ? 44.0 : 52.0;
    final toolbarIconSize = isPhoneWidth ? 20.0 : 24.0;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFDCE3ED),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FB),
                  borderRadius: BorderRadius.circular(inputRadius),
                  border: Border.all(
                    color: const Color(0xFFD7E2F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onLongPress: widget.isLoading
                      ? null
                      : () => _pasteFromClipboard(context),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Paste',
                        onPressed: widget.isLoading
                            ? null
                            : () => _pasteFromClipboard(context),
                        icon: Icon(
                          Icons.content_paste_rounded,
                          size: toolbarIconSize,
                        ),
                      ),
                      Expanded(
                        child: Focus(
                          onKeyEvent: (_, event) => _handleKeyPress(event),
                          child: TextField(
                            controller: widget.controller,
                            minLines: 1,
                            maxLines: isPhoneWidth ? 4 : 6,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: showHint
                                  ? 'Ask UniGuide anything from your syllabus.'
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 8,
                          bottom: 6,
                        ),
                        child: FilledButton(
                          onPressed: widget.isLoading ? null : _sendMessage,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1B4D8C),
                            foregroundColor: Colors.white,
                            minimumSize: Size(
                              sendButtonSize,
                              sendButtonSize,
                            ),
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ),
                          child: const Icon(Icons.arrow_upward_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
