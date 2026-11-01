import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_fonts.dart';

class ChatInputField extends StatelessWidget {
  const ChatInputField({
    super.key,
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  KeyEventResult _handleKeyPress(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      onSend();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final pastedText = clipboardData?.text?.trim();

    if (pastedText == null || pastedText.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }

    final updatedText =
        '${controller.text}${controller.text.isEmpty ? '' : '\n'}$pastedText';
    controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedText.length),
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
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(inputRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: GestureDetector(
                  onLongPress:
                      isLoading ? null : () => _pasteFromClipboard(context),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Paste',
                        color: AppColors.accent,
                        onPressed: isLoading
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
                            controller: controller,
                            minLines: 1,
                            maxLines: isPhoneWidth ? 4 : 6,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            cursorColor: AppColors.accent,
                            style: AppFonts.assistantMessage(
                              color: AppColors.botText,
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  'Ask UniGuide anything from your syllabus',
                              hintStyle: TextStyle(color: AppColors.muted),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 6),
                        child: FilledButton(
                          onPressed: isLoading ? null : onSend,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.sidebar,
                            minimumSize: Size(sendButtonSize, sendButtonSize),
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
            ),
          ),
        ),
      ),
    );
  }
}
