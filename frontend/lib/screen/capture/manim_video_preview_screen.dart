// ignore_for_file: spelling

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

class ManimVideoPreviewScreen extends StatefulWidget {
  const ManimVideoPreviewScreen({
    super.key,
    required this.title,
    required this.videoUrl,
  });

  final String title;
  final String videoUrl;

  @override
  State<ManimVideoPreviewScreen> createState() => _ManimVideoPreviewScreenState();
}

class _ManimVideoPreviewScreenState extends State<ManimVideoPreviewScreen> {
  late final String _videoUrl;
  late final VideoPlayerController _controller;
  bool _hasError = false;
  bool _useWebViewFallback = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _videoUrl = _absoluteUrl(widget.videoUrl);
    _controller = VideoPlayerController.networkUrl(Uri.parse(_videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      }).catchError((error) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
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
          child: Center(child: _buildBody()),
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
    if (_useWebViewFallback) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: WebViewWidget(
          controller: WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.transparent)
            ..loadHtmlString(_buildVideoHtml(_videoUrl)),
        ),
      );
    }

    if (_hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '讲解视频暂时无法用原生播放器打开。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _videoUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFC3B8),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _useWebViewFallback = true;
              });
            },
            icon: const Icon(
              Icons.open_in_browser_rounded,
              color: AppPalette.almondCream,
            ),
            label: const Text(
              '用 WebView 播放',
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

    if (!_controller.value.isInitialized) {
      return const CircularProgressIndicator(color: AppPalette.almondCream);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }

  String _absoluteUrl(String rawUrl) {
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
    video {
      width: 100%;
      max-height: 100%;
      background: #000;
    }
  </style>
</head>
<body>
  <video controls autoplay playsinline src="$encodedUrl"></video>
</body>
</html>
''';
  }
}
