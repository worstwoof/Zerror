import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/native_channel.dart';
import '../../core/theme.dart';

class GalleryImagePickerScreen extends StatefulWidget {
  const GalleryImagePickerScreen({super.key});

  @override
  State<GalleryImagePickerScreen> createState() =>
      _GalleryImagePickerScreenState();
}

class _GalleryImagePickerScreenState extends State<GalleryImagePickerScreen> {
  List<GalleryImageItem> _items = const [];
  bool _isLoading = true;
  Object? _error;
  String? _copyingUri;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await NativeChannel.listGalleryImages(limit: 200);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectImage(GalleryImageItem item) async {
    if (_copyingUri != null) return;
    setState(() => _copyingUri = item.uri);
    try {
      final imagePath = await NativeChannel.copyGalleryImageToCache(item.uri);
      if (!mounted || imagePath == null) return;
      Navigator.of(context).pop(imagePath);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入图片失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _copyingUri = null);
      }
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
        title: const Text(
          '选择题目图片',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _isLoading ? null : _loadImages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _buildMessage(
              icon: Icons.photo_library_outlined,
              title: '没有拿到相册图片',
              detail: '请允许相册权限后重试。\n$_error',
              actionLabel: '重试',
              onAction: _loadImages,
            )
          else if (_items.isEmpty)
            _buildMessage(
              icon: Icons.image_not_supported_outlined,
              title: '相册里还没有可导入图片',
              detail: '可以先截图或保存题目图片，再回到这里选择。',
              actionLabel: '刷新',
              onAction: _loadImages,
            )
          else
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isCopying = _copyingUri == item.uri;
                return _GalleryTile(
                  item: item,
                  isCopying: isCopying,
                  onTap: () => _selectImage(item),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String detail,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppPalette.textSecondary, size: 46),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.item,
    required this.isCopying,
    required this.onTap,
  });

  final GalleryImageItem item;
  final bool isCopying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = item.thumbnailPath;
    return Material(
      color: AppPalette.paper,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isCopying ? null : onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailPath != null)
              Image.file(
                File(thumbnailPath),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) =>
                    const _GalleryTileFallback(),
              )
            else
              const _GalleryTileFallback(),
            if (isCopying)
              Container(
                color: Colors.black.withValues(alpha: 0.42),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTileFallback extends StatelessWidget {
  const _GalleryTileFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppPalette.kombuGreen,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_rounded,
        color: AppPalette.textSecondary,
        size: 28,
      ),
    );
  }
}
