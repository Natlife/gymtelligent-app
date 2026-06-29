import 'dart:math' as math;

import 'rep_counter_service.dart';

/// Which extreme of the joint angle is the resting/home position of one rep.
///
/// For squat/push-up/curl the body rests with the joint extended (large angle)
/// and the work happens while flexing. For the shoulder press the body rests
/// with the elbow flexed (arms at the shoulders) and the work happens while
/// extending overhead, so its home pose is inverted.
enum HomePose { extended, contracted }

class AngleExerciseConfig {
  /// Joint-angle triplets as landmark id `[a, b, c]`, one per usable side.
  /// The angle is measured at the middle joint `b`.
  final List<List<int>> angleTriplets;

  /// Fallback thresholds (degrees) used until enough range of motion has been
  /// observed for the adaptive band to take over.
  final double fixedFlexedAngle;
  final double fixedExtendedAngle;

  final HomePose home;

  /// Minimum observed angular travel (degrees) before a rep is allowed to count.
  /// Rejects small jitter being mistaken for a repetition.
  final double minSpanDegrees;

  /// Minimum time between two counted reps.
  final int debounceMs;

  const AngleExerciseConfig({
    required this.angleTriplets,
    required this.fixedFlexedAngle,
    required this.fixedExtendedAngle,
    required this.home,
    this.minSpanDegrees = 40,
    this.debounceMs = 350,
  });
}

/// Rule-based, angle-driven repetition counter.
///
/// Unlike the TCN counter this produces a count with ~1 frame of latency, has
/// no model warm-up window, and is independent of the pose estimator (any
/// backend that yields the 12 body landmarks works). A two-state machine with
/// hysteresis and an adaptive range-of-motion band makes it robust to body
/// proportions, camera angle, and jitter without a separate calibration step.
class AngleRepCounter {
  static const double _minConfidence = 0.3;
  static const double _smoothingAlpha = 0.5;
  // Per-frame relaxation (degrees) that lets a stale adaptive min/max drift
  // back toward the current angle, so the band shrinks if reps get smaller.
  static const double _bandRelaxPerFrame = 0.08;
  static const int _gapResetMs = 600;

  static const configs = <String, AngleExerciseConfig>{
    'squat': AngleExerciseConfig(
      angleTriplets: [
        [23, 25, 27],
        [24, 26, 28],
      ],
      fixedFlexedAngle: 100,
      fixedExtendedAngle: 160,
      home: HomePose.extended,
    ),
    'push_up': AngleExerciseConfig(
      angleTriplets: [
        [11, 13, 15],
        [12, 14, 16],
      ],
      fixedFlexedAngle: 95,
      fixedExtendedAngle: 158,
      home: HomePose.extended,
    ),
    'bicep_curl': AngleExerciseConfig(
      angleTriplets: [
        [11, 13, 15],
        [12, 14, 16],
      ],
      fixedFlexedAngle: 55,
      fixedExtendedAngle: 150,
      home: HomePose.extended,
      minSpanDegrees: 50,
    ),
    'shoulder_press': AngleExerciseConfig(
      angleTriplets: [
        [11, 13, 15],
        [12, 14, 16],
      ],
      fixedFlexedAngle: 95,
      fixedExtendedAngle: 158,
      home: HomePose.contracted,
    ),
  };

  final Map<String, _AngleState> _states = {};

  bool supports(String exerciseKey) => configs.containsKey(exerciseKey);

  int getCounter(String exerciseKey) => _states[exerciseKey]?.count ?? 0;

