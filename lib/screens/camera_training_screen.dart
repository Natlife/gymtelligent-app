import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../theme.dart';
import '../services/workout_service.dart';
import '../models/workout_session.dart';
import '../services/rep_counter_service.dart';
import '../services/pose_tracking_service.dart';
import '../services/tcn_pose_features.dart';
import '../services/angle_rep_counter_service.dart';

class CameraTrainingScreen extends StatefulWidget {
  final int exerciseId;
  final String exerciseTitle;
  final String duration;
  final String level;
  final int targetSets;
  final int targetReps;
  final int restSeconds;
  final bool isFreestyleMode;

  const CameraTrainingScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseTitle,
    required this.duration,
    required this.level,
    this.targetSets = 3,
    this.targetReps = 12,
    this.restSeconds = 60,
    this.isFreestyleMode = false,
  });

  @override
  State<CameraTrainingScreen> createState() => _CameraTrainingScreenState();
}

class _CameraTrainingScreenState extends State<CameraTrainingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late AnimationController _audioWaveController;

  final RepCounterService _repCounterService = RepCounterService();
  final AngleRepCounter _angleRepCounter = AngleRepCounter();
  final PoseFrameStabilizer _poseFrameStabilizer = PoseFrameStabilizer();
  final ValueNotifier<Map<int, Point3D>> _landmarksNotifier =
      ValueNotifier<Map<int, Point3D>>({});

  // Camera States
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isInitializingCamera = false;
  bool _cameraInitializationDeferred = false;
  bool _cameraRequested = true;
  int _cameraGeneration = 0;

  // Timer & Stats States
  int _elapsedSeconds = 0;
  Timer? _workoutTimer;
  int _repCount = 0;
  int _targetReps = 12;
  double _formAccuracy = 0.0;
  String _hudMessage = "Align your body in the camera frame";
  Color _hudColor = AppTheme.gradientStart;

  bool _isPaused = false;
  bool _isVoiceMuted = false;
  bool _calibrationDone = false;
  // Driven every camera frame; kept off setState so calibration updates do not
  // rebuild the whole camera/overlay tree and cause jank.
  final ValueNotifier<double> _calibrationProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _calibrationGuidance = ValueNotifier<String>(
    "Move into the frame",
  );
  int _stableCalibrationFrames = 0;

  int? _sessionId;
  bool _isSavingWorkout = false;
  WorkoutSession? _completedSession;

  // Multi-set state
  int _currentSet = 1;
  int _targetSets = 3;
  int _restSeconds = 60;
  bool _isResting = false;
  int _restCountdown = 0;
  Timer? _restTimer;
  int _totalRepsAllSets = 0;

  // Free Style Mode state
  bool _isFreestyleMode = false;
  Interpreter? _tfliteInterpreter;
  final List<List<double>> _frameBuffer = [];
  String _detectedExercise = 'detecting...';
  String _detectedExerciseStable = '';
  String _candidateExercise = '';
  int _stableFrameCount = 0;
  static const int _windowSize = 30;
  static const List<String> _exerciseLabels = [
    'barbell biceps curl',
    'push-up',
    'shoulder press',
    'squat',
  ];

  // ML Kit Pose Detection States
  late PoseDetector _poseDetector;
  bool _isDetecting = false;
  bool _useLiveCameraDetection = false;
  bool _isLiveTracking = true;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = -1;
  DateTime? _lastProcessedTime;
  bool _tcnModelsReady = false;
  int _missingPoseFrames = 0;
  bool _trackingWarningShown = false;
  bool _unsupportedImageFormatWarned = false;
  double _averagePoseLatencyMs = 0;
  int _processedPoseFrames = 0;

  // Custom audio wave bars
  final List<double> _waveAmplitudes = [0.2, 0.5, 0.8, 0.4, 0.7, 0.3, 0.6, 0.2];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _targetReps = widget.targetReps;
    _targetSets = widget.targetSets;
    _restSeconds = widget.restSeconds;
    _isFreestyleMode = widget.isFreestyleMode;

    final options = PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    );
    _poseDetector = PoseDetector(options: options);

    _initializeCamera();
    _startSessionOnBackend();
    _loadAiModels();

    // Pulse animation for AI scanner rings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Animation for real-time coaching audio indicator
    _audioWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    _startCalibration();
  }

  Future<void> _loadAiModels() async {
    try {
      // Rep counting is rule-based (instant, no model warm-up). Only freestyle
      // mode still needs the lightweight classifier to auto-detect the exercise.
      if (_isFreestyleMode) {
        _tfliteInterpreter = await Interpreter.fromAsset(
          'assets/models/exercise_classifier_with_scaler_fp16.tflite',
        );
      }
      if (mounted) {
        setState(() {
          _tcnModelsReady = true;
        });
      }
    } catch (e) {
      debugPrint('AI model load error: $e');
      if (mounted) {
        setState(() {
          _hudMessage = "Unable to load the rep counting model";
          _hudColor = Colors.redAccent;
        });
      }
    }
  }

  Future<void> _startSessionOnBackend() async {
    try {
      final sid = await WorkoutService.startSession(widget.exerciseId);
      if (mounted) {
        setState(() {
          _sessionId = sid;
        });
      }
    } catch (_) {}
  }

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) {
      _cameraInitializationDeferred = true;
      return;
    }
    _isInitializingCamera = true;
    final generation = ++_cameraGeneration;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("No cameras found");
        return;
      }

      _cameras = cameras;

      CameraDescription? frontCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      final selectedCamera = frontCamera ?? cameras.first;
      _cameraIndex = cameras.indexOf(selectedCamera);

      final controller = CameraController(
        selectedCamera,
        // ML Kit recommends at least 480x360 pose input. Medium preserves
        // enough body detail at training distance while stream mode drops
        // frames whenever the detector is busy.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted || !_cameraRequested || generation != _cameraGeneration) {
        await controller.dispose();
        return;
      }
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {
        // Some fixed-focus front cameras do not expose these controls.
      }
      _cameraController = controller;
      _cameraInitializationDeferred = false;
      await controller.startImageStream((CameraImage image) {
        _processCameraImage(image);
      });
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
      final failedController = _cameraController;
      _cameraController = null;
      _isCameraInitialized = false;
      if (failedController != null) {
        await failedController.dispose();
      }
    } finally {
      _isInitializingCamera = false;
      if (mounted &&
          _cameraRequested &&
          _cameraInitializationDeferred &&
          _cameraController == null) {
        _cameraInitializationDeferred = false;
        scheduleMicrotask(_initializeCamera);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cameraRequested = false;
      unawaited(_pauseCamera());
    } else if (state == AppLifecycleState.resumed) {
      _cameraRequested = true;
      unawaited(_initializeCamera());
    }
  }

  Future<void> _pauseCamera() async {
    _cameraGeneration++;
    final controller = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;
    _poseFrameStabilizer.reset();
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // The native camera may already be closed during a lifecycle transition.
    }
    await controller.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraRequested = false;
    _cameraGeneration++;
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _pulseController.dispose();
    _audioWaveController.dispose();
    _cameraController?.dispose();
    _poseDetector.close();
    _tfliteInterpreter?.close();
    _landmarksNotifier.dispose();
    _calibrationProgress.dispose();
    _calibrationGuidance.dispose();
    super.dispose();
  }

  void _startCalibration() {
    _calibrationProgress.value = 0.0;
    _calibrationGuidance.value = "Move into the frame";
    _stableCalibrationFrames = 0;
    setState(() {
      _calibrationDone = false;
      _hudMessage = "Camera setup: show your full body";
      _hudColor = Colors.cyan;
    });
    _angleRepCounter.reset();
  }

  void _startWorkoutTimer() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isPaused) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _finishWorkout() async {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    if (_isSavingWorkout) return;
    setState(() {
      _isSavingWorkout = true;
    });

    if (_sessionId != null) {
      final double calculatedCalories = _calculateCalories();
      final completed = await WorkoutService.completeSession(
        sessionId: _sessionId!,
        totalReps: _getTotalReps(),
        totalSets: _isFreestyleMode ? 1 : _currentSet,
        durationSeconds: _elapsedSeconds,
        avgPostureScore: _formAccuracy,
        caloriesBurned: calculatedCalories,
      );
      if (mounted) {
        setState(() {
          _completedSession = completed;
          _isSavingWorkout = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isSavingWorkout = false;
        });
      }
    }

    if (mounted) {
      _showWorkoutSummaryDialog();
    }
  }

  String _getExerciseKey(String title) {
    final t = title.toLowerCase();
    if (t.contains('push')) return 'push_up';
    if (t.contains('squat')) return 'squat';
    if (t.contains('curl') || t.contains('bicep')) return 'bicep_curl';
    if (t.contains('press') || t.contains('shoulder')) return 'shoulder_press';
    return 'squat';
  }

  String _getPredictedLabel(String title) {
    final t = title.toLowerCase();
    if (t.contains('push')) return 'push-up';
    if (t.contains('squat')) return 'squat';
    if (t.contains('curl') || t.contains('bicep')) return 'barbell biceps curl';
    if (t.contains('press') || t.contains('shoulder')) return 'shoulder press';
    return 'squat';
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isLiveTracking) return;
    if (_isPaused || _isDetecting) return;

    final now = DateTime.now();

    if (_lastProcessedTime != null &&
        now.difference(_lastProcessedTime!).inMilliseconds < 60) {
      return;
    }

    _isDetecting = true;
    _lastProcessedTime = now;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _handleMissingPose();
        _isDetecting = false;
        return;
      }

      final poseStopwatch = Stopwatch()..start();
      final poses = await _poseDetector.processImage(inputImage);
      poseStopwatch.stop();
      _processedPoseFrames++;
      final latency = poseStopwatch.elapsedMicroseconds / 1000.0;
      _averagePoseLatencyMs = _processedPoseFrames == 1
          ? latency
          : _averagePoseLatencyMs * 0.9 + latency * 0.1;
      if (_processedPoseFrames % 60 == 0) {
        debugPrint(
          "Pose pipeline: ${_averagePoseLatencyMs.toStringAsFixed(1)} ms "
          "average over $_processedPoseFrames frames",
        );
      }

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final Map<int, Point3D> landmarks = {};
        final Map<int, double> confidence = {};

        final camera = _cameras[_cameraIndex];
        final sensorOrientation = camera.sensorOrientation;
        int rotationDegrees = sensorOrientation;
        if (Platform.isAndroid) {
          var rotationCompensation =
              _orientations[_cameraController!.value.deviceOrientation];
          rotationCompensation ??= 0;
          if (camera.lensDirection == CameraLensDirection.front) {
            rotationDegrees = (sensorOrientation + rotationCompensation) % 360;
          } else {
            rotationDegrees =
                (sensorOrientation - rotationCompensation + 360) % 360;
          }
        }

        final rotatedImageSize = _getRotatedImageSize(image, rotationDegrees);

        pose.landmarks.forEach((type, landmark) {
          final id = _mapPoseLandmarkTypeToId(type);
          if (id != null) {
            confidence[id] = landmark.likelihood;
            // Keep moderately uncertain points and pass their confidence to
            // the TCN. Dropping at 0.55 made otherwise complete poses flicker.
            if (landmark.likelihood < 0.25) return;

            // Preserve out-of-frame coordinates so readiness can tell the
            // user to move back. Clamping them silently distorted the pose.
            final double normX = landmark.x / rotatedImageSize.width;
            final double normY = landmark.y / rotatedImageSize.height;

            // The TCN was trained on 2D coordinates. Keep z only for the
            // painter/debug representation; it is not part of its features.
            final double normZ = landmark.z / rotatedImageSize.width;
            landmarks[id] = Point3D(normX, normY, normZ);
          }
        });

        final stabilized = _poseFrameStabilizer.smooth(
          landmarks,
          confidence,
          now,
        );
        landmarks
          ..clear()
          ..addAll(stabilized);

        if (!_calibrationDone) {
          _updateCalibration(landmarks, confidence);
        }

        if (TcnPoseFeatures.landmarkIds.every(landmarks.containsKey)) {
          _useLiveCameraDetection = true;
          _missingPoseFrames = 0;
          if (_trackingWarningShown && _calibrationDone && mounted) {
            _trackingWarningShown = false;
            setState(() {
              _hudMessage = "Body detected. Continue";
              _hudColor = AppTheme.gradientStart;
            });
          }
          _landmarksNotifier.value = landmarks;

          if (_isFreestyleMode) {
            final features = _extractTfliteFeatures(landmarks);
            _runTfliteInference(features);
          }

          if (_calibrationDone && _tcnModelsReady && !_isResting) {
            final predictedLabel = _isFreestyleMode
                ? _detectedExerciseStable
                : _getPredictedLabel(widget.exerciseTitle);
            if (predictedLabel.isNotEmpty && predictedLabel != 'detecting...') {
              final exerciseKey = _isFreestyleMode
                  ? _getFreestyleExerciseKey(predictedLabel)
                  : _getExerciseKey(widget.exerciseTitle);
              final count = _angleRepCounter.update(
                exerciseKey,
                landmarks,
                confidence,
                now,
              );
              _onRepCounted(count);
            }
          }
        } else {
          _handleMissingPose();
        }
      } else {
        _handleMissingPose();
      }
    } catch (e) {
      debugPrint("Error processing camera image: $e");
    } finally {
      _isDetecting = false;
    }
  }

  void _handleMissingPose() {
    _useLiveCameraDetection = false;
    if (!_calibrationDone) {
      _updateCalibration(const {}, const {});
      return;
    }
    _missingPoseFrames++;
    if (_missingPoseFrames >= 5 && !_trackingWarningShown && mounted) {
      _trackingWarningShown = true;
      setState(() {
        _hudMessage = "Move your full body into frame";
        _hudColor = Colors.amberAccent;
      });
    }
  }

  void _updateCalibration(
    Map<int, Point3D> landmarks,
    Map<int, double> confidence,
  ) {
    final readiness = PoseReadinessEvaluator.evaluate(
      landmarks,
      confidence,
      modelReady: _tcnModelsReady,
    );

    // Rule-based counting self-calibrates its angle band, so this is only a
    // quick "are you in frame" check rather than a long baseline capture.
    const requiredFrames = 10;
    if (readiness.ready) {
      _stableCalibrationFrames = math.min(
        _stableCalibrationFrames + 1,
        requiredFrames,
      );
    } else {
      _stableCalibrationFrames = math.max(_stableCalibrationFrames - 2, 0);
    }
    final progress = _stableCalibrationFrames / requiredFrames;
    if (!mounted) return;
    // Update via notifiers only; avoids a full-tree rebuild every frame.
    _calibrationProgress.value = progress;
    _calibrationGuidance.value = readiness.guidance;

    if (_stableCalibrationFrames >= requiredFrames && !_calibrationDone) {
      _calibrationProgress.value = 1.0;
      setState(() {
        _calibrationDone = true;
        _hudMessage = "Ready. Start your ${widget.exerciseTitle}!";
        _hudColor = AppTheme.gradientStart;
      });
      _angleRepCounter.reset();
      _startWorkoutTimer();
    }
  }

  InputImageRotation _getRotation(int degrees) {
    switch (degrees) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation90deg;
    }
  }

  Size _getRotatedImageSize(CameraImage image, int rotationDegrees) {
    final bool isQuarterTurn = rotationDegrees == 90 || rotationDegrees == 270;
    return isQuarterTurn
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
  }

  Size _getCameraPreviewDisplaySize() {
    final previewSize = _cameraController?.value.previewSize;
    if (previewSize == null) {
      return const Size(720, 1280);
    }

    final double shorterSide = math.min(previewSize.width, previewSize.height);
    final double longerSide = math.max(previewSize.width, previewSize.height);
    final orientation = _cameraController?.value.deviceOrientation;
    final bool isLandscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;

    return isLandscape
        ? Size(longerSide, shorterSide)
        : Size(shorterSide, longerSide);
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null || _cameraIndex == -1) return null;
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    int rotationDegrees = sensorOrientation;
    if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_cameraController!.value.deviceOrientation];
      rotationCompensation ??= 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationDegrees = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationDegrees =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
    }

    if (image.planes.length != 1) {
      if (!_unsupportedImageFormatWarned) {
        _unsupportedImageFormatWarned = true;
        debugPrint(
          "Unsupported camera stream: expected one NV21/BGRA plane, "
          "received ${image.planes.length}.",
        );
      }
      return null;
    }

    final rotation = _getRotation(rotationDegrees);
    // CameraX reports yuv420 for an NV21-requested stream even though its
    // single-plane bytes are NV21. Using image.format.raw here incorrectly
    // declared the buffer as YUV_420_888 to ML Kit.
    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;
    final plane = image.planes.first;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: plane.bytes, metadata: metadata);
  }

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  int? _mapPoseLandmarkTypeToId(PoseLandmarkType type) {
    switch (type) {
      case PoseLandmarkType.nose:
        return 0;
      case PoseLandmarkType.leftShoulder:
        return 11;
      case PoseLandmarkType.rightShoulder:
        return 12;
      case PoseLandmarkType.leftElbow:
        return 13;
      case PoseLandmarkType.rightElbow:
        return 14;
      case PoseLandmarkType.leftWrist:
        return 15;
      case PoseLandmarkType.rightWrist:
        return 16;
      case PoseLandmarkType.leftHip:
        return 23;
      case PoseLandmarkType.rightHip:
        return 24;
      case PoseLandmarkType.leftKnee:
        return 25;
      case PoseLandmarkType.rightKnee:
        return 26;
      case PoseLandmarkType.leftAnkle:
        return 27;
      case PoseLandmarkType.rightAnkle:
        return 28;
      default:
        return null;
    }
  }

  void _processFrameLandmarks() {
    if (_isLiveTracking) {
      if (!_useLiveCameraDetection) {
        _landmarksNotifier.value = {};
      }
      return;
    }
    if (!_calibrationDone || _isPaused) return;

    const progress = 0.0;
    final exerciseType = widget.exerciseTitle.toLowerCase();

    // We will generate the 12 key landmarks listed in model_specs.txt:

    final Map<int, Point3D> landmarks = {};

    final double midX = 200;
    final double midY = 400;

    // Default stable landmarks
    landmarks[23] = Point3D(midX + 35, midY + 20, 0);
    landmarks[24] = Point3D(midX - 35, midY + 20, 0);
    landmarks[25] = Point3D(midX + 40, midY + 100, 0);
    landmarks[26] = Point3D(midX - 40, midY + 100, 0);
    landmarks[27] = Point3D(midX + 45, midY + 180, 0);
    landmarks[28] = Point3D(midX - 45, midY + 180, 0);

    landmarks[0] = Point3D(midX, midY - 170, 0);

    if (exerciseType.contains('push')) {
      final double angleDeg = 205 + (progress * 50);
      final double angleRad = angleDeg * math.pi / 180;
      landmarks[13] = Point3D(midX - 80, midY + 45, 0);
      landmarks[11] = Point3D(landmarks[13]!.x, landmarks[13]!.y - 60, 0);
      landmarks[15] = Point3D(
        landmarks[13]!.x + 50 * math.cos(angleRad - math.pi / 2),
        landmarks[13]!.y + 50 * math.sin(angleRad - math.pi / 2),
        0,
      );

      landmarks[14] = Point3D(midX + 80, midY + 45, 0);
      landmarks[12] = Point3D(landmarks[14]!.x, landmarks[14]!.y - 60, 0);
      landmarks[16] = Point3D(
        landmarks[14]!.x - 50 * math.cos(angleRad - math.pi / 2),
        landmarks[14]!.y + 50 * math.sin(angleRad - math.pi / 2),
        0,
      );

      final double bodyOffset = math.sin(progress * math.pi) * 35.0;
      landmarks[23] = Point3D(midX + 80, midY + 100 + (bodyOffset * 0.6), 0);
      landmarks[24] = Point3D(midX + 90, midY + 80 + (bodyOffset * 0.6), 0);
      landmarks[25] = Point3D(midX + 170, midY + 150 + (bodyOffset * 0.3), 0);
      landmarks[26] = Point3D(midX + 180, midY + 130 + (bodyOffset * 0.3), 0);
      landmarks[27] = Point3D(midX + 250, midY + 200, 0);
      landmarks[28] = Point3D(midX + 260, midY + 180, 0);
      landmarks[0] = Point3D(midX - 110, midY - 60 + bodyOffset, 0);
    } else if (exerciseType.contains('squat')) {
      final double rightLegDeg = 165 - (progress * 30);
      final double rightLegRad = rightLegDeg * math.pi / 180;
      landmarks[26] = Point3D(midX - 50, midY + 90, 0);
      landmarks[24] = Point3D(landmarks[26]!.x, landmarks[26]!.y - 80, 0);
      landmarks[28] = Point3D(
        landmarks[26]!.x + 90 * math.cos(rightLegRad - math.pi / 2),
        landmarks[26]!.y + 90 * math.sin(rightLegRad - math.pi / 2),
        0,
      );

      final double leftLegDeg = 215 + (progress * 10);
      final double leftLegRad = leftLegDeg * math.pi / 180;
      landmarks[25] = Point3D(midX + 50, midY + 90, 0);
      landmarks[23] = Point3D(landmarks[25]!.x, landmarks[25]!.y - 80, 0);
      landmarks[27] = Point3D(
        landmarks[25]!.x + 90 * math.cos(leftLegRad - math.pi / 2),
        landmarks[25]!.y + 90 * math.sin(leftLegRad - math.pi / 2),
        0,
      );

      final double bodyOffset = math.sin(progress * math.pi) * 55.0;
      landmarks[11] = Point3D(midX + 55, midY - 120 + bodyOffset, 0);
      landmarks[12] = Point3D(midX - 55, midY - 120 + bodyOffset, 0);
      landmarks[13] = Point3D(midX + 80, midY - 70 + bodyOffset, 0);
      landmarks[14] = Point3D(midX - 80, midY - 70 + bodyOffset, 0);
      landmarks[15] = Point3D(midX + 60, midY - 30 + bodyOffset, 0);
      landmarks[16] = Point3D(midX - 60, midY - 30 + bodyOffset, 0);
      landmarks[0] = Point3D(midX, midY - 170 + bodyOffset, 0);
    } else if (exerciseType.contains('curl') ||
        exerciseType.contains('bicep')) {
      final double rightArmDeg = 180 + (progress * 150);
      final double rightArmRad = rightArmDeg * math.pi / 180;
      landmarks[14] = Point3D(midX - 70, midY - 60, 0);
      landmarks[12] = Point3D(landmarks[14]!.x, landmarks[14]!.y - 60, 0);
      landmarks[16] = Point3D(
        landmarks[14]!.x + 70 * math.cos(rightArmRad - math.pi / 2),
        landmarks[14]!.y + 70 * math.sin(rightArmRad - math.pi / 2),
        0,
      );

      final double leftArmDeg = 180 + (progress * 150);
      final double leftArmRad = leftArmDeg * math.pi / 180;
      landmarks[13] = Point3D(midX + 70, midY - 60, 0);
      landmarks[11] = Point3D(landmarks[13]!.x, landmarks[13]!.y - 60, 0);
      landmarks[15] = Point3D(
        landmarks[13]!.x + 70 * math.cos(leftArmRad - math.pi / 2),
        landmarks[13]!.y + 70 * math.sin(leftArmRad - math.pi / 2),
        0,
      );

      landmarks[11] = Point3D(midX + 55, midY - 120, 0);
      landmarks[12] = Point3D(midX - 55, midY - 120, 0);
    } else {
      final double rightArmDeg = 290 - (progress * 60);
      final double rightArmRad = rightArmDeg * math.pi / 180;
      landmarks[14] = Point3D(midX - 75, midY - 100, 0);
      landmarks[12] = Point3D(landmarks[14]!.x, landmarks[14]!.y - 60, 0);
      landmarks[16] = Point3D(
        landmarks[14]!.x + 70 * math.cos(rightArmRad - math.pi / 2),
        landmarks[14]!.y + 70 * math.sin(rightArmRad - math.pi / 2),
        0,
      );

      final double leftArmDeg = 70 + (progress * 60);
      final double leftArmRad = leftArmDeg * math.pi / 180;
      landmarks[13] = Point3D(midX + 75, midY - 100, 0);
      landmarks[11] = Point3D(landmarks[13]!.x, landmarks[13]!.y - 60, 0);
      landmarks[15] = Point3D(
        landmarks[13]!.x + 70 * math.cos(leftArmRad - math.pi / 2),
        landmarks[13]!.y + 70 * math.sin(leftArmRad - math.pi / 2),
        0,
      );

      landmarks[11] = Point3D(midX + 55, midY - 120, 0);
      landmarks[12] = Point3D(midX - 55, midY - 120, 0);
    }

    _landmarksNotifier.value = landmarks;

    final predictedLabel = _getPredictedLabel(widget.exerciseTitle);
    _repCounterService.update(predictedLabel, landmarks);

    final exerciseKey = _getExerciseKey(widget.exerciseTitle);
    final count = _repCounterService.getCounter(exerciseKey);
    _onRepCounted(count);
  }

  void _onRepCounted(int count) {
    if (_isResting || _isSavingWorkout) return;

    if (_isFreestyleMode) {
      if (count == _repCount) return;
      setState(() {
        _repCount = count;
        _hudMessage = "Rep $_repCount counted";
        _hudColor = AppTheme.gradientStart;
      });
      if (!_isVoiceMuted) {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
      }
      return;
    }

    final int normalizedCount = count.clamp(0, _targetReps).toInt();
    if (normalizedCount == _repCount) return;

    setState(() {
      _repCount = normalizedCount;
      _hudMessage = "Rep $_repCount counted";
      _hudColor = AppTheme.gradientStart;
    });
    if (!_isVoiceMuted) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    }

    if (normalizedCount >= _targetReps) {
      _completeCurrentSet(countFullTarget: true);
    }
  }

  void _completeCurrentSet({required bool countFullTarget}) {
    if (_isFreestyleMode ||
        !_calibrationDone ||
        _isPaused ||
        _isResting ||
        _isSavingWorkout)
      return;

    final int repsToAdd = countFullTarget
        ? _targetReps
        : _repCount.clamp(0, _targetReps).toInt();
    final bool isLastSet = _currentSet >= _targetSets;

    setState(() {
      _totalRepsAllSets = (_totalRepsAllSets + repsToAdd)
          .clamp(0, _targetSets * _targetReps)
          .toInt();
      _repCount = 0;
      _repCounterService.reset();
      _angleRepCounter.reset();

      if (isLastSet) {
        _hudMessage = "Goal Achieved! Outstanding work!";
        _hudColor = Colors.cyan;
      } else {
        _hudMessage = "Set $_currentSet complete. Take a break.";
        _hudColor = Colors.cyan;
      }
    });

    if (isLastSet) {
      _finishWorkout();
    } else {
      _startRestPhase();
    }
  }

  void _startRestPhase() {
    setState(() {
      _isResting = true;
      _restCountdown = _restSeconds;
      _hudMessage = "Resting: Prepare for Set ${_currentSet + 1}";
      _hudColor = Colors.cyan;
    });

    _repCounterService.reset();
    _angleRepCounter.reset();
    _repCount = 0;

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_restCountdown > 1) {
          _restCountdown--;
          _hudMessage =
              "Resting: Set ${_currentSet + 1} starts in $_restCountdown s";
        } else {
          _stopRestPhase();
        }
      });
    });
  }

  void _stopRestPhase() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _currentSet++;
      _repCount = 0;
      _hudMessage = "Set $_currentSet/$_targetSets: Start!";
      _hudColor = AppTheme.gradientStart;
    });
  }

  double _calculateTfliteAngle(Point3D a, Point3D b, Point3D c) {
    double radians =
        math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    double degrees = radians * (180.0 / math.pi);
    if (degrees < 0) {
      degrees += 360;
    }
    return degrees;
  }

  double _calculateTfliteDistance(Point3D a, Point3D b) {
    return math.sqrt(
      math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2) + math.pow(a.z - b.z, 2),
    );
  }

  double _calculateTfliteYDistance(Point3D a, Point3D b) {
    return (a.y - b.y).abs();
  }

  List<double> _extractTfliteFeatures(Map<int, Point3D> landmarks) {
    final requiredIds = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28];
    for (var id in requiredIds) {
      if (!landmarks.containsKey(id)) {
        return List.filled(22, -1.0);
      }
    }

    final lShoulder = landmarks[11]!;
    final rShoulder = landmarks[12]!;
    final lElbow = landmarks[13]!;
    final rElbow = landmarks[14]!;
    final lWrist = landmarks[15]!;
    final rWrist = landmarks[16]!;
    final lHip = landmarks[23]!;
    final rHip = landmarks[24]!;
    final lKnee = landmarks[25]!;
    final rKnee = landmarks[26]!;
    final lAnkle = landmarks[27]!;
    final rAnkle = landmarks[28]!;

    final features = <double>[];

    // 1. Angles
    features.add(_calculateTfliteAngle(lShoulder, lElbow, lWrist));
    features.add(_calculateTfliteAngle(rShoulder, rElbow, rWrist));
    features.add(_calculateTfliteAngle(lHip, lKnee, lAnkle));
    features.add(_calculateTfliteAngle(rHip, rKnee, rAnkle));
    features.add(_calculateTfliteAngle(lShoulder, lHip, lKnee));
    features.add(_calculateTfliteAngle(rShoulder, rHip, rKnee));
    features.add(_calculateTfliteAngle(lHip, lShoulder, lElbow));
    features.add(_calculateTfliteAngle(rHip, rShoulder, rElbow));

    // 2. Distances
    final double d1 = _calculateTfliteDistance(lShoulder, rShoulder);
    final double d2 = _calculateTfliteDistance(lHip, rHip);
    final double d3 = _calculateTfliteDistance(lHip, lKnee);
    final double d4 = _calculateTfliteDistance(rHip, rKnee);
    final double d5 = _calculateTfliteDistance(lShoulder, lHip);
    final double d6 = _calculateTfliteDistance(rShoulder, rHip);
    final double d7 = _calculateTfliteDistance(lElbow, lKnee);
    final double d8 = _calculateTfliteDistance(rElbow, rKnee);
    final double d9 = _calculateTfliteDistance(lWrist, lShoulder);
    final double d10 = _calculateTfliteDistance(rWrist, rShoulder);
    final double d11 = _calculateTfliteDistance(lWrist, lHip);
    final double d12 = _calculateTfliteDistance(rWrist, rHip);

    double normFactor = -1.0;
    final checkNorms = [d5, d6, d3, d4];
    for (var val in checkNorms) {
      if (val > 0) {
        normFactor = val;
        break;
      }
    }
    if (normFactor <= 0) {
      normFactor = 0.5;
    }

    features.add(d1 / normFactor);
    features.add(d2 / normFactor);
    features.add(d3 / normFactor);
    features.add(d4 / normFactor);
    features.add(d5 / normFactor);
    features.add(d6 / normFactor);
    features.add(d7 / normFactor);
    features.add(d8 / normFactor);
    features.add(d9 / normFactor);
    features.add(d10 / normFactor);
    features.add(d11 / normFactor);
    features.add(d12 / normFactor);

    final double y1 = _calculateTfliteYDistance(lElbow, lShoulder);
    final double y2 = _calculateTfliteYDistance(rElbow, rShoulder);

    features.add(y1 / normFactor);
    features.add(y2 / normFactor);

    return features;
  }

  void _runTfliteInference(List<double> currentFeatures) {
    if (_tfliteInterpreter == null) return;

    _frameBuffer.add(currentFeatures);
    if (_frameBuffer.length > _windowSize) {
      _frameBuffer.removeAt(0);
    }

    if (_frameBuffer.length == _windowSize) {
      var input = List.generate(
        1,
        (i) => List.generate(_windowSize, (j) => _frameBuffer[j]),
      );
      var output = List.generate(1, (i) => List.filled(4, 0.0));

      try {
        _tfliteInterpreter!.run(input, output);
        final List<double> probabilities = output.first;
        int maxIdx = 0;
        double maxVal = probabilities[0];
        for (int i = 1; i < probabilities.length; i++) {
          if (probabilities[i] > maxVal) {
            maxVal = probabilities[i];
            maxIdx = i;
          }
        }

        if (maxVal >= 0.60) {
          final predictedLabel = _exerciseLabels[maxIdx];
          if (mounted) {
            setState(() {
              _detectedExercise = predictedLabel;

              if (_detectedExerciseStable == predictedLabel) {
                _stableFrameCount = 0;
              } else {
                if (_candidateExercise == predictedLabel) {
                  _stableFrameCount++;
                } else {
                  _candidateExercise = predictedLabel;
                  _stableFrameCount = 1;
                }
                if (_stableFrameCount >= 3) {
                  _detectedExerciseStable = predictedLabel;
                  _candidateExercise = '';
                  _stableFrameCount = 0;

                  _hudMessage =
                      "Auto-classified: ${_detectedExerciseStable.toUpperCase()}";
                  _hudColor = Colors.cyan;
                }
              }
            });
          }
        }
      } catch (e) {
        debugPrint("TFLite inference error: $e");
      }
    }
  }

  String _getFreestyleExerciseKey(String label) {
    if (label == 'push-up') return 'push_up';
    if (label == 'squat') return 'squat';
    if (label == 'barbell biceps curl') return 'bicep_curl';
    if (label == 'shoulder press') return 'shoulder_press';
    return 'squat';
  }

  int _getTotalReps() {
    if (_isFreestyleMode) {
      return _angleRepCounter.getCounter('push_up') +
          _angleRepCounter.getCounter('squat') +
          _angleRepCounter.getCounter('bicep_curl') +
          _angleRepCounter.getCounter('shoulder_press');
    } else {
      return (_totalRepsAllSets + _repCount)
          .clamp(0, _targetSets * _targetReps)
          .toInt();
    }
  }

  void _onPauseToggle() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _hudMessage = "Workout Paused";
        _hudColor = Colors.white60;
      } else {
        _hudMessage = "Workout Resumed! Keep going!";
        _hudColor = AppTheme.gradientStart;
      }
    });
  }

  double _getMetValue(String title) {
    final t = title.toLowerCase().trim();
    if (t.contains('push')) return 3.8;
    if (t.contains('squat')) return 5.0;
    if (t.contains('curl') || t.contains('bicep')) return 4.5;
    if (t.contains('press') || t.contains('shoulder')) return 5.0;
    return 4.0;
  }

  double _calculateCalories() {
    if (_isFreestyleMode) {
      double totalCal = 0.0;
      final exercises = ['push_up', 'squat', 'bicep_curl', 'shoulder_press'];
      for (var key in exercises) {
        final reps = _angleRepCounter.getCounter(key);
        if (reps > 0) {
          final double met = _getMetValue(key);
          totalCal += reps * (met * 0.12);
        }
      }
      final double durationMinutes = _elapsedSeconds / 60.0;
      final double baselineCal = 4.0 * 3.5 * (65.0 / 200.0) * durationMinutes;
      return math.max(totalCal, baselineCal);
    } else {
      final double met = _getMetValue(widget.exerciseTitle);
      final double durationMinutes = _elapsedSeconds / 60.0;
      final double caloriesFromTime =
          met * 3.5 * (65.0 / 200.0) * durationMinutes;
      final int totalReps = _getTotalReps();
      final double caloriesFromReps = totalReps * (met * 0.12);

      final double finalCalories = math.max(caloriesFromTime, caloriesFromReps);
      if (finalCalories == 0.0 && totalReps > 0) {
        return totalReps * 3.0;
      }
      return finalCalories;
    }
  }

  void _showWorkoutSummaryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final int finalReps = _getTotalReps();
        final int finalSeconds = _elapsedSeconds;
        final double calBurned =
            (_completedSession != null && _completedSession!.caloriesBurned > 0)
            ? _completedSession!.caloriesBurned.toDouble()
            : _calculateCalories();

        final int totalRepsTarget = _targetSets * _targetReps;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF131415),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.gradientStart.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Completed Medal Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2C29),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gradientStart, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: AppTheme.gradientStart,
                      size: 48,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Workout Complete!',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.exerciseTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),

                const SizedBox(height: 28),

                // Stats Grid
                Table(
                  children: [
                    TableRow(
                      children: [
                        _buildSummaryStatCard(
                          'Reps Done',
                          _isFreestyleMode
                              ? '$finalReps'
                              : '$finalReps/$totalRepsTarget',
                          Colors.white,
                        ),
                        _buildSummaryStatCard(
                          'Duration',
                          _formatTime(finalSeconds),
                          Colors.white,
                        ),
                      ],
                    ),
                    const TableRow(
                      children: [SizedBox(height: 12), SizedBox(height: 12)],
                    ),
                    TableRow(
                      children: [
                        _buildSummaryStatCard(
                          'Form Score',
                          'Not scored',
                          Colors.white54,
                        ),
                        _buildSummaryStatCard(
                          'Calories',
                          '${calBurned.toStringAsFixed(0)} kcal',
                          Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _repCount = 0;
                            _elapsedSeconds = 0;
                            _currentSet = 1;
                            _totalRepsAllSets = 0;
                            _isResting = false;
                            _repCounterService.reset();
                            _angleRepCounter.reset();
                          });
                          _startCalibration();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.gradientStart.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryStatCard(String label, String value, Color valueColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2021),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.4),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Simulated Live Camera View Background (styled dark tech feed)
          _buildCameraMockFeed(),

          // 2. Animated Custom Skeletal Overlay (AI Posture Detection)
          if (_isCameraInitialized)
            Positioned.fill(
              child: ValueListenableBuilder<Map<int, Point3D>>(
                valueListenable: _landmarksNotifier,
                builder: (context, landmarks, child) {
                  final isFront =
                      _cameraController?.description.lensDirection ==
                      CameraLensDirection.front;
                  final previewSize = _getCameraPreviewDisplaySize();
                  return CustomPaint(
                    painter: PoseSkeletalPainter(
                      landmarks: landmarks,
                      pulseIntensity: _pulseController.value,
                      previewWidth: previewSize.width,
                      previewHeight: previewSize.height,
                      isFrontCamera: isFront,
                    ),
                  );
                },
              ),
            ),

          // 3. AI Scanner/Calibration HUD Overlay (When calibrating)
          if (!_calibrationDone) _buildCalibrationOverlay(screenSize, isTablet),

          // 4. Floating HUD Displays (Accuracy, Target, Coach waves)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: _buildTopStatusHUD(isTablet),
          ),

          // 5. Giant Circular Rep Count HUD (Under top HUD)
          if (_calibrationDone)
            Positioned(
              left: 24,
              top: MediaQuery.of(context).padding.top + 96,
              child: _buildRepCounterHUD(isTablet),
            ),

          // 6. Form Feedback Alert Overlay (Bottom alert HUD)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: _buildBottomControlsHUD(isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraMockFeed() {
    final cameraPreviewSize = _getCameraPreviewDisplaySize();

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview
          if (_isCameraInitialized && _cameraController != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cameraPreviewSize.width,
                height: cameraPreviewSize.height,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppTheme.gradientStart),
            ),

          // 2. Grid scanning lines (tech background overlay)
          CustomPaint(painter: TechGridPainter()),

          // 3. Real-time green glow lens blur vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationOverlay(Size screenSize, bool isTablet) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Pulsating Scanning Target Circle
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.12);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: isTablet ? 240 : 180,
                    height: isTablet ? 240 : 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.cyan.withOpacity(0.7),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(
                            0.2 * _pulseController.value,
                          ),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.accessibility_new_rounded,
                        color: Colors.cyan,
                        size: isTablet ? 90 : 70,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            Text(
              'CALIBRATING CAMERA',
              style: TextStyle(
                fontSize: isTablet ? 26 : 20,
                fontWeight: FontWeight.w900,
                color: Colors.cyan,
                letterSpacing: 2,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: ValueListenableBuilder<String>(
                valueListenable: _calibrationGuidance,
                builder: (context, guidance, _) => Text(
                  guidance,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.6),
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Premium scanning progress bar
            Container(
              width: 220,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: ValueListenableBuilder<double>(
                  valueListenable: _calibrationProgress,
                  builder: (context, progress, _) => LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    color: Colors.cyan,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.cyan.withOpacity(0.15),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: _calibrationGuidance,
                    builder: (context, guidance, _) => Text(
                      guidance.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.cyan,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI Smart Motion Tracking Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.4),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatusHUD(bool isTablet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131415).withOpacity(0.85),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
      ),
      child: Row(
        children: [
          // Left: Active Info & Title
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPaused
                        ? Colors.amberAccent
                        : AppTheme.gradientStart,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.exerciseTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isTablet ? 20 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isPaused ? 'PAUSED' : 'AI ACTIVE',
                        style: TextStyle(
                          fontSize: isTablet ? 13 : 11,
                          fontWeight: FontWeight.bold,
                          color: _isPaused
                              ? Colors.amberAccent
                              : AppTheme.gradientStart,
                          letterSpacing: 1,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Text(
            _formatTime(_elapsedSeconds),
            style: TextStyle(
              fontSize: isTablet ? 28 : 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Courier',
            ),
          ),

          const SizedBox(width: 12),

          GestureDetector(
            onTap: () {
              setState(() {
                _isVoiceMuted = !_isVoiceMuted;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isVoiceMuted
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFF0C2C29),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isVoiceMuted
                      ? Colors.white.withOpacity(0.15)
                      : AppTheme.gradientStart.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: _isVoiceMuted
                  ? Icon(
                      Icons.volume_off_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: isTablet ? 24 : 18,
                    )
                  : AnimatedBuilder(
                      animation: _audioWaveController,
                      builder: (context, child) {
                        return Icon(
                          Icons.volume_up_rounded,
                          color: AppTheme.gradientStart,
                          size: isTablet ? 24 : 18,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreestyleMiniCard(
    String label,
    int count,
    IconData icon,
    bool isActive,
    bool isTablet,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF0C2C29).withOpacity(0.9)
            : const Color(0xFF131415).withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppTheme.gradientStart
              : Colors.white.withOpacity(0.08),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.gradientStart.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppTheme.gradientStart,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(
            icon,
            color: isActive ? AppTheme.gradientStart : Colors.white30,
            size: isTablet ? 18 : 15,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isTablet ? 10.5 : 8.5,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white70 : Colors.white30,
                  fontFamily: 'Inter',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count reps',
                style: TextStyle(
                  fontSize: isTablet ? 15 : 13,
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppTheme.gradientStart : Colors.white70,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepCounterHUD(bool isTablet) {
    if (_isResting) {
      final double percent = _restCountdown / _restSeconds;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isTablet ? 200 : 170,
            height: isTablet ? 200 : 170,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.cyan.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: isTablet ? 182 : 152,
                  height: isTablet ? 182 : 152,
                  child: CircularProgressIndicator(
                    value: percent,
                    strokeWidth: 6,
                    color: Colors.cyan,
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_restCountdown',
                      style: TextStyle(
                        fontSize: isTablet ? 62 : 52,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyan,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      'RESTING',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.cyan.withOpacity(0.6),
                        fontFamily: 'Inter',
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
            ),
            child: Text(
              'Set $_currentSet/$_targetSets Complete!',
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      );
    }

    final int totalRepsTarget = _targetSets * _targetReps;
    final int totalRepsDone = _getTotalReps().clamp(0, totalRepsTarget).toInt();
    final double percent = _isFreestyleMode
        ? 0.0
        : (totalRepsDone / totalRepsTarget).clamp(0.0, 1.0).toDouble();
    final String repsLabel = _isFreestyleMode
        ? '${_getTotalReps()}'
        : '$_repCount';
    final String repsSubLabel = _isFreestyleMode
        ? 'TOTAL REPS'
        : 'SET $_currentSet/$_targetSets  •  TARGET $_targetReps';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isTablet ? 200 : 170,
          height: isTablet ? 200 : 170,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!_isFreestyleMode)
                SizedBox(
                  width: isTablet ? 182 : 152,
                  height: isTablet ? 182 : 152,
                  child: CircularProgressIndicator(
                    value: percent,
                    strokeWidth: 6,
                    color: AppTheme.gradientStart,
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    repsLabel,
                    style: TextStyle(
                      fontSize: _isFreestyleMode
                          ? (isTablet ? 62 : 52)
                          : (isTablet ? 72 : 58),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Text(
                    repsSubLabel,
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.4),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (_isFreestyleMode) ...[
          // Gorgeous full list wrap for freedom mode
          Container(
            constraints: BoxConstraints(maxWidth: isTablet ? 340 : 270),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFreestyleMiniCard(
                  'Push-Up',
                  _angleRepCounter.getCounter('push_up'),
                  Icons.fitness_center_rounded,
                  _detectedExerciseStable == 'push-up',
                  isTablet,
                ),
                _buildFreestyleMiniCard(
                  'Squat',
                  _angleRepCounter.getCounter('squat'),
                  Icons.accessibility_new_rounded,
                  _detectedExerciseStable == 'squat',
                  isTablet,
                ),
                _buildFreestyleMiniCard(
                  'Bicep Curl',
                  _angleRepCounter.getCounter('bicep_curl'),
                  Icons.sports_gymnastics_rounded,
                  _detectedExerciseStable == 'barbell biceps curl',
                  isTablet,
                ),
                _buildFreestyleMiniCard(
                  'Shoulder Press',
                  _angleRepCounter.getCounter('shoulder_press'),
                  Icons.bolt_rounded,
                  _detectedExerciseStable == 'shoulder press',
                  isTablet,
                ),
              ],
            ),
          ),
        ] else ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppTheme.gradientStart.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt,
                      color: AppTheme.gradientStart,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TCN REP COUNT',
                      style: const TextStyle(
                        color: AppTheme.gradientStart,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2C29).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.cyan.withOpacity(0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.psychology_rounded,
                      color: Colors.cyan,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SET $_currentSet/$_targetSets',
                      style: const TextStyle(
                        color: Colors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBottomControlsHUD(bool isTablet) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _hudColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hudColor.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: _hudColor.withOpacity(0.05), blurRadius: 16),
            ],
          ),
          child: Row(
            children: [
              Icon(
                _hudColor == AppTheme.gradientStart
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: _hudColor,
                size: 26,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _hudMessage,
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            GestureDetector(
              onTap: () {
                _workoutTimer?.cancel();
                _restTimer?.cancel();
                Navigator.of(context).pop();
              },
              child: Container(
                width: isTablet ? 68 : 58,
                height: isTablet ? 68 : 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2021).withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.redAccent,
                  size: 26,
                ),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_isResting) {
                    _stopRestPhase();
                  } else if (_isFreestyleMode) {
                    _finishWorkout();
                  } else {
                    _completeCurrentSet(countFullTarget: false);
                  }
                },
                child: Container(
                  height: isTablet ? 68 : 58,
                  decoration: BoxDecoration(
                    gradient: (_calibrationDone && !_isPaused) || _isResting
                        ? AppTheme.primaryGradient
                        : null,
                    color: (_calibrationDone && !_isPaused) || _isResting
                        ? null
                        : const Color(0xFF131415),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: ((_calibrationDone && !_isPaused) || _isResting)
                        ? [
                            BoxShadow(
                              color: AppTheme.gradientStart.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                    border: Border.all(
                      color: ((_calibrationDone && !_isPaused) || _isResting)
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _isResting
                          ? 'SKIP REST & START SET ${_currentSet + 1}'
                          : _isFreestyleMode
                          ? 'FINISH WORKOUT'
                          : !_calibrationDone
                          ? 'CALIBRATING...'
                          : _isPaused
                          ? 'PAUSED'
                          : 'BREAK',
                      style: TextStyle(
                        fontSize: isTablet ? 17 : 14.5,
                        fontWeight: FontWeight.bold,
                        color: ((_calibrationDone && !_isPaused) || _isResting)
                            ? Colors.black
                            : Colors.white60,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (!_isResting) ...[
              const SizedBox(width: 16),

              GestureDetector(
                onTap: _onPauseToggle,
                child: Container(
                  width: isTablet ? 68 : 58,
                  height: isTablet ? 68 : 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2021).withOpacity(0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isPaused
                          ? Colors.amberAccent.withOpacity(0.4)
                          : Colors.white.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: _isPaused ? Colors.amberAccent : Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// 1. Tech Grid Background scanning effect
class TechGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0C2C29).withOpacity(0.15)
      ..strokeWidth = 1.0;

    const spacing = 45.0;

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 2. Animated Custom Skeletal Keypoints Painter drawing a gorgeous posture skeleton doing workouts!
class PoseSkeletalPainter extends CustomPainter {
  final Map<int, Point3D> landmarks;
  final double pulseIntensity;
  final double previewWidth;
  final double previewHeight;
  final bool isFrontCamera;

  PoseSkeletalPainter({
    required this.landmarks,
    required this.pulseIntensity,
    required this.previewWidth,
    required this.previewHeight,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final linePaint = Paint()
      ..color = AppTheme.gradientStart
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = const Color(0xFF00BBFC)
      ..style = PaintingStyle.fill;

    final pulsePaint = Paint()
      ..color = AppTheme.gradientStart.withOpacity(0.3 * (1.0 - pulseIntensity))
      ..style = PaintingStyle.fill;

    final double screenWidth = size.width;
    final double screenHeight = size.height;
    final double scale = math.max(
      screenWidth / previewWidth,
      screenHeight / previewHeight,
    );
    final double scaledWidth = previewWidth * scale;
    final double scaledHeight = previewHeight * scale;
    final double dx = (screenWidth - scaledWidth) / 2;
    final double dy = (screenHeight - scaledHeight) / 2;

    Offset getOffset(int id) {
      final pt = landmarks[id];
      if (pt == null) return Offset.zero;

      final double actualX = isFrontCamera ? (1.0 - pt.x) : pt.x;
      final double screenX = dx + (actualX * scaledWidth);
      final double screenY = dy + (pt.y * scaledHeight);
      return Offset(screenX, screenY);
    }

    final head = getOffset(0);
    final lShoulder = getOffset(11);
    final rShoulder = getOffset(12);

    final neck = (lShoulder == Offset.zero || rShoulder == Offset.zero)
        ? Offset.zero
        : Offset(
            (lShoulder.dx + rShoulder.dx) / 2,
            (lShoulder.dy + rShoulder.dy) / 2,
          );

    final lElbow = getOffset(13);
    final rElbow = getOffset(14);
    final lWrist = getOffset(15);
    final rWrist = getOffset(16);
    final lHip = getOffset(23);
    final rHip = getOffset(24);

    final spine = (lHip == Offset.zero || rHip == Offset.zero)
        ? Offset.zero
        : Offset((lHip.dx + rHip.dx) / 2, (lHip.dy + rHip.dy) / 2 - 30);

    final lKnee = getOffset(25);
    final rKnee = getOffset(26);
    final lAnkle = getOffset(27);
    final rAnkle = getOffset(28);

    // 1. Draw connecting bones lines
    if (head != Offset.zero && neck != Offset.zero)
      canvas.drawLine(head, neck, linePaint);
    if (rShoulder != Offset.zero && lShoulder != Offset.zero)
      canvas.drawLine(rShoulder, lShoulder, linePaint);
    if (neck != Offset.zero && spine != Offset.zero)
      canvas.drawLine(neck, spine, linePaint);

    if (rShoulder != Offset.zero && rElbow != Offset.zero)
      canvas.drawLine(rShoulder, rElbow, linePaint);
    if (rElbow != Offset.zero && rWrist != Offset.zero)
      canvas.drawLine(rElbow, rWrist, linePaint);
    if (lShoulder != Offset.zero && lElbow != Offset.zero)
      canvas.drawLine(lShoulder, lElbow, linePaint);
    if (lElbow != Offset.zero && lWrist != Offset.zero)
      canvas.drawLine(lElbow, lWrist, linePaint);

    if (spine != Offset.zero && rHip != Offset.zero)
      canvas.drawLine(spine, rHip, linePaint);
    if (spine != Offset.zero && lHip != Offset.zero)
      canvas.drawLine(spine, lHip, linePaint);
    if (rHip != Offset.zero && lHip != Offset.zero)
      canvas.drawLine(rHip, lHip, linePaint);

    if (rHip != Offset.zero && rKnee != Offset.zero)
      canvas.drawLine(rHip, rKnee, linePaint);
    if (rKnee != Offset.zero && rAnkle != Offset.zero)
      canvas.drawLine(rKnee, rAnkle, linePaint);
    if (lHip != Offset.zero && lKnee != Offset.zero)
      canvas.drawLine(lHip, lKnee, linePaint);
    if (lKnee != Offset.zero && lAnkle != Offset.zero)
      canvas.drawLine(lKnee, lAnkle, linePaint);

    // 2. Draw joint circles with glowing breath effect rings
    final joints = [
      head,
      neck,
      rShoulder,
      lShoulder,
      rElbow,
      lElbow,
      rWrist,
      lWrist,
      spine,
      rHip,
      lHip,
      rKnee,
      lKnee,
      rAnkle,
      lAnkle,
    ];
    for (var joint in joints) {
      if (joint == Offset.zero) continue;

      canvas.drawCircle(joint, 12.0 * pulseIntensity, pulsePaint);

      canvas.drawCircle(joint, 5.0, jointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PoseSkeletalPainter oldDelegate) =>
      oldDelegate.pulseIntensity != pulseIntensity ||
      oldDelegate.landmarks != landmarks ||
      oldDelegate.previewWidth != previewWidth ||
      oldDelegate.previewHeight != previewHeight ||
      oldDelegate.isFrontCamera != isFrontCamera;
}
