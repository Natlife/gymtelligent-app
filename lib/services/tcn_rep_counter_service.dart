import 'dart:math' as math;

import 'package:tflite_flutter/tflite_flutter.dart';

class TcnExerciseConfig {
  final String asset;
  final double eventThreshold;
  final int minimumEventDistanceFrames;

  /// Indices into the 48-value feature vector of the joint angle(s) that flex
  /// during one repetition (normalized acos/pi, 0 = fully bent, 1 = straight).
  /// A committed event is only counted when this angle actually traversed at
  /// least [minRangeOfMotion] since the previous counted rep. This rejects
  /// false event spikes from idle jitter without retraining the model.
  final List<int> romAngleIndices;
  final double minRangeOfMotion;

  /// Average landmark confidence required across the rep segment. Counting is
  /// suppressed when the skeleton was too unreliable to trust the geometry.
  final double minSegmentConfidence;

  const TcnExerciseConfig({
    required this.asset,
    required this.eventThreshold,
    required this.minimumEventDistanceFrames,
    this.romAngleIndices = const [],
    this.minRangeOfMotion = 0.12,
    this.minSegmentConfidence = 0.30,
  });
}

class TcnRepCounterService {
  static const int windowSize = 64;
  static const int featureCount = 48;
  static const int targetFps = 15;
  static const int _samplePeriodMs = 1000 ~/ targetFps;

  static const configs = <String, TcnExerciseConfig>{
    'squat': TcnExerciseConfig(
      asset: 'assets/models/tcn/squat.tflite',
      eventThreshold: 0.08,
      minimumEventDistanceFrames: 17,
      // Knee angles flex on the way down and extend at the top.
      romAngleIndices: [42, 43],
      minRangeOfMotion: 0.13,
    ),
    'push_up': TcnExerciseConfig(
      asset: 'assets/models/tcn/push_up.tflite',
      eventThreshold: 0.02,
      minimumEventDistanceFrames: 15,
      // Elbow angles flex at the bottom of the push-up.
      romAngleIndices: [36, 37],
    ),
    'bicep_curl': TcnExerciseConfig(
      asset: 'assets/models/tcn/bicep_curl.tflite',
      eventThreshold: 0.02,
      minimumEventDistanceFrames: 15,
      // Elbow angles fold during the curl.
      romAngleIndices: [36, 37],
    ),
    'shoulder_press': TcnExerciseConfig(
      asset: 'assets/models/tcn/shoulder_press.tflite',
      eventThreshold: 0.02,
      minimumEventDistanceFrames: 15,
      // Elbows extend overhead at the top of the press.
      romAngleIndices: [36, 37],
    ),
  };

  final Map<String, Interpreter> _interpreters = {};
  final Map<String, _ExerciseState> _states = {};

  Future<void> initialize({String? exerciseKey}) async {
    final keys = exerciseKey == null ? configs.keys : <String>[exerciseKey];
    for (final key in keys) {
      if (_interpreters.containsKey(key)) continue;
      final config = configs[key];
      if (config == null) throw ArgumentError('Unsupported exercise: $key');
      final options = InterpreterOptions()..threads = 2;
      _interpreters[key] = await Interpreter.fromAsset(
        config.asset,
        options: options,
      );
      _states[key] = _ExerciseState();
    }
  }

  bool get isReady => _interpreters.isNotEmpty;

  int getCounter(String exerciseKey) => _states[exerciseKey]?.count ?? 0;

  /// Resamples asynchronous pose results to the 15 FPS timeline used in
  /// training, then runs causal TCN inference.
  int processFrame(
    String exerciseKey,
    List<double> features,
    DateTime timestamp,
  ) {
    if (features.length != featureCount) {
      throw ArgumentError('Expected $featureCount pose features');
    }
    final interpreter = _interpreters[exerciseKey];
    final config = configs[exerciseKey];
    final state = _states[exerciseKey];
    if (interpreter == null || config == null || state == null) {
      return getCounter(exerciseKey);
    }

    final timeMs = timestamp.millisecondsSinceEpoch;
    if (state.previousTimeMs != null && timeMs - state.previousTimeMs! > 500) {
      state.resetTracking();
    }
    if (state.previousFeatures == null ||
        state.previousTimeMs == null ||
        timeMs <= state.previousTimeMs! ||
        timeMs - state.previousTimeMs! > 500) {
      state.nextSampleTimeMs = timeMs + _samplePeriodMs;
      _appendSample(interpreter, config, state, features);
    } else {
      state.nextSampleTimeMs ??= state.previousTimeMs! + _samplePeriodMs;
      while (state.nextSampleTimeMs! <= timeMs) {
        final fraction =
            (state.nextSampleTimeMs! - state.previousTimeMs!) /
            (timeMs - state.previousTimeMs!);
        final interpolated = List<double>.generate(
          featureCount,
          (index) =>
              state.previousFeatures![index] +
              (features[index] - state.previousFeatures![index]) * fraction,
          growable: false,
        );
        _appendSample(interpreter, config, state, interpolated);
        state.nextSampleTimeMs = state.nextSampleTimeMs! + _samplePeriodMs;
      }
    }
    state.previousFeatures = List<double>.of(features, growable: false);
    state.previousTimeMs = timeMs;
    return state.count;
  }

