import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'workout_detail_screen.dart';
import '../services/stats_service.dart';
import '../services/profile_service.dart';
import '../models/stats_summary.dart';
import '../models/daily_stats.dart';
import '../widgets/onboarding_tour.dart';

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToWorkouts;
  final GlobalKey? workoutsTabKey;
  final GlobalKey? progressTabKey;
  final GlobalKey? profileTabKey;
  
  const HomeDashboardScreen({
    super.key, 
    required this.onNavigateToWorkouts,
    this.workoutsTabKey,
    this.progressTabKey,
    this.profileTabKey,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> with SingleTickerProviderStateMixin {
  // GlobalKeys for Onboarding
  final GlobalKey _profileHeaderKey = GlobalKey();
  final GlobalKey _activityRingKey = GlobalKey();
  final GlobalKey _quickStartKey = GlobalKey();
  final GlobalKey _statsDashboardKey = GlobalKey();

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
      final today = StatsService.vietnamNow();
      final todayKey = StatsService.formatVietnamDate(today);
      final profile = await ProfileService.getProfile();
      final cacheKey = _dailyStatsCacheKey(profile, todayKey);
      final cachedDaily = await _readCachedDailyStats(cacheKey, todayKey);

      if (mounted && cachedDaily != null) {
        setState(() {
          _dailyStats = cachedDaily;
          _isLoading = false;
        });
      }

      final summary = await StatsService.getSummary();
      final daily = await StatsService.getDailyStats(today);
      if (daily != null) {
        await _cacheDailyStats(cacheKey, daily);
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _dailyStats = daily ?? cachedDaily;
          if (profile != null && profile['fullName'] != null) {
            _userName = profile['fullName'];
          }
          _isLoading = false;
        });

        // Trigger onboarding tour after dashboard has rendered
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOnboardingTour();
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

  void _showOnboardingTour({bool force = false}) {
    if (!mounted) return;

    final steps = [
      OnboardingStep(
        title: 'Chào mừng đến với Gymtelligent! 👋',
        description: 'Tôi là trợ lý ảo hỗ trợ tập luyện của bạn. Hãy để tôi hướng dẫn bạn các tính năng chính của ứng dụng nhé.',
      ),
      OnboardingStep(
        title: 'Thông tin cá nhân',
        description: 'Nơi hiển thị thông tin lời chào và ảnh đại diện của bạn. Hãy cập nhật đầy đủ thông tin cá nhân trong mục Profile nhé.',
        targetKey: _profileHeaderKey,
        highlightShape: 'rect',
      ),
      OnboardingStep(
        title: 'Mục tiêu hàng ngày',
        description: 'Theo dõi tiến trình hoàn thành mục tiêu calo tiêu thụ và tổng thời gian rèn luyện của bạn hôm nay tại đây.',
        targetKey: _activityRingKey,
        highlightShape: 'rect',
      ),
      OnboardingStep(
        title: 'Bắt đầu tập luyện ngay',
        description: 'Bấm vào đây để truy cập nhanh danh sách bài tập thông minh được hỗ trợ bởi AI và bắt đầu buổi tập của bạn.',
        targetKey: _quickStartKey,
        highlightShape: 'rect',
      ),
      OnboardingStep(
        title: 'Chỉ số sức khỏe tổng hợp',
        description: 'Xem nhanh số bài tập đã hoàn thành, lượng calo đốt cháy và số ngày tập liên tiếp để luôn giữ vững động lực.',
        targetKey: _statsDashboardKey,
        highlightShape: 'rect',
      ),
      if (widget.workoutsTabKey != null)
        OnboardingStep(
          title: 'Thư viện bài tập',
          description: 'Xem danh sách toàn bộ các động tác được hướng dẫn chi tiết bởi AI.',
          targetKey: widget.workoutsTabKey,
          highlightShape: 'circle',
        ),
      if (widget.progressTabKey != null)
        OnboardingStep(
          title: 'Biểu đồ tiến trình',
          description: 'Xem các thống kê chuyên sâu và biểu đồ tiến bộ của bạn qua từng tuần/tháng.',
          targetKey: widget.progressTabKey,
          highlightShape: 'circle',
        ),
    ];

    OnboardingTour.start(
      context,
      steps: steps,
      tourKey: 'home_dashboard_tour',
      force: force,
    );
  }

  String _dailyStatsCacheKey(Map<String, dynamic>? profile, String dateKey) {
    final userKey = (profile?['id'] ??
            profile?['userId'] ??
            profile?['username'] ??
            profile?['email'] ??
            'current_user')
        .toString();
    return 'daily_stats_${userKey}_$dateKey';
  }

  Future<DailyStats?> _readCachedDailyStats(String cacheKey, String todayKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return null;

      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;

      final stats = DailyStats.fromJson(data);
      if (stats.date.isNotEmpty && stats.date != todayKey) return null;
      return stats;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheDailyStats(String cacheKey, DailyStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(stats.toJson()));
    } catch (_) {}
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
                  key: _profileHeaderKey,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getCurrentDateString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: isTablet ? 36 : 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.help_outline_rounded,
                        color: AppTheme.gradientStart,
                        size: 26,
                      ),
                      onPressed: () {
                        _showOnboardingTour(force: true);
                      },
                      tooltip: 'Xem hướng dẫn',
                    ),
                    const SizedBox(width: 8),
                    
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
                KeyedSubtree(
                  key: _activityRingKey,
                  child: _buildActivityRingCard(isTablet),
                ),

                const SizedBox(height: 24),

                // 3. Quick Start Neon Gradient Button
                KeyedSubtree(
                  key: _quickStartKey,
                  child: _buildQuickStartCard(isTablet),
                ),

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
                  title: 'Shoulder Press',
                  category: 'Strength',
                  level: 'Intermediate',
                  duration: '12 min',
                  calories: 150,
                  imageUrl: 'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxzaG91bGRlciUyMHByZXNzfGVufDF8fHx8MTc3MzAzODc2Nnww&ixlib=rb-4.1.0&q=80&w=1080',
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
                KeyedSubtree(
                  key: _statsDashboardKey,
                  child: _buildStatsDashboard(isTablet),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildActivityRingCard(bool isTablet) {
    final double calories = _dailyStats?.totalCalories ?? 0.0;
    final int durationMin = ((_dailyStats?.totalDurationSeconds ?? 0) / 60).round();
    const double targetCalories = 600.0; 
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
