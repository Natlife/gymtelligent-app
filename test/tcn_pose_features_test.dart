import 'package:flutter_test/flutter_test.dart';
import 'package:gymtelligent/services/rep_counter_service.dart';
import 'package:gymtelligent/services/tcn_pose_features.dart';

void main() {
  test('extracts the exact 48-value finite feature contract', () {
    final landmarks = <int, Point3D>{};
    final confidence = <int, double>{};
    for (var index = 0; index < TcnPoseFeatures.landmarkIds.length; index++) {
      final id = TcnPoseFeatures.landmarkIds[index];
      landmarks[id] = Point3D(0.2 + index * 0.03, 0.1 + index * 0.05, 0);
      confidence[id] = 0.8;
    }

    final features = TcnPoseFeatures.extract(landmarks, confidence);

    expect(features, isNotNull);
    expect(features, hasLength(48));
    expect(features!.every((value) => value.isFinite), isTrue);
    expect(features.sublist(24, 36), everyElement(closeTo(0.8, 1e-9)));
  });

  test('rejects an incomplete skeleton', () {
    expect(TcnPoseFeatures.extract(const {}, const {}), isNull);
  });
}
