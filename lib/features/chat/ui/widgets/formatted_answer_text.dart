import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_fonts.dart';
import 'chat_code_viewer.dart';

class FormattedAnswerText extends StatelessWidget {
  const FormattedAnswerText({
    super.key,
    required this.text,
    this.important = false,
  });

  final String text;
  final bool important;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle =
        AppFonts.aiResponse(color: AppColors.responseBody).copyWith(
      height: 1.7,
      letterSpacing: 0.1,
      fontWeight: important ? FontWeight.w700 : FontWeight.normal,
    );
    final inlineCodeStyle = AppFonts.code(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
    );
    final strongStyle = bodyStyle.copyWith(
      color: AppColors.highlight,
      fontWeight: FontWeight.w700,
    );
    final headingStyle = AppFonts.responseHeading(color: AppColors.heading);
    final sourceMatch = RegExp(
      r'^#{0,6}\s*(?:sources|references)\s*:?\s*$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    final answerText = sourceMatch == null
        ? text
        : text.substring(0, sourceMatch.start).trim();
    final nextHeading = sourceMatch == null
        ? null
        : RegExp(
            r'^#{1,6}\s+',
            multiLine: true,
          ).firstMatch(text.substring(sourceMatch.end));
    final sourceSectionEnd = sourceMatch == null || nextHeading == null
        ? text.length
        : sourceMatch.end + nextHeading.start;
    final sourceEntries = sourceMatch == null
        ? const <String>[]
        : text
            .substring(sourceMatch.end, sourceSectionEnd)
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (answerText.isNotEmpty)
            MarkdownBody(
              data: answerText,
              selectable: false,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              inlineSyntaxes: [_CitationSyntax()],
              builders: {
                'pre': CopyableCodeBlockBuilder(),
              },
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: bodyStyle,
                h1: headingStyle.copyWith(fontSize: 26),
                h2: headingStyle.copyWith(fontSize: 22),
                h3: headingStyle.copyWith(fontSize: 19),
                h4: headingStyle.copyWith(fontSize: 17),
                h1Padding: const EdgeInsets.only(top: 18, bottom: 8),
                h2Padding: const EdgeInsets.only(top: 16, bottom: 7),
                h3Padding: const EdgeInsets.only(top: 14, bottom: 6),
                h4Padding: const EdgeInsets.only(top: 12, bottom: 4),
                code: inlineCodeStyle.copyWith(
                  fontSize: 14,
                  backgroundColor: AppColors.surface,
                ),
                strong: strongStyle,
                blockSpacing: 12,
                tableBorder: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                ),
                tableColumnWidth: const IntrinsicColumnWidth(),
                tableCellsPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                tableCellsDecoration: const BoxDecoration(),
                tableHeadCellsDecoration: const BoxDecoration(
                  color: AppColors.tableHeader,
                ),
                tableHead: bodyStyle.copyWith(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w600,
                ),
                tableBody: bodyStyle,
                a: bodyStyle.copyWith(
                  color: AppColors.highlight,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
                blockquote: bodyStyle,
                blockquoteDecoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(4),
                  border: const Border(
                    left: BorderSide(color: AppColors.accent, width: 3),
                  ),
                ),
              ),
            ),
          if (sourceEntries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                iconColor: AppColors.muted,
                collapsedIconColor: AppColors.muted,
                title: Text(
                  'Sources',
                  style: AppFonts.messageLabel(
                    color: AppColors.muted,
                    isUser: false,
                  ),
                ),
                children: [
                  ...sourceEntries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          entry,
                          style: AppFonts.assistantMessage(
                            color: AppColors.muted,
                          ).copyWith(fontSize: 13, height: 1.45),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CitationSyntax extends md.InlineSyntax {
  _CitationSyntax() : super(r'\[(\d+)\](?!\()');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final citation = md.Element.text('sup', match[0]!);
    final link = md.Element('a', [citation])
      ..attributes['href'] = '#citation-${match[1]}';
    parser.addNode(link);
    return true;
  }
}
