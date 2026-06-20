import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'camera_access_screen.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> with TickerProviderStateMixin {
  late List<AnimationController> _staggerControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;
  
  bool _isBackHovered = false;
  bool _isContinueHovered = false;

  @override
  void initState() {
    super.initState();

    // 5 Staggered Animation intervals:
    // 0: "Powered by AI" Title
    // 1: Subtitle
    
    
    
    _staggerControllers = List.generate(
      5,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _fadeAnimations = _staggerControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    _slideAnimations = _staggerControllers.map((controller) {
      return Tween<Offset>(begin: const Offset(0.0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      );
    }).toList();

    
    _animateStaggered();
  }

  Future<void> _animateStaggered() async {
    for (var i = 0; i < _staggerControllers.length; i++) {
      await Future.delayed(Duration(milliseconds: i == 0 ? 100 : 150));
      if (mounted) {
        _staggerControllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _staggerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Header Section: "Powered by AI"
              AnimatedBuilder(
                animation: _staggerControllers[0],
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimations[0],
                    child: SlideTransition(
                      position: _slideAnimations[0],
                      child: Text(
                        'Powered by AI',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: isTablet ? 60 : 44,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              
              AnimatedBuilder(
                animation: _staggerControllers[1],
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimations[1],
                    child: SlideTransition(
                      position: _slideAnimations[1],
                      child: Text(
                        'Experience the future of fitness training',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: isTablet ? 22 : 18,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const Spacer(flex: 2),

              // Features List
              _buildFeatureItem(
                index: 2,
                iconPath: 'assets/icons/eye.svg',
                fallbackIcon: Icons.remove_red_eye_rounded,
                title: 'AI Pose Detection',
                description: 'Advanced computer vision tracks your form in real-time',
                isTablet: isTablet,
              ),

              const Spacer(),

              _buildFeatureItem(
                index: 3,
                iconPath: 'assets/icons/heartbeat.svg',
                fallbackIcon: Icons.favorite_rounded,
                title: 'Real-Time Feedback',
                description: 'Get instant corrections to perfect your technique',
                isTablet: isTablet,
              ),

              const Spacer(),

              _buildFeatureItem(
                index: 4,
                iconPath: 'assets/icons/arrow_trend_up.svg',
                fallbackIcon: Icons.trending_up_rounded,
                title: 'Track Progress',
                description: 'Detailed analytics to monitor your fitness journey',
                isTablet: isTablet,
              ),

              const Spacer(flex: 3),

              // Bottom Button Row: Back & Continue
              Row(
                children: [
                  // Back Button (Outline)
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
                                  fontSize: isTablet ? 22 : 18,
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

                  // Continue Button (Filled Gradient)
                  Expanded(
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isContinueHovered = true),
                      onExit: (_) => setState(() => _isContinueHovered = false),
                      child: AnimatedScale(
                        scale: _isContinueHovered ? 1.02 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const CameraAccessScreen(),
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
                            },
                          child: Container(
                            height: isTablet ? 76 : 64,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.gradientStart.withOpacity(0.3),
                                  blurRadius: _isContinueHovered ? 20 : 10,
                                  offset: const Offset(0, 4),
                                  spreadRadius: _isContinueHovered ? 2 : 0,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: isTablet ? 22 : 18,
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
  }

  Widget _buildFeatureItem({
    required int index,
    required String iconPath,
    required IconData fallbackIcon,
    required String title,
    required String description,
    required bool isTablet,
  }) {
    return AnimatedBuilder(
      animation: _staggerControllers[index],
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimations[index],
          child: SlideTransition(
            position: _slideAnimations[index],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Icon Container (Glassmorphic dark look with neon accent)
                Container(
                  width: isTablet ? 60 : 48,
                  height: isTablet ? 60 : 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      iconPath,
                      width: isTablet ? 30 : 24,
                      height: isTablet ? 30 : 24,
                      colorFilter: const ColorFilter.mode(
                        AppTheme.gradientStart,
                        BlendMode.srcIn,
                      ),
                      placeholderBuilder: (context) => Icon(
                        fallbackIcon,
                        size: isTablet ? 28 : 22,
                        color: AppTheme.gradientStart,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 20),

                // Right Content (Title & Description)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 15,
                          fontWeight: FontWeight.normal,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Inter',
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
