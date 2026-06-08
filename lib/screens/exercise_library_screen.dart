import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'workout_detail_screen.dart';
import 'camera_training_screen.dart';
import 'home_dashboard_screen.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import '../services/workout_service.dart';
import '../models/exercise.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSearchFocused = false;
  String _selectedCategory = 'All';
  int _activeNavIndex = 0;

  bool _isLoading = true;
  List<Exercise> _exercises = [];
  List<Exercise> _filteredExercises = [];

  @override
  void initState() {
    super.initState();

    // Entry Animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    _searchController.addListener(_onSearchChanged);

    _fadeController.forward();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await WorkoutService.getExercises();
      if (mounted) {
        setState(() {
          _exercises = list;
          _filteredExercises = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterExercises();
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _filterExercises();
    });
  }

  void _filterExercises() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExercises = _exercises.where((exercise) {
        final matchesSearch = exercise.name.toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == 'All' || 
            exercise.category.toLowerCase() == _selectedCategory.toLowerCase();
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _onCardTapped(Exercise exercise) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => WorkoutDetailScreen(
          title: exercise.name,
          category: exercise.category,
          level: exercise.difficultyLevel,
          duration: '${exercise.defaultSets * 5} min',
          imagePath: exercise.name.toLowerCase().contains('push')
              ? 'assets/images/push_ups.png'
              : exercise.name.toLowerCase().contains('squat')
                  ? 'assets/images/squats.png'
                  : 'assets/images/deadlifts.png',
          fallbackIcon: exercise.name.toLowerCase().contains('push')
              ? Icons.fitness_center_rounded
              : exercise.name.toLowerCase().contains('squat')
                  ? Icons.accessibility_new_rounded
                  : Icons.fitness_center_rounded,
          exercise: exercise,
        ),
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    Widget bodyContent;
    switch (_activeNavIndex) {
      case 0:
        bodyContent = HomeDashboardScreen(
          onNavigateToWorkouts: () {
            setState(() {
              _activeNavIndex = 1;
            });
          },
        );
        break;
      case 1:
        bodyContent = AnimatedBuilder(
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
                      const SizedBox(height: 32),

                      // Title: "Exercise Library"
                      Text(
                        'Exercise Library',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: isTablet ? 60 : 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 24),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: isTablet ? 76 : 64,
                        decoration: BoxDecoration(
                          color: AppTheme.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _isSearchFocused 
                                ? Theme.of(context).primaryColor 
                                : AppTheme.getBorderColor(context),
                            width: _isSearchFocused ? 2.0 : 1.5,
                          ),
                          boxShadow: _isSearchFocused 
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: TextStyle(
                              fontSize: isTablet ? 20 : 17,
                              color: AppTheme.getTextColor(context),
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                            ),
                            cursorColor: Theme.of(context).primaryColor,
                            decoration: InputDecoration(
                              hintText: 'Search exercises...',
                              hintStyle: TextStyle(
                                color: AppTheme.getTextColor(context).withOpacity(0.4),
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
                                  'assets/icons/search.svg',
                                  width: isTablet ? 26 : 22,
                                  height: isTablet ? 26 : 22,
                                  colorFilter: ColorFilter.mode(
                                    _isSearchFocused ? Theme.of(context).primaryColor : AppTheme.getTextColor(context).withOpacity(0.4),
                                    BlendMode.srcIn,
                                  ),
                                  placeholderBuilder: (context) => Icon(
                                    Icons.search_rounded,
                                    size: isTablet ? 26 : 22,
                                    color: _isSearchFocused ? Theme.of(context).primaryColor : AppTheme.getTextColor(context).withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Horizontal category chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildCategoryChip('All', isTablet),
                            const SizedBox(width: 14),
                            _buildCategoryChip('Strength', isTablet),
                            const SizedBox(width: 14),
                            _buildCategoryChip('Cardio', isTablet),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gradientStart),
                                ),
                              )
                            : _filteredExercises.isEmpty
                                ? Center(
                                     child: Text(
                                       'No exercises found',
                                       style: TextStyle(
                                         fontSize: 18,
                                         color: AppTheme.getSecondaryTextColor(context),
                                         fontFamily: 'Inter',
                                       ),
                                     ),
                                  )
                                : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _filteredExercises.length,
                                itemBuilder: (context, index) {
                                  final exercise = _filteredExercises[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 24.0),
                                    child: _buildExerciseCard(exercise, isTablet),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        break;
      case 2:
        bodyContent = const ProgressScreen();
        break;
      case 3:
        bodyContent = const ProfileScreen();
        break;
      default:
        bodyContent = Container();
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: bodyContent,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(isTablet),
    );
  }

  Widget _buildCategoryChip(String label, bool isTablet) {
    final isSelected = _selectedCategory == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _onCategorySelected(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(isSelected ? 35 : 30),
          border: isSelected ? null : Border.all(
            color: AppTheme.getBorderColor(context),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.gradientStart.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isSelected 
                ? (isDark ? Colors.black : Colors.white) 
                : AppTheme.getTextColor(context).withOpacity(0.5),
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise, bool isTablet) {
    final imagePath = exercise.name.toLowerCase().contains('push')
        ? 'assets/images/push_ups.png'
        : exercise.name.toLowerCase().contains('squat')
            ? 'assets/images/squats.png'
            : 'assets/images/deadlifts.png';

    final fallbackIcon = exercise.name.toLowerCase().contains('push')
        ? Icons.fitness_center_rounded
        : exercise.name.toLowerCase().contains('squat')
            ? Icons.accessibility_new_rounded
            : Icons.fitness_center_rounded;

    return GestureDetector(
      onTap: () => _onCardTapped(exercise),
      child: Container(
        height: isTablet ? 320 : 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppTheme.getBorderColor(context),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppTheme.surface,
                    child: Center(
                      child: Icon(
                        fallbackIcon,
                        size: 60,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  );
                },
              ),

              // Gradient Overlay for Title & Tag Contrast
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

              // Card Tags Overlay (Top Left & Top Right)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Level Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        exercise.difficultyLevel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),

                    // Duration Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${exercise.defaultSets * 5} min',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom details overlay
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(
                        fontSize: isTablet ? 36 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.category,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 14,
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
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.getBorderColor(context),
            width: 1.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: isTablet ? 96 : 80,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, 'Home', 'assets/icons/home.svg', Icons.home_rounded, isTablet),
              _buildNavItem(1, 'Workouts', 'assets/icons/dumbbell_nav.svg', Icons.fitness_center_rounded, isTablet),
              _buildNavItem(2, 'Progress', 'assets/icons/arrow_trend_up.svg', Icons.show_chart_rounded, isTablet),
              _buildNavItem(3, 'Profile', 'assets/icons/user.svg', Icons.person_rounded, isTablet),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildNavItem(int index, String label, String iconPath, IconData fallbackIcon, bool isTablet) {
    final isActive = _activeNavIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);
    final inactiveColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeNavIndex = index;
        });
      },
      child: Container(
        color: Colors.transparent,
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              width: isTablet ? 30 : 24,
              height: isTablet ? 30 : 24,
              colorFilter: ColorFilter.mode(
                isActive ? activeColor : inactiveColor,
                BlendMode.srcIn,
              ),
              placeholderBuilder: (context) => Icon(
                fallbackIcon,
                size: isTablet ? 30 : 24,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 14 : 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? activeColor : inactiveColor,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
