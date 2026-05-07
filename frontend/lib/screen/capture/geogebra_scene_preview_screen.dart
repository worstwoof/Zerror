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
  int _variantIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);
    _loadCurrentScene();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _mapValue(widget.spec['metadata']);
    final geogebra = _mapValue(widget.spec['geogebra']);
    final variants = _variantList(widget.spec);
    final commands = _commandsForVariant(widget.spec, _variantIndex);
    final isValid = metadata['valid'] != false && commands.isNotEmpty;
    final caption = _stringValue(
      geogebra['caption'],
      _stringValue(
        metadata['fallback_text'],
        'Drag points or sliders to inspect the graph.',
      ),
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
              _buildHeader(caption, commands.length, variants.length, isValid),
              if (variants.length > 1) ...[
                const SizedBox(height: 10),
                _buildVariantTabs(variants),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: isValid
                    ? ClipRRect(
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
                      )
                    : _buildFailureState(metadata),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    String caption,
    int commandCount,
    int variantCount,
    bool isValid,
  ) {
    return Container(
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
          Text(
            isValid ? 'GeoGebra graph' : 'Graph unavailable',
            style: const TextStyle(
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('$commandCount commands'),
              if (variantCount > 1) _chip('$variantCount cases'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantTabs(List<Map<String, dynamic>> variants) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: variants.asMap().entries.map((entry) {
        final selected = entry.key == _variantIndex;
        final title = _stringValue(
          entry.value['title'],
          'Case ${entry.key + 1}',
        );
        return ChoiceChip(
          selected: selected,
          label: Text(title),
          selectedColor: AppPalette.almondCream.withValues(alpha: 0.22),
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          labelStyle: TextStyle(
            color: selected ? AppPalette.almondCream : AppPalette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(
            color: selected
                ? AppPalette.almondCream.withValues(alpha: 0.45)
                : AppPalette.pastelGrey.withValues(alpha: 0.12),
          ),
          onSelected: (_) {
            setState(() {
              _variantIndex = entry.key;
            });
            _loadCurrentScene();
          },
        );
      }).toList(),
    );
  }

  Widget _buildFailureState(Map<String, dynamic> metadata) {
    final errors = _stringList(metadata['errors']);
    final fallback = _stringValue(
      metadata['fallback_text'],
      'GeoGebra commands are not available. Please regenerate or complete the question text.',
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppPalette.pastelGrey.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppPalette.almondCream,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            fallback,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              errors.join('\n'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFC3B8),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _loadCurrentScene() {
    _controller.loadHtmlString(_buildGeoGebraHtml(widget.spec, _variantIndex));
  }

  String _buildGeoGebraHtml(Map<String, dynamic> spec, int variantIndex) {
    final directHtml = _stringValue(spec['html']);
    if (directHtml.trim().isNotEmpty) {
      return directHtml;
    }
    final geogebra = _mapValue(spec['geogebra']);
    final commands = _commandsForVariant(spec, variantIndex);
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
    .loading, .error {
      height: 100%;
      display: grid;
      place-items: center;
      padding: 16px;
      font-family: sans-serif;
      color: #34413d;
      white-space: pre-wrap;
      text-align: center;
    }
  </style>
  <script src="https://www.geogebra.org/apps/deployggb.js"></script>
</head>
<body>
  <div id="ggb-element"><div class="loading">Loading GeoGebra...</div></div>
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
        const failures = [];
        api.setAxesVisible(true, true);
        api.setGridVisible(false);
        commands.forEach(function(command) {
          if (!command || !command.trim()) return;
          try {
            api.evalCommand(command);
          } catch (error) {
            failures.push(command + " => " + error);
          }
        });
        try {
          api.setCoordSystem(-2, 12, -2, 7);
        } catch (_) {}
        if (failures.length && failures.length >= commands.length) {
          document.body.innerHTML =
            '<div class="error">GeoGebra commands failed.\\n' +
            failures.slice(0, 4).join('\\n') +
            '</div>';
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

List<String> _commandsForVariant(Map<String, dynamic> spec, int variantIndex) {
  final variants = _variantList(spec);
  if (variants.isNotEmpty) {
    final safeIndex = variantIndex.clamp(0, variants.length - 1).toInt();
    final variantCommands = _stringList(variants[safeIndex]['commands']);
    if (variantCommands.isNotEmpty) {
      return variantCommands;
    }
  }
  final geogebra = _mapValue(spec['geogebra']);
  return [
    ..._stringList(spec['commands']),
    ..._stringList(geogebra['commands']),
  ].toSet().toList();
}

List<Map<String, dynamic>> _variantList(Map<String, dynamic> spec) {
  final raw = spec['scene_variants'];
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
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

String _stringValue(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
