// ignore_for_file: spelling

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants.dart';
import '../../core/media_utils.dart';
import '../../core/theme.dart';

enum _VideoPreviewStatus { loading, ready, failed }

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
  State<ManimVideoPreviewScreen> createState() =>
      _ManimVideoPreviewScreenState();
}

class _ManimVideoPreviewScreenState extends State<ManimVideoPreviewScreen> {
  late final String _videoUrl;
  late final WebViewController _controller;
  _VideoPreviewStatus _status = _VideoPreviewStatus.loading;
  String _errorMessage = '';
  bool _nativeFullscreenVisible = false;

  @override
  void initState() {
    super.initState();
    _videoUrl = _absoluteUrl(widget.videoUrl, widget.absoluteVideoUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppPalette.night)
      ..addJavaScriptChannel(
        'VideoDiagnostics',
        onMessageReceived: _handleVideoDiagnosticsMessage,
      );
    _configureAndroidFullscreen();
    _controller.loadHtmlString(
      _buildVideoHtml(_videoUrl),
      baseUrl: AppConstants.apiBaseUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_status == _VideoPreviewStatus.failed) {
      return _buildFailureState();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),
          if (_status == _VideoPreviewStatus.loading)
            const Positioned.fill(
              child: ColoredBox(
                color: AppPalette.night,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppPalette.almondCream,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final text = switch (_status) {
      _VideoPreviewStatus.loading => '讲解视频正在加载...',
      _VideoPreviewStatus.ready => '播放器已加载。',
      _VideoPreviewStatus.failed => '讲解视频暂时无法播放，请稍后重试。',
    };
    final color = switch (_status) {
      _VideoPreviewStatus.ready => AppPalette.matchaMist,
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
              _status = _VideoPreviewStatus.loading;
              _errorMessage = '';
            });
            _controller.loadHtmlString(
              _buildVideoHtml(_videoUrl),
              baseUrl: AppConstants.apiBaseUrl,
            );
          },
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppPalette.almondCream,
          ),
          label: const Text(
            '重新加载',
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
      if (event == 'webview_can_play' || event == 'webview_loaded_metadata') {
        _status = _VideoPreviewStatus.ready;
      } else if (event == 'webview_error') {
        _status = _VideoPreviewStatus.failed;
        _errorMessage = _stringValue(payload['error'], _errorMessage);
      }
    });
  }

  String _absoluteUrl(String rawUrl, String absoluteUrl) {
    final preferred = absoluteUrl.trim();
    if (isRemoteMediaPath(preferred)) {
      return preferred;
    }
    final url = rawUrl.trim();
    if (isRemoteMediaPath(url)) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${AppConstants.apiBaseUrl}$url';
    }
    return '${AppConstants.apiBaseUrl}/$url';
  }

  Future<void> _configureAndroidFullscreen() async {
    final platform = _controller.platform;
    if (platform is! AndroidWebViewController) {
      return;
    }
    await platform.setMediaPlaybackRequiresUserGesture(false);
    await platform.setCustomWidgetCallbacks(
      onShowCustomWidget: _showNativeFullscreenWidget,
      onHideCustomWidget: _hideNativeFullscreenWidget,
    );
  }

  void _showNativeFullscreenWidget(
    Widget widget,
    OnHideCustomWidgetCallback onCustomWidgetHidden,
  ) {
    if (!mounted || _nativeFullscreenVisible) {
      return;
    }
    _nativeFullscreenVisible = true;
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _NativeVideoFullscreenHost(
          onExitRequested: onCustomWidgetHidden,
          child: widget,
        ),
        fullscreenDialog: true,
      ),
    )
        .whenComplete(() {
      _nativeFullscreenVisible = false;
    });
  }

  void _hideNativeFullscreenWidget() {
    if (!_nativeFullscreenVisible || !mounted) {
      return;
    }
    Navigator.of(context).pop();
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

class _NativeVideoFullscreenHost extends StatefulWidget {
  const _NativeVideoFullscreenHost({
    required this.child,
    required this.onExitRequested,
  });

  @override
  State<_NativeVideoFullscreenHost> createState() =>
      _NativeVideoFullscreenHostState();

  final Widget child;
  final VoidCallback onExitRequested;
}

class _NativeVideoFullscreenHostState
    extends State<_NativeVideoFullscreenHost> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onExitRequested();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(child: widget.child),
      ),
    );
  }
}

String _stringValue(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
