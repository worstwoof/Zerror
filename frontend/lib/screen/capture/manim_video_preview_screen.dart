// ignore_for_file: spelling

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

enum _VideoPreviewStatus { loading, ready, fallback, failed }

class ManimVideoPreviewScreen extends StatefulWidget {
  const ManimVideoPreviewScreen({
    super.key,
    required this.title,
    required this.videoUrl,
    this.absoluteVideoUrl = '',
    this.jobId = '',
    this.jobStatus = '',
    this.progress,
    this.message = '',
    this.error = '',
    this.diagnostics = const {},
  });

  final String title;
  final String videoUrl;
  final String absoluteVideoUrl;
  final String jobId;
  final String jobStatus;
  final int? progress;
  final String message;
  final String error;
  final Map<String, dynamic> diagnostics;

  @override
  State<ManimVideoPreviewScreen> createState() => _ManimVideoPreviewScreenState();
}

class _ManimVideoPreviewScreenState extends State<ManimVideoPreviewScreen> {
  late final String _videoUrl;
  late final VideoPlayerController _controller;
  WebViewController? _webViewController;
  _VideoPreviewStatus _status = _VideoPreviewStatus.loading;
  bool _useWebViewFallback = false;
  bool _diagnosticsExpanded = false;
  String _errorMessage = '';
  Map<String, dynamic> _runtimeDiagnostics = const {};

