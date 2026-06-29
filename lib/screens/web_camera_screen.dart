import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Conditional import — dart:html + dart:ui_web are only available on Web.
// On mobile, we use a dummy stub so the file still compiles.
import 'web_camera_screen_stub.dart'
    if (dart.library.html) 'web_camera_screen_impl.dart';

/// Entry-point widget for the Web AI camera experience.
/// On mobile this widget should never be reached (CameraTrainingScreen
/// guards it with kIsWeb), but we keep it safe here too.
class WebCameraScreen extends StatelessWidget {
  const WebCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Web camera only available on browser.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return const WebCameraScreenImpl();
  }
}
