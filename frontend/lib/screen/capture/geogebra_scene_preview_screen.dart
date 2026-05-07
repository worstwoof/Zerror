import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme.dart';

enum _PreviewStatus { loading, ready, fallback, failed }

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
  _PreviewStatus _status = _PreviewStatus.loading;
  int _variantIndex = 0;
  bool _diagnosticsExpanded = false;
  Map<String, dynamic> _runtimeDiagnostics = const {};

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'PreviewDiagnostics',
        onMessageReceived: _handleDiagnosticsMessage,
      );
    _loadCurrentScene(resetStatus: false);
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
        '拖动点或滑块，观察图形关系变化。',
      ),
    );
    final diagnostics = _buildDiagnostics(
      metadata: metadata,
      commands: commands,
      variants: variants,
      isValid: isValid,
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
              const SizedBox(height: 10),
              _buildStatusBanner(isValid),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              _buildDiagnosticsPanel(diagnostics),
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
            isValid ? 'GeoGebra 交互图' : '图形不可用',
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
              _chip('$commandCount 条命令'),
              if (variantCount > 1) _chip('$variantCount 种情形'),
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
          '情形 ${entry.key + 1}',
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

  Widget _buildStatusBanner(bool isValid) {
    final text = !isValid
        ? '当前题目没有可渲染的 GeoGebra 命令。'
        : switch (_status) {
            _PreviewStatus.loading => 'GeoGebra 正在加载...',
            _PreviewStatus.ready => '交互图已加载。',
            _PreviewStatus.fallback => 'GeoGebra 加载不稳定，已切换本地示意图。',
            _PreviewStatus.failed => '交互图暂时无法显示，请稍后重试。',
          };
    final color = switch (_status) {
      _PreviewStatus.ready => AppPalette.matchaMist,
      _PreviewStatus.fallback => AppPalette.almondCream,
      _PreviewStatus.failed => const Color(0xFFFFC3B8),
      _PreviewStatus.loading => AppPalette.textSecondary,
    };
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: _status == _PreviewStatus.loading && isValid
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(
                  _status == _PreviewStatus.ready
                      ? Icons.check_circle_rounded
                      : _status == _PreviewStatus.failed
                          ? Icons.error_outline_rounded
                          : Icons.info_outline_rounded,
                  color: color,
                  size: 16,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailureState(Map<String, dynamic> metadata) {
    final errors = _stringList(metadata['errors']);
    final fallback = _stringValue(
      metadata['fallback_text'],
      'GeoGebra 命令不可用，请补充题目信息或重新生成。',
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

  Widget _buildDiagnosticsPanel(Map<String, String> diagnostics) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                _diagnosticsExpanded = !_diagnosticsExpanded;
              });
            },
            onLongPress: () {
              setState(() {
                _diagnosticsExpanded = true;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.bug_report_outlined,
                    color: AppPalette.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '诊断信息',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _diagnosticsExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppPalette.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_diagnosticsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: diagnostics.entries
                    .map((entry) => _diagnosticRow(entry.key, entry.value))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _diagnosticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 11.5,
          height: 1.35,
        ),
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

  void _loadCurrentScene({bool resetStatus = true}) {
    if (resetStatus && mounted) {
      setState(() {
        _status = _PreviewStatus.loading;
        _runtimeDiagnostics = const {};
      });
    }
    _controller.loadHtmlString(
      _buildGeoGebraHtml(widget.spec, _variantIndex),
      baseUrl: 'https://www.geogebra.org',
    );
  }

  void _handleDiagnosticsMessage(JavaScriptMessage message) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(message.message);
      payload = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'event': message.message};
    } catch (_) {
      payload = <String, dynamic>{'event': message.message};
    }
    final event = (payload['event'] ?? '').toString();
    final status = switch (event) {
      'applet_ready' => _PreviewStatus.ready,
      'fallback_rendered' => _PreviewStatus.fallback,
      'render_failed' => _PreviewStatus.failed,
      _ => _status,
    };
    if (!mounted) return;
    setState(() {
      _status = status;
      _runtimeDiagnostics = {
        ..._runtimeDiagnostics,
        ...payload,
        'last_event': event.isEmpty ? payload.toString() : event,
      };
    });
  }

  Map<String, String> _buildDiagnostics({
    required Map<String, dynamic> metadata,
    required List<String> commands,
    required List<Map<String, dynamic>> variants,
    required bool isValid,
  }) {
    final diagnostics = <String, String>{
      'status': _status.name,
      'valid': isValid.toString(),
      'command_count': commands.length.toString(),
      'variant_count': variants.length.toString(),
      'scene_type': _stringValue(metadata['scene_type'], '-'),
      'source': _stringValue(metadata['source'], '-'),
      'last_event': _stringValue(_runtimeDiagnostics['last_event'], '-'),
    };
    for (final entry in _runtimeDiagnostics.entries) {
      if (entry.value == null) continue;
      diagnostics['webview.${entry.key}'] = entry.value.toString();
    }
    final errors = _stringList(metadata['errors']);
    final warnings = _stringList(metadata['warnings']);
    if (errors.isNotEmpty) {
      diagnostics['metadata.errors'] = errors.join(' | ');
    }
    if (warnings.isNotEmpty) {
      diagnostics['metadata.warnings'] = warnings.join(' | ');
    }
    return diagnostics;
  }

  String _buildGeoGebraHtml(Map<String, dynamic> spec, int variantIndex) {
    final directHtml = _stringValue(spec['html']);
    if (directHtml.trim().isNotEmpty) {
      return directHtml;
    }
    final geogebra = _mapValue(spec['geogebra']);
    final metadata = _mapValue(spec['metadata']);
    final sceneType = _stringValue(metadata['scene_type'], _stringValue(spec['scene_type']));
    if (sceneType == 'charged_particle_magnetic_field' ||
        sceneType == 'electromagnetism') {
      return _buildElectromagnetismDemoHtml(spec, variantIndex);
    }
    final commands = _commandsForVariant(spec, variantIndex);
    final sceneTypeJson = jsonEncode(sceneType);
    final commandsJson = jsonEncode(commands);
    final appNameJson = jsonEncode(_stringValue(geogebra['app_name'], 'classic'));
    final fallbackText = jsonEncode(
      _stringValue(
        spec['fallback_text'],
        _stringValue(
          metadata['fallback_text'],
          'GeoGebra 暂时没有加载成功，已显示本地示意图。',
        ),
      ),
    );

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
    .fallback {
      box-sizing: border-box;
      width: 100%;
      height: 100%;
      padding: 14px;
      font-family: sans-serif;
      color: #24312d;
      background: #fff;
    }
    .fallback svg {
      width: 100%;
      height: calc(100% - 48px);
      min-height: 260px;
      display: block;
    }
    .fallback-note {
      min-height: 40px;
      font-size: 13px;
      line-height: 1.45;
      color: #52625d;
      overflow: hidden;
    }
  </style>
  <script
    src="https://www.geogebra.org/apps/deployggb.js"
    onload="postStatus('script_loaded')"
    onerror="window.__ggbLoadFailed = true; postStatus('script_failed')">
  </script>
</head>
<body>
  <div id="ggb-element"><div class="loading">正在加载 GeoGebra...</div></div>
  <script>
    const commands = $commandsJson;
    const sceneType = $sceneTypeJson;
    const appName = $appNameJson;
    const fallbackText = $fallbackText;
    let appletReady = false;

    function postStatus(event, detail) {
      try {
        PreviewDiagnostics.postMessage(JSON.stringify(Object.assign({
          event: event,
          command_count: commands.length
        }, detail || {})));
      } catch (_) {}
    }

    function splitArgs(text) {
      const args = [];
      let current = '';
      let depth = 0;
      let quote = '';
      for (let i = 0; i < text.length; i += 1) {
        const ch = text[i];
        if (quote) {
          current += ch;
          if (ch === quote && text[i - 1] !== '\\\\') quote = '';
          continue;
        }
        if (ch === '"' || ch === "'") {
          quote = ch;
          current += ch;
          continue;
        }
        if (ch === '(') depth += 1;
        if (ch === ')') depth -= 1;
        if (ch === ',' && depth === 0) {
          args.push(current.trim());
          current = '';
          continue;
        }
        current += ch;
      }
      if (current.trim()) args.push(current.trim());
      return args;
    }

    function renderFallbackScene(reason, failures) {
      const values = {};
      const points = {};
      const segments = [];
      const polygons = [];
      const curves = [];
      const labels = [];

      function resolveExpression(expression) {
        try {
          const scoped = String(expression).replace(/\\^/g, '**').replace(
            /[A-Za-z_]\\w*/g,
            function(name) {
              return Object.prototype.hasOwnProperty.call(values, name)
                ? String(values[name])
                : name;
            }
          );
          if (/^[0-9+\\-*/().\\s]+\$/.test(scoped)) {
            return Function('"use strict"; return (' + scoped + ')')();
          }
        } catch (_) {}
        return Number(expression) || 0;
      }

      function parsePoint(text) {
        const value = String(text || '').trim();
        if (points[value]) return points[value];
        const match = value.match(/^\\((.*)\\)\$/);
        if (!match) return null;
        const parts = splitArgs(match[1]);
        if (parts.length < 2) return null;
        return { x: resolveExpression(parts[0]), y: resolveExpression(parts[1]) };
      }

      commands.forEach(function(command) {
        const text = String(command || '').trim();
        if (!text) return;
        let match = text.match(/^([A-Za-z_]\\w*)\\s*=\\s*([-+*/().\\w\\s]+)\$/);
        if (match && !text.includes(',')) {
          values[match[1]] = resolveExpression(match[2]);
          return;
        }
        match = text.match(/^([A-Za-z_]\\w*)\\s*=\\s*\\((.*)\\)\$/);
        if (match) {
          const parts = splitArgs(match[2]);
          if (parts.length >= 2) {
            points[match[1]] = {
              x: resolveExpression(parts[0]),
              y: resolveExpression(parts[1])
            };
          }
          return;
        }
        match = text.match(/^([A-Za-z_]\\w*)\\s*=\\s*Segment\\((.*)\\)\$/);
        if (match) {
          const args = splitArgs(match[2]);
          if (args.length >= 2) segments.push([parsePoint(args[0]), parsePoint(args[1])]);
          return;
        }
        match = text.match(/^([A-Za-z_]\\w*)\\s*=\\s*Polygon\\((.*)\\)\$/);
        if (match) {
          polygons.push(splitArgs(match[2]).map(parsePoint).filter(Boolean));
          return;
        }
        match = text.match(/^([A-Za-z_]\\w*)\\s*=\\s*Curve\\((.*)\\)\$/);
        if (match) {
          const args = splitArgs(match[2]);
          if (args.length >= 5) curves.push({ xExpr: args[0], yExpr: args[1] });
          return;
        }
        match = text.match(/^Text\\((.*)\\)\$/);
        if (match) {
          const args = splitArgs(match[1]);
          const rawText = (args[0] || '').replace(/^["']|["']\$/g, '');
          labels.push({ text: rawText, point: parsePoint(args[1]) || { x: 0, y: 0 } });
        }
      });

      const allPoints = Object.values(points);
      polygons.forEach(function(items) { items.forEach(function(point) { allPoints.push(point); }); });
      segments.forEach(function(items) { items.forEach(function(point) { if (point) allPoints.push(point); }); });
      if (!allPoints.length) allPoints.push({ x: 0, y: 0 }, { x: 10, y: 6 });
      const minX = Math.min.apply(null, allPoints.map(function(p) { return p.x; })) - 1;
      const maxX = Math.max.apply(null, allPoints.map(function(p) { return p.x; })) + 1;
      const minY = Math.min.apply(null, allPoints.map(function(p) { return p.y; })) - 1;
      const maxY = Math.max.apply(null, allPoints.map(function(p) { return p.y; })) + 1;
      const width = 720;
      const height = 520;
      const pad = 44;
      function sx(x) { return pad + (x - minX) / Math.max(1, maxX - minX) * (width - pad * 2); }
      function sy(y) { return height - pad - (y - minY) / Math.max(1, maxY - minY) * (height - pad * 2); }
      function esc(text) {
        return String(text).replace(/[&<>"]/g, function(ch) {
          return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[ch];
        });
      }
      function pointMarkup(name, point) {
        return '<circle cx="' + sx(point.x) + '" cy="' + sy(point.y) + '" r="5" fill="#e78b42"/>' +
          '<text x="' + (sx(point.x) + 8) + '" y="' + (sy(point.y) - 8) + '" font-size="16" fill="#24312d">' + esc(name) + '</text>';
      }
      function lineMarkup(points, color, widthValue) {
        if (!points[0] || !points[1]) return '';
        return '<line x1="' + sx(points[0].x) + '" y1="' + sy(points[0].y) + '" x2="' + sx(points[1].x) + '" y2="' + sy(points[1].y) + '" stroke="' + color + '" stroke-width="' + widthValue + '" stroke-linecap="round"/>';
      }
      function polygonMarkup(points) {
        if (points.length < 3) return '';
        return '<polygon points="' + points.map(function(p) { return sx(p.x) + ',' + sy(p.y); }).join(' ') + '" fill="#cfe1d3" stroke="#5f846f" stroke-width="2" opacity="0.7"/>';
      }
      const curveMarkup = curves.map(function(curve) {
        const coords = [];
        for (let i = 0; i <= 44; i += 1) {
          values.t = i / 44;
          coords.push(sx(resolveExpression(curve.xExpr)) + ',' + sy(resolveExpression(curve.yExpr)));
        }
        delete values.t;
        return '<polyline points="' + coords.join(' ') + '" fill="none" stroke="#d56f3e" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>';
      }).join('');
      const svg =
        '<svg viewBox="0 0 ' + width + ' ' + height + '" role="img">' +
        '<rect x="0" y="0" width="' + width + '" height="' + height + '" fill="#ffffff"/>' +
        '<line x1="' + sx(minX) + '" y1="' + sy(0) + '" x2="' + sx(maxX) + '" y2="' + sy(0) + '" stroke="#b7c3bf" stroke-width="1"/>' +
        '<line x1="' + sx(0) + '" y1="' + sy(minY) + '" x2="' + sx(0) + '" y2="' + sy(maxY) + '" stroke="#b7c3bf" stroke-width="1"/>' +
        polygons.map(polygonMarkup).join('') +
        segments.map(function(item) { return lineMarkup(item, '#55756a', 2.5); }).join('') +
        curveMarkup +
        Object.keys(points).map(function(name) { return pointMarkup(name, points[name]); }).join('') +
        labels.map(function(item) {
          return '<text x="' + sx(item.point.x) + '" y="' + sy(item.point.y) + '" font-size="15" fill="#52625d">' + esc(item.text) + '</text>';
        }).join('') +
        '</svg>';
      document.getElementById('ggb-element').innerHTML =
        '<div class="fallback">' + svg +
        '<div class="fallback-note">' + esc(fallbackText) + '</div></div>';
      postStatus('fallback_rendered', {
        reason: reason || '',
        command_failures: failures ? failures.length : 0,
        first_failure: failures && failures.length ? String(failures[0]).slice(0, 160) : ''
      });
    }

    const params = {
      appName: appName,
      width: window.innerWidth,
      height: window.innerHeight,
      showToolBar: false,
      showAlgebraInput: false,
      showMenuBar: false,
      showResetIcon: false,
      showToolBarHelp: false,
      showFullscreenButton: false,
      showZoomButtons: false,
      showAnimationButton: false,
      allowStyleBar: false,
      enableRightClick: false,
      enableLabelDrags: true,
      enableShiftDragZoom: true,
      useBrowserForJS: false,
      perspective: 'G',
      customToolBar: '',
      appletOnLoad: function(api) {
        appletReady = true;
        const failures = [];
        try { api.setErrorDialogsActive(false); } catch (_) {}
        const isMathScene = ['conic', 'circle', 'ellipse', 'hyperbola', 'parabola', 'function_graph', 'locus_tangent'].includes(sceneType);
        try { api.setAxesVisible(isMathScene, isMathScene); } catch (_) {}
        try { api.setGridVisible(isMathScene); } catch (_) {}
        commands.forEach(function(command) {
          if (!command || !command.trim()) return;
          try {
            api.evalCommand(command);
          } catch (error) {
            failures.push(command + ' => ' + error);
          }
        });
        if (isMathScene) {
          const darkObjects = ['C', 'c', 'l', 'line', 'OA', 'OB', 'AB', 'axis'];
          darkObjects.forEach(function(name) {
            try { api.setColor(name, 0, 0, 0); } catch (_) {}
            try { api.setLineThickness(name, name === 'axis' ? 3 : 5); } catch (_) {}
          });
          try { api.setColor('tri', 85, 120, 255); } catch (_) {}
          try { api.setFilling('tri', 0.16); } catch (_) {}
        }
        try {
          if (isMathScene) {
            api.setCoordSystem(-8, 8, -6, 6);
          } else {
            api.setCoordSystem(-2, 12, -2, 7);
          }
        } catch (_) {}
        if (commands.length && failures.length >= commands.length) {
          renderFallbackScene('all_commands_failed', failures);
          return;
        }
        postStatus('applet_ready', {
          command_failures: failures.length,
          first_failure: failures.length ? String(failures[0]).slice(0, 160) : ''
        });
      }
    };

    window.addEventListener('load', function() {
      if (window.__ggbLoadFailed || typeof GGBApplet === 'undefined') {
        renderFallbackScene('script_failed', []);
        return;
      }
      try {
        const applet = new GGBApplet(params, true);
        applet.inject('ggb-element');
      } catch (error) {
        postStatus('render_failed', { reason: String(error).slice(0, 180) });
        renderFallbackScene(String(error), []);
      }
    });

    window.setTimeout(function() {
      if (!appletReady) {
        renderFallbackScene('timeout', []);
      }
    }, 4500);
  </script>
</body>
</html>
''';
  }

  String _buildElectromagnetismDemoHtml(
    Map<String, dynamic> spec,
    int variantIndex,
  ) {
    final metadata = _mapValue(spec['metadata']);
    final variants = _variantList(spec);
    final variant = variants.isEmpty
        ? const <String, dynamic>{}
        : variants[variantIndex.clamp(0, variants.length - 1)];
    final title = jsonEncode(
      _stringValue(variant['title'], _stringValue(metadata['fallback_text'], '磁场中圆周偏转')),
    );
    final condition = jsonEncode(_stringValue(variant['condition']));
    final caption = jsonEncode(
      _stringValue(
        spec['fallback_text'],
        _stringValue(metadata['fallback_text'], '拖动滑块，观察磁场边界、半径和轨迹变化。'),
      ),
    );
    final isNarrowCase = variantIndex == 1;

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    html, body {
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #ffffff;
      color: #202725;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    .demo {
      box-sizing: border-box;
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      gap: 8px;
      padding: 12px;
      background: #fff;
    }
    .controls {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 8px 12px;
      flex: 0 0 auto;
    }
    label {
      display: grid;
      grid-template-columns: 28px 1fr 38px;
      align-items: center;
      gap: 6px;
      color: #52625d;
      font-size: 12px;
      white-space: nowrap;
    }
    input[type="range"] {
      width: 100%;
      accent-color: #6b5bd6;
    }
    .stage {
      flex: 1 1 auto;
      min-height: 0;
      border-radius: 14px;
      overflow: hidden;
      background: #ffffff;
    }
    svg {
      width: 100%;
      height: 100%;
      display: block;
    }
    .hint {
      flex: 0 0 auto;
      color: #66736f;
      font-size: 12px;
      line-height: 1.35;
      max-height: 34px;
      overflow: hidden;
    }
  </style>
</head>
<body>
  <div class="demo">
    <div class="controls">
      <label>a <input id="a" type="range" min="2.4" max="5.2" step="0.1" value="4" /><span id="av">4.0</span></label>
      <label>b <input id="b" type="range" min="8" max="12.5" step="0.1" value="10" /><span id="bv">10.0</span></label>
      <label>L <input id="L" type="range" min="1.4" max="4.8" step="0.1" value="3" /><span id="Lv">3.0</span></label>
      <label>R <input id="R" type="range" min="1.8" max="5.6" step="0.1" value="${isNarrowCase ? '2.5' : '4.2'}" /><span id="Rv">4.2</span></label>
    </div>
    <div class="stage">
      <svg id="scene" viewBox="0 0 720 500" role="img"></svg>
    </div>
    <div class="hint" id="hint"></div>
  </div>
  <script>
    const title = $title;
    const condition = $condition;
    const caption = $caption;
    const narrowCase = ${isNarrowCase ? 'true' : 'false'};
    const svg = document.getElementById('scene');
    const controls = ['a', 'b', 'L', 'R'].map(function(id) {
      return document.getElementById(id);
    });

    function esc(text) {
      return String(text).replace(/[&<>"]/g, function(ch) {
        return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[ch];
      });
    }
    function n(id) { return Number(document.getElementById(id).value); }
    function sx(x) { return 84 + x * 48; }
    function sy(y) { return 410 - y * 58; }
    function arrow(id, color) {
      return '<marker id="' + id + '" markerWidth="10" markerHeight="10" refX="7" refY="3" orient="auto" markerUnits="strokeWidth"><path d="M0,0 L0,6 L8,3 z" fill="' + color + '"/></marker>';
    }
    function line(x1, y1, x2, y2, color, width, dash) {
      return '<line x1="' + sx(x1) + '" y1="' + sy(y1) + '" x2="' + sx(x2) + '" y2="' + sy(y2) + '" stroke="' + color + '" stroke-width="' + width + '" stroke-linecap="round" marker-end="url(#arrow' + color.slice(1) + ')"' + (dash ? ' stroke-dasharray="7 7"' : '') + '/>';
    }
    function text(body, x, y, color, size, extra) {
      return '<text x="' + sx(x) + '" y="' + sy(y) + '" fill="' + color + '" font-size="' + size + '" font-weight="' + (extra || 600) + '">' + esc(body) + '</text>';
    }
    function point(label, x, y, color) {
      return '<circle cx="' + sx(x) + '" cy="' + sy(y) + '" r="4.5" fill="' + color + '"/>' + text(label, x + 0.12, y + 0.22, color, 17, 700);
    }
    function render() {
      const a = n('a');
      const b = n('b');
      const L = n('L');
      const R = n('R');
      const left = narrowCase ? b - L / 2 : b - L;
      const right = left + L;
      const mid = (left + right) / 2;
      const exitY = narrowCase ? 0.75 : 0.35;
      const curve = [];
      for (let i = 0; i <= 44; i += 1) {
        const t = i / 44;
        const x = left + (b - left) * t;
        const y = a - (narrowCase ? a * 0.62 : a * 0.90) * t * t + exitY * t;
        curve.push(sx(x) + ',' + sy(y));
      }
      document.getElementById('av').textContent = a.toFixed(1);
      document.getElementById('bv').textContent = b.toFixed(1);
      document.getElementById('Lv').textContent = L.toFixed(1);
      document.getElementById('Rv').textContent = R.toFixed(1);
      document.getElementById('hint').textContent = caption;
      const crosses = [];
      for (let row = 0; row < 3; row += 1) {
        for (let col = 0; col < 4; col += 1) {
          crosses.push(text('×', left + L * (0.18 + col * 0.22), 0.65 + row * 1.05, '#6f7976', 22, 500));
        }
      }
      svg.innerHTML =
        '<defs>' + arrow('arrow3f4750', '#3f4750') + arrow('arrow6748bd', '#6748bd') + arrow('arrow238552', '#238552') + '</defs>' +
        '<rect width="720" height="500" fill="#fff"/>' +
        '<line x1="48" y1="' + sy(0) + '" x2="676" y2="' + sy(0) + '" stroke="#8b918e" stroke-width="2"/>' +
        '<rect x="' + sx(left) + '" y="' + sy(a + 1.2) + '" width="' + Math.max(42, sx(right) - sx(left)) + '" height="' + (sy(-0.15) - sy(a + 1.2)) + '" fill="#dfeee7" stroke="#6f9f83" stroke-width="2" opacity="0.78"/>' +
        crosses.join('') +
        '<polyline points="' + curve.join(' ') + '" fill="none" stroke="#7a45d8" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>' +
        line(0, a, left, a, '#3f4750', 3.5, false) +
        line(b, exitY, b, 0, '#3f4750', 2.6, false) +
        line(0, a, left + 1.05, a + 0.6, '#6748bd', 3.4, false) +
        line(mid, 1.2, mid + Math.min(1.2, R / 3), 1.2 + Math.min(1.5, R / 2.8), '#238552', 3.4, false) +
        line(left, a, b, exitY, '#e36f62', 2.2, true) +
        point('P', 0, a, '#3f4750') +
        point('Q', b, 0, '#3f4750') +
        text(title, left + 0.2, a + 1.55, '#202725', 21, 800) +
        (condition ? text(condition, left + 0.2, a + 1.1, '#52625d', 15, 500) : '') +
        text('磁场 B', mid - 0.35, -0.72, '#5f756d', 18, 700) +
        text('v₀', left + 0.9, a + 0.86, '#6748bd', 17, 700) +
        text('R', mid + 1.0, 2.85, '#238552', 17, 700);
    }
    controls.forEach(function(control) { control.addEventListener('input', render); });
    render();
    try {
      PreviewDiagnostics.postMessage(JSON.stringify({
        event: 'applet_ready',
        command_count: 0,
        renderer: 'electromagnetism_svg_demo'
      }));
    } catch (_) {}
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
  final seen = <String>{};
  return <String>[
    ..._stringList(spec['commands']),
    ..._stringList(geogebra['commands']),
  ].where(seen.add).toList();
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
