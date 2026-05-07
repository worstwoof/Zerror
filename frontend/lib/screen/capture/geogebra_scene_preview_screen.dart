import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme.dart';

class GeoGebraScenePreviewScreen extends StatefulWidget {
  const GeoGebraScenePreviewScreen({
    super.key,
    required this.title,
    required this.spec,
  });

  final String title;
  final Map<String, dynamic> spec;

  @override
  State<GeoGebraScenePreviewScreen> createState() =>
      _GeoGebraScenePreviewScreenState();
}

class _GeoGebraScenePreviewScreenState extends State<GeoGebraScenePreviewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(_buildGeoGebraHtml(widget.spec));
  }

  @override
  Widget build(BuildContext context) {
    final geogebra = _mapValue(widget.spec['geogebra']);
    final caption = _stringValue(
      geogebra['caption'],
      '拖动图形中的点或滑块，观察参数变化。',
    );

    return Scaffold(
      backgroundColor: AppPalette.night,
      appBar: AppBar(
        backgroundColor: AppPalette.night,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppPalette.pastelGrey.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GeoGebra 交互图',
                      style: TextStyle(
                        color: AppPalette.almondCream,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      caption,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
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
            ],
          ),
        ),
      ),
    );
  }

  String _buildGeoGebraHtml(Map<String, dynamic> spec) {
    final directHtml = _stringValue(spec['html'], '');
    if (directHtml.trim().isNotEmpty) {
      return directHtml;
    }
    final geogebra = _mapValue(spec['geogebra']);
    final commands = [
      ..._stringList(spec['commands']),
      ..._stringList(geogebra['commands']),
    ];
    final commandsJson = jsonEncode(commands);
    final appName = _stringValue(geogebra['app_name'], 'classic');

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    html, body, #ggb-element {
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #ffffff;
    }
    .loading {
      height: 100%;
      display: grid;
      place-items: center;
      font-family: sans-serif;
      color: #34413d;
    }
  </style>
  <script src="https://www.geogebra.org/apps/deployggb.js"></script>
</head>
<body>
  <div id="ggb-element"><div class="loading">正在加载 GeoGebra...</div></div>
  <script>
    const commands = $commandsJson;
    const params = {
      appName: "$appName",
      width: window.innerWidth,
      height: window.innerHeight,
      showToolBar: false,
      showAlgebraInput: false,
      showMenuBar: false,
      showResetIcon: true,
      enableLabelDrags: true,
      enableShiftDragZoom: true,
      useBrowserForJS: false,
      appletOnLoad: function(api) {
        try {
          api.setCoordSystem(-1, 12, -1, 6);
          commands.forEach(function(command) {
            if (command && command.trim()) {
              api.evalCommand(command);
            }
          });
          api.setAxesVisible(true, true);
          api.setGridVisible(false);
        } catch (error) {
          document.body.innerHTML = '<pre style="padding:16px;color:#222;white-space:pre-wrap;">GeoGebra 加载失败：' + error + '</pre>';
        }
      }
    };
    const applet = new GGBApplet(params, true);
    window.addEventListener('load', function() {
      applet.inject('ggb-element');
    });
  </script>
</body>
</html>
''';
  }
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _stringValue(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
