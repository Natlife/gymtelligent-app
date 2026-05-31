import 'dart:math' as math;

class Point3D {
  final double x;
  final double y;
  final double z;

  const Point3D(this.x, this.y, this.z);
}

class RepCounterService {
  // Counters for all exercises
  final Map<String, int> _counters = {
    "push_up": 0,
    "squat": 0,
    "bicep_curl": 0,
    "shoulder_press": 0,
  };

  // Tracking stages
  final Map<String, String?> _stages = {
    "push_up": null,
    "squat": null,
    "right_bicep_curl": null,
    "left_bicep_curl": null,
    "shoulder_press": null,
  };

  // Reset counters
  void reset() {
    _counters.updateAll((key, value) => 0);
    _stages.updateAll((key, value) => null);
  }

  int getCounter(String exerciseKey) => _counters[exerciseKey] ?? 0;
  String? getStage(String key) => _stages[key];

  // Match the Python's angle ABC calculation
  double calculateAngle(Point3D a, Point3D b, Point3D c) {
    double radians = math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    double degrees = radians * (180.0 / math.pi);
    if (degrees < 0) {
      degrees += 360;
    }
    return degrees;
  }

  // Update counters based on prediction label and coordinate map
  void update(String predictedLabel, Map<int, Point3D> landmarks) {
    final label = predictedLabel.toLowerCase().trim();

    if (label == "push-up" || label == "push_up") {
      if (landmarks.containsKey(11) && landmarks.containsKey(13) && landmarks.containsKey(15)) {
        final leftArm = calculateAngle(landmarks[11]!, landmarks[13]!, landmarks[15]!);
        if (leftArm < 220) {
          _stages["push_up"] = "down";
        }
        if (leftArm > 240 && _stages["push_up"] == "down") {
          _stages["push_up"] = "up";
          _counters["push_up"] = (_counters["push_up"] ?? 0) + 1;
        }
      }
    } else if (label == "squat") {
      if (landmarks.containsKey(24) && landmarks.containsKey(26) && landmarks.containsKey(28) &&
          landmarks.containsKey(23) && landmarks.containsKey(25) && landmarks.containsKey(27)) {
        final rightLeg = calculateAngle(landmarks[24]!, landmarks[26]!, landmarks[28]!);
        final leftLeg = calculateAngle(landmarks[23]!, landmarks[25]!, landmarks[27]!);
        if (rightLeg > 160 && leftLeg < 220) {
          _stages["squat"] = "down";
        }
        if (rightLeg < 140 && leftLeg > 210 && _stages["squat"] == "down") {
          _stages["squat"] = "up";
          _counters["squat"] = (_counters["squat"] ?? 0) + 1;
        }
      }
    } else if (label == "barbell biceps curl" || label == "bicep_curl" || label == "barbell biceps curl".replaceAll(' ', '_')) {
      if (landmarks.containsKey(12) && landmarks.containsKey(14) && landmarks.containsKey(16) &&
          landmarks.containsKey(11) && landmarks.containsKey(13) && landmarks.containsKey(15)) {
        final rightArm = calculateAngle(landmarks[12]!, landmarks[14]!, landmarks[16]!);
        final leftArm = calculateAngle(landmarks[11]!, landmarks[13]!, landmarks[15]!);

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
        }
      }
    } else if (label == "shoulder press" || label == "shoulder_press" || label == "shoulder press".replaceAll(' ', '_')) {
      if (landmarks.containsKey(12) && landmarks.containsKey(14) && landmarks.containsKey(16) &&
          landmarks.containsKey(11) && landmarks.containsKey(13) && landmarks.containsKey(15)) {
        final rightArm = calculateAngle(landmarks[12]!, landmarks[14]!, landmarks[16]!);
        final leftArm = calculateAngle(landmarks[11]!, landmarks[13]!, landmarks[15]!);

        if (rightArm > 280 && leftArm < 80) {
          _stages["shoulder_press"] = "down";
        }
        if (rightArm < 240 && leftArm > 120 && _stages["shoulder_press"] == "down") {
          _stages["shoulder_press"] = "up";
          _counters["shoulder_press"] = (_counters["shoulder_press"] ?? 0) + 1;
        }
      }
    }
  }
}
