import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'exercise_library_screen.dart';

class GoalSelectionScreen extends StatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> with TickerProviderStateMixin {
  late List<AnimationController> _staggerControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  int _selectedGoalIndex = 0; // Default: Build Muscle

  bool _isBackHovered = false;
  bool _isStartHovered = false;

  final List<Map<String, String>> _goals = [
    {
      'title': 'Build Muscle',
      'description': 'Strength and hypertrophy focused',
      'iconPath': 'assets/icons/muscle.svg',
    },
    {
      'title': 'Lose Fat',
      'description': 'High intensity cardio workouts',
      'iconPath': 'assets/icons/fire.svg',
    },
    {
      'title': 'Improve Strength',
      'description': 'Progressive overload training',
      'iconPath': 'assets/icons/strength.svg',
    },
  ];

  @override
  void initState() {
    super.initState();

    // 5 Staggered elements:
    // 0: Header Title
    // 1: Subtitle
    // 2: Card 1 (Build Muscle)
    // 3: Card 2 (Lose Fat)
    // 4: Card 3 (Improve Strength)
    _staggerControllers = List.generate(
      5,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    _fadeAnimations = _staggerControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    _slideAnimations = _staggerControllers.map((controller) {
      return Tween<Offset>(begin: const Offset(0.0, 0.12), end: Offset.zero).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    _animateStaggered();
  }

  Future<void> _animateStaggered() async {
    for (var i = 0; i < _staggerControllers.length; i++) {
      await Future.delayed(Duration(milliseconds: i == 0 ? 100 : 120));
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

  void _onStartTraining() {
    final chosenGoal = _goals[_selectedGoalIndex]['title'];
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch_rounded, color: Colors.black),
            const SizedBox(width: 10),
            Text(
              'Training Started: $chosenGoal!',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.gradientStart,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      ),
    );

    // Transition to ExerciseLibraryScreen
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ExerciseLibraryScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0); // Slide up transition from bottom for main screen entry!
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

              // Title: "Your Goal"
              AnimatedBuilder(
                animation: _staggerControllers[0],
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimations[0],
                    child: SlideTransition(
                      position: _slideAnimations[0],
                      child: Text(
                        'Your Goal',
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

              // Sub-headline: "What do you want to achieve?"
              AnimatedBuilder(
                animation: _staggerControllers[1],
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimations[1],
                    child: SlideTransition(
                      position: _slideAnimations[1],
                      child: Text(
                        'What do you want to achieve?',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: isTablet ? 22 : 18,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const Spacer(flex: 2),

              // Goals List options
              Column(
                children: List.generate(_goals.length, (index) {
                  final goal = _goals[index];
                  final isSelected = _selectedGoalIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: _buildGoalCard(
                      index: index + 2,
                      goalIndex: index,
                      iconPath: goal['iconPath']!,
                      title: goal['title']!,
                      description: goal['description']!,
                      isSelected: isSelected,
                      isTablet: isTablet,
                    ),
                  );
                }),
              ),

              const Spacer(flex: 3),

              // Bottom Button Row: Back & Start Training
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

                  // Start Training Button (Gradient)
                  Expanded(
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isStartHovered = true),
                      onExit: (_) => setState(() => _isStartHovered = false),
                      child: AnimatedScale(
                        scale: _isStartHovered ? 1.02 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: GestureDetector(
                          onTap: _onStartTraining,
                          child: Container(
                            height: isTablet ? 76 : 64,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.gradientStart.withOpacity(0.3),
                                  blurRadius: _isStartHovered ? 20 : 10,
                                  offset: const Offset(0, 4),
                                  spreadRadius: _isStartHovered ? 2 : 0,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Start Training',
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
  }

  Widget _buildGoalCard({
    required int index,
    required int goalIndex,
    required String iconPath,
    required String title,
    required String description,
    required bool isSelected,
    required bool isTablet,
  }) {
    IconData fallbackIcon = Icons.fitness_center_rounded;
    if (title.contains('Fat')) fallbackIcon = Icons.local_fire_department_rounded;
    if (title.contains('Strength')) fallbackIcon = Icons.shield_rounded;

    return AnimatedBuilder(
      animation: _staggerControllers[index],
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimations[index],
          child: SlideTransition(
            position: _slideAnimations[index],
            child: AnimatedScale(
              scale: isSelected ? 1.01 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGoalIndex = goalIndex;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0C2C29) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFF0BFF88) 
                          : Colors.white.withOpacity(0.15),
                      width: isSelected ? 2.0 : 1.5,
                    ),
                    boxShadow: isSelected 
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0BFF88).withOpacity(0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      // Circular graphic background for Icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isTablet ? 70 : 60,
                        height: isTablet ? 70 : 60,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF0BFF88).withOpacity(0.2) 
                              : const Color(0xFF252626),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            iconPath,
                            width: isTablet ? 36 : 28,
                            height: isTablet ? 36 : 28,
                            colorFilter: ColorFilter.mode(
                              isSelected ? const Color(0xFF0BFF88) : Colors.white,
                              BlendMode.srcIn,
                            ),
                            placeholderBuilder: (context) => Icon(
                              fallbackIcon,
                              size: isTablet ? 32 : 26,
                              color: isSelected ? const Color(0xFF0BFF88) : Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Goal text content
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
                                fontSize: isTablet ? 17 : 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected 
                                    ? const Color(0xFF0BFF88).withOpacity(0.8) 
                                    : AppTheme.textSecondary,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Custom Selection Indicator (Glowing Neon Green Circle Check)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0BFF88) : Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          color: isSelected ? const Color(0xFF0BFF88) : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.black,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