  /// Feeds one pose frame and returns the current rep count for [exerciseKey].
  int update(
    String exerciseKey,
    Map<int, Point3D> landmarks,
    Map<int, double> confidence,
    DateTime timestamp,
  ) {
    final config = configs[exerciseKey];
    if (config == null) return 0;
    final state = _states.putIfAbsent(exerciseKey, () => _AngleState());

    final timeMs = timestamp.millisecondsSinceEpoch;
    if (state.previousTimeMs != null &&
        timeMs - state.previousTimeMs! > _gapResetMs) {
      state.resetTracking();
    }
    state.previousTimeMs = timeMs;

    final rawAngle = _measureAngle(config, landmarks, confidence);
    if (rawAngle == null) return state.count; // unreliable frame, hold.

    final angle = state.smoothedAngle == null
        ? rawAngle
        : state.smoothedAngle! + _smoothingAlpha * (rawAngle - state.smoothedAngle!);
    state.smoothedAngle = angle;

    // Adaptive range-of-motion band with slow relaxation toward the angle.
    state.observedMin = math.min(angle, state.observedMin + _bandRelaxPerFrame);
    state.observedMax = math.max(angle, state.observedMax - _bandRelaxPerFrame);
    final span = state.observedMax - state.observedMin;

    double flexedThreshold;
    double extendedThreshold;
    if (span >= config.minSpanDegrees) {
      flexedThreshold = state.observedMin + 0.30 * span;
      extendedThreshold = state.observedMin + 0.70 * span;
    } else {
      flexedThreshold = config.fixedFlexedAngle;
      extendedThreshold = config.fixedExtendedAngle;
    }

    _Phase newPhase = state.phase;
    if (angle <= flexedThreshold) {
      newPhase = _Phase.contracted;
    } else if (angle >= extendedThreshold) {
      newPhase = _Phase.extended;
    }
    if (newPhase == state.phase) return state.count;

    final _Phase homePhase =
        config.home == HomePose.extended ? _Phase.extended : _Phase.contracted;
    final bool enoughRange = span >= config.minSpanDegrees;

    if (state.phase == _Phase.unknown) {
      // First determinate reading establishes the phase without counting.
      state.phase = newPhase;
      return state.count;
    }

    if (newPhase != homePhase) {
      state.visitedAway = true;
    } else if (state.visitedAway &&
        enoughRange &&
        (state.lastRepTimeMs == null ||
            timeMs - state.lastRepTimeMs! >= config.debounceMs)) {
      state.count++;
      state.lastRepTimeMs = timeMs;
      state.visitedAway = false;
    }
    state.phase = newPhase;
    return state.count;
  }

  /// Returns the averaged joint angle in degrees over the confident sides,
  /// or null when no side is reliable enough this frame.
  double? _measureAngle(
    AngleExerciseConfig config,
    Map<int, Point3D> landmarks,
    Map<int, double> confidence,
  ) {
    var sum = 0.0;
    var sides = 0;
    for (final triplet in config.angleTriplets) {
      final a = landmarks[triplet[0]];
      final b = landmarks[triplet[1]];
      final c = landmarks[triplet[2]];
      if (a == null || b == null || c == null) continue;
      final ca = confidence[triplet[0]] ?? 0;
      final cb = confidence[triplet[1]] ?? 0;
      final cc = confidence[triplet[2]] ?? 0;
      if (ca < _minConfidence || cb < _minConfidence || cc < _minConfidence) {
        continue;
      }
      sum += _angleDegrees(a, b, c);
      sides++;
    }
    if (sides == 0) return null;
    return sum / sides;
  }

  static double _angleDegrees(Point3D a, Point3D b, Point3D c) {
    final bax = a.x - b.x;
    final bay = a.y - b.y;
    final bcx = c.x - b.x;
    final bcy = c.y - b.y;
    final denominator =
        math.sqrt(bax * bax + bay * bay) * math.sqrt(bcx * bcx + bcy * bcy);
    if (denominator < 1e-9) return 180;
    final cosine = ((bax * bcx + bay * bcy) / denominator).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180.0 / math.pi;
  }

  void reset([String? exerciseKey]) {
    if (exerciseKey != null) {
      _states[exerciseKey]?.reset();
      return;
    }
    for (final state in _states.values) {
      state.reset();
    }
  }
}

enum _Phase { unknown, contracted, extended }

class _AngleState {
  int count = 0;
  _Phase phase = _Phase.unknown;
  bool visitedAway = false;
  double? smoothedAngle;
  double observedMin = double.infinity;
  double observedMax = double.negativeInfinity;
  int? lastRepTimeMs;
  int? previousTimeMs;

  void reset() {
    count = 0;
    resetTracking();
  }

  void resetTracking() {
    phase = _Phase.unknown;
    visitedAway = false;
    smoothedAngle = null;
    observedMin = double.infinity;
    observedMax = double.negativeInfinity;
    lastRepTimeMs = null;
    previousTimeMs = null;
  }
}
