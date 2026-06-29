import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class OnboardingStep {
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final String highlightShape; // 'rect' or 'circle'

  OnboardingStep({
    required this.title,
    required this.description,
    this.targetKey,
    this.highlightShape = 'rect',
  });
}

class OnboardingTour {
  static OverlayEntry? _overlayEntry;

  static void start(
    BuildContext context, {
    required List<OnboardingStep> steps,
    required String tourKey,
    bool force = false,
    VoidCallback? onFinished,
  }) async {
    // If not forced, check SharedPreferences to see if this tour was already completed.
    if (!force) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isCompleted = prefs.getBool('tour_completed_$tourKey') ?? false;
        if (isCompleted) {
          onFinished?.call();
          return;
        }
      } catch (e) {
        debugPrint("Error reading SharedPreferences for onboarding: $e");
      }
    }

    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => OnboardingTourWidget(
        steps: steps,
        tourKey: tourKey,
        onFinished: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
          onFinished?.call();
        },
        onDismissed: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
        },
      ),
    );

    if (!context.mounted) return;

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void dismiss() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }
}

class OnboardingTourWidget extends StatefulWidget {
  final List<OnboardingStep> steps;
  final String tourKey;
  final VoidCallback onFinished;
  final VoidCallback onDismissed;

  const OnboardingTourWidget({
    super.key,
    required this.steps,
    required this.tourKey,
    required this.onFinished,
    required this.onDismissed,
  });

  @override
  State<OnboardingTourWidget> createState() => _OnboardingTourWidgetState();
}

class _OnboardingTourWidgetState extends State<OnboardingTourWidget>
    with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Rect? _getTargetRect(GlobalKey? key) {
    if (key == null) return null;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final position = renderBox.localToGlobal(Offset.zero);
    return position & renderBox.size;
  }

  void _nextStep() {
    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    } else {
      _finishTour();
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  void _finishTour() {
    _fadeController.reverse().then((_) {
      widget.onFinished();
    });
  }

  void _skipTour() {
    _fadeController.reverse().then((_) {
      widget.onDismissed();
    });
  }

  void _dontShowAgainAndDismiss() {
    _fadeController.reverse().then((_) {
      widget.onDismissed();
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('tour_completed_${widget.tourKey}', true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStepIndex];
    final screenSize = MediaQuery.of(context).size;
    final targetRect = _getTargetRect(step.targetKey);

    double? cardTop;
    double? cardBottom;
    double cardLeft = 16.0;
    double cardRight = 16.0;

    // Determine position of the card based on targeted element
    if (targetRect == null) {
      cardTop = (screenSize.height - 220) / 2;
    } else {
      final targetCenterY = targetRect.center.dy;
      // Leave a gap of 16px from the highlighted item
      if (targetCenterY < screenSize.height / 2) {
        cardTop = targetRect.bottom + 20;
        // Make sure it doesn't overflow screen bottom
        if (cardTop + 220 > screenSize.height) {
          cardTop = null;
          cardBottom = 16.0;
        }
      } else {
        cardBottom = (screenSize.height - targetRect.top) + 20;
        // Make sure it doesn't overflow screen top
        if (cardBottom + 220 > screenSize.height) {
          cardBottom = null;
          cardTop = 16.0;
        }
      }
    }

    // Wrap in WillPopScope to prevent back button dismissing target screen during tour
    return WillPopScope(
      onWillPop: () async {
        _skipTour();
        return false;
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // 1. Hole background overlay
            Positioned.fill(
              child: CustomPaint(
                painter: HolePainter(
                  targetRect: targetRect,
                  shape: step.highlightShape,
                ),
              ),
            ),

            // 2. Click block gestures outside the highlighted item (if any)
            // This prevents interaction with underlying components
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // Option: progress on background tap, or just absorb pointer.
                  // For safety, we just absorb to keep user focused on the popup actions.
                },
                child: const SizedBox(),
              ),
            ),

            // 3. Information popup card
            Positioned(
              top: cardTop,
              bottom: cardBottom,
              left: cardLeft,
              right: cardRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  margin: EdgeInsets.symmetric(
                    horizontal: screenSize.width > 600 ? (screenSize.width - 500) / 2 : 0,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF161A1E).withOpacity(0.92),
                        const Color(0xFF0F2624).withOpacity(0.92),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF00FE8B).withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FE8B).withOpacity(0.12),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Progress & Skip Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FE8B).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Bước ${_currentStepIndex + 1} / ${widget.steps.length}',
                                    style: const TextStyle(
                                      color: Color(0xFF00FE8B),
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _dontShowAgainAndDismiss,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Text(
                                          'Không hiện lại',
                                          style: TextStyle(
                                            color: const Color(0xFFFF5252).withOpacity(0.85),
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _skipTour,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Text(
                                          'Bỏ qua',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Step Title
                            Text(
                              step.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Step Description
                            Text(
                              step.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14.0,
                                height: 1.45,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Navigation Control Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_currentStepIndex > 0) ...[
                                  GestureDetector(
                                    onTap: _prevStep,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                      ),
                                      child: const Text(
                                        'Quay lại',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                GestureDetector(
                                  onTap: _nextStep,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00FE8B).withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _currentStepIndex == widget.steps.length - 1
                                          ? 'Hoàn tất'
                                          : 'Tiếp tục',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HolePainter extends CustomPainter {
  final Rect? targetRect;
  final String shape;

  HolePainter({this.targetRect, this.shape = 'rect'});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.78)
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
      return;
    }

    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path();

    // Inflate a bit to give breathing room to the highlighted widget
    final double padding = shape == 'circle' ? 6.0 : 8.0;
    final r = targetRect!.inflate(padding);

    if (shape == 'circle') {
      final radius = math.max(r.width, r.height) / 2;
      innerPath.addOval(Rect.fromCircle(center: targetRect!.center, radius: radius));
    } else {
      innerPath.addRRect(RRect.fromRectAndRadius(r, const Radius.circular(16)));
    }

    final path = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(path, backgroundPaint);

    // Glowing outline
    final glowPaint = Paint()
      ..color = const Color(0xFF00FE8B).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final borderPaint = Paint()
      ..color = const Color(0xFF00FE8B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (shape == 'circle') {
      final radius = math.max(r.width, r.height) / 2;
      canvas.drawOval(Rect.fromCircle(center: targetRect!.center, radius: radius), glowPaint);
      canvas.drawOval(Rect.fromCircle(center: targetRect!.center, radius: radius), borderPaint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(16)), glowPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(16)), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HolePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.shape != shape;
  }
}
