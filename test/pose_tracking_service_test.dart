import 'package:flutter_test/flutter_test.dart';
import 'package:gymtelligent/services/pose_tracking_service.dart';
import 'package:gymtelligent/services/rep_counter_service.dart';
import 'package:gymtelligent/services/tcn_pose_features.dart';

void main() {
  Map<int, Point3D> fullPose() {
    final points = <int, Point3D>{};
    for (var i = 0; i < TcnPoseFeatures.landmarkIds.length; i++) {
      final id = TcnPoseFeatures.landmarkIds[i];
      points[id] = Point3D(0.35 + (i % 2) * 0.3, 0.12 + i * 0.065, 0);
    }
    return points;
  }

  test('readiness accepts a confident full pose', () {
    final pose = fullPose();
    final confidence = {for (final id in TcnPoseFeatures.landmarkIds) id: 0.9};

    final result = PoseReadinessEvaluator.evaluate(
      pose,
      confidence,
      modelReady: true,
    );

    expect(result.ready, isTrue);
  });

  test('readiness rejects missing and low-confidence poses', () {
    final missing = PoseReadinessEvaluator.evaluate(
      const {},
      const {},
      modelReady: true,
    );
    expect(missing.ready, isFalse);
    expect(missing.guidance, 'Full body not visible');

    final pose = fullPose();
    final lowConfidence = {
      for (final id in TcnPoseFeatures.landmarkIds) id: 0.3,
    };
    final uncertain = PoseReadinessEvaluator.evaluate(
      pose,
      lowConfidence,
      modelReady: true,
    );
    expect(uncertain.ready, isFalse);
  });

  test('stabilizer damps jitter and resets after a tracking gap', () {
    final stabilizer = PoseFrameStabilizer();
    final start = DateTime(2026);
    final first = stabilizer.smooth(
      {11: const Point3D(0.5, 0.5, 0)},
      {11: 0.9},
      start,
    );
    final jittered = stabilizer.smooth(
      {11: const Point3D(0.52, 0.5, 0)},
      {11: 0.9},
      start.add(const Duration(milliseconds: 66)),
    );
    final afterGap = stabilizer.smooth(
      {11: const Point3D(0.8, 0.5, 0)},
      {11: 0.9},
      start.add(const Duration(seconds: 1)),
    );

    expect(first[11]!.x, 0.5);
    expect(jittered[11]!.x, greaterThan(0.5));
    expect(jittered[11]!.x, lessThan(0.52));
    expect(afterGap[11]!.x, 0.8);
  });
}
