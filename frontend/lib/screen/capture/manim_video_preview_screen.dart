import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  late final VideoPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(_absoluteUrl(widget.videoUrl)))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
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
      floatingActionButton: _controller.value.isInitialized
          ? FloatingActionButton(
              backgroundColor: AppPalette.almondCream,
              foregroundColor: AppPalette.night,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
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
    if (_hasError) {
      return const Text(
        '讲解视频暂时无法播放，请稍后重试。',
        style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
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
}

