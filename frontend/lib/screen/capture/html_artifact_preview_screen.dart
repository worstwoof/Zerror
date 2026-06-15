import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme.dart';

class HtmlArtifactPreviewScreen extends StatefulWidget {
  const HtmlArtifactPreviewScreen({
    super.key,
    required this.title,
    required this.htmlContent,
    this.infoTitle = 'HTML 学科扩展预览',
    this.infoNote,
    this.scrollable = false,
    this.exportable = false,
  });

  final String title;
  final String htmlContent;
  final String infoTitle;
  final String? infoNote;
  final bool scrollable;
  final bool exportable;

  @override
  State<HtmlArtifactPreviewScreen> createState() =>
      _HtmlArtifactPreviewScreenState();
}

class _HtmlArtifactPreviewScreenState extends State<HtmlArtifactPreviewScreen> {
  static const MethodChannel _printChannel = MethodChannel('zerror/print');
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(
        _prepareHtmlForPreview(
          widget.htmlContent,
          scrollable: widget.scrollable,
        ),
      );
    if (widget.scrollable) {
      unawaited(_controller.enableZoom(true).catchError((Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.cream,
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
        actions: [
          if (widget.exportable)
            IconButton(
              tooltip: '导出 PDF',
              onPressed: _exportPdf,
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppPalette.textPrimary,
              ),
            ),
        ],
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
                  color: AppPalette.pastelGrey.withOpacity(0.10),
                ),
              ),
              child: WebViewWidget(
                controller: _controller,
                gestureRecognizers: widget.scrollable
                    ? {
                        Factory<VerticalDragGestureRecognizer>(
                          () => VerticalDragGestureRecognizer(),
                        ),
                        Factory<HorizontalDragGestureRecognizer>(
                          () => HorizontalDragGestureRecognizer(),
                        ),
                        Factory<ScaleGestureRecognizer>(
                          () => ScaleGestureRecognizer(),
                        ),
                      }
                    : const <Factory<OneSequenceGestureRecognizer>>{},
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    try {
      await _printChannel.invokeMethod<void>('printHtml', {
        'title': _safePrintTitle(widget.title),
        'html': _prepareHtmlForPreview(widget.htmlContent, scrollable: true),
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出 PDF 失败：${error.message ?? error.code}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('当前设备暂不支持导出 PDF：$error')),
      );
    }
  }

  String _safePrintTitle(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return normalized.isEmpty ? '专题讲义' : normalized;
  }

  String _prepareHtmlForPreview(String rawHtml, {required bool scrollable}) {
    final normalized = rawHtml.trim();
    final previewFitHead = scrollable
        ? '''
<meta name="viewport" content="width=device-width, initial-scale=0.75, minimum-scale=0.25, maximum-scale=5.0, user-scalable=yes" />
<style id="zerror-preview-fit">
  html, body {
    margin: 0;
    width: 100%;
    height: auto !important;
    min-height: 100% !important;
    max-height: none !important;
    overflow-x: auto !important;
    overflow-y: auto !important;
    overscroll-behavior: contain;
    -webkit-overflow-scrolling: touch;
    -webkit-text-size-adjust: 100%;
    text-size-adjust: 100%;
  }
  *, *::before, *::after { box-sizing: border-box; }
  body {
    min-width: 0;
    height: auto !important;
    min-height: 100% !important;
    width: max-content;
    min-width: 100%;
    max-width: none !important;
    max-height: none !important;
    overflow-x: auto !important;
    overflow-y: auto !important;
    touch-action: pan-x pan-y pinch-zoom;
  }
  .sheet {
    width: 210mm !important;
    min-width: 210mm !important;
    max-width: none !important;
  }
  img, svg, canvas, video {
    max-width: 100%;
    height: auto;
  }
</style>
<script>
  window.MathJax = {
    tex: {
      inlineMath: [['\\\\(', '\\\\)'], ['\$', '\$']],
      displayMath: [['\\\\[', '\\\\]'], ['\$\$', '\$\$']],
      processEscapes: true
    },
    svg: { fontCache: 'global' },
    options: {
      skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code']
    }
  };
  function zerrorLoadMathJaxFallback() {
    var fallback = document.createElement('script');
    fallback.async = true;
    fallback.src = 'https://unpkg.com/mathjax@3/es5/tex-svg.js';
    document.head.appendChild(fallback);
  }
</script>
<script async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js" onerror="zerrorLoadMathJaxFallback()"></script>
<script>
  window.addEventListener('load', function () {
    var viewport = document.querySelector('meta[name="viewport"]');
    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.name = 'viewport';
      document.head.appendChild(viewport);
    }
    viewport.setAttribute('content', 'width=device-width, initial-scale=0.75, minimum-scale=0.25, maximum-scale=5.0, user-scalable=yes');
    document.documentElement.style.height = 'auto';
    document.documentElement.style.minHeight = '100%';
    document.documentElement.style.maxHeight = 'none';
    document.documentElement.style.overflowX = 'auto';
    document.documentElement.style.overflowY = 'auto';
    document.body.style.height = 'auto';
    document.body.style.minHeight = '100%';
    document.body.style.maxHeight = 'none';
    document.body.style.width = 'max-content';
    document.body.style.minWidth = '100%';
    document.body.style.maxWidth = 'none';
    document.body.style.overflowX = 'auto';
    document.body.style.overflowY = 'auto';
    document.body.style.touchAction = 'pan-x pan-y pinch-zoom';
    if (window.MathJax && window.MathJax.typesetPromise) {
      window.MathJax.typesetPromise();
    }
  });
</script>
'''
        : '''
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
