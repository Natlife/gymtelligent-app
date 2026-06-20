import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'camera_training_screen.dart';
import '../models/exercise.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String title;
  final String category;
  final String level;
  final String duration;
  final String imagePath;
  final IconData fallbackIcon;
  final Exercise? exercise;

  const WorkoutDetailScreen({
    super.key,
    required this.title,
    required this.category,
    required this.level,
    required this.duration,
    required this.imagePath,
    required this.fallbackIcon,
    this.exercise,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  
  final Set<int> _completedSteps = {};

  
  late String _aboutText;
  late List<String> _steps;
  late String _calories;
  late String _setsReps;
  late String _heroImage;

  // Workout configuration state
  int _selectedSets = 3;
  int _selectedReps = 12;
  int _selectedRestSeconds = 60;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );

    if (widget.exercise != null) {
      final ex = widget.exercise!;
      _aboutText = ex.description;
      _steps = ex.instructions;
      _calories = (ex.metValue * 25).toStringAsFixed(0);
      _setsReps = '${ex.defaultSets}x${ex.defaultReps}';
      _heroImage = widget.imagePath;
      _selectedSets = ex.defaultSets;
      _selectedReps = ex.defaultReps;
    } else if (widget.title.toLowerCase().contains('push')) {
      _aboutText = 'A fundamental upper body exercise that targets chest, shoulders, and triceps. Perfect for building pushing strength and core stability.';
      _steps = [
        'Start in a plank position with hands shoulder-width apart',
        'Lower your body until chest nearly touches the floor',
        'Keep your core tight and body in a straight line',
        'Push back up to starting position',
        'Repeat for desired reps',
      ];
      _calories = '120';
      _setsReps = '3x15';
      _heroImage = 'assets/images/push_up_hero.png';
      _selectedSets = 3;
      _selectedReps = 15;
    } else if (widget.title.toLowerCase().contains('squat')) {
      _aboutText = 'An essential lower body movement focusing on quadriceps, hamstrings, and glutes. Great for functional strength, flexibility, and power.';
      _steps = [
        'Stand with feet shoulder-width apart, toes slightly outward',
        'Lower hips back and down as if sitting in a chair',
        'Keep your chest high and knees behind your toes',
        'Drive through your heels to return to standing position',
        'Squeeze glutes at the top and repeat',
      ];
      _calories = '150';
      _setsReps = '4x12';
      _heroImage = 'assets/images/squats.png';
      _selectedSets = 4;
      _selectedReps = 12;
    } else {
      _aboutText = 'A powerhouse compound exercise targeting the entire posterior chain, including lower back, glutes, hamstrings, and core muscles.';
      _steps = [
        'Stand with mid-foot under the barbell, feet hip-width apart',
        'Bend at hips and knees, grab the bar with a shoulder-width grip',
        'Flatten your back, engage lats, and pull chest up',
        'Drive through heels to stand straight up, locking hips',
        'Control the weight back to the floor and repeat',
      ];
      _calories = '180';
      _setsReps = '4x8';
      _heroImage = 'assets/images/deadlifts.png';
      _selectedSets = 4;
      _selectedReps = 8;
    }

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onStepTapped(int index) {
    setState(() {
      if (_completedSteps.contains(index)) {
        _completedSteps.remove(index);
      } else {
        _completedSteps.add(index);
      }
    });
  }

  void _navigateToCamera() {
    final exId = widget.exercise?.id ?? (widget.title.toLowerCase().contains('push') ? 1 : widget.title.toLowerCase().contains('squat') ? 2 : 3);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => CameraTrainingScreen(
          exerciseId: exId,
          exerciseTitle: widget.title,
          duration: widget.duration,
          level: widget.level,
          targetSets: _selectedSets,
          targetReps: _selectedReps,
          restSeconds: _selectedRestSeconds,
          isFreestyleMode: false,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _onBeginWorkoutPressed() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildWorkoutSettingsSheet(),
    );
  }

  Widget _buildWorkoutSettingsSheet() {
    int tempSets = _selectedSets;
    int tempReps = _selectedReps;
    int tempRest = _selectedRestSeconds;
    return StatefulBuilder(
      builder: (context, setSheetState) {
        Widget stepper(String label, int value, VoidCallback onDec, VoidCallback onInc) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 16, color: Colors.white70, fontFamily: 'Inter')),
              Row(
                children: [
                  GestureDetector(
                    onTap: onDec,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: const Color(0xFF252626), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.remove_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text('$value', textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Inter')),
                  ),
                  GestureDetector(
                    onTap: onInc,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Container(
          padding: EdgeInsets.only(
            left: 28, right: 28, top: 28,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF131415),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.gradientStart.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.tune_rounded, color: AppTheme.gradientStart, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workout Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Inter')),
                      Text('Customize your session', style: TextStyle(fontSize: 13, color: Colors.white38, fontFamily: 'Inter')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              stepper('Sets', tempSets, () { if (tempSets > 1) setSheetState(() => tempSets--); }, () { if (tempSets < 10) setSheetState(() => tempSets++); }),
              const SizedBox(height: 22),
              stepper('Reps per Set', tempReps, () { if (tempReps > 1) setSheetState(() => tempReps--); }, () { if (tempReps < 50) setSheetState(() => tempReps++); }),
              const SizedBox(height: 22),
              stepper('Rest (seconds)', tempRest, () { if (tempRest > 10) setSheetState(() => tempRest -= 10); }, () { if (tempRest < 300) setSheetState(() => tempRest += 10); }),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSets = tempSets;
                    _selectedReps = tempReps;
                    _selectedRestSeconds = tempRest;
                  });
                  Navigator.pop(context);
                  _navigateToCamera();
                },
                child: Container(
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppTheme.gradientStart.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: const Center(
                    child: Text('START WORKOUT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Inter', letterSpacing: 1.2)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header Image & Title details overlay
                  _buildHeroHeader(screenSize, isTablet),

                  
                  AnimatedBuilder(
                    animation: _fadeController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeInAnimation,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 28),

                                // Metric Cards (3-column layout)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricCard(
                                        iconPath: 'assets/icons/clock.svg',
                                        fallbackIcon: Icons.access_time_rounded,
                                        value: widget.duration,
                                        label: 'Duration',
                                        isTablet: isTablet,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildMetricCard(
                                        iconPath: 'assets/icons/fire.svg',
                                        fallbackIcon: Icons.local_fire_department_rounded,
                                        value: '$_calories kcal',
                                        label: 'Calories',
                                        isTablet: isTablet,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildMetricCard(
                                        iconPath: 'assets/icons/graph.svg',
                                        fallbackIcon: Icons.trending_up_rounded,
                                        value: _setsReps,
                                        label: 'Sets x Reps',
                                        isTablet: isTablet,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 36),

                                // "About" Section
                                Text(
                                  'About',
                                  style: TextStyle(
                                    fontSize: isTablet ? 30 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _aboutText,
                                  style: TextStyle(
                                    fontSize: isTablet ? 18 : 15,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white.withOpacity(0.5),
                                    height: 1.5,
                                    fontFamily: 'Inter',
                                  ),
                                ),

                                const SizedBox(height: 36),

                                // "How to Perform" Section
                                Text(
                                  'How to Perform',
                                  style: TextStyle(
                                    fontSize: isTablet ? 30 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Steps List
                                ...List.generate(_steps.length, (index) {
                                  final isCompleted = _completedSteps.contains(index);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 18.0),
                                    child: _buildStepItem(index, _steps[index], isCompleted, isTablet),
                                  );
                                }),

                                // Padding to clear the sticky bottom action card
                                const SizedBox(height: 160),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Sticky Floating Action Card at the bottom!
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: _buildStickyActionCard(isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(Size screenSize, bool isTablet) {
    return Container(
      height: screenSize.height * 0.45,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          
          Image.asset(
            _heroImage,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppTheme.surface,
                child: Center(
                  child: Icon(
                    widget.fallbackIcon,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              );
            },
          ),

          // Dark overlay to fade image to black at the bottom
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.95),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),

          // Top Header Row with Glass Back Button and Goal badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Circular Glassmorphic Back Button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: isTablet ? 56 : 46,
                    height: isTablet ? 56 : 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FE8B).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00FE8B).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/arrow_left.svg',
                        width: isTablet ? 26 : 20,
                        height: isTablet ? 26 : 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        placeholderBuilder: (context) => Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: isTablet ? 22 : 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Difficulty Level Badge (Figma green badge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.gradientStart,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gradientStart.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.level,
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Exercise Info text
          Positioned(
            bottom: 8,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: isTablet ? 50 : 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.category,
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.5),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String iconPath,
    required IconData fallbackIcon,
    required String value,
    required String label,
    required bool isTablet,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Icon centered inside a small gradient ring or simply neon green
          SvgPicture.asset(
            iconPath,
            width: isTablet ? 36 : 28,
            height: isTablet ? 36 : 28,
            colorFilter: const ColorFilter.mode(
              AppTheme.gradientStart,
              BlendMode.srcIn,
            ),
            placeholderBuilder: (context) => Icon(
              fallbackIcon,
              size: isTablet ? 32 : 26,
              color: AppTheme.gradientStart,
            ),
          ),
          const SizedBox(height: 14),

          
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 24 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.4),
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int index, String description, bool isCompleted, bool isTablet) {
    return GestureDetector(
      onTap: () => _onStepTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFF0C2C29).withOpacity(0.5) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted ? AppTheme.gradientStart.withOpacity(0.4) : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step Number Badge (glowing neon green check or index number)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isTablet ? 40 : 32,
              height: isTablet ? 40 : 32,
              decoration: BoxDecoration(
                color: isCompleted ? AppTheme.gradientStart : const Color(0xFF252626),
                shape: BoxShape.circle,
                boxShadow: isCompleted 
                    ? [
                        BoxShadow(
                          color: AppTheme.gradientStart.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: isCompleted
                    ? Icon(
                        Icons.check_rounded,
                        size: isTablet ? 22 : 18,
                        color: Colors.black,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.8),
                          fontFamily: 'Inter',
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 16),

            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 14.5,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.white : Colors.white.withOpacity(0.75),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white.withOpacity(0.4),
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyActionCard(bool isTablet) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gradientStart.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title Text Column
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start AI Training',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.65),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Begin Workout',
                  style: TextStyle(
                    fontSize: isTablet ? 28 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),

          // Play Circle Button
          GestureDetector(
            onTap: _onBeginWorkoutPressed,
            child: Container(
              width: isTablet ? 64 : 54,
              height: isTablet ? 64 : 54,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/play.svg',
                  width: isTablet ? 30 : 24,
                  height: isTablet ? 30 : 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                  placeholderBuilder: (context) => Icon(
                    Icons.play_arrow_rounded,
                    size: isTablet ? 34 : 28,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
