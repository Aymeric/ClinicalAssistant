import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_record.dart';
import 'health_trend.dart';

/// Custom painter for rendering clinical time-series trend lines, grid lines,
/// reference ranges, and optional moving averages.
class TrendChartPainter extends CustomPainter {
  const TrendChartPainter({
    required this.points,
    required this.pointIndexes,
    required this.referenceMarks,
    required this.averages,
    required this.totalPoints,
    this.inspectedIndex,
    this.inspectedPoint,
    this.referenceBand,
    this.secondaryPoints,
    this.secondaryIndexes,
    this.secondaryColor,
    required this.color,
    required this.averageColor,
    required this.referenceColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<HealthTrendPoint> points;
  final List<int> pointIndexes;
  final List<HealthTrendReferenceMark> referenceMarks;
  final List<double> averages;
  final int totalPoints;
  final int? inspectedIndex;
  final HealthTrendPoint? inspectedPoint;
  final HealthReferenceRange? referenceBand;
  final List<HealthTrendPoint>? secondaryPoints;
  final List<int>? secondaryIndexes;
  final Color? secondaryColor;
  final Color color;
  final Color averageColor;
  final Color referenceColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;
    const left = 58.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 8.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right < left + 1 ? left + 1 : size.width - right,
      size.height - bottom < top + 1 ? top + 1 : size.height - bottom,
    );
    final values = [
      ...points.map((point) => point.value),
      if (secondaryPoints != null) ...secondaryPoints!.map((p) => p.value),
      ...averages,
      for (final mark in referenceMarks) ?mark.range.lowerBound,
      for (final mark in referenceMarks) ?mark.range.upperBound,
      if (referenceBand?.lowerBound != null) referenceBand!.lowerBound!,
      if (referenceBand?.upperBound != null) referenceBand!.upperBound!,
    ];
    var minimum = values.reduce((a, b) => a < b ? a : b);
    var maximum = values.reduce((a, b) => a > b ? a : b);
    final padding = maximum == minimum
        ? math.max(maximum.abs() * 0.06, 0.5)
        : (maximum - minimum) * 0.12;
    minimum -= padding;
    maximum += padding;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: textColor, fontSize: 11);
    for (var index = 0; index <= 3; index++) {
      final fraction = index / 3;
      final y = plot.top + plot.height * fraction;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final value = maximum - (maximum - minimum) * fraction;
      final textPainter = TextPainter(
        text: TextSpan(text: formatSensibleNumber(value), style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: left - 8);
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    Offset pointOffset(double index, double value) {
      final x =
          plot.left +
          (totalPoints <= 1 ? 0.5 : index / (totalPoints - 1)) * plot.width;
      final y =
          plot.bottom - (value - minimum) / (maximum - minimum) * plot.height;
      return Offset(x, y);
    }

    if (referenceBand != null) {
      final lower = referenceBand!.lowerBound;
      final upper = referenceBand!.upperBound;
      if (lower != null && upper != null) {
        final lowerY = pointOffset(0, lower).dy.clamp(plot.top, plot.bottom);
        final upperY = pointOffset(0, upper).dy.clamp(plot.top, plot.bottom);
        final top = math.min(lowerY, upperY);
        final bottom = math.max(lowerY, upperY);
        canvas.drawRect(
          Rect.fromLTRB(plot.left, top, plot.right, bottom),
          Paint()
            ..color = referenceColor.withValues(alpha: 0.10)
            ..style = PaintingStyle.fill,
        );
        final bandBorderPaint = Paint()
          ..color = referenceColor.withValues(alpha: 0.35)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(plot.left, top), Offset(plot.right, top), bandBorderPaint);
        canvas.drawLine(Offset(plot.left, bottom), Offset(plot.right, bottom), bandBorderPaint);
      } else if (lower != null || upper != null) {
        final bound = lower ?? upper!;
        final y = pointOffset(0, bound).dy.clamp(plot.top, plot.bottom);
        final isMax = upper != null;
        final top = isMax ? y : plot.top;
        final bottom = isMax ? plot.bottom : y;
        canvas.drawRect(
          Rect.fromLTRB(plot.left, top, plot.right, bottom),
          Paint()
            ..color = referenceColor.withValues(alpha: 0.07)
            ..style = PaintingStyle.fill,
        );
        final linePaint = Paint()
          ..color = referenceColor.withValues(alpha: 0.35)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), linePaint);
      }
    }

    final referenceLinePaint = Paint()
      ..color = referenceColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final referenceFillPaint = Paint()
      ..color = referenceColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    for (final mark in referenceMarks) {
      final x = pointOffset(mark.index.toDouble(), minimum).dx;
      final lower = mark.range.lowerBound;
      final upper = mark.range.upperBound;
      if (lower != null && upper != null) {
        final lowerY = pointOffset(mark.index.toDouble(), lower).dy;
        final upperY = pointOffset(mark.index.toDouble(), upper).dy;
        final top = math.min(lowerY, upperY);
        final bottom = math.max(lowerY, upperY);
        canvas.drawRect(
          Rect.fromLTRB(x - 3, top, x + 3, math.max(top + 2, bottom)),
          referenceFillPaint,
        );
        canvas.drawLine(Offset(x, top), Offset(x, bottom), referenceLinePaint);
        canvas.drawLine(
          Offset(x - 4, lowerY),
          Offset(x + 4, lowerY),
          referenceLinePaint,
        );
        canvas.drawLine(
          Offset(x - 4, upperY),
          Offset(x + 4, upperY),
          referenceLinePaint,
        );
      } else {
        final bound = lower ?? upper!;
        final y = pointOffset(mark.index.toDouble(), bound).dy;
        canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), referenceLinePaint);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final line = Path();
    for (var index = 0; index < points.length; index++) {
      final offset = pointOffset(
        pointIndexes[index].toDouble(),
        points[index].value,
      );
      if (index == 0) {
        line.moveTo(offset.dx, offset.dy);
      } else {
        line.lineTo(offset.dx, offset.dy);
      }
    }
    if (points.length == 1) {
      canvas.drawCircle(
        pointOffset(pointIndexes.single.toDouble(), points.single.value),
        4.5,
        Paint()..color = color,
      );
    } else {
      canvas.drawPath(line, linePaint);
      final markerPaint = Paint()..color = color;
      for (var index = 0; index < points.length; index++) {
        if (index % 8 == 0 || index == points.length - 1) {
          final offset = pointOffset(
            pointIndexes[index].toDouble(),
            points[index].value,
          );
          canvas.drawCircle(offset, 3.2, markerPaint);
        }
      }
    }

    if (averages.isNotEmpty && totalPoints >= 3) {
      final averageLine = Path();
      for (var index = 0; index < averages.length; index++) {
        final averageIndex =
            2.0 +
            (averages.length == 1
                ? 0.0
                : index * (totalPoints - 3) / (averages.length - 1));
        final offset = pointOffset(averageIndex, averages[index]);
        if (index == 0) {
          averageLine.moveTo(offset.dx, offset.dy);
        } else {
          averageLine.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        averageLine,
        Paint()
          ..color = averageColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (secondaryPoints != null && secondaryPoints!.isNotEmpty) {
      final secColor = secondaryColor ?? averageColor;
      final secPaint = Paint()
        ..color = secColor
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final secLine = Path();
      final secIndexes = secondaryIndexes ?? List.generate(secondaryPoints!.length, (i) => i);
      final secTotal = secondaryIndexes != null ? totalPoints : secondaryPoints!.length;
      for (var index = 0; index < secondaryPoints!.length; index++) {
        final secOffset = Offset(
          plot.left + (secTotal <= 1 ? 0.5 : secIndexes[index] / (secTotal - 1)) * plot.width,
          plot.bottom - (secondaryPoints![index].value - minimum) / (maximum - minimum) * plot.height,
        );
        if (index == 0) {
          secLine.moveTo(secOffset.dx, secOffset.dy);
        } else {
          secLine.lineTo(secOffset.dx, secOffset.dy);
        }
      }
      canvas.drawPath(secLine, secPaint);
      final secMarkerPaint = Paint()..color = secColor;
      for (var index = 0; index < secondaryPoints!.length; index++) {
        if (index % 8 == 0 || index == secondaryPoints!.length - 1) {
          final secOffset = Offset(
            plot.left + (secTotal <= 1 ? 0.5 : secIndexes[index] / (secTotal - 1)) * plot.width,
            plot.bottom - (secondaryPoints![index].value - minimum) / (maximum - minimum) * plot.height,
          );
          canvas.drawCircle(secOffset, 3.0, secMarkerPaint);
        }
      }
    }

    if (inspectedIndex != null && inspectedPoint != null) {
      final inspectedOffset = pointOffset(
        inspectedIndex!.toDouble(),
        inspectedPoint!.value,
      );
      final guidePaint = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(inspectedOffset.dx, plot.top),
        Offset(inspectedOffset.dx, plot.bottom),
        guidePaint,
      );
      canvas.drawCircle(
        inspectedOffset,
        8.0,
        Paint()..color = color.withValues(alpha: 0.22),
      );
      canvas.drawCircle(inspectedOffset, 4.5, Paint()..color = color);
      canvas.drawCircle(
        inspectedOffset,
        4.5,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.pointIndexes != pointIndexes ||
      oldDelegate.referenceMarks != referenceMarks ||
      oldDelegate.averages != averages ||
      oldDelegate.totalPoints != totalPoints ||
      oldDelegate.inspectedIndex != inspectedIndex ||
      oldDelegate.inspectedPoint != inspectedPoint ||
      oldDelegate.color != color ||
      oldDelegate.averageColor != averageColor ||
      oldDelegate.referenceColor != referenceColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.textColor != textColor;
}

/// Custom painter for the reference range legend indicator showing bounds.
class ReferenceRangeLegendPainter extends CustomPainter {
  const ReferenceRangeLegendPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final center = size.width / 2;
    canvas.drawLine(Offset(center, 1), Offset(center, size.height - 1), paint);
    canvas.drawLine(Offset(1, 1), Offset(size.width - 1, 1), paint);
    canvas.drawLine(
      Offset(1, size.height - 1),
      Offset(size.width - 1, size.height - 1),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ReferenceRangeLegendPainter oldDelegate) =>
      oldDelegate.color != color;
}
