import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme.dart';

class HtmlArtifactPreviewScreen extends StatefulWidget {
  const HtmlArtifactPreviewScreen({
    super.key,
    required this.title,
    required this.htmlContent,
  });

  final String title;
  final String htmlContent;

  @override
  State<HtmlArtifactPreviewScreen> createState() =>
      _HtmlArtifactPreviewScreenState();
}

class _HtmlArtifactPreviewScreenState extends State<HtmlArtifactPreviewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(_prepareHtmlForPreview(widget.htmlContent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.night,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: AppPalette.pastelGrey.withValues(alpha: 0.10),
                ),
              ),
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ),
      ),
    );
  }

  String _prepareHtmlForPreview(String rawHtml) {
    final normalized = rawHtml.trim();
    const previewFitHead = '''
<style id="zerror-preview-fit">
  html, body {
    margin: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
    overscroll-behavior: none;
    -webkit-text-size-adjust: 100%;
    text-size-adjust: 100%;
  }
  *, *::before, *::after { box-sizing: border-box; }
  body {
    min-width: 0;
    max-width: 100vw;
    max-height: 100vh;
    touch-action: pan-x pan-y;
  }
  body[data-scene] {
    padding: 0 !important;
  }
  body[data-scene] .shell {
    gap: 8px !important;
  }
  body[data-scene] .shell > section.card:first-child:not(.stage),
  body[data-scene] .hero,
  body[data-scene] .question-hint,
  body[data-scene] .subtitle,
  body[data-scene] .scene-chips {
    display: none !important;
  }
  body[data-scene] .stage {
    margin: 0 !important;
  }
  svg, canvas, video {
    max-width: 100%;
    max-height: 100%;
  }
</style>
<script>
  function zerrorStartAnimation() {
    var buttons = Array.prototype.slice.call(document.querySelectorAll('button'));
    var startButton = buttons.find(function (button) {
      var text = (button.textContent || '').toLowerCase();
      return text.indexOf('开始') >= 0 ||
        text.indexOf('播放') >= 0 ||
        text.indexOf('start') >= 0 ||
        text.indexOf('play') >= 0;
    });
    if (startButton) {
      startButton.click();
    }
    ['start', 'play', 'run', 'startAnimation'].forEach(function (name) {
      try {
        if (typeof window[name] === 'function') {
          window[name]();
        }
      } catch (_) {}
    });
  }
  window.addEventListener('load', function () {
    document.documentElement.style.width = '100%';
    document.documentElement.style.height = '100%';
    document.body.style.width = '100%';
    document.body.style.height = '100%';
    window.scrollTo(0, 0);
    setTimeout(zerrorStartAnimation, 250);
    setTimeout(zerrorStartAnimation, 1000);
  });
</script>
''';

    if (normalized.isEmpty) {
      return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  $previewFitHead
</head>
<body></body>
</html>
''';
    }

    if (RegExp(r'<head[^>]*>', caseSensitive: false).hasMatch(normalized)) {
      final withFitHead = normalized.replaceFirstMapped(
        RegExp(r'</head>', caseSensitive: false),
        (match) => '$previewFitHead</head>',
      );
      if (withFitHead != normalized) {
        return withFitHead;
      }
    }

    if (RegExp(r'<html[^>]*>', caseSensitive: false).hasMatch(normalized)) {
      return normalized.replaceFirstMapped(
        RegExp(r'<html[^>]*>', caseSensitive: false),
        (match) => '${match.group(0)}\n<head>\n'
            '<meta charset="UTF-8" />\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1.0" />\n'
            '$previewFitHead\n'
            '</head>',
      );
    }

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  $previewFitHead
</head>
<body>
$normalized
</body>
</html>
''';
  }
}
