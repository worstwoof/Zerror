import 'package:flutter/material.dart';
import 'package:latext/latext.dart';

class AppLatexText extends StatelessWidget {
  const AppLatexText(
    this.content, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  final String content;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeDelimiters(content).trim();
    if (normalized.isEmpty) {
      return const SizedBox.shrink();
    }

    final fallbackText = _fallbackPlainText(normalized);
    final plainText = Text(
      normalized,
      textAlign: textAlign,
      style: style,
    );

    return Builder(
      builder: (context) => Align(
        alignment: _alignmentFor(textAlign),
        child: LaTexT(
          laTeXCode: plainText,
          equationStyle: style.copyWith(
            fontSize: style.fontSize == null ? null : style.fontSize! + 1,
          ),
          onErrorFallback: (_) => Text(
            fallbackText,
            textAlign: textAlign,
            style: style,
          ),
        ),
      ),
    );
  }

  Alignment _alignmentFor(TextAlign textAlign) {
    switch (textAlign) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.left:
      case TextAlign.start:
      case TextAlign.justify:
        return Alignment.centerLeft;
    }
  }

  String _normalizeDelimiters(String value) {
    return value
        .replaceAll(r'\[', r'$$')
        .replaceAll(r'\]', r'$$')
        .replaceAll(r'\(', r'$')
        .replaceAll(r'\)', r'$');
  }

  String _fallbackPlainText(String value) {
    return value
        .replaceAll(RegExp(r'\${1,2}'), '')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\ln', 'ln')
        .replaceAll(r'\sin', 'sin')
        .replaceAll(r'\cos', 'cos')
        .replaceAll(r'\tan', 'tan')
        .replaceAll(r'\pi', 'π')
        .replaceAllMapped(
          RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'),
          (match) => '(${match.group(1)})/(${match.group(2)})',
        )
        .replaceAll('{', '')
        .replaceAll('}', '');
  }
}
