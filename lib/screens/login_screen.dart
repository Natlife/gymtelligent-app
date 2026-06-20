import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'signup_screen.dart';
import 'exercise_library_screen.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/analytics_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _breathingController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _logoBreathingAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;
  bool _isPasswordObscured = true;
  bool _isLoginHovered = false;

  @override
  void initState() {
    super.initState();

    // Entry Animations
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

    // Subtle breathing animation for Logo
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _logoBreathingAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Track input focus states for premium glowing border effects
    _emailFocusNode.addListener(() {
      setState(() {
        _isEmailFocused = _emailFocusNode.hasFocus;
      });
    });

    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _breathingController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onLoginPressed() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.black),
              SizedBox(width: 10),
              Text(
                'Please enter credentials',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Inter'),
              ),
            ],
          ),
          backgroundColor: AppTheme.gradientEnd,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.gradientStart)),
    );

    // Call actual backend login (using email)
    final result = await AuthService.login(email, pass);
    
    // Close loading indicator
    if (mounted) Navigator.pop(context);

    if (result['success'] == true) {
      // Set the theme reactively based on the user's role
      try {
        final profile = await ProfileService.getProfile();
        await AnalyticsService.applyUserContext(profile);
        await AnalyticsService.logLogin();
        if (profile != null && profile['roleName'] == 'ROLE_ADMIN') {
          appThemeNotifier.value = AppTheme.lightTheme;
        } else {
          appThemeNotifier.value = AppTheme.darkTheme;
        }
      } catch (_) {
        appThemeNotifier.value = AppTheme.darkTheme;
      }

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.black),
              SizedBox(width: 10),
              Text(
                'Logged in successfully!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Inter'),
              ),
            ],
          ),
          backgroundColor: AppTheme.gradientStart,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
        ),
      );

      // Transition to ExerciseLibraryScreen
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const ExerciseLibraryScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0); // Slide up transition
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
            (route) => false,
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.black),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['message'] ?? 'Login failed',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.gradientEnd,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
        ),
      );
    }
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: screenSize.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: 32),
                            
                            // Top Logo Image (Centered)
                            ScaleTransition(
                              scale: _logoBreathingAnimation,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: isTablet ? 300 : 220,
                                  maxHeight: isTablet ? 220 : 160,
                                ),
                                child: Image.asset(
                                  'assets/images/login_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Soft fallback logo if png is missing
                                    return SvgPicture.asset(
                                      'assets/icons/global_icon.svg',
                                      width: 100,
                                      height: 100,
                                      colorFilter: const ColorFilter.mode(
                                        AppTheme.gradientStart,
                                        BlendMode.srcIn,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 48),

                            // Email Field
                            _buildInputField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              isFocused: _isEmailFocused,
                              hintText: 'Email Address',
                              iconPath: 'assets/icons/envelope.svg',
                              fallbackIcon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              isTablet: isTablet,
                            ),

                            const SizedBox(height: 20),

                            // Password Field
                            _buildInputField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              isFocused: _isPasswordFocused,
                              hintText: 'Password',
                              iconPath: 'assets/icons/lock.svg',
                              fallbackIcon: Icons.lock_outline_rounded,
                              obscureText: _isPasswordObscured,
                              isTablet: isTablet,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordObscured 
                                      ? Icons.visibility_off_rounded 
                                      : Icons.visibility_rounded,
                                  color: _isPasswordFocused 
                                      ? AppTheme.gradientStart 
                                      : Colors.white.withOpacity(0.3),
                                  size: isTablet ? 28 : 22,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordObscured = !_isPasswordObscured;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Login Button
                            MouseRegion(
                              onEnter: (_) => setState(() => _isLoginHovered = true),
                              onExit: (_) => setState(() => _isLoginHovered = false),
                              child: AnimatedScale(
                                scale: _isLoginHovered ? 1.015 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: GestureDetector(
                                  onTap: _onLoginPressed,
                                  child: Container(
                                    width: double.infinity,
                                    height: isTablet ? 76 : 64,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.gradientStart.withOpacity(0.3),
                                          blurRadius: _isLoginHovered ? 20 : 10,
                                          offset: const Offset(0, 4),
                                          spreadRadius: _isLoginHovered ? 2 : 0,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Login',
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

                            const SizedBox(height: 24),

                            // "Don’t have an account? Sign up" Text
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushReplacement(
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: isTablet ? 18 : 15,
                                      fontWeight: FontWeight.normal,
                                      color: Colors.white.withOpacity(0.65),
                                      fontFamily: 'Inter',
                                    ),
                                    children: const [
                                      TextSpan(text: 'Don’t have an account? '),
                                      TextSpan(
                                        text: 'Sign up',
                                        style: TextStyle(
                                          color: AppTheme.gradientStart,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Back to Welcome Screen (Bottom link)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0, top: 32.0),
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Back to Welcome',
                              style: TextStyle(
                                fontSize: isTablet ? 17 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String hintText,
    required String iconPath,
    required IconData fallbackIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required bool isTablet,
    Widget? suffixIcon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: isTablet ? 76 : 64,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isFocused 
              ? AppTheme.gradientStart 
              : Colors.white.withOpacity(0.15),
          width: isFocused ? 2.0 : 1.5,
        ),
        boxShadow: isFocused 
            ? [
                BoxShadow(
                  color: AppTheme.gradientStart.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: isTablet ? 20 : 17,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
          cursorColor: AppTheme.gradientStart,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: isTablet ? 20 : 17,
              fontFamily: 'Inter',
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              vertical: isTablet ? 18 : 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SvgPicture.asset(
                iconPath,
                width: isTablet ? 26 : 22,
                height: isTablet ? 26 : 22,
                colorFilter: ColorFilter.mode(
                  isFocused ? AppTheme.gradientStart : Colors.white.withOpacity(0.3),
                  BlendMode.srcIn,
                ),
                placeholderBuilder: (context) => Icon(
                  fallbackIcon,
                  size: isTablet ? 26 : 22,
                  color: isFocused ? AppTheme.gradientStart : Colors.white.withOpacity(0.3),
                ),
              ),
            ),
            suffixIcon: suffixIcon != null 
                ? Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: suffixIcon,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