  void _appendSample(
    Interpreter interpreter,
    TcnExerciseConfig config,
    _ExerciseState state,
    List<double> features,
  ) {
    if (state.frames.isEmpty) {
      for (var index = 0; index < windowSize - 1; index++) {
        state.frames.add(List<double>.of(features, growable: false));
      }
    }
    state.frames.add(List<double>.of(features, growable: false));
    if (state.frames.length > windowSize) state.frames.removeAt(0);
    if (state.frames.length < windowSize) return;

    // Reuse pre-allocated input/output buffers across frames. Allocating fresh
    // nested lists every sample produced steady GC churn and visible jank.
    state.inputBuffer[0] = state.frames;
    interpreter.runForMultipleInputs(
      <Object>[state.inputBuffer],
      <int, Object>{
        0: state.formBuffer,
        1: state.phaseBuffer,
        2: state.eventBuffer,
      },
    );

    state.sampleIndex++;
    final probability = state.eventBuffer[0][windowSize - 1][0];
    state.eventHistory.add(probability);
    state.angleHistory.add(_monitoredAngle(features, config));
    state.confidenceHistory.add(_meanConfidence(features));

    for (final peak in _stablePeaks(state.eventHistory, config)) {
      final globalFrame = state.historyStartFrame + peak;
      if (!state.evaluatedPeakFrames.add(globalFrame)) continue;
      if (_passesRepGate(state, config, peak)) {
        state.committedPeakFrames.add(globalFrame);
        state.lastCountedPeakGlobal = globalFrame;
      }
    }
    state.count = state.committedCount + state.committedPeakFrames.length;

    if (state.eventHistory.length > 1024) {
      state.eventHistory.removeRange(0, 512);
      state.angleHistory.removeRange(0, 512);
      state.confidenceHistory.removeRange(0, 512);
      state.historyStartFrame += 512;
      state.evaluatedPeakFrames.removeWhere(
        (frame) => frame < state.historyStartFrame,
      );
    }
  }

  /// Mean of the monitored joint angles for one sample, in normalized [0, 1].
  static double _monitoredAngle(List<double> features, TcnExerciseConfig config) {
    if (config.romAngleIndices.isEmpty) return 0;
    var sum = 0.0;
    for (final index in config.romAngleIndices) {
      sum += features[index];
    }
    return sum / config.romAngleIndices.length;
  }

  /// Mean of the 12 landmark confidences (features 24..35).
  static double _meanConfidence(List<double> features) {
    var sum = 0.0;
    for (var index = 24; index < 36; index++) {
      sum += features[index];
    }
    return sum / 12.0;
  }

  /// A model event peak only counts when the monitored joint actually moved
  /// through a real repetition since the previously counted rep, and the
  /// skeleton was reliable enough to trust that geometry.
  bool _passesRepGate(
    _ExerciseState state,
    TcnExerciseConfig config,
    int peakLocalIndex,
  ) {
    if (config.romAngleIndices.isEmpty) return true;

    var start = 0;
    if (state.lastCountedPeakGlobal >= 0) {
      start = state.lastCountedPeakGlobal - state.historyStartFrame;
    }
    start = start.clamp(0, peakLocalIndex);

    var minAngle = double.infinity;
    var maxAngle = double.negativeInfinity;
    var confidenceSum = 0.0;
    var samples = 0;
    for (var i = start; i <= peakLocalIndex; i++) {
      final angle = state.angleHistory[i];
      if (angle < minAngle) minAngle = angle;
      if (angle > maxAngle) maxAngle = angle;
      confidenceSum += state.confidenceHistory[i];
      samples++;
    }
    if (samples == 0) return false;

    final rangeOfMotion = maxAngle - minAngle;
    final meanConfidence = confidenceSum / samples;
    return rangeOfMotion >= config.minRangeOfMotion &&
        meanConfidence >= config.minSegmentConfidence;
  }

