import 'package:flutter/material.dart';
// Using system font instead of google_fonts for stability

enum _AnswerBlockType {
  heading,
  subheading,
  paragraph,
  bullet,
  numbered,
}

class _AnswerBlock {
  const _AnswerBlock({
    required this.type,
    required this.text,
    this.number,
  });

  final _AnswerBlockType type;
  final String text;
  final String? number;
}

class FormattedAnswerText extends StatelessWidget {
  const FormattedAnswerText({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);

    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < blocks.length; i++)
            Padding(
              padding: EdgeInsets.only(
                top: _topSpacing(blocks[i], i),
                bottom: _bottomSpacing(blocks[i]),
              ),
              child: _AnswerBlockView(block: blocks[i]),
            ),
        ],
      ),
    );
  }

  List<_AnswerBlock> _parseBlocks(String rawText) {
    final normalized = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (normalized.isEmpty) return const [];

    final blocks = <_AnswerBlock>[];
    final paragraphLines = <String>[];

    void flushParagraph() {
      final paragraph = paragraphLines.join(' ').trim();
      paragraphLines.clear();
      if (paragraph.isNotEmpty) {
        blocks.add(_AnswerBlock(
          type: _AnswerBlockType.paragraph,
          text: _cleanInlineMarkdown(paragraph),
        ));
      }
    }

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        flushParagraph();
        continue;
      }

      final headingMatch = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        flushParagraph();
        blocks.add(_AnswerBlock(
          type: headingMatch.group(1)!.length == 1
              ? _AnswerBlockType.heading
              : _AnswerBlockType.subheading,
          text: _cleanInlineMarkdown(headingMatch.group(2)!),
        ));
        continue;
      }

      final boldHeadingMatch = RegExp(r'^\*\*(.+?)\*\*:?\s*$').firstMatch(line);
      if (boldHeadingMatch != null) {
        flushParagraph();
        blocks.add(_AnswerBlock(
          type: _AnswerBlockType.subheading,
          text: _cleanInlineMarkdown(boldHeadingMatch.group(1)!),
        ));
        continue;
      }

      final bulletMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        flushParagraph();
        blocks.add(_AnswerBlock(
          type: _AnswerBlockType.bullet,
          text: _cleanInlineMarkdown(bulletMatch.group(1)!),
        ));
        continue;
      }

      final numberedMatch = RegExp(r'^(\d+)[.)]\s+(.+)$').firstMatch(line);
      if (numberedMatch != null) {
        flushParagraph();
        blocks.add(_AnswerBlock(
          type: _AnswerBlockType.numbered,
          number: numberedMatch.group(1),
          text: _cleanInlineMarkdown(numberedMatch.group(2)!),
        ));
        continue;
      }

      final labelMatch = RegExp(r'^([A-Z][A-Za-z ]{2,32}):\s*$').firstMatch(line);
      if (labelMatch != null) {
        flushParagraph();
        blocks.add(_AnswerBlock(
          type: _AnswerBlockType.subheading,
          text: _cleanInlineMarkdown(labelMatch.group(1)!),
        ));
        continue;
      }

      paragraphLines.add(line);
    }

    flushParagraph();
    return blocks;
  }

  String _cleanInlineMarkdown(String value) {
    final withoutBold = value
        .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (match) => match.group(1)!)
        .replaceAllMapped(RegExp(r'__(.*?)__'), (match) => match.group(1)!);

    return withoutBold
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1)!)
        .replaceFirst(RegExp(r':$'), '')
        .trim();
  }

  double _topSpacing(_AnswerBlock block, int index) {
    if (index == 0) return 0;

    return switch (block.type) {
      _AnswerBlockType.heading => 16,
      _AnswerBlockType.subheading => 14,
      _AnswerBlockType.paragraph => 8,
      _AnswerBlockType.bullet => 5,
      _AnswerBlockType.numbered => 5,
    };
  }

  double _bottomSpacing(_AnswerBlock block) {
    return switch (block.type) {
      _AnswerBlockType.heading => 3,
      _AnswerBlockType.subheading => 2,
      _AnswerBlockType.paragraph => 3,
      _AnswerBlockType.bullet => 2,
      _AnswerBlockType.numbered => 2,
    };
  }
}

class _AnswerBlockView extends StatelessWidget {
  const _AnswerBlockView({
    required this.block,
  });

  final _AnswerBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (block.type) {
      _AnswerBlockType.heading => Text(
          block.text,
          textAlign: TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF142033),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.6,
            fontFamily: 'sans-serif',
          ),
        ),
      _AnswerBlockType.subheading => Text(
          block.text,
          textAlign: TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF172B45),
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.6,
            fontFamily: 'sans-serif',
          ),
        ),
      _AnswerBlockType.paragraph => Text(
          block.text,
          textAlign: TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF1B2430),
            fontSize: 18.0,
            height: 1.6,
            fontWeight: FontWeight.w400,
            fontFamily: 'sans-serif',
          ),
        ),
      _AnswerBlockType.bullet => _ListLine(
          marker: '\u2022',
          text: block.text,
        ),
      _AnswerBlockType.numbered => _ListLine(
          marker: '${block.number}.',
          text: block.text,
        ),
    };
  }
}

class _ListLine extends StatelessWidget {
  const _ListLine({
    required this.marker,
    required this.text,
  });

  final String marker;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNumbered = marker.endsWith('.');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isNumbered ? 28 : 20,
          child: Text(
              marker,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Color(0xFF1B4D8C),
                fontSize: 18.0,
                height: 1.6,
                fontWeight: FontWeight.w700,
                fontFamily: 'sans-serif',
              ),
            ),
        ),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Color(0xFF1B2430),
              fontSize: 18.0,
              height: 1.6,
              fontWeight: FontWeight.w400,
              fontFamily: 'sans-serif',
            ),
          ),
        ),
      ],
    );
  }
}
