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
    final normalized = _normalizeForLatexRendering(content).trim();
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

  String _normalizeForLatexRendering(String value) {
    return _wrapBareLatexCommands(_normalizeDelimiters(value));
  }

  String _wrapBareLatexCommands(String value) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < value.length) {
      final delimiter = value.indexOf(r'$', index);
      if (delimiter < 0) {
        buffer.write(_wrapBareLatexInPlainText(value.substring(index)));
        break;
      }

      buffer
          .write(_wrapBareLatexInPlainText(value.substring(index, delimiter)));
      final isDisplay =
          delimiter + 1 < value.length && value[delimiter + 1] == r'$';
      final marker = isDisplay ? r'$$' : r'$';
      final bodyStart = delimiter + marker.length;
      final end = value.indexOf(marker, bodyStart);
      if (end < 0) {
        buffer.write(value.substring(delimiter));
        break;
      }
      buffer.write(marker);
      buffer.write(_normalizeMathBody(value.substring(bodyStart, end)));
      buffer.write(marker);
      index = end + marker.length;
    }
    return buffer.toString();
  }

  String _wrapBareLatexInPlainText(String value) {
    final pattern = RegExp(
      r'\\(?:dfrac|tfrac|frac)\{[^{}]+\}\{[^{}]+\}|\\(?:sqrt|overline|vec|bar|hat)\{[^{}]+\}|\\(?:sin|cos|tan|ln|log|leq|geq|alpha|beta|gamma|lambda|mu|theta|pi|Delta|Omega)\b',
    );
    return value.replaceAllMapped(pattern, (match) {
      final body = _normalizeMathBody(match.group(0) ?? '');
      return body.isEmpty ? '' : '\$$body\$';
    });
  }

  String _normalizeMathBody(String value) {
    return value
        .replaceAll('₀', '_0')
        .replaceAll('₁', '_1')
        .replaceAll('₂', '_2')
        .replaceAll('₃', '_3')
        .replaceAll('₄', '_4')
        .replaceAll('₅', '_5')
        .replaceAll('₆', '_6')
        .replaceAll('₇', '_7')
        .replaceAll('₈', '_8')
        .replaceAll('₉', '_9');
  }

  String _fallbackPlainText(String value) {
    return value
        .replaceAll(RegExp(r'\${1,2}'), '')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\lambda', 'λ')
        .replaceAll(r'\mu', 'μ')
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
