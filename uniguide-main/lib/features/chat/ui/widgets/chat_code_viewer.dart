import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// use system font for labels

class ChatCodeBlock {
  const ChatCodeBlock({
    required this.code,
    this.language,
  });

  final String code;
  final String? language;

  String get displayLanguage {
    final value = language?.trim();
    if (value == null || value.isEmpty) return 'code';
    return value;
  }
}

class ChatCodeBlockParser {
  static final RegExp _fencedCodePattern = RegExp(
    r'```([A-Za-z0-9_+\-#.]*)?[ \t]*\n([\s\S]*?)```',
    multiLine: true,
  );

  static List<ChatCodeBlock> extract(String text) {
    return _fencedCodePattern
        .allMatches(text)
        .map((match) {
          return ChatCodeBlock(
            language: match.group(1),
            code: match.group(2)?.trimRight() ?? '',
          );
        })
        .where((block) => block.code.trim().isNotEmpty)
        .toList();
  }

  static String withoutCodeBlocks(String text) {
    return text
        .replaceAll(_fencedCodePattern, '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

class ChatInlineCodeBlocks extends StatelessWidget {
  const ChatInlineCodeBlocks({
    super.key,
    required this.blocks,
  });

  final List<ChatCodeBlock> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
            child: _InlineCodeBox(block: blocks[i]),
          ),
      ],
    );
  }
}

class _InlineCodeBox extends StatelessWidget {
  const _InlineCodeBox({
    required this.block,
  });

  final ChatCodeBlock block;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: block.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // prevent code blocks from expanding to full screen width
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF101820),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF26384A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
                decoration: const BoxDecoration(
                  color: Color(0xFF182635),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.code_rounded,
                      color: const Color(0xFFB8C7D9),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          block.displayLanguage,
                          style: const TextStyle(
                            color: Color(0xFFEAF2FF),
                            fontWeight: FontWeight.w600,
                            height: 1.6,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                    ),
                    IconButton(
                      tooltip: 'Copy code',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copy(context),
                      icon: const Icon(
                        Icons.content_copy_rounded,
                        color: Color(0xFFB8C7D9),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: _CodePanel(block: block),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodePanel extends StatelessWidget {
  const _CodePanel({
    required this.block,
  });

  final ChatCodeBlock block;

  @override
  Widget build(BuildContext context) {
    final lines = block.code.split('\n');
    final numberWidth = '${lines.length}'.length * 9.0 + 22.0;

    return Container(
      color: const Color(0xFF101820),
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectionArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: numberWidth,
                    child: Text(
                      List.generate(lines.length, (index) => '${index + 1}')
                          .join('\n'),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF7D8EA3),
                        fontFamily: 'monospace',
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      // prevent inline code area from expanding beyond 85% of screen
                      maxWidth: MediaQuery.of(context).size.width * 0.85,
                    ),
                    child: Text(
                      block.code,
                      textAlign: TextAlign.left,
                      softWrap: false,
                        style: const TextStyle(
                        color: Color(0xFFEAF2FF),
                        fontFamily: 'monospace',
                        fontSize: 17,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
