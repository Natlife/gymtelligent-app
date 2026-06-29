import 'dart:math' as math;

class Point3D {
  final double x;
  final double y;
  final double z;

  const Point3D(this.x, this.y, this.z);
}

class RepCounterService {
  
  final Map<String, int> _counters = {
    "push_up": 0,
    "squat": 0,
    "bicep_curl": 0,
    "shoulder_press": 0,
  };

  
  final Map<String, String?> _stages = {
    "push_up": null,
    "squat": null,
    "right_bicep_curl": null,
    "left_bicep_curl": null,
    "shoulder_press": null,
  };

  /// 0.0 = start of rep, 1.0 = end of rep (peak position reached).
  /// This reflects progress within the CURRENT single rep cycle.
  double _currentRepProgress = 0.0;

  double getCurrentRepProgress() => _currentRepProgress;

  
  void reset() {
    _counters.updateAll((key, value) => 0);
    _stages.updateAll((key, value) => null);
    _currentRepProgress = 0.0;
  }

  int getCounter(String exerciseKey) => _counters[exerciseKey] ?? 0;
  String? getStage(String key) => _stages[key];

  
  double calculateAngle(Point3D a, Point3D b, Point3D c) {
    double radians = math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    double degrees = radians * (180.0 / math.pi);
    if (degrees < 0) {
      degrees += 360;
    }
    return degrees;
  }

