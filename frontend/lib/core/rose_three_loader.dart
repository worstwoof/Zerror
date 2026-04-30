import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

class RoseThreeLoader extends StatefulWidget {
  const RoseThreeLoader({
    super.key,
    this.size = 156,
    this.color = AppPalette.almondCream,
  });

  final double size;
  final Color color;

  @override
  State<RoseThreeLoader> createState() => _RoseThreeLoaderState();
}

class _RoseThreeLoaderState extends State<RoseThreeLoader>
    with TickerProviderStateMixin {
  late final AnimationController _pathController;
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5300),
    )..repeat();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 28000),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    )..repeat();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pathController,
            _rotationController,
            _pulseController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              painter: _RoseThreePainter(
                progress: _pathController.value,
                rotation: -_rotationController.value * math.pi * 2,
                pulse: _pulseController.value,
                color: widget.color,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoseThreePainter extends CustomPainter {
  const _RoseThreePainter({
    required this.progress,
    required this.rotation,
    required this.pulse,
    required this.color,
  });

  static const int _particleCount = 76;
  static const double _trailSpan = 0.31;
  static const double _strokeWidth = 4.6;
  static const double _roseA = 9.2;
  static const double _roseABoost = 0.6;
  static const double _roseBreathBase = 0.72;
  static const double _roseBreathBoost = 0.28;
  static const double _roseScale = 3.25;

  final double progress;
  final double rotation;
  final double pulse;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final scale = shortest / 100;
    final offset = Offset(
      (size.width - shortest) / 2,
      (size.height - shortest) / 2,
    );
    final detailScale = _detailScale(pulse);

    canvas.save();
    canvas.translate(offset.dx + shortest / 2, offset.dy + shortest / 2);
    canvas.rotate(rotation);
    canvas.translate(-shortest / 2, -shortest / 2);

    final pathPaint = Paint()
      ..color = color.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _strokeWidth * scale;

    canvas.drawPath(_buildPath(scale, detailScale), pathPaint);

    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < _particleCount; index++) {
      final tailOffset = index / (_particleCount - 1);
      final point =
          _point(_normalize(progress - tailOffset * _trailSpan), detailScale);
      final fade = math.pow(1 - tailOffset, 0.56).toDouble();
      particlePaint.color = color.withValues(alpha: 0.04 + fade * 0.96);
      canvas.drawCircle(
        Offset(point.dx * scale, point.dy * scale),
        (0.9 + fade * 2.7) * scale,
        particlePaint,
      );
    }

    canvas.restore();
  }

  Path _buildPath(double scale, double detailScale) {
    const steps = 320;
    final path = Path();
    for (var index = 0; index <= steps; index++) {
      final point = _point(index / steps, detailScale);
      final x = point.dx * scale;
      final y = point.dy * scale;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  Offset _point(double progress, double detailScale) {
    final t = progress * math.pi * 2;
    final a = _roseA + detailScale * _roseABoost;
    final r = a *
        (_roseBreathBase + detailScale * _roseBreathBoost) *
        math.cos(3 * t);
    return Offset(
      50 + math.cos(t) * r * _roseScale,
      50 + math.sin(t) * r * _roseScale,
    );
  }

  double _detailScale(double pulse) {
    final pulseAngle = pulse * math.pi * 2;
    return 0.52 + ((math.sin(pulseAngle + 0.55) + 1) / 2) * 0.48;
  }

  double _normalize(double value) {
    return ((value % 1) + 1) % 1;
  }

  @override
  bool shouldRepaint(covariant _RoseThreePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.color != color;
  }
}
