import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'exercise_library_screen.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/profile_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _breathingController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _logoBreathingAnimation;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isNameFocused = false;
  bool _isUsernameFocused = false;
  bool _isPhoneFocused = false;
  bool _isPasswordFocused = false;
  bool _isPasswordObscured = true;
  bool _isCreateHovered = false;

  // Onboarding parameters
  bool _isProfileOnboarding = false;

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _heightFocusNode = FocusNode();
  final FocusNode _ageFocusNode = FocusNode();

  bool _isWeightFocused = false;
  bool _isHeightFocused = false;
  bool _isAgeFocused = false;

  String _selectedGender = 'MALE';
  String _selectedGoal = 'BUILD_MUSCLE';
  String _selectedLevel = 'BEGINNER';

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
    _nameFocusNode.addListener(() {
      setState(() {
        _isNameFocused = _nameFocusNode.hasFocus;
      });
    });

    _usernameFocusNode.addListener(() {
      setState(() {
        _isUsernameFocused = _usernameFocusNode.hasFocus;
      });
    });

    _phoneFocusNode.addListener(() {
      setState(() {
        _isPhoneFocused = _phoneFocusNode.hasFocus;
      });
    });

    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });

    _weightFocusNode.addListener(() {
      setState(() {
        _isWeightFocused = _weightFocusNode.hasFocus;
      });
    });

    _heightFocusNode.addListener(() {
      setState(() {
        _isHeightFocused = _heightFocusNode.hasFocus;
      });
    });

    _ageFocusNode.addListener(() {
      setState(() {
        _isAgeFocused = _ageFocusNode.hasFocus;
      });
    });

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _breathingController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _nameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _weightFocusNode.dispose();
    _heightFocusNode.dispose();
    _ageFocusNode.dispose();
    super.dispose();
  }

  void _onCreateAccountPressed() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _phoneController.text.trim(); // Now email
    final pass = _passwordController.text.trim();

    void showValidationError(String message) {
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
                  message,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.gradientEnd,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        ),
      );
    }

    if (name.isEmpty || username.isEmpty || email.isEmpty || pass.isEmpty) {
      showValidationError('Please fill out all fields');
      return;
    }

    if (name.length < 2) {
      showValidationError('Full Name must be at least 2 characters');
      return;
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (username.length < 3) {
      showValidationError('Username must be at least 3 characters');
      return;
    }
    if (!usernameRegex.hasMatch(username)) {
      showValidationError('Username can only contain alphanumeric characters & underscores');
      return;
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      showValidationError('Please enter a valid email address');
      return;
    }

    if (pass.length < 6) {
      showValidationError('Password must be at least 6 characters');
      return;
    }

    // Transition to profile onboarding locally.
    setState(() {
      _isProfileOnboarding = true;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.black),
            SizedBox(width: 10),
            Text(
              'Please complete your profile details!',
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
  }

  void _onSubmitOnboarding() async {
    final weightStr = _weightController.text.trim();
    final heightStr = _heightController.text.trim();
    final ageStr = _ageController.text.trim();
    
    if (weightStr.isEmpty || heightStr.isEmpty || ageStr.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill out all onboarding fields'),
          backgroundColor: AppTheme.gradientEnd,
        ),
      );
      return;
    }
    
    final weight = double.tryParse(weightStr);
    final height = double.tryParse(heightStr);
    final age = int.tryParse(ageStr);
    
    if (weight == null || height == null || age == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter valid numeric values'),
          backgroundColor: AppTheme.gradientEnd,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.gradientStart)),
    );
    
    // Map user-friendly frontend goals to exact backend enum values
    String mappedGoal = 'GENERAL_FITNESS';
    if (_selectedGoal == 'BUILD_MUSCLE') {
      mappedGoal = 'BUILD_MUSCLE';
    } else if (_selectedGoal == 'LOSE_WEIGHT') {
      mappedGoal = 'LOSE_FAT';
    } else if (_selectedGoal == 'KEEP_FIT') {
      mappedGoal = 'GENERAL_FITNESS';
    }

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _phoneController.text.trim(); // Now email
    final pass = _passwordController.text.trim();

    final result = await AuthService.register(
      username: username,
      password: pass,
      email: email,
      fullName: name,
      weightKg: weight,
      heightCm: height,
      age: age,
      gender: _selectedGender,
      fitnessGoal: mappedGoal,
      fitnessLevel: _selectedLevel,
    );
    
    if (mounted) Navigator.pop(context); // Close loading
    
    if (result['success'] == true) {
      try {
        final profile = await ProfileService.getProfile();
        await AnalyticsService.applyUserContext(profile);
        await AnalyticsService.logSignUp();
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ExerciseLibraryScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
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
                  result['message'] ?? 'Registration failed',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.gradientEnd,
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title, bool isTablet) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: isTablet ? 16 : 13,
          fontWeight: FontWeight.bold,
          color: Colors.white.withOpacity(0.4),
          letterSpacing: 1.5,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap, bool isTablet) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.gradientStart : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black : Colors.white.withOpacity(0.7),
              fontFamily: 'Inter',
            ),
          ),
        ),
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
                        _isProfileOnboarding
                            ? Column(
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            _isProfileOnboarding = false;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Complete Your Profile',
                                    style: TextStyle(
                                      fontSize: isTablet ? 36 : 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Help us customize your workouts and calculate correct calories.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isTablet ? 18 : 14,
                                      color: Colors.white.withOpacity(0.6),
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  
                                  // Weight Field
                                  _buildInputField(
                                    controller: _weightController,
                                    focusNode: _weightFocusNode,
                                    isFocused: _isWeightFocused,
                                    hintText: 'Weight (kg)',
                                    iconPath: 'assets/icons/global_icon.svg',
                                    fallbackIcon: Icons.fitness_center_rounded,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    isTablet: isTablet,
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Height Field
                                  _buildInputField(
                                    controller: _heightController,
                                    focusNode: _heightFocusNode,
                                    isFocused: _isHeightFocused,
                                    hintText: 'Height (cm)',
                                    iconPath: 'assets/icons/global_icon.svg',
                                    fallbackIcon: Icons.height_rounded,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    isTablet: isTablet,
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Age Field
                                  _buildInputField(
                                    controller: _ageController,
                                    focusNode: _ageFocusNode,
                                    isFocused: _isAgeFocused,
                                    hintText: 'Age',
                                    iconPath: 'assets/icons/global_icon.svg',
                                    fallbackIcon: Icons.calendar_today_rounded,
                                    keyboardType: TextInputType.number,
                                    isTablet: isTablet,
                                  ),
                                  const SizedBox(height: 30),
                                  
                                  // Gender Selection Chips
                                  _buildSectionTitle('GENDER', isTablet),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: _buildChoiceChip('MALE', _selectedGender == 'MALE', () => setState(() => _selectedGender = 'MALE'), isTablet)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildChoiceChip('FEMALE', _selectedGender == 'FEMALE', () => setState(() => _selectedGender = 'FEMALE'), isTablet)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildChoiceChip('OTHER', _selectedGender == 'OTHER', () => setState(() => _selectedGender = 'OTHER'), isTablet)),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Fitness Goal Selection Chips
                                  _buildSectionTitle('FITNESS GOAL', isTablet),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: _buildChoiceChip('BUILD MUSCLE', _selectedGoal == 'BUILD_MUSCLE', () => setState(() => _selectedGoal = 'BUILD_MUSCLE'), isTablet)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildChoiceChip('LOSE WEIGHT', _selectedGoal == 'LOSE_WEIGHT', () => setState(() => _selectedGoal = 'LOSE_WEIGHT'), isTablet)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildChoiceChip('KEEP FIT', _selectedGoal == 'KEEP_FIT', () => setState(() => _selectedGoal = 'KEEP_FIT'), isTablet)),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Fitness Level Selection Chips
                                  _buildSectionTitle('FITNESS LEVEL', isTablet),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: _buildChoiceChip('BEGINNER', _selectedLevel == 'BEGINNER', () => setState(() => _selectedLevel = 'BEGINNER'), isTablet)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildChoiceChip('INTERMEDIATE', _selectedLevel == 'INTERMEDIATE', () => setState(() => _selectedLevel = 'INTERMEDIATE'), isTablet)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildChoiceChip('ADVANCED', _selectedLevel == 'ADVANCED', () => setState(() => _selectedLevel = 'ADVANCED'), isTablet)),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                  
                                  // Submit Button
                                  GestureDetector(
                                    onTap: _onSubmitOnboarding,
                                    child: Container(
                                      width: double.infinity,
                                      height: isTablet ? 76 : 64,
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.gradientStart.withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Save & Continue',
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
                                ],
                              )
                            : Column(
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
                                  
                                  const SizedBox(height: 40),

                                  // Full Name Field
                                  _buildInputField(
                                    controller: _nameController,
                                    focusNode: _nameFocusNode,
                                    isFocused: _isNameFocused,
                                    hintText: 'Full Name',
                                    iconPath: 'assets/icons/user.svg',
                                    fallbackIcon: Icons.person_outline_rounded,
                                    isTablet: isTablet,
                                  ),

                                  const SizedBox(height: 20),

                                  // Username Field
                                  _buildInputField(
                                    controller: _usernameController,
                                    focusNode: _usernameFocusNode,
                                    isFocused: _isUsernameFocused,
                                    hintText: 'Username',
                                    iconPath: 'assets/icons/user.svg',
                                    fallbackIcon: Icons.alternate_email_rounded,
                                    isTablet: isTablet,
                                  ),

                                  const SizedBox(height: 20),

                                  // Email Field
                                  _buildInputField(
                                    controller: _phoneController, // Keep controller name to avoid breaking other logic
                                    focusNode: _phoneFocusNode,
                                    isFocused: _isPhoneFocused,
                                    hintText: 'Email',
                                    iconPath: 'assets/icons/mail.svg',
                                    fallbackIcon: Icons.email_outlined,
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

                                  // Create Account Button
                                  MouseRegion(
                                    onEnter: (_) => setState(() => _isCreateHovered = true),
                                    onExit: (_) => setState(() => _isCreateHovered = false),
                                    child: AnimatedScale(
                                      scale: _isCreateHovered ? 1.015 : 1.0,
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOutBack,
                                      child: GestureDetector(
                                        onTap: _onCreateAccountPressed,
                                        child: Container(
                                          width: double.infinity,
                                          height: isTablet ? 76 : 64,
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.primaryGradient,
                                            borderRadius: BorderRadius.circular(30),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppTheme.gradientStart.withOpacity(0.3),
                                                blurRadius: _isCreateHovered ? 20 : 10,
                                                offset: const Offset(0, 4),
                                                spreadRadius: _isCreateHovered ? 2 : 0,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Create Account',
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

                                  // "Already have an account? Login" Text
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pushReplacement(
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
                                            TextSpan(text: 'Already have an account? '),
                                            TextSpan(
                                              text: 'Login',
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
