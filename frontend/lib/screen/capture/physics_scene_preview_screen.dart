import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_ui.dart';
import '../../core/latex_text.dart';
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
                aspectRatio: 0.62,
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

    final gap = size.width * 0.055;
    final panelWidth = size.width - gap * 2;
    final panelHeight = (size.height - gap * 4 - 28) / 2;
    final top = gap;
    final upperPanel = Rect.fromLTWH(gap, top, panelWidth, panelHeight);
    final lowerPanel = Rect.fromLTWH(
      gap,
      top + panelHeight + gap,
      panelWidth,
      panelHeight,
    );

    _drawCasePanel(
      canvas,
      upperPanel,
      title: '甲  r > L',
      bendsEarly: true,
      progress: progress,
    );
    _drawCasePanel(
      canvas,
      lowerPanel,
      title: '乙  r <= L',
      bendsEarly: false,
      progress: (progress + 0.38) % 1,
    );

    _drawText(
      canvas,
      '$particleLabel  从 P 水平射出，磁场左边界可能有两种位置',
      Offset(gap, size.height - 24),
      color: AppPalette.textSecondary.withValues(alpha: 0.82),
      size: 12,
    );
  }

  void _drawCasePanel(
    Canvas canvas,
    Rect panel, {
    required String title,
    required bool bendsEarly,
    required double progress,
  }) {
    final panelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(18)),
      panelPaint,
    );
    _drawText(
      canvas,
      title,
      panel.topLeft.translate(12, 10),
      color: AppPalette.almondCream,
      size: 12,
    );

    final plot = Rect.fromLTWH(
      panel.left + panel.width * 0.13,
      panel.top + panel.height * 0.18,
      panel.width * 0.78,
      panel.height * 0.72,
    );
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final helperPaint = Paint()
      ..color = AppPalette.matchaMist.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(plot.left, plot.bottom), Offset(plot.right, plot.bottom), axisPaint);
    canvas.drawLine(Offset(plot.left, plot.bottom), Offset(plot.left, plot.top), axisPaint);
    _drawArrowHead(canvas, Offset(plot.right, plot.bottom), 0, axisPaint.color);
    _drawArrowHead(canvas, Offset(plot.left, plot.top), -math.pi / 2, axisPaint.color);

    final p = Offset(plot.left, plot.top + plot.height * 0.20);
    final q = Offset(plot.right - plot.width * 0.05, plot.bottom);
    final fieldLeft = bendsEarly ? plot.left + plot.width * 0.34 : plot.left + plot.width * 0.58;
    final fieldRect = Rect.fromLTWH(
      fieldLeft,
      plot.top + plot.height * 0.02,
      plot.width * 0.28,
      plot.height * 0.78,
    );
    _drawField(canvas, fieldRect);
    _drawText(
      canvas,
      'L',
      fieldRect.topCenter.translate(-4, -17),
      color: AppPalette.textSecondary,
      size: 11,
    );

    final straightEnd = Offset(fieldLeft, p.dy);
    final path = Path()
      ..moveTo(p.dx, p.dy)
      ..lineTo(straightEnd.dx, straightEnd.dy);
    if (bendsEarly) {
      path.quadraticBezierTo(
        fieldLeft + fieldRect.width * 0.78,
        p.dy + plot.height * 0.22,
        q.dx - plot.width * 0.05,
        q.dy,
      );
    } else {
      final arcStart = Offset(fieldRect.left + fieldRect.width * 0.58, p.dy);
      path.lineTo(arcStart.dx, arcStart.dy);
      path.quadraticBezierTo(
        fieldRect.right + plot.width * 0.18,
        p.dy + plot.height * 0.45,
        q.dx - plot.width * 0.02,
        q.dy,
      );
    }

    final tracePaint = Paint()
      ..color = AppPalette.almondCream
      ..strokeWidth = 2.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, tracePaint);
    _drawDashedLine(canvas, Offset(q.dx, p.dy), q, helperPaint);
    _drawDashedLine(canvas, straightEnd, Offset(q.dx, p.dy), helperPaint);

    final metrics = path.computeMetrics().iterator;
    final tangent = metrics.moveNext()
        ? metrics.current.getTangentForOffset(
            metrics.current.length * progress,
          )
        : null;
    if (tangent != null) {
      canvas.drawCircle(
        tangent.position,
        12,
        Paint()
          ..color = AppPalette.almondCream.withValues(alpha: 0.16)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        tangent.position,
        5,
        Paint()
          ..color = chargeSign == 'negative' ? const Color(0xFF9ED6FF) : AppPalette.honeyOrange
          ..style = PaintingStyle.fill,
      );
    }

    _drawPoint(canvas, p, 'P');
    _drawPoint(canvas, q, 'Q', labelAbove: false);
    _drawVector(
      canvas,
      p.translate(4, 0),
      p.translate(math.min(36, plot.width * 0.22), 0),
      Paint()
        ..color = AppPalette.almondCream
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    _drawText(canvas, 'v0', p.translate(28, -18), color: AppPalette.almondCream, size: 11);
    _drawText(canvas, 'x', Offset(plot.right + 4, plot.bottom - 5), size: 11);
    _drawText(canvas, 'y', Offset(plot.left + 4, plot.top - 15), size: 11);
  }

  void _drawField(Canvas canvas, Rect fieldRect) {
    final fieldPaint = Paint()
      ..color = AppPalette.matchaMist.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final fieldBorder = Paint()
      ..color = AppPalette.matchaMist.withValues(alpha: 0.34)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(10)),
      fieldPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(10)),
      fieldBorder,
    );
    final marker = fieldMarker == 'dot' ? '•' : '×';
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(fieldRect.deflate(2), const Radius.circular(8)),
    );
    for (var x = fieldRect.left + 14; x < fieldRect.right - 6; x += 24) {
      for (var y = fieldRect.top + 20; y < fieldRect.bottom - 8; y += 26) {
        _drawText(
          canvas,
          marker,
          Offset(x, y),
          color: AppPalette.textSecondary.withValues(alpha: 0.62),
          size: 14,
          align: TextAlign.center,
        );
      }
    }
    canvas.restore();
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final vector = end - start;
    final distance = vector.distance;
    if (distance <= 0) {
      return;
    }
    final direction = vector / distance;
    var drawn = 0.0;
    while (drawn < distance) {
      final next = math.min(drawn + 6, distance);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * next,
        paint,
      );
      drawn += 11;
    }
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
            child: AppLatexText(
              _formulaAsLatex(formula),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formulaAsLatex(String formula) {
  final trimmed = formula.trim();
  if (trimmed.startsWith(r'$')) {
    return trimmed;
  }
  return r'$$' + _normalizeFormulaLatex(trimmed) + r'$$';
}

String _normalizeFormulaLatex(String formula) {
  var text = formula;
  text = text.replaceAllMapped(
    RegExp(r'\bsqrt\((.*)\)'),
    (match) => r'\sqrt{' + (match.group(1) ?? '') + '}',
  );
  text = text.replaceAllMapped(
    RegExp(r'\b(theta|Delta|arcsin|sin|cos|cot)\b'),
    (match) {
      final command = match.group(1) ?? '';
      return '\\$command';
    },
  );
  text = text.replaceAllMapped(
    RegExp(r'\b([A-Za-z])([0-9]+)\b'),
    (match) => '${match.group(1)}_${match.group(2)}',
  );
  return text;
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
