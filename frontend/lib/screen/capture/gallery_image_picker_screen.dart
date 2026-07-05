import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native_channel.dart';
import '../../core/theme.dart';

class GalleryImagePickerScreen extends StatefulWidget {
  const GalleryImagePickerScreen({super.key});

  @override
  State<GalleryImagePickerScreen> createState() =>
      _GalleryImagePickerScreenState();
}

class _GalleryImagePickerScreenState extends State<GalleryImagePickerScreen>
    with WidgetsBindingObserver {
  List<GalleryImageItem> _items = const [];
  bool _isCheckingPermission = true;
  bool _hasPermission = false;
  bool _isRequestingPermission = false;
  bool _isLoading = true;
  bool _permissionDenied = false;
  Object? _error;
  String? _copyingUri;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionAndLoad();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasPermission) {
      _checkPermissionAndLoad();
    }
  }

  Future<void> _checkPermissionAndLoad() async {
    if (!mounted) return;
    setState(() {
      _isCheckingPermission = true;
      _error = null;
    });
    try {
      final granted = await NativeChannel.hasGalleryPermission();
      if (!mounted) return;
      setState(() {
        _hasPermission = granted;
        _isCheckingPermission = false;
        _isLoading = granted;
        if (granted) {
          _permissionDenied = false;
        }
      });
      if (granted) {
        await _loadImages();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isCheckingPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    if (_isRequestingPermission) return;
    setState(() {
      _isRequestingPermission = true;
      _error = null;
    });
    try {
      final granted = await NativeChannel.requestGalleryPermission();
      if (!mounted) return;
      setState(() {
        _hasPermission = granted;
        _permissionDenied = !granted;
        _isRequestingPermission = false;
        _isLoading = granted;
      });
      if (granted) {
        await _loadImages();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
        _isRequestingPermission = false;
        _error = error;
      });
    }
  }

  Future<void> _openSettings() async {
    await NativeChannel.openAppSettings();
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
      if (error is PlatformException && error.code == 'PERMISSION_DENIED') {
        setState(() {
          _hasPermission = false;
          _permissionDenied = true;
          _isLoading = false;
          _error = null;
        });
        return;
      }
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
            onPressed: _isLoading || _isCheckingPermission
                ? null
                : _checkPermissionAndLoad,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isCheckingPermission)
            const Center(child: CircularProgressIndicator())
          else if (!_hasPermission)
            _buildMessage(
              icon: Icons.photo_library_outlined,
              title: '需要相册权限',
              detail: _permissionDenied
                  ? '系统没有授予相册权限，请在权限弹窗里允许访问照片；如果不再弹窗，就到应用设置里开启照片/相册权限。'
                  : '为了从相册导入题目图片，需要先允许知芽访问照片和图片。',
              actionLabel: _permissionDenied ? '去设置开启' : '允许访问相册',
              onAction: _permissionDenied ? _openSettings : _requestPermission,
              secondaryActionLabel: _permissionDenied ? '重新申请' : null,
              onSecondaryAction: _permissionDenied ? _requestPermission : null,
            )
          else if (_isLoading)
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
    required VoidCallback? onAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
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
              child: _isRequestingPermission
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(actionLabel),
            ),
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isRequestingPermission ? null : onSecondaryAction,
                child: Text(secondaryActionLabel),
              ),
            ],
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
