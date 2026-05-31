import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../theme.dart';
import 'workout_detail_screen.dart';
import '../services/stats_service.dart';
import '../services/profile_service.dart';
import '../models/stats_summary.dart';
import '../models/daily_stats.dart';

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToWorkouts;
  
  const HomeDashboardScreen({
    super.key, 
    required this.onNavigateToWorkouts,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  bool _isLoading = true;
  StatsSummary? _summary;
  DailyStats? _dailyStats;
  String _userName = 'Athlete';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await StatsService.getSummary();
      final daily = await StatsService.getDailyStats(DateTime.now());
      final profile = await ProfileService.getProfile();

      if (mounted) {
        setState(() {
          _summary = summary;
          _dailyStats = daily;
          if (profile != null && profile['fullName'] != null) {
            _userName = profile['fullName'];
          }
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
    super.dispose();
  }

  String _getCurrentDateString() {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return FadeTransition(
      opacity: _fadeIn,
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: Theme.of(context).primaryColor,
        backgroundColor: AppTheme.getSurfaceColor(context),
        child: _isLoading 
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              children: [
                // 1. Header (Date & Profile Avatar)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCurrentDateString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getSecondaryTextColor(context),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hello, $_userName!',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: isTablet ? 36 : 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Glowing Profile Avatar
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.gradientStart,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gradientStart.withOpacity(0.2),
                            blurRadius: 10,
                          ),
                        ],
                        gradient: const LinearGradient(
                          colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // 2. Activity Goal Card (Activity Ring)
                _buildActivityRingCard(isTablet),

                const SizedBox(height: 24),

                // 3. Quick Start Neon Gradient Button
                _buildQuickStartCard(isTablet),

                const SizedBox(height: 32),

                // 4. Recommended Workouts Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Today's Workouts",
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextColor(context),
                        fontFamily: 'Inter',
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onNavigateToWorkouts,
                      child: Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 5. Recommended Workout Cards
                _buildWorkoutCard(
                  title: 'Push Ups',
                  category: 'Strength',
                  level: 'Beginner',
                  duration: '15 min',
                  calories: 120,
                  imageUrl: 'https://images.unsplash.com/photo-1758521959396-4dbfd4a8ab11?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxneW0lMjB3b3Jrb3V0JTIwbWFuJTIwcHVzaCUyMHVwc3xlbnwxfHx8fDE3NzMwMzg3NjV8MA&ixlib=rb-4.1.0&q=80&w=1080',
                  fallbackIcon: Icons.fitness_center_rounded,
                  isTablet: isTablet,
                ),

                const SizedBox(height: 16),

                _buildWorkoutCard(
                  title: 'Squats',
                  category: 'Strength',
                  level: 'Beginner',
                  duration: '20 min',
                  calories: 180,
                  imageUrl: 'https://images.unsplash.com/photo-1657289244708-a4d379018991?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxhdGhsZXRpYyUyMG1hbiUyMHNxdWF0cyUyMGV4ZXJjaXNlfGVufDF8fHx8MTc3MzAzODc2Nnww&ixlib=rb-4.1.0&q=80&w=1080',
                  fallbackIcon: Icons.accessibility_new_rounded,
                  isTablet: isTablet,
                ),

                const SizedBox(height: 32),

                // 6. Bottom Stats Dashboard
                _buildStatsDashboard(isTablet),
              ],
            ),
      ),
    );
  }

  Widget _buildActivityRingCard(bool isTablet) {
    final double calories = _dailyStats?.totalCalories ?? 0.0;
    final int durationMin = ((_dailyStats?.totalDurationSeconds ?? 0) / 60).round();
    const double targetCalories = 600.0; // Default daily goal of 600 kcal
    final double goalProgress = (calories / targetCalories).clamp(0.0, 1.0);
    final String goalPercent = '${(goalProgress * 100).toStringAsFixed(0)}%';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppTheme.getBorderColor(context),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Activity Ring Circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: goalProgress,
                  strokeWidth: 6.5,
                  color: primaryColor,
                  backgroundColor: AppTheme.getBorderColor(context),
                ),
              ),
              Icon(
                Icons.local_fire_department_rounded,
                color: primaryColor,
                size: 32,
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Ring Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Goal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.getSecondaryTextColor(context),
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      goalPercent,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calories',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getSecondaryTextColor(context).withOpacity(0.8),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${calories.toStringAsFixed(0)} kcal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getTextColor(context),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Duration',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getSecondaryTextColor(context).withOpacity(0.8),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$durationMin mins',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getTextColor(context),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartCard(bool isTablet) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.gradientStart.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: widget.onNavigateToWorkouts,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to train?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.6),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Quick Workout Setup',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.12),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutCard({
    required String title,
    required String category,
    required String level,
    required String duration,
    required int calories,
    required String imageUrl,
    required IconData fallbackIcon,
    required bool isTablet,
  }) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppTheme.getBorderColor(context),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Exercise Image
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF1E2021),
                child: Center(
                  child: Icon(
                    fallbackIcon,
                    color: Colors.white.withOpacity(0.15),
                    size: 64,
                  ),
                ),
              ),
            ),
            // Black gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            // Text Details bottom
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isTablet ? 28 : 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            duration,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$calories kcal',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Small Neon Play Button
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => WorkoutDetailScreen(
                            title: title,
                            category: category,
                            level: level,
                            duration: duration,
                            imagePath: '',
                            fallbackIcon: fallbackIcon,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppTheme.gradientStart,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsDashboard(bool isTablet) {
    final int workouts = _summary?.totalWorkouts ?? 0;
    final double calories = _summary?.totalCalories ?? 0.0;
    final int streak = _summary?.currentStreak ?? 0;

    String calText;
    if (calories >= 1000) {
      calText = '${(calories / 1000).toStringAsFixed(1)}k';
    } else {
      calText = calories.toStringAsFixed(0);
    }

    return Row(
      children: [
        Expanded(child: _buildSingleDashboardStat('Workouts', '$workouts', Icons.emoji_events_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _buildSingleDashboardStat('Calories', calText, Icons.local_fire_department_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _buildSingleDashboardStat('Streak', '$streak', Icons.ads_click_rounded)),
      ],
    );
  }
  Widget _buildSingleDashboardStat(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.getBorderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.getTextColor(context),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.getSecondaryTextColor(context),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
