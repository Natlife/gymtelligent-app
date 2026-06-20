import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'goal_selection_screen.dart';

class CameraAccessScreen extends StatefulWidget {
  const CameraAccessScreen({super.key});

  @override
  State<CameraAccessScreen> createState() => _CameraAccessScreenState();
}

class _CameraAccessScreenState extends State<CameraAccessScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _glowPulseAnimation;

  bool _isBackHovered = false;
  bool _isAllowHovered = false;

  @override
  void initState() {
    super.initState();

    // Fade and slide entry animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );

    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowPulseAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _requestCameraPermission() {
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.black),
            SizedBox(width: 10),
            Text(
              'Camera Access Allowed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Inter'),
            ),
          ],
        ),
        backgroundColor: AppTheme.gradientStart,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
      ),
    );

    // Navigate to GoalSelectionScreen after a short delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const GoalSelectionScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeInAnimation,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Top Pulse Camera Icon Graphic
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C2C29), 
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF0BFF88).withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0BFF88).withOpacity(0.2),
                                  blurRadius: _glowPulseAnimation.value,
                                  spreadRadius: _glowPulseAnimation.value / 3,
                                ),
                              ],
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/camera.svg',
                                width: 55,
                                height: 55,
                                colorFilter: const ColorFilter.mode(
                                  AppTheme.gradientStart,
                                  BlendMode.srcIn,
                                ),
                                placeholderBuilder: (context) => const Icon(
                                  Icons.videocam_rounded,
                                  size: 55,
                                  color: AppTheme.gradientStart,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const Spacer(),

                      // Header: "Camera Access"
                      Text(
                        'Camera Access',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: isTablet ? 52 : 38,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 18),

                      // Description Text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'We need access to your camera to analyze your workout form and count reps in real-time',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: isTablet ? 22 : 17,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const Spacer(),

                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/shield.svg',
                              width: 26,
                              height: 26,
                              colorFilter: const ColorFilter.mode(
                                AppTheme.gradientStart,
                                BlendMode.srcIn,
                              ),
                              placeholderBuilder: (context) => const Icon(
                                Icons.shield_rounded,
                                size: 24,
                                color: AppTheme.gradientStart,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Your privacy is protected. Video is never stored.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Bottom Button Row: Back & Allow Camera
                      Row(
                        children: [
                          // Back Button
                          Expanded(
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _isBackHovered = true),
                              onExit: (_) => setState(() => _isBackHovered = false),
                              child: AnimatedScale(
                                scale: _isBackHovered ? 1.02 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: isTablet ? 76 : 64,
                                    decoration: BoxDecoration(
                                      color: _isBackHovered ? Colors.white.withOpacity(0.05) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: _isBackHovered 
                                            ? Colors.white 
                                            : Colors.white.withOpacity(0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Back',
                                        style: TextStyle(
                                          fontSize: isTablet ? 20 : 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Allow Camera Button
                          Expanded(
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _isAllowHovered = true),
                              onExit: (_) => setState(() => _isAllowHovered = false),
                              child: AnimatedScale(
                                scale: _isAllowHovered ? 1.02 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: GestureDetector(
                                  onTap: _requestCameraPermission,
                                  child: Container(
                                    height: isTablet ? 76 : 64,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.gradientStart.withOpacity(0.3),
                                          blurRadius: _isAllowHovered ? 20 : 10,
                                          offset: const Offset(0, 4),
                                          spreadRadius: _isAllowHovered ? 2 : 0,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Allow Camera',
                                        style: TextStyle(
                                          fontSize: isTablet ? 20 : 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
