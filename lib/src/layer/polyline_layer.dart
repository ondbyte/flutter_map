import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/helpers/helpers.dart';
import 'package:flutter_map/src/map/map.dart';
import 'package:latlong2/latlong.dart';

class PolylineLayerOptions extends LayerOptions<Polyline> {
  final List<Polyline> polylines;
  final bool polylineCulling;

  PolylineLayerOptions({
    Key? key,
    this.polylines = const [],
    this.polylineCulling = false,
    Stream<Null>? rebuild,
  }) : super(
          key: key,
          rebuild: rebuild,
        ) {
    if (polylineCulling) {
      for (var polyline in polylines) {
        polyline.boundingBox = LatLngBounds.fromPoints(polyline.points);
      }
    }
  }
}

typedef Null PolylineCallback(Marker);

typedef PolylineBuilder = Widget Function(
  BuildContext context,
  List<LatLng> points,
  List<Offset> offsets,
  LatLngBounds? boundingBox,
);

class Polyline extends MapElement<PolylineBuilder, Polyline> {
  final List<LatLng> points;
  final List<Offset> offsets = [];
  LatLngBounds? boundingBox;

  Polyline({
    PolylineCallback? onTap,
    required String id,
    required PolylineBuilder builder,
    required this.points,
  }) : super(
            builder: builder,
            id: id,
            onDrag: null,
            onTap: onTap,
            delta: LatLng.zero(),
            zIndex: 0);

  @override
  Polyline copyWithNewDelta(LatLng location) {
    // TODO: implement copyWithNewPoint
    throw UnimplementedError();
  }
}

class PolylineLayerWidget extends StatelessWidget {
  final PolylineLayerOptions options;

  PolylineLayerWidget({Key? key, required this.options}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mapState = MapState.maybeOf(context)!;
    return PolylineLayer(options, mapState, mapState.onMoved);
  }
}

class PolylineLayer extends StatelessWidget {
  final PolylineLayerOptions polylineOpts;
  final MapState map;
  final Stream<Null>? stream;

  PolylineLayer(this.polylineOpts, this.map, this.stream)
      : super(key: polylineOpts.key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return _build(context, size);
      },
    );
  }

  Widget _build(BuildContext context, Size size) {
    return StreamBuilder<void>(
      stream: stream, // a Stream<void> or null
      builder: (BuildContext context, _) {
        var polylines = <Widget>[];

        for (var polylineOpt in polylineOpts.polylines) {
          polylineOpt.offsets.clear();

          if (polylineOpts.polylineCulling &&
              (polylineOpt.boundingBox?.isOverlapping(map.bounds) ?? false)) {
            // skip this polyline as it's offscreen
            continue;
          }

          _fillOffsets(polylineOpt.offsets, polylineOpt.points);

          polylines.add(
            SizedBox.fromSize(
              size: size,
              child: polylineOpt.builder(
                context,
                polylineOpt.points,
                polylineOpt.offsets,
                polylineOpt.boundingBox,
              ),
            ),
          );
        }

        return Container(
          child: Stack(
            children: polylines,
          ),
        );
      },
    );
  }

  void _fillOffsets(final List<Offset> offsets, final List<LatLng> points) {
    for (var i = 0, len = points.length; i < len; ++i) {
      var point = points[i];

      var pos = map.project(point);
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) -
          map.getPixelOrigin();
      offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
      if (i > 0) {
        offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
      }
    }
  }
}

