import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_fonts.dart';

class CopyableCodeBlockBuilder extends MarkdownElementBuilder {
  CopyableCodeBlockBuilder();

  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    var language = '';
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'code') {
        final className = child.attributes['class'] ?? '';
        language = RegExp(r'(?:^|\s)language-([A-Za-z0-9_+#.-]+)')
                .firstMatch(className)
                ?.group(1) ??
            '';
        break;
      }
    }

    var code = element.textContent;
    if (code.endsWith('\n')) {
      code = code.substring(0, code.length - 1);
    }

    return _CopyableCodeBlock(code: code, language: language);
  }
}

class _CopyableCodeBlock extends StatelessWidget {
  const _CopyableCodeBlock({
    required this.code,
    required this.language,
  });

  final String code;
  final String language;

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = AppColors.surface;
    final foreground = AppColors.botText;
    final codeTheme = <String, TextStyle>{
      'root': AppFonts.code(color: foreground),
      'keyword': TextStyle(color: AppColors.codeKeyword),
      'selector-tag': TextStyle(color: AppColors.codeKeyword),
      'literal': TextStyle(color: AppColors.codeKeyword),
      'string': TextStyle(color: AppColors.codeString),
      'doctag': TextStyle(color: AppColors.codeString),
      'comment': TextStyle(color: AppColors.codeComment),
      'quote': TextStyle(color: AppColors.codeComment),
      'function': TextStyle(color: AppColors.codeFunction),
      'title': TextStyle(color: AppColors.codeFunction),
      'number': TextStyle(color: AppColors.codeNumber),
      'built_in': TextStyle(color: AppColors.accent),
      'attr': TextStyle(color: AppColors.accent),
      'variable': TextStyle(color: foreground),
      'params': TextStyle(color: foreground),
    };
    final normalizedLanguage = _supportedLanguage(language);
    final lines = code.split('\n');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? 'code' : language,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copyCode(context),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: SelectionArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        List.generate(lines.length, (index) => '${index + 1}')
                            .join('\n'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontFamily: AppFonts.code().fontFamily,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(width: 14),
                      if (normalizedLanguage == null)
                        Text(
                          code,
                          softWrap: false,
                          style: AppFonts.code(color: foreground),
                        )
                      else
                        HighlightView(
                          code,
                          language: normalizedLanguage,
                          theme: codeTheme,
                          textStyle: AppFonts.code(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _supportedLanguage(String language) {
    final normalized = language.toLowerCase();
    const aliases = {
      'c++': 'cpp',
      'c#': 'cs',
      'js': 'javascript',
      'ts': 'typescript',
      'py': 'python',
      'sh': 'bash',
      'shell': 'bash',
      'plain': '',
      'plaintext': '',
      'text': '',
    };
    final resolved = aliases[normalized] ?? normalized;
    const supported = {
      'bash',
      'c',
      'cpp',
      'cs',
      'css',
      'dart',
      'go',
      'html',
      'java',
      'javascript',
      'json',
      'kotlin',
      'markdown',
      'python',
      'ruby',
      'rust',
      'sql',
      'swift',
      'typescript',
      'xml',
      'yaml',
    };
    return supported.contains(resolved) ? resolved : null;
  }
}