  List<int> _stablePeaks(List<double> values, TcnExerciseConfig config) {
    if (values.length < 3) return const [];
    final peaks = <int>[];
    var index = 1;
    while (index < values.length - 1) {
      if (values[index] > values[index - 1]) {
        var plateauEnd = index;
        while (plateauEnd + 1 < values.length &&
            values[plateauEnd + 1] == values[index]) {
          plateauEnd++;
        }
        if (plateauEnd < values.length - 1 &&
            values[index] > values[plateauEnd + 1]) {
          peaks.add((index + plateauEnd) ~/ 2);
        }
        index = plateauEnd + 1;
      } else {
        index++;
      }
    }

    final prominenceThreshold = math.max(0.01, config.eventThreshold * 0.1);
    final eligible = <int>[];
    for (final peak in peaks) {
      final peakValue = values[peak];
      if (peakValue < config.eventThreshold) continue;

      var leftMinimum = peakValue;
      for (var cursor = peak - 1; cursor >= 0; cursor--) {
        if (values[cursor] > peakValue) break;
        leftMinimum = math.min(leftMinimum, values[cursor]);
      }
      var rightMinimum = peakValue;
      for (var cursor = peak + 1; cursor < values.length; cursor++) {
        if (values[cursor] > peakValue) break;
        rightMinimum = math.min(rightMinimum, values[cursor]);
      }
      final prominence = peakValue - math.max(leftMinimum, rightMinimum);
      if (prominence >= prominenceThreshold) eligible.add(peak);
    }

    final keep = List<bool>.filled(eligible.length, true);
    final priorityOrder = List<int>.generate(eligible.length, (i) => i)
      ..sort((a, b) => values[eligible[a]].compareTo(values[eligible[b]]));
    for (final position in priorityOrder.reversed) {
      if (!keep[position]) continue;
      var cursor = position - 1;
      while (cursor >= 0 &&
          eligible[position] - eligible[cursor] <
              config.minimumEventDistanceFrames) {
        keep[cursor] = false;
        cursor--;
      }
      cursor = position + 1;
      while (cursor < eligible.length &&
          eligible[cursor] - eligible[position] <
              config.minimumEventDistanceFrames) {
        keep[cursor] = false;
        cursor++;
      }
    }

    final stableThrough = values.length - config.minimumEventDistanceFrames - 1;
    final selected = <int>[];
    for (var i = 0; i < eligible.length; i++) {
      if (keep[i] && eligible[i] <= stableThrough) {
        selected.add(eligible[i]);
      }
    }
    return selected;
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

  void dispose() {
    for (final interpreter in _interpreters.values) {
      interpreter.close();
    }
    _interpreters.clear();
    _states.clear();
  }
}

class _ExerciseState {
  final List<List<double>> frames = [];
  final List<double> eventHistory = [];
  final List<double> angleHistory = [];
  final List<double> confidenceHistory = [];
  final Set<int> committedPeakFrames = {};
  final Set<int> evaluatedPeakFrames = {};
  int count = 0;
  int committedCount = 0;
  int sampleIndex = 0;
  int historyStartFrame = 0;
  int lastCountedPeakGlobal = -1;
  int? previousTimeMs;
  int? nextSampleTimeMs;
  List<double>? previousFeatures;

  // Pre-allocated TFLite I/O buffers, reused every inference.
  final List<List<List<double>>> inputBuffer = [<List<double>>[]];
  final List<List<List<double>>> formBuffer = [
    List.generate(
      TcnRepCounterService.windowSize,
      (_) => List<double>.filled(3, 0),
    ),
  ];
  final List<List<List<double>>> phaseBuffer = [
    List.generate(
      TcnRepCounterService.windowSize,
      (_) => List<double>.filled(4, 0),
    ),
  ];
  final List<List<List<double>>> eventBuffer = [
    List.generate(
      TcnRepCounterService.windowSize,
      (_) => List<double>.filled(1, 0),
    ),
  ];

  void reset() {
    count = 0;
    committedCount = 0;
    committedPeakFrames.clear();
    resetTracking();
  }

  void resetTracking() {
    committedCount = count;
    committedPeakFrames.clear();
    evaluatedPeakFrames.clear();
    frames.clear();
    eventHistory.clear();
    angleHistory.clear();
    confidenceHistory.clear();
    sampleIndex = 0;
    historyStartFrame = 0;
    lastCountedPeakGlobal = -1;
    previousTimeMs = null;
    nextSampleTimeMs = null;
    previousFeatures = null;
  }
}
