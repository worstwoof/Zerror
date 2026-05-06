import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_ui.dart';
import '../../core/theme.dart';

class PhysicsScenePreviewScreen extends StatefulWidget {
  const PhysicsScenePreviewScreen({
    super.key,
    required this.title,
    required this.spec,
  });

  final String title;
  final Map<String, dynamic> spec;

  @override
  State<PhysicsScenePreviewScreen> createState() =>
      _PhysicsScenePreviewScreenState();
}

class _PhysicsScenePreviewScreenState extends State<PhysicsScenePreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _stringValue(widget.spec['title'], widget.title);
    final summary = _stringValue(widget.spec['summary'], '观察题目中的场区、粒子运动和受力方向。');
    final field = _mapValue(widget.spec['field']);
    final particle = _mapValue(widget.spec['particle']);
    final parameters = _mapValue(widget.spec['parameters']);
    final focusPoints = _stringList(widget.spec['focus_points']);
    final formulaSteps = _mapList(widget.spec['formula_steps']);

    return Scaffold(
      backgroundColor: AppPalette.night,
      appBar: AppBar(
        backgroundColor: AppPalette.night,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text(
          '题目情景动画演示',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AppSurface(
        topSafe: false,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: ListView(
          children: [
            _SceneCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppPalette.almondCream.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppPalette.almondCream,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary,
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SceneCard(
              padding: const EdgeInsets.all(10),
              child: AspectRatio(
                aspectRatio: 1.08,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ChargedParticleFieldPainter(
                        progress: _controller.value,
                        fieldMarker: _stringValue(field['marker'], 'cross'),
                        particleLabel: _stringValue(particle['label'], '带电粒子'),
                        chargeSign: _stringValue(
                          particle['charge_sign'],
                          'unknown',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SceneCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: '场区',
                    value: _stringValue(field['direction_label'], '磁场区域'),
                  ),
                  _InfoChip(
                    label: '粒子',
                    value: _stringValue(particle['label'], '带电粒子'),
                  ),
                  for (final entry in parameters.entries)
                    _InfoChip(label: entry.key, value: entry.value.toString()),
                ],
              ),
            ),
            if (formulaSteps.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SceneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '核心关系',
                      style: TextStyle(
                        color: AppPalette.almondCream,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final step in formulaSteps)
                      _FormulaLine(
                        label: _stringValue(step['label'], '关系式'),
                        formula: _stringValue(step['formula'], ''),
                      ),
                  ],
                ),
              ),
            ],
            if (focusPoints.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SceneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '观察重点',
                      style: TextStyle(
                        color: AppPalette.almondCream,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final point in focusPoints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 8, right: 8),
                              decoration: const BoxDecoration(
                                color: AppPalette.almondCream,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChargedParticleFieldPainter extends CustomPainter {
  _ChargedParticleFieldPainter({
    required this.progress,
    required this.fieldMarker,
    required this.particleLabel,
    required this.chargeSign,
  });

  final double progress;
  final String fieldMarker;
  final String particleLabel;
  final String chargeSign;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x332D4B3F), Color(0x11101512)],
      ).createShader(rect);
    final shell = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    canvas.drawRRect(shell, bgPaint);

    final plot = Rect.fromLTWH(
      size.width * 0.11,
      size.height * 0.12,
      size.width * 0.78,
      size.height * 0.70,
    );
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.54)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (var i = 1; i < 4; i++) {
      final x = plot.left + plot.width * i / 4;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    final origin = Offset(plot.left, plot.bottom);
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right + 8, plot.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.left, plot.top - 8),
      axisPaint,
    );
    _drawArrowHead(canvas, Offset(plot.right + 8, plot.bottom), 0, axisPaint.color);
    _drawArrowHead(
      canvas,
      Offset(plot.left, plot.top - 8),
      -math.pi / 2,
      axisPaint.color,
    );

    final fieldRect = Rect.fromLTWH(
      plot.left + plot.width * 0.08,
      plot.top + plot.height * 0.04,
      plot.width * 0.36,
      plot.height * 0.88,
    );
    final fieldPaint = Paint()
      ..color = AppPalette.matchaMist.withValues(alpha: 0.11)
      ..style = PaintingStyle.fill;
    final fieldBorder = Paint()
      ..color = AppPalette.matchaMist.withValues(alpha: 0.36)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(16)),
      fieldPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(16)),
      fieldBorder,
    );

    final marker = fieldMarker == 'dot' ? '•' : '×';
    for (var x = fieldRect.left + 20; x < fieldRect.right; x += 34) {
      for (var y = fieldRect.top + 24; y < fieldRect.bottom; y += 34) {
        _drawText(
          canvas,
          marker,
          Offset(x, y),
          color: AppPalette.textSecondary.withValues(alpha: 0.62),
          size: 16,
          align: TextAlign.center,
        );
      }
    }

    final p = Offset(plot.left, plot.top + plot.height * 0.28);
    final q = Offset(plot.left + plot.width * 0.72, plot.bottom);
    final c1 = Offset(plot.left + plot.width * 0.16, plot.top + plot.height * 0.24);
    final c2 = Offset(plot.left + plot.width * 0.42, plot.bottom - plot.height * 0.10);
    final path = Path()
      ..moveTo(p.dx, p.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, q.dx, q.dy);

    final tracePaint = Paint()
      ..color = AppPalette.almondCream.withValues(alpha: 0.95)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, tracePaint);

    final helperPaint = Paint()
      ..color = AppPalette.matchaMist.withValues(alpha: 0.48)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(p, Offset(plot.left, plot.bottom), helperPaint);
    canvas.drawLine(q, Offset(q.dx, p.dy), helperPaint);
    canvas.drawLine(Offset(q.dx, p.dy), q, helperPaint);

    final metric = path.computeMetrics().first;
    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent != null) {
      final glow = Paint()
        ..color = AppPalette.almondCream.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tangent.position, 16, glow);
      final particlePaint = Paint()
        ..color = chargeSign == 'negative'
            ? const Color(0xFF9ED6FF)
            : AppPalette.almondCream
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tangent.position, 6.5, particlePaint);
    }

    final velocityPaint = Paint()
      ..color = AppPalette.almondCream
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final forcePaint = Paint()
      ..color = const Color(0xFF9ED6FF)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    _drawVector(canvas, p.translate(8, 0), p.translate(52, 0), velocityPaint);
    _drawVector(canvas, p.translate(72, 28), p.translate(72, -22), forcePaint);

    _drawPoint(canvas, p, 'P(0,a)');
    _drawPoint(canvas, q, 'Q(b,0)', labelAbove: false);
    _drawText(
      canvas,
      particleLabel,
      p.translate(46, -30),
      color: AppPalette.textSecondary,
      size: 12,
    );
    _drawText(
      canvas,
      'v0',
      p.translate(54, -2),
      color: AppPalette.almondCream,
      size: 12,
    );
    _drawText(
      canvas,
      'F',
      p.translate(78, -36),
      color: const Color(0xFF9ED6FF),
      size: 12,
    );
    _drawText(canvas, 'x', Offset(plot.right + 13, plot.bottom - 8));
    _drawText(canvas, 'y', Offset(plot.left + 7, plot.top - 16));
    _drawText(
      canvas,
      '磁场区域',
      fieldRect.topLeft.translate(12, 10),
      color: AppPalette.textSecondary,
      size: 12,
    );
    _drawText(
      canvas,
      '轨迹由 App 原生模板绘制',
      Offset(origin.dx, size.height - 18),
      color: AppPalette.textSecondary.withValues(alpha: 0.76),
      size: 12,
    );
  }

  void _drawPoint(
    Canvas canvas,
    Offset point,
    String label, {
    bool labelAbove = true,
  }) {
    final paint = Paint()
      ..color = AppPalette.honeyOrange
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 4.8, paint);
    _drawText(
      canvas,
      label,
      point.translate(8, labelAbove ? -22 : 8),
      color: AppPalette.textPrimary,
      size: 12,
    );
  }

  void _drawVector(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    _drawArrowHead(canvas, end, angle, paint.color);
  }

  void _drawArrowHead(Canvas canvas, Offset tip, double angle, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - 8 * math.cos(angle - math.pi / 7),
        tip.dy - 8 * math.sin(angle - math.pi / 7),
      )
      ..lineTo(
        tip.dx - 8 * math.cos(angle + math.pi / 7),
        tip.dy - 8 * math.sin(angle + math.pi / 7),
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    Color color = AppPalette.textSecondary,
    double size = 12,
    TextAlign align = TextAlign.left,
  }) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w600,
      ),
    );
    final painter = TextPainter(
      text: span,
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ChargedParticleFieldPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fieldMarker != fieldMarker ||
        oldDelegate.particleLabel != particleLabel ||
        oldDelegate.chargeSign != chargeSign;
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppPalette.pastelGrey.withValues(alpha: 0.10),
        ),
      ),
      child: child,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.almondCream.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppPalette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FormulaLine extends StatelessWidget {
  const _FormulaLine({required this.label, required this.formula});

  final String label;
  final String formula;

  @override
  Widget build(BuildContext context) {
    if (formula.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppPalette.night.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppPalette.pastelGrey.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              formula,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _stringValue(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
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

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}
