import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/ai_api_client.dart';
import 'error_edit_screen.dart';

class ErrorPreviewScreen extends StatefulWidget {
  const ErrorPreviewScreen({
    super.key,
    required this.imagePath,
  });

  final String imagePath;

  @override
  State<ErrorPreviewScreen> createState() => _ErrorPreviewScreenState();
}

class _ErrorPreviewScreenState extends State<ErrorPreviewScreen> {
  static const Rect _defaultSelection = Rect.fromLTWH(0.12, 0.18, 0.76, 0.46);
  static const double _minSelectionEdge = 24;
  static const double _handleTouchRadius = 22;

  final AiApiClient _apiClient = const AiApiClient();
  bool _isRecognizing = false;
  Size? _sourceImageSize;
  Rect _selection = _defaultSelection;
  _SelectionDragMode _dragMode = _SelectionDragMode.none;
  Offset? _dragStartPoint;
  Rect? _dragStartRect;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _sourceImageSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
      });
      image.dispose();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法读取图片尺寸，请重新选择图片。'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _startOCR() async {
    if (_sourceImageSize == null) {
      return;
    }

    setState(() {
      _isRecognizing = true;
    });

    try {
      final croppedImagePath = await _cropSelectionToTempFile();
      final payload = await _apiClient.analyzeImage(
        imagePath: croppedImagePath,
        enableSubjectExtensions: true,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecognizing = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ErrorEditScreen(
            imagePath: croppedImagePath,
            initialText: payload.extractedText,
            initialAnalysis: payload.analysis,
          ),
        ),
      );
    } on AiApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecognizing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image analysis failed: ${error.message}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecognizing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('图片裁剪或分析失败，请重新框选后再试。'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<String> _cropSelectionToTempFile() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    try {
      final srcRect = Rect.fromLTWH(
        _selection.left * image.width,
        _selection.top * image.height,
        _selection.width * image.width,
        _selection.height * image.height,
      ).intersect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );

      final targetWidth = srcRect.width.round().clamp(1, image.width);
      final targetHeight = srcRect.height.round().clamp(1, image.height);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        srcRect,
        Rect.fromLTWH(
          0,
          0,
          targetWidth.toDouble(),
          targetHeight.toDouble(),
        ),
        Paint(),
      );

      final picture = recorder.endRecording();
      final cropped = await picture.toImage(targetWidth, targetHeight);

      try {
        final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw const FormatException('Missing PNG bytes');
        }
        final pngBytes = byteData.buffer.asUint8List();
        final outputPath = '${Directory.systemTemp.path}${Platform.pathSeparator}'
            'zerror-crop-${DateTime.now().microsecondsSinceEpoch}.png';
        await File(outputPath).writeAsBytes(pngBytes, flush: true);
        return outputPath;
      } finally {
        cropped.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  Rect _computeImageRect(Size availableSize) {
    final imageSize = _sourceImageSize;
    if (imageSize == null || imageSize.width == 0 || imageSize.height == 0) {
      return Offset.zero & availableSize;
    }

    final imageRatio = imageSize.width / imageSize.height;
    final boxRatio = availableSize.width / availableSize.height;

    if (imageRatio > boxRatio) {
      final height = availableSize.width / imageRatio;
      final top = (availableSize.height - height) / 2;
      return Rect.fromLTWH(0, top, availableSize.width, height);
    }

    final width = availableSize.height * imageRatio;
    final left = (availableSize.width - width) / 2;
    return Rect.fromLTWH(left, 0, width, availableSize.height);
  }

  void _handlePanStart(DragStartDetails details, Rect imageRect) {
    final point = _clampPointToImage(details.localPosition, imageRect);
    if (point == null) {
      return;
    }

    final selectionRect = _selectionRectForPaint(imageRect);
    final handle = _hitTestHandle(point, selectionRect);
    final mode = handle ??
        (selectionRect.contains(point)
            ? _SelectionDragMode.move
            : _SelectionDragMode.create);

    final seedRect = mode == _SelectionDragMode.create
        ? Rect.fromPoints(point, point)
        : selectionRect;

    setState(() {
      _dragMode = mode;
      _dragStartPoint = point;
      _dragStartRect = seedRect;
      if (mode == _SelectionDragMode.create) {
        _selection = _normalizedRect(seedRect, imageRect);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, Rect imageRect) {
    if (_dragMode == _SelectionDragMode.none ||
        _dragStartPoint == null ||
        _dragStartRect == null) {
      return;
    }

    final point = _clampPointToImage(details.localPosition, imageRect);
    if (point == null) {
      return;
    }

    Rect nextRect;
    switch (_dragMode) {
      case _SelectionDragMode.create:
        nextRect = Rect.fromPoints(_dragStartPoint!, point);
        break;
      case _SelectionDragMode.move:
        nextRect = _translateRect(
          _dragStartRect!,
          point - _dragStartPoint!,
          imageRect,
        );
        break;
      case _SelectionDragMode.resizeTopLeft:
        nextRect = _resizeRect(
          _dragStartRect!,
          left: point.dx,
          top: point.dy,
          imageRect: imageRect,
        );
        break;
      case _SelectionDragMode.resizeTopRight:
        nextRect = _resizeRect(
          _dragStartRect!,
          right: point.dx,
          top: point.dy,
          imageRect: imageRect,
        );
        break;
      case _SelectionDragMode.resizeBottomLeft:
        nextRect = _resizeRect(
          _dragStartRect!,
          left: point.dx,
          bottom: point.dy,
          imageRect: imageRect,
        );
        break;
      case _SelectionDragMode.resizeBottomRight:
        nextRect = _resizeRect(
          _dragStartRect!,
          right: point.dx,
          bottom: point.dy,
          imageRect: imageRect,
        );
        break;
      case _SelectionDragMode.none:
        return;
    }

    if (nextRect.width < _minSelectionEdge || nextRect.height < _minSelectionEdge) {
      return;
    }

    setState(() {
      _selection = _normalizedRect(nextRect, imageRect);
    });
  }

  void _handlePanEnd() {
    setState(() {
      _dragMode = _SelectionDragMode.none;
      _dragStartPoint = null;
      _dragStartRect = null;
    });
  }

  Offset? _clampPointToImage(Offset point, Rect imageRect) {
    if (!imageRect.inflate(16).contains(point)) {
      return null;
    }
    return Offset(
      point.dx.clamp(imageRect.left, imageRect.right),
      point.dy.clamp(imageRect.top, imageRect.bottom),
    );
  }

  Rect _selectionRectForPaint(Rect imageRect) {
    return Rect.fromLTWH(
      imageRect.left + imageRect.width * _selection.left,
      imageRect.top + imageRect.height * _selection.top,
      imageRect.width * _selection.width,
      imageRect.height * _selection.height,
    );
  }

  Rect _normalizedRect(Rect rect, Rect imageRect) {
    return Rect.fromLTWH(
      ((rect.left - imageRect.left) / imageRect.width).clamp(0.0, 1.0),
      ((rect.top - imageRect.top) / imageRect.height).clamp(0.0, 1.0),
      (rect.width / imageRect.width).clamp(0.0, 1.0),
      (rect.height / imageRect.height).clamp(0.0, 1.0),
    );
  }

  Rect _translateRect(Rect rect, Offset delta, Rect imageRect) {
    var shifted = rect.shift(delta);
    if (shifted.left < imageRect.left) {
      shifted = shifted.shift(Offset(imageRect.left - shifted.left, 0));
    }
    if (shifted.right > imageRect.right) {
      shifted = shifted.shift(Offset(imageRect.right - shifted.right, 0));
    }
    if (shifted.top < imageRect.top) {
      shifted = shifted.shift(Offset(0, imageRect.top - shifted.top));
    }
    if (shifted.bottom > imageRect.bottom) {
      shifted = shifted.shift(Offset(0, imageRect.bottom - shifted.bottom));
    }
    return shifted;
  }

  Rect _resizeRect(
    Rect rect, {
    double? left,
    double? top,
    double? right,
    double? bottom,
    required Rect imageRect,
  }) {
    final nextLeft =
        (left ?? rect.left).clamp(imageRect.left, rect.right - _minSelectionEdge);
    final nextTop =
        (top ?? rect.top).clamp(imageRect.top, rect.bottom - _minSelectionEdge);
    final nextRight =
        (right ?? rect.right).clamp(rect.left + _minSelectionEdge, imageRect.right);
    final nextBottom =
        (bottom ?? rect.bottom).clamp(rect.top + _minSelectionEdge, imageRect.bottom);

    return Rect.fromLTRB(nextLeft, nextTop, nextRight, nextBottom);
  }

  _SelectionDragMode? _hitTestHandle(Offset point, Rect rect) {
    final handles = <_SelectionDragMode, Offset>{
      _SelectionDragMode.resizeTopLeft: rect.topLeft,
      _SelectionDragMode.resizeTopRight: rect.topRight,
      _SelectionDragMode.resizeBottomLeft: rect.bottomLeft,
      _SelectionDragMode.resizeBottomRight: rect.bottomRight,
    };

    for (final entry in handles.entries) {
      if ((entry.value - point).distance <= _handleTouchRadius) {
        return entry.key;
      }
    }
    return null;
  }

  void _resetSelection() {
    setState(() {
      _selection = _defaultSelection;
      _dragMode = _SelectionDragMode.none;
      _dragStartPoint = null;
      _dragStartRect = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.night,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text(
          '图片框选',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppPalette.pastelGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppPalette.pastelGrey.withValues(alpha: 0.10),
                ),
              ),
              child: const Text(
                '在图片上拖动框选题目区域。分析时只会上传框内的小图，不会把整张原图发到云端。',
                style: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: AppPalette.kombuGreen,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppPalette.pastelGrey.withValues(alpha: 0.08),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final imageRect = _computeImageRect(canvasSize);
                  final selectionRect = _selectionRectForPaint(imageRect);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) => _handlePanStart(details, imageRect),
                    onPanUpdate: (details) => _handlePanUpdate(details, imageRect),
                    onPanEnd: (_) => _handlePanEnd(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.contain,
                        ),
                        CustomPaint(
                          painter: _SelectionOverlayPainter(
                            imageRect: imageRect,
                            selectionRect: selectionRect,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            decoration: BoxDecoration(
              color: AppPalette.night.withValues(alpha: 0.94),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: AppPalette.pastelGrey.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isRecognizing ? null : _resetSelection,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.textPrimary,
                          side: BorderSide(
                            color: AppPalette.pastelGrey.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.crop_free_rounded, size: 18),
                        label: const Text('重置框选'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isRecognizing ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.textPrimary,
                          side: BorderSide(
                            color: AppPalette.pastelGrey.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('重新选择'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isRecognizing || _sourceImageSize == null ? null : _startOCR,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.almondCream,
                      foregroundColor: AppPalette.night,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isRecognizing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppPalette.night,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '分析框选内容',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SelectionDragMode {
  none,
  create,
  move,
  resizeTopLeft,
  resizeTopRight,
  resizeBottomLeft,
  resizeBottomRight,
}

class _SelectionOverlayPainter extends CustomPainter {
  const _SelectionOverlayPainter({
    required this.imageRect,
    required this.selectionRect,
  });

  final Rect imageRect;
  final Rect selectionRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.46);
    final framePaint = Paint()
      ..color = AppPalette.almondCream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final guidePaint = Paint()
      ..color = AppPalette.almondCream.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final handlePaint = Paint()..color = AppPalette.almondCream;

    final overlayPath = Path()
      ..addRect(Offset.zero & size)
      ..addRect(selectionRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, overlayPaint);

    canvas.drawRect(selectionRect, framePaint);

    final thirdWidth = selectionRect.width / 3;
    final thirdHeight = selectionRect.height / 3;
    for (var index = 1; index <= 2; index++) {
      final dx = selectionRect.left + thirdWidth * index;
      final dy = selectionRect.top + thirdHeight * index;
      canvas.drawLine(
        Offset(dx, selectionRect.top),
        Offset(dx, selectionRect.bottom),
        guidePaint,
      );
      canvas.drawLine(
        Offset(selectionRect.left, dy),
        Offset(selectionRect.right, dy),
        guidePaint,
      );
    }

    for (final point in <Offset>[
      selectionRect.topLeft,
      selectionRect.topRight,
      selectionRect.bottomLeft,
      selectionRect.bottomRight,
    ]) {
      canvas.drawCircle(point, 5, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter oldDelegate) {
    return oldDelegate.imageRect != imageRect ||
        oldDelegate.selectionRect != selectionRect;
  }
}
