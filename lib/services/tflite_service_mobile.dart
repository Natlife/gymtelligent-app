// tflite_service_mobile.dart
import 'package:tflite_flutter/tflite_flutter.dart';
import 'tflite_service.dart';

class TfliteInterpreterWrapperImpl implements TfliteInterpreterWrapper {
  Interpreter? _interpreter;

  @override
  Future<void> loadModel(String assetPath) async {
    _interpreter = await Interpreter.fromAsset(assetPath);
  }

  @override
  void run(Object input, Object output) {
    _interpreter?.run(input, output);
  }

  @override
  void close() {
    _interpreter?.close();
  }
}

TfliteInterpreterWrapper createInterpreter() => TfliteInterpreterWrapperImpl();

void openWebDemo() {
  // Mobile doesn't need to do anything here
}
