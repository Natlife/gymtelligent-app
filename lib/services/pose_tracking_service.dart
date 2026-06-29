import 'dart:math' as math;

import 'rep_counter_service.dart';
import 'tcn_pose_features.dart';

class PoseReadinessResult {
  final bool ready;
  final String guidance;

  const PoseReadinessResult({required this.ready, required this.guidance});
}

class PoseReadinessEvaluator {
  static PoseReadinessResult evaluate(
    Map<int, Point3D> landmarks,
    Map<int, double> confidence, {
    required bool modelReady,
  }) {
    if (!modelReady) {
      return const PoseReadinessResult(
        ready: false,
        guidance: "Loading rep counting model...",
      );
    }
    if (TcnPoseFeatures.landmarkIds.any((id) => !landmarks.containsKey(id))) {
      return const PoseReadinessResult(
        ready: false,
        guidance: "Full body not visible",
      );
    }

    final points = TcnPoseFeatures.landmarkIds
        .map((id) => landmarks[id]!)
        .toList();
    final values = TcnPoseFeatures.landmarkIds
        .map((id) => confidence[id] ?? 0)
        .toList();
    final averageConfidence = values.reduce((a, b) => a + b) / values.length;
    final minimumConfidence = values.reduce(math.min);
    if (averageConfidence < 0.55 || minimumConfidence < 0.25) {
      return const PoseReadinessResult(
        ready: false,
        guidance: "Improve lighting and hold still",
      );
    }

    final minX = points.map((point) => point.x).reduce(math.min);
    final maxX = points.map((point) => point.x).reduce(math.max);
    final minY = points.map((point) => point.y).reduce(math.min);
    final maxY = points.map((point) => point.y).reduce(math.max);
    final span = math.max(maxX - minX, maxY - minY);
    final outsideSafeArea =
        minX < 0.025 || maxX > 0.975 || minY < 0.025 || maxY > 0.975;
    if (outsideSafeArea || span > 0.95) {
      return const PoseReadinessResult(
        ready: false,
        guidance: "Move back and center your body",
      );
    }
    if (span < 0.35) {
      return const PoseReadinessResult(
        ready: false,
        guidance: "Move closer to the camera",
      );
    }
    return const PoseReadinessResult(ready: true, guidance: "Hold position");
  }
}

/// Confidence- and motion-adaptive exponential smoothing.
///
/// Small landmark changes are damped to remove camera jitter. Large changes
/// use a higher alpha so fast exercise motion does not acquire excessive lag.
class PoseFrameStabilizer {
  final Map<int, Point3D> _previous = {};
  DateTime? _previousTimestamp;

  Map<int, Point3D> smooth(
    Map<int, Point3D> raw,
    Map<int, double> confidence,
    DateTime timestamp,
  ) {
    if (_previousTimestamp == null ||
        timestamp.difference(_previousTimestamp!).inMilliseconds > 500) {
      reset();
    }

    final result = <int, Point3D>{};
    for (final entry in raw.entries) {
      final previous = _previous[entry.key];
      if (previous == null) {
        result[entry.key] = entry.value;
        continue;
      }
      final movement = math.sqrt(
        math.pow(entry.value.x - previous.x, 2) +
            math.pow(entry.value.y - previous.y, 2),
      );
      final visibility = (confidence[entry.key] ?? 0).clamp(0.0, 1.0);
      final alpha = (0.32 + movement * 4.0 + visibility * 0.18)
          .clamp(0.35, 0.88)
          .toDouble();
      result[entry.key] = Point3D(
        _mix(previous.x, entry.value.x, alpha),
        _mix(previous.y, entry.value.y, alpha),
        _mix(previous.z, entry.value.z, alpha),
      );
    }

    _previous
      ..clear()
      ..addAll(result);
    _previousTimestamp = timestamp;
    return result;
  }

  void reset() {
    _previous.clear();
    _previousTimestamp = null;
  }

  static double _mix(double previous, double current, double alpha) {
    return previous + (current - previous) * alpha;
  }
}