  /// Maps a value from [inMin,inMax] → [outMin,outMax] and clamps.
  double _mapAngle(double value, double inMin, double inMax,
      double outMin, double outMax) {
    final ratio = (value - inMin) / (inMax - inMin);
    return (outMin + ratio * (outMax - outMin)).clamp(outMin, outMax);
  }

  
  void update(String predictedLabel, Map<int, Point3D> landmarks) {
    final label = predictedLabel.toLowerCase().trim();

    if (label == "push-up" || label == "push_up") {
      if (landmarks.containsKey(11) && landmarks.containsKey(13) && landmarks.containsKey(15)) {
        final leftArm = calculateAngle(landmarks[11]!, landmarks[13]!, landmarks[15]!);

        // down phase: ~160°–220°, up phase: ~220°–260°
        // Progress: 0.0 at fully down (160°), 1.0 at fully up (245°)
        if (_stages["push_up"] != "up") {
          // Going down → 0.0
          _currentRepProgress = _mapAngle(leftArm, 260, 160, 1.0, 0.0);
        } else {
          // Already counted, reset toward 0 for next rep
          _currentRepProgress = _mapAngle(leftArm, 220, 260, 0.0, 1.0);
        }

        if (leftArm < 220) {
          _stages["push_up"] = "down";
        }
        if (leftArm > 240 && _stages["push_up"] == "down") {
          _stages["push_up"] = "up";
          _counters["push_up"] = (_counters["push_up"] ?? 0) + 1;
          _currentRepProgress = 1.0;
        }
      }
    } else if (label == "squat") {
      if (landmarks.containsKey(24) && landmarks.containsKey(26) && landmarks.containsKey(28) &&
          landmarks.containsKey(23) && landmarks.containsKey(25) && landmarks.containsKey(27)) {
        final rightLeg = calculateAngle(landmarks[24]!, landmarks[26]!, landmarks[28]!);

        // Squat: standing ~170°+, bottom ~<140°
        // Progress: 0.0 at standing (170°+), 1.0 at bottom (<140°), back to 0 when standing again
        final stage = _stages["squat"];
        if (stage == null || stage == "up") {
          // Going down from standing
          _currentRepProgress = _mapAngle(rightLeg, 165, 135, 0.0, 1.0);
        } else {
          // Coming back up
          _currentRepProgress = _mapAngle(rightLeg, 135, 165, 1.0, 0.0);
        }

        if (rightLeg > 160 && landmarks.containsKey(25)) {
          final leftLeg = calculateAngle(landmarks[23]!, landmarks[25]!, landmarks[27]!);
          if (leftLeg < 220) _stages["squat"] = "down";
        }
        if (rightLeg < 140) {
          final leftLeg = calculateAngle(landmarks[23]!, landmarks[25]!, landmarks[27]!);
          if (leftLeg > 210 && _stages["squat"] == "down") {
            _stages["squat"] = "up";
            _counters["squat"] = (_counters["squat"] ?? 0) + 1;
            _currentRepProgress = 0.0; // rep complete → reset for next
          }
        }
      }
    } else if (label == "barbell biceps curl" || label == "bicep_curl" || label == "barbell biceps curl".replaceAll(' ', '_')) {
      if (landmarks.containsKey(12) && landmarks.containsKey(14) && landmarks.containsKey(16) &&
          landmarks.containsKey(11) && landmarks.containsKey(13) && landmarks.containsKey(15)) {
        final rightArm = calculateAngle(landmarks[12]!, landmarks[14]!, landmarks[16]!);
        final leftArm = calculateAngle(landmarks[11]!, landmarks[13]!, landmarks[15]!);

        // Bicep curl: arm extended ~160°–200°, fully curled: >310° or <60°
        // Use right arm as the primary angle indicator
        // Progress: 0.0 at extended (180°), 1.0 at top (curled, ~330° or ~30°)
        double rightProgress;
        final rDown = rightArm > 160 && rightArm < 210;
        if (rDown) {
          rightProgress = 0.0;
        } else if (rightArm >= 210 && rightArm <= 310) {
          rightProgress = _mapAngle(rightArm, 200, 310, 0.0, 1.0);
        } else {
          // >310 or <60 → fully curled
          rightProgress = 1.0;
        }
        _currentRepProgress = rightProgress;

        if (rightArm > 160 && rightArm < 200) {
          _stages["right_bicep_curl"] = "down";
        }
        if (leftArm > 140 && leftArm < 200) {
          _stages["left_bicep_curl"] = "down";
        }

        final rightTop = rightArm > 310 || rightArm < 60;
        final leftTop = leftArm > 310 || leftArm < 60;

        if (_stages["right_bicep_curl"] == "down" &&
            _stages["left_bicep_curl"] == "down" &&
            rightTop &&
            leftTop) {
          _stages["right_bicep_curl"] = "up";
          _stages["left_bicep_curl"] = "up";
          _counters["bicep_curl"] = (_counters["bicep_curl"] ?? 0) + 1;
          _currentRepProgress = 1.0;
        }
      }
    } else if (label == "shoulder press" || label == "shoulder_press" || label == "shoulder press".replaceAll(' ', '_')) {
      if (landmarks.containsKey(12) && landmarks.containsKey(14) && landmarks.containsKey(16) &&
          landmarks.containsKey(11) && landmarks.containsKey(13) && landmarks.containsKey(15)) {
        final rightArm = calculateAngle(landmarks[12]!, landmarks[14]!, landmarks[16]!);

        // Shoulder press: down ~280°+, up ~<240°
        // Progress: 0.0 at down (280°+), 1.0 at fully pressed up (<240°)
        _currentRepProgress = _mapAngle(rightArm, 280, 240, 0.0, 1.0);

        if (rightArm > 280) {
          final leftArm = calculateAngle(landmarks[11]!, landmarks[13]!, landmarks[15]!);
          if (leftArm < 80) _stages["shoulder_press"] = "down";
        }
        if (rightArm < 240) {
          final leftArm = calculateAngle(landmarks[11]!, landmarks[13]!, landmarks[15]!);
          if (leftArm > 120 && _stages["shoulder_press"] == "down") {
            _stages["shoulder_press"] = "up";
            _counters["shoulder_press"] = (_counters["shoulder_press"] ?? 0) + 1;
            _currentRepProgress = 1.0;
          }
        }
      }
    }
  }
}
