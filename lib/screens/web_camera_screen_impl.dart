// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';

/// The real iframe-based Web camera screen — compiled only on Web targets.
class WebCameraScreenImpl extends StatefulWidget {
  const WebCameraScreenImpl({super.key});

  @override
  State<WebCameraScreenImpl> createState() => _WebCameraScreenImplState();
}

class _WebCameraScreenImplState extends State<WebCameraScreenImpl> {
  static const String _viewType = 'gymtelligent-mediapipe-iframe';
  static bool _viewRegistered = false;

  @override
  void initState() {
    super.initState();
    if (!_viewRegistered) {
      _viewRegistered = true;
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = 'https://gymtelligent.io.vn/pose-detection.html'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allow =
                'camera; microphone; accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
            ..allowFullscreen = true;
          return iframe;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D16),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
            SizedBox(width: 8),
            Text(
              'AI Camera — Nhận Diện Khung Xương',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: Color(0xFF10B981), size: 13),
                  SizedBox(width: 4),
                  Text(
                    'MediaPipe',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: const HtmlElementView(viewType: _viewType),
    );
  }
}
