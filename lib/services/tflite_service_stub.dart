// tflite_service_stub.dart
import 'tflite_service.dart';

class TfliteInterpreterWrapperImpl implements TfliteInterpreterWrapper {
  @override
  Future<void> loadModel(String assetPath) async {
    throw UnsupportedError('TFLite is not supported on this platform');
  }

  @override
  void run(Object input, Object output) {
    throw UnsupportedError('TFLite is not supported on this platform');
  }

  @override
  void close() {}
}

TfliteInterpreterWrapper createInterpreter() => TfliteInterpreterWrapperImpl();

void openWebDemo() {
  throw UnsupportedError('openWebDemo is only supported on Web');
}
