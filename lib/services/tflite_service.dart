// tflite_service.dart
// Abstract wrapper interface to allow conditional compilation on Mobile and Web.

export 'tflite_service_stub.dart'
    if (dart.library.io) 'tflite_service_mobile.dart'
    if (dart.library.html) 'tflite_service_web.dart';

abstract class TfliteInterpreterWrapper {
  Future<void> loadModel(String assetPath);
  void run(Object input, Object output);
  void close();
}