class PolylineWidget extends StatelessWidget {
  final List<LatLng> points;
  final List<Offset> offsets;
  final double strokeWidth;
  final Color color;
  final double borderStrokeWidth;
  final Color? borderColor;
  final List<Color>? gradientColors;
  final List<double>? colorsStop;
  final bool isDotted;
  final LatLngBounds? boundingBox;
  const PolylineWidget({
    Key? key,
    required this.points,
    this.strokeWidth = 1.0,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.gradientColors,
    this.colorsStop,
    this.isDotted = false,
    required this.offsets,
    required this.boundingBox,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PolylinePainter(
        boundingBox: boundingBox,
        offsets: offsets,
        points: points,
        borderColor: borderColor,
        borderStrokeWidth: borderStrokeWidth,
        color: color,
        colorsStop: colorsStop,
        gradientColors: gradientColors,
        isDotted: isDotted,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class PolylinePainter extends CustomPainter {
  //final Polyline polylineOpt;
  final List<LatLng> points;
  final List<Offset> offsets;
  final double strokeWidth;
  final Color color;
  final double borderStrokeWidth;
  final Color? borderColor;
  final List<Color>? gradientColors;
  final List<double>? colorsStop;
  final bool isDotted;
  final LatLngBounds? boundingBox;

  PolylinePainter({
    required this.offsets,
    required this.boundingBox,
    required this.points,
    this.strokeWidth = 1.0,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.gradientColors,
    this.colorsStop,
    this.isDotted = false,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (offsets.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.srcOver;

    if (gradientColors == null) {
      paint.color = color;
    } else {
      gradientColors!.isNotEmpty
          ? paint.shader = _paintGradient()
          : paint.color = color;
    }

    Paint? filterPaint;
    if (borderColor != null) {
      filterPaint = Paint()
        ..color = borderColor!.withAlpha(255)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.dstOut;
    }

    final borderPaint = strokeWidth > 0.0
        ? (Paint()
          ..color = borderColor ?? Color(0x00000000)
          ..strokeWidth = strokeWidth + strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..blendMode = BlendMode.srcOver)
        : null;
    var radius = paint.strokeWidth / 2;
    var borderRadius = (borderPaint?.strokeWidth ?? 0) / 2;
    if (isDotted) {
      var spacing = strokeWidth * 1.5;
      canvas.saveLayer(rect, Paint());
      if (borderPaint != null && filterPaint != null) {
        _paintDottedLine(canvas, offsets, borderRadius, spacing, borderPaint);
        _paintDottedLine(canvas, offsets, radius, spacing, filterPaint);
      }
      _paintDottedLine(canvas, offsets, radius, spacing, paint);
      canvas.restore();
    } else {
      paint.style = PaintingStyle.stroke;
      canvas.saveLayer(rect, Paint());
      if (borderPaint != null && filterPaint != null) {
        borderPaint.style = PaintingStyle.stroke;
        _paintLine(canvas, offsets, borderPaint);
        filterPaint.style = PaintingStyle.stroke;
        _paintLine(canvas, offsets, filterPaint);
      }
      _paintLine(canvas, offsets, paint);
      canvas.restore();
    }
  }

  void _paintDottedLine(Canvas canvas, List<Offset> offsets, double radius,
      double stepLength, Paint paint) {
    final path = ui.Path();
    var startDistance = 0.0;
    for (var i = 0; i < offsets.length - 1; i++) {
      var o0 = offsets[i];
      var o1 = offsets[i + 1];
      var totalDistance = _dist(o0, o1);
      var distance = startDistance;
      while (distance < totalDistance) {
        var f1 = distance / totalDistance;
        var f0 = 1.0 - f1;
        var offset = Offset(o0.dx * f0 + o1.dx * f1, o0.dy * f0 + o1.dy * f1);
        path.addOval(Rect.fromCircle(center: offset, radius: radius));
        distance += stepLength;
      }
      startDistance = distance < totalDistance
          ? stepLength - (totalDistance - distance)
          : distance - totalDistance;
    }
    path.addOval(Rect.fromCircle(center: offsets.last, radius: radius));
    canvas.drawPath(path, paint);
  }

  void _paintLine(Canvas canvas, List<Offset> offsets, Paint paint) {
    if (offsets.isNotEmpty) {
      final path = ui.Path()..moveTo(offsets[0].dx, offsets[0].dy);
      for (var offset in offsets) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  ui.Gradient _paintGradient() => ui.Gradient.linear(
      offsets.first, offsets.last, gradientColors!, _getColorsStop());

  List<double>? _getColorsStop() =>
      (colorsStop != null && colorsStop!.length == gradientColors!.length)
          ? colorsStop
          : _calculateColorsStop();

  List<double> _calculateColorsStop() {
    final colorsStopInterval = 1.0 / gradientColors!.length;
    return gradientColors!
        .map<double>((gradientColor) =>
            gradientColors!.indexOf(gradientColor) * colorsStopInterval)
        .toList();
  }

  @override
  bool shouldRepaint(PolylinePainter other) => false;
}

double _dist(Offset v, Offset w) {
  return sqrt(_dist2(v, w));
}

double _dist2(Offset v, Offset w) {
  return _sqr(v.dx - w.dx) + _sqr(v.dy - w.dy);
}

double _sqr(double x) {
  return x * x;
}