  @override
  void initState() {
    super.initState();
    _videoUrl = _absoluteUrl(widget.videoUrl, widget.absoluteVideoUrl);
    _controller = VideoPlayerController.networkUrl(Uri.parse(_videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _status = _VideoPreviewStatus.ready;
        });
      }).catchError((error) {
        if (!mounted) return;
        setState(() {
          _status = _VideoPreviewStatus.fallback;
          _useWebViewFallback = true;
          _errorMessage = error.toString();
          _runtimeDiagnostics = {
            ..._runtimeDiagnostics,
            'native_error': error.toString(),
          };
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = _buildDiagnostics();
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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatusBanner(),
              const SizedBox(height: 12),
              Expanded(child: Center(child: _buildBody())),
              const SizedBox(height: 12),
              _buildDiagnosticsPanel(diagnostics),
            ],
          ),
        ),
      ),
      floatingActionButton:
          !_useWebViewFallback && _controller.value.isInitialized
              ? FloatingActionButton(
                  backgroundColor: AppPalette.almondCream,
                  foregroundColor: AppPalette.night,
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                )
              : null,
    );
  }

  Widget _buildBody() {
    if (_status == _VideoPreviewStatus.failed) {
      return _buildFailureState();
    }

    if (_useWebViewFallback) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _ensureWebViewController()),
            ),
            _buildFullscreenButton(),
          ],
        ),
      );
    }

    if (!_controller.value.isInitialized) {
      return const CircularProgressIndicator(color: AppPalette.almondCream);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          _buildFullscreenButton(),
        ],
      ),
    );
  }

  Widget _buildFullscreenButton() {
    return Positioned(
      top: 10,
      right: 10,
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        child: IconButton(
          tooltip: '横屏全屏',
          icon: const Icon(Icons.fullscreen_rounded),
          color: Colors.white,
          onPressed: _openLandscapePlayer,
        ),
      ),
    );
  }

  Future<void> _openLandscapePlayer() async {
    final wasPlaying = !_useWebViewFallback && _controller.value.isPlaying;
    if (wasPlaying) {
      await _controller.pause();
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LandscapeVideoPlayerScreen(
          videoUrl: _videoUrl,
          useWebView: _useWebViewFallback,
        ),
      ),
    );
    if (wasPlaying && mounted) {
      await _controller.play();
    }
  }

  Widget _buildStatusBanner() {
    final text = switch (_status) {
      _VideoPreviewStatus.loading => '讲解视频正在加载...',
      _VideoPreviewStatus.ready => _useWebViewFallback ? '备用播放器已加载。' : '视频已加载。',
      _VideoPreviewStatus.fallback => '原生播放器不可用，正在切换备用播放器。',
      _VideoPreviewStatus.failed => '讲解视频暂时无法播放，请稍后重试。',
    };
    final color = switch (_status) {
      _VideoPreviewStatus.ready => AppPalette.matchaMist,
      _VideoPreviewStatus.fallback => AppPalette.almondCream,
      _VideoPreviewStatus.failed => const Color(0xFFFFC3B8),
      _VideoPreviewStatus.loading => AppPalette.textSecondary,
    };
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: _status == _VideoPreviewStatus.loading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(
                  _status == _VideoPreviewStatus.ready
                      ? Icons.check_circle_rounded
                      : _status == _VideoPreviewStatus.failed
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

  Widget _buildFailureState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.play_disabled_rounded,
          color: AppPalette.almondCream,
          size: 42,
        ),
        const SizedBox(height: 12),
        const Text(
          '讲解视频暂时无法播放，请稍后重试。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _status = _VideoPreviewStatus.fallback;
              _webViewController = null;
              _useWebViewFallback = true;
            });
          },
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppPalette.almondCream,
          ),
          label: const Text(
            '重试备用播放',
            style: TextStyle(color: AppPalette.almondCream),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: AppPalette.almondCream.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
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

  WebViewController _ensureWebViewController() {
    final existing = _webViewController;
    if (existing != null) {
      return existing;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppPalette.night)
      ..addJavaScriptChannel(
        'VideoDiagnostics',
        onMessageReceived: _handleVideoDiagnosticsMessage,
      )
      ..loadHtmlString(
        _buildVideoHtml(_videoUrl),
        baseUrl: AppConstants.apiBaseUrl,
      );
    _webViewController = controller;
    return controller;
  }

  void _handleVideoDiagnosticsMessage(JavaScriptMessage message) {
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
    if (!mounted) return;
    setState(() {
      _runtimeDiagnostics = {
        ..._runtimeDiagnostics,
        ...payload,
        'last_event': event,
      };
      if (event == 'webview_can_play' || event == 'webview_loaded_metadata') {
        _status = _VideoPreviewStatus.ready;
      } else if (event == 'webview_error') {
        _status = _VideoPreviewStatus.failed;
        _errorMessage = _stringValue(payload['error'], _errorMessage);
      }
    });
  }

  Map<String, String> _buildDiagnostics() {
    final diagnostics = <String, String>{
      'status': _status.name,
      'playback': _useWebViewFallback ? 'webview' : 'native',
      'video_url': widget.videoUrl,
      'absolute_video_url': _videoUrl,
    };
    if (widget.jobId.isNotEmpty) diagnostics['job_id'] = widget.jobId;
    if (widget.jobStatus.isNotEmpty) diagnostics['job_status'] = widget.jobStatus;
    if (widget.progress != null) diagnostics['progress'] = '${widget.progress}%';
    if (widget.message.isNotEmpty) diagnostics['message'] = widget.message;
    if (widget.error.isNotEmpty) diagnostics['job_error'] = widget.error;
    if (_errorMessage.isNotEmpty) diagnostics['player_error'] = _errorMessage;
    for (final entry in widget.diagnostics.entries) {
      if (entry.value == null) continue;
      diagnostics['job.${entry.key}'] = entry.value.toString();
    }
    for (final entry in _runtimeDiagnostics.entries) {
      if (entry.value == null) continue;
      diagnostics['runtime.${entry.key}'] = entry.value.toString();
    }
    return diagnostics;
  }

  String _absoluteUrl(String rawUrl, String absoluteUrl) {
    final preferred = absoluteUrl.trim();
    if (preferred.startsWith('http://') || preferred.startsWith('https://')) {
      return preferred;
    }
    final url = rawUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${AppConstants.apiBaseUrl}$url';
    }
    return '${AppConstants.apiBaseUrl}/$url';
  }

  String _buildVideoHtml(String url) {
    final encodedUrl = Uri.encodeFull(url);
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
      background: #11160f;
      display: grid;
      place-items: center;
    }
    .wrap {
      width: 100%;
      height: 100%;
      display: grid;
      place-items: center;
    }
    video {
      width: 100%;
      max-height: 100%;
      background: #000;
    }
    .hint {
      position: fixed;
      left: 16px;
      right: 16px;
      bottom: 16px;
      color: #d6d1c7;
      font: 13px/1.45 sans-serif;
      text-align: center;
      display: none;
    }
    .hint.show {
      display: block;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <video id="video" controls autoplay playsinline preload="auto" src="$encodedUrl"></video>
    <div class="hint">视频地址暂时不可用，请稍后重试。</div>
  </div>
  <script>
    const video = document.getElementById('video');
    const hint = document.querySelector('.hint');
    function postStatus(event, detail) {
      try {
        VideoDiagnostics.postMessage(JSON.stringify(Object.assign({
          event: event,
          ready_state: video.readyState,
          network_state: video.networkState,
          current_src: video.currentSrc || video.src
        }, detail || {})));
      } catch (_) {}
    }
    video.addEventListener('loadedmetadata', function() {
      postStatus('webview_loaded_metadata', {
        duration: Number.isFinite(video.duration) ? video.duration : null
      });
    });
    video.addEventListener('canplay', function() {
      postStatus('webview_can_play');
    });
    video.addEventListener('error', function() {
      hint.classList.add('show');
      const mediaError = video.error;
      postStatus('webview_error', {
        error: mediaError ? String(mediaError.code) : 'unknown'
      });
    });
  </script>
</body>
</html>
''';
  }
}

class _LandscapeVideoPlayerScreen extends StatefulWidget {
  const _LandscapeVideoPlayerScreen({
    required this.videoUrl,
    required this.useWebView,
  });

  final String videoUrl;
  final bool useWebView;

  @override
  State<_LandscapeVideoPlayerScreen> createState() =>
      _LandscapeVideoPlayerScreenState();
}

class _LandscapeVideoPlayerScreenState
    extends State<_LandscapeVideoPlayerScreen> {
  VideoPlayerController? _controller;
  WebViewController? _webViewController;
  bool _ready = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (widget.useWebView) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadHtmlString(
          _buildFullscreenVideoHtml(widget.videoUrl),
          baseUrl: AppConstants.apiBaseUrl,
        );
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
      controller.play();
    }).catchError((error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Center(child: _buildPlayer(controller))),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: '退出全屏',
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(VideoPlayerController? controller) {
    if (widget.useWebView) {
      final webViewController = _webViewController;
      if (webViewController == null) {
        return const CircularProgressIndicator(color: AppPalette.almondCream);
      }
      return WebViewWidget(controller: webViewController);
    }
    if (_error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13),
        ),
      );
    }
    if (!_ready || controller == null) {
      return const CircularProgressIndicator(color: AppPalette.almondCream);
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          colors: const VideoProgressColors(
            playedColor: AppPalette.almondCream,
            bufferedColor: Colors.white24,
            backgroundColor: Colors.white10,
          ),
        ),
        Center(
          child: IconButton(
            iconSize: 56,
            color: Colors.white.withValues(alpha: 0.86),
            icon: Icon(
              controller.value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
            ),
            onPressed: () {
              setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              });
            },
          ),
        ),
      ],
    );
  }

  String _buildFullscreenVideoHtml(String url) {
    final encodedUrl = Uri.encodeFull(url);
    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    html, body { margin: 0; width: 100%; height: 100%; background: #000; }
    body { display: grid; place-items: center; overflow: hidden; }
    video { width: 100vw; height: 100vh; object-fit: contain; background: #000; }
  </style>
</head>
<body>
  <video controls autoplay playsinline preload="auto" src="$encodedUrl"></video>
</body>
</html>
''';
  }
}

String _stringValue(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
