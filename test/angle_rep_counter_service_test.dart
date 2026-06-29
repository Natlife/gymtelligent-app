import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymtelligent/services/angle_rep_counter_service.dart';
import 'package:gymtelligent/services/rep_counter_service.dart';

void main() {
  // Builds a pose whose knee angle (hip-knee-ankle) equals [degrees] on both
  // legs, with the other landmarks parked away so only the knee drives counting.
  Map<int, Point3D> squatPose(double degrees) {
    final rad = degrees * math.pi / 180;
    final ankle = Point3D(math.sin(rad), -math.cos(rad), 0);
    const hip = Point3D(0, -1, 0);
    const knee = Point3D(0, 0, 0);
    return {
      23: hip, 25: knee, 27: ankle, // left leg
      24: hip, 26: knee, 28: ankle, // right leg
    };
  }

  Map<int, double> fullConfidence() => {
    for (final id in [23, 24, 25, 26, 27, 28]) id: 1.0,
  };

  test('counts clean squat reps and ignores small jitter', () {
    final counter = AngleRepCounter();
    final confidence = fullConfidence();
    var time = DateTime(2026);
    DateTime tick() {
      time = time.add(const Duration(milliseconds: 60));
      return time;
    }

    void feed(double degrees) {
      counter.update('squat', squatPose(degrees), confidence, tick());
    }

    void doRep() {
      for (var d = 170.0; d >= 80; d -= 6) {
        feed(d);
      }
      for (var d = 80.0; d <= 170; d += 6) {
        feed(d);
      }
    }

    // Establish standing position.
    for (var i = 0; i < 5; i++) {
      feed(172);
    }

    for (var i = 0; i < 5; i++) {
      doRep();
    }

    expect(counter.getCounter('squat'), 5);

    // Tiny tremor around standing must not add reps.
    for (var i = 0; i < 20; i++) {
      feed(168 + (i.isEven ? 2 : -2));
    }
    expect(counter.getCounter('squat'), 5);
  });

  test('holds the count when the joints are not confident', () {
    final counter = AngleRepCounter();
    final lowConfidence = {for (final id in [23, 24, 25, 26, 27, 28]) id: 0.1};
    var time = DateTime(2026);

    for (var d = 170.0; d >= 80; d -= 6) {
      counter.update(
        'squat',
        squatPose(d),
        lowConfidence,
        time = time.add(const Duration(milliseconds: 60)),
      );
    }
    expect(counter.getCounter('squat'), 0);
  });
}
