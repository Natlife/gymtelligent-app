import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _imagePulseAnimation;
  
  String _currentLanguage = 'EN';
  bool _isButtonHovered = false;

  @override
  void initState() {
    super.initState();

    // Intro Animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    // Subtle breathing animation for the illustration
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _imagePulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleLanguage() {
    setState(() {
      _currentLanguage = _currentLanguage == 'EN' ? 'VI' : 'EN';
    });
    
    // Show a mini snackbar with premium styling
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _currentLanguage == 'EN' ? 'Language changed to English' : 'Đã đổi sang Tiếng Việt',
          style: const TextStyle(fontSize: 16, fontFamily: 'Inter', color: Colors.black),
          textAlign: TextAlign.center,
        ),
        backgroundColor: AppTheme.gradientStart,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
      ),
    );
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
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Row with Language Switcher
                      Align(
                        alignment: Alignment.topRight,
                        child: _buildLanguageSwitcher(),
                      ),
                      
                      const Spacer(),

                      // Illustration
                      ScaleTransition(
                        scale: _imagePulseAnimation,
                        child: Center(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: isTablet ? 450 : 370,
                              maxHeight: isTablet ? 330 : 270,
                            ),
                            child: Image.asset(
                              'assets/images/welcome_image.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Elegant placeholder if image is missing
                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: AppTheme.borderLight),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.fitness_center_rounded,
                                      size: 80,
                                      color: AppTheme.gradientStart,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Title "GYMTELLIGENT"
                      Text(
                        'GYMTELLIGENT',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: isTablet ? 60 : 44,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),

                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          _currentLanguage == 'EN'
                              ? 'Your personal AI-powered fitness trainer. Real-time posture detection and rep counting.'
                              : 'Huấn luyện viên cá nhân AI của bạn. Phát hiện tư thế và đếm số lần lặp thời gian thực.',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: isTablet ? 24 : 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Get started Button
                      MouseRegion(
                        onEnter: (_) => setState(() => _isButtonHovered = true),
                        onExit: (_) => setState(() => _isButtonHovered = false),
                        child: AnimatedScale(
                          scale: _isButtonHovered ? 1.02 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
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
                              width: double.infinity,
                              height: isTablet ? 76 : 64,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.gradientStart.withOpacity(0.3),
                                    blurRadius: _isButtonHovered ? 20 : 10,
                                    offset: const Offset(0, 4),
                                    spreadRadius: _isButtonHovered ? 2 : 0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _currentLanguage == 'EN' ? 'Get started' : 'Bắt đầu ngay',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontSize: isTablet ? 24 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // "I already have an account" button
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
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
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentLanguage == 'EN'
                              ? 'I already have an account'
                              : 'Tôi đã có tài khoản',
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      
                      const Spacer(),
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

  Widget _buildLanguageSwitcher() {
    return GestureDetector(
      onTap: _toggleLanguage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 109,
        height: 45,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // SVG Icon loader with safe fallback
              SvgPicture.asset(
                'assets/icons/global_icon.svg',
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                placeholderBuilder: (context) => const Icon(
                  Icons.language_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              Text(
                _currentLanguage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
