import 'dart:math' as math;

import 'rep_counter_service.dart';

/// Converts the 12 ML Kit landmarks used during training into the exact
/// 48-value TCN input contract.
class TcnPoseFeatures {
  static const landmarkIds = <int>[
    11, 12, // shoulders
    13, 14, // elbows
    15, 16, // wrists
    23, 24, // hips
    25, 26, // knees
    27, 28, // ankles
  ];

  static List<double>? extract(
    Map<int, Point3D> landmarks,
    Map<int, double> confidence,
  ) {
    if (landmarkIds.any((id) => !landmarks.containsKey(id))) return null;

    final points = landmarkIds.map((id) => landmarks[id]!).toList();
    final hipX = (points[6].x + points[7].x) * 0.5;
    final hipY = (points[6].y + points[7].y) * 0.5;
    final shoulderX = (points[0].x + points[1].x) * 0.5;
    final shoulderY = (points[0].y + points[1].y) * 0.5;
    final torso = _distance(hipX, hipY, shoulderX, shoulderY);
    final shoulderWidth = _distance(
      points[0].x,
      points[0].y,
      points[1].x,
      points[1].y,
    );
    final scale = math.max(math.max(torso, shoulderWidth), 0.001);

    final normalized = points
        .map(
          (point) => (x: (point.x - hipX) / scale, y: (point.y - hipY) / scale),
        )
        .toList();

    final result = <double>[];
    for (final point in normalized) {
      result
        ..add(point.x)
        ..add(point.y);
    }
    for (final id in landmarkIds) {
      result.add((confidence[id] ?? 0).clamp(0.0, 1.0).toDouble());
    }

    const angleTriplets = <(int, int, int)>[
      (0, 2, 4),
      (1, 3, 5),
      (2, 0, 6),
      (3, 1, 7),
      (0, 6, 8),
      (1, 7, 9),
      (6, 8, 10),
      (7, 9, 11),
    ];
    for (final (a, b, c) in angleTriplets) {
      result.add(_angle(normalized[a], normalized[b], normalized[c]));
    }

    result
      ..add(normalized[4].y - normalized[0].y)
      ..add(normalized[5].y - normalized[1].y)
      ..add((hipY - shoulderY) / scale)
      ..add(
        ((normalized[10].y + normalized[11].y) -
                (normalized[6].y + normalized[7].y)) *
            0.5,
      );

    assert(result.length == 48);
    return result;
  }

  static double _distance(double ax, double ay, double bx, double by) {
    return math.sqrt(math.pow(ax - bx, 2) + math.pow(ay - by, 2));
  }

  static double _angle(
    ({double x, double y}) a,
    ({double x, double y}) b,
    ({double x, double y}) c,
  ) {
    final bax = a.x - b.x;
    final bay = a.y - b.y;
    final bcx = c.x - b.x;
    final bcy = c.y - b.y;
    final denominator =
        math.sqrt(bax * bax + bay * bay) * math.sqrt(bcx * bcx + bcy * bcy);
    if (denominator < 1e-6) return 0;
    final cosine = ((bax * bcx + bay * bcy) / denominator).clamp(-1.0, 1.0);
    return math.acos(cosine) / math.pi;
  }
}
