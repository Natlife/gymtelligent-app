// tflite_service_web.dart
import 'dart:html' as html;
import 'tflite_service.dart';

class TfliteInterpreterWrapperImpl implements TfliteInterpreterWrapper {
  @override
  Future<void> loadModel(String assetPath) async {
    // Graceful no-op on Web
  }

  @override
  void run(Object input, Object output) {
    // Mock the classification results to prevent runtime errors and keep web stable
    if (output is List<List<double>> && output.isNotEmpty && output[0].length >= 4) {
      // Return high confidence for one label so that repetition logic has a default behavior
      // [barbell biceps curl, push-up, shoulder press, squat]
      output[0] = [0.1, 0.1, 0.1, 0.7]; // Mock a Squat prediction
    }
  }

  @override
  void close() {}
}

TfliteInterpreterWrapper createInterpreter() => TfliteInterpreterWrapperImpl();

void openWebDemo() {
  html.window.open('https://gymtelligent.io.vn/pose-detection.html', '_blank');
}
