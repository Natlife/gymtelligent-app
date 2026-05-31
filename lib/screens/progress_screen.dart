import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../theme.dart';
import '../services/stats_service.dart';
import '../models/stats_summary.dart';
import '../models/daily_stats.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  bool _isLoading = true;
  StatsSummary? _summary;
  List<DailyStats> _weeklyStats = [];
  List<double> _chartData = [0, 0, 0, 0, 0, 0, 0];
  List<String> _chartDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await StatsService.getSummary();
      
      // Calculate Monday of current week
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekly = await StatsService.getWeeklyStats(weekStart);

      if (mounted) {
        setState(() {
          _summary = summary;
          _weeklyStats = weekly;
          
          if (weekly.isNotEmpty) {
            _chartData = weekly.map((d) => d.totalCalories).toList();
            final df = DateFormat('E'); // Mon, Tue, etc.
            _chartDays = weekly.map((d) => df.format(DateTime.parse(d.date))).toList();
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    final int workouts = _summary?.totalWorkouts ?? 0;
    final double calories = _summary?.totalCalories ?? 0.0;
    final int streak = _summary?.currentStreak ?? 0;

    String calText;
    if (calories >= 1000) {
      calText = '${(calories / 1000).toStringAsFixed(1)}k';
    } else {
      calText = calories.toStringAsFixed(0);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);

    return FadeTransition(
      opacity: _fadeIn,
      child: RefreshIndicator(
        onRefresh: _loadProgressData,
        color: primaryColor,
        backgroundColor: AppTheme.getSurfaceColor(context),
        child: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              children: [
                // 1. Header
                Text(
                  'Progress',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: isTablet ? 44 : 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Keep track of your journey',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.getSecondaryTextColor(context),
                    fontFamily: 'Inter',
                  ),
                ),

                const SizedBox(height: 32),

                // 2. Stats Grid (2x2 Grid)
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.25,
                  children: [
                    _buildStatsCard(
                      icon: Icons.calendar_today_rounded,
                      value: '$workouts',
                      label: 'Total Workouts',
                      isHighlighted: true,
                    ),
                    _buildStatsCard(
                      icon: Icons.local_fire_department_rounded,
                      value: calText,
                      label: 'Calories Burned (kcal)',
                      isHighlighted: true,
                    ),
                    _buildStatsCard(
                      icon: Icons.trending_up_rounded,
                      value: '$streak',
                      label: 'Current Streak (Days)',
                      isHighlighted: false,
                    ),
                    _buildStatsCard(
                      icon: Icons.emoji_events_rounded,
                      value: '${_summary?.longestStreak ?? 0}',
                      label: 'Longest Streak (Days)',
                      isHighlighted: false,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 3. Weekly Area Chart
                Text(
                  'Weekly Activity',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextColor(context),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 14),
                _buildChartContainer(
                  label: 'Calories burned per day',
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: NeonAreaChartPainter(
                        dataPoints: _chartData,
                        days: _chartDays,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 4. Monthly Trend Chart
                Text(
                  'Monthly Trend',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextColor(context),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 14),
                _buildChartContainer(
                  label: 'Calories burned per week',
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: NeonLineChartPainter(
                        dataPoints: [calories, calories, calories, calories], // Standard dynamic fallback
                        weeks: ['W1', 'W2', 'W3', 'W4'],
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 5. Recent Achievements
                Text(
                  'Recent Achievements',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextColor(context),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 18),
                _buildAchievementItem('🏆', 'First Workout Complete', 'Completed your first AI-assisted workout'),
                const SizedBox(height: 12),
                _buildAchievementItem('🔥', '7 Day Streak Active', 'Exercised 7 days in a row with zero misses'),
                const SizedBox(height: 12),
                _buildAchievementItem('💪', 'Posture Master', 'Maintained 95%+ posture accuracy in 5 exercises'),
              ],
            ),
      ),
    );
  }

  Widget _buildStatsCard({
    required IconData icon,
    required String value,
    required String label,
    required bool isHighlighted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);
    final secondaryColor = isDark ? AppTheme.gradientEnd : const Color(0xFF0D9488);

    final cardBg = isHighlighted
        ? LinearGradient(
            colors: [
              primaryColor.withOpacity(0.18),
              secondaryColor.withOpacity(0.18),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    final border = Border.all(
      color: isHighlighted 
          ? primaryColor.withOpacity(0.3) 
          : AppTheme.getBorderColor(context),
      width: 1.5,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted ? null : AppTheme.getSurfaceColor(context),
        gradient: cardBg,
        borderRadius: BorderRadius.circular(25),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 24,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.getTextColor(context),
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 3),
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
        ],
      ),
    );
  }

  Widget _buildChartContainer({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppTheme.getBorderColor(context),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.getSecondaryTextColor(context),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(String emoji, String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);
    final secondaryColor = isDark ? AppTheme.gradientEnd : const Color(0xFF0D9488);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.getBorderColor(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.25),
                  secondaryColor.withOpacity(0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextColor(context),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.getSecondaryTextColor(context),
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
}

// ---------------------------------------------------------
// Custom Painter for Neon Glowing Area Chart
// ---------------------------------------------------------
class NeonAreaChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final List<String> days;
  final bool isDark;

  NeonAreaChartPainter({
    required this.dataPoints,
    required this.days,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final double paddingBottom = 20.0;
    final double paddingLeft = 32.0;
    final double chartHeight = height - paddingBottom;
    final double chartWidth = width - paddingLeft;

    final double maxVal = dataPoints.reduce(math.max) * 1.15;
    final double xSegment = chartWidth / (dataPoints.length - 1);

    // Draw background grid lines (y axis horizontal lines)
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 4; i++) {
      final yGrid = chartHeight - (i * chartHeight / 3);
      canvas.drawLine(Offset(paddingLeft, yGrid), Offset(width, yGrid), gridPaint);
    }

    // Path calculation
    final path = Path();
    final List<Offset> points = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final double x = paddingLeft + (i * xSegment);
      final double y = chartHeight - (dataPoints[i] / maxVal * chartHeight);
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Curved line using cubicTo for natural flow
        final prevX = points[i - 1].dx;
        final prevY = points[i - 1].dy;
        final controlX1 = prevX + xSegment / 2;
        final controlY1 = prevY;
        final controlX2 = x - xSegment / 2;
        final controlY2 = y;
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    // Draw Area gradient underneath the curve
    final areaPath = Path.from(path);
    areaPath.lineTo(points.last.dx, chartHeight);
    areaPath.lineTo(points.first.dx, chartHeight);
    areaPath.close();

    final primaryColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);

    final areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withOpacity(0.35),
          primaryColor.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(paddingLeft, 0, width, chartHeight));
    
    canvas.drawPath(areaPath, areaPaint);

    // Draw glowing neon line
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw data labels (X axis and values)
    final textStyle = TextStyle(
      color: isDark ? Colors.white60 : Colors.black54,
      fontSize: 10,
      fontFamily: 'Inter',
    );

    for (int i = 0; i < days.length; i++) {
      // Draw days labels on X axis
      final textSpan = TextSpan(text: days[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas, 
        Offset(points[i].dx - textPainter.width / 2, chartHeight + 6)
      );
    }

    // Y Axis indicators
    for (int i = 0; i < 4; i++) {
      final yGrid = chartHeight - (i * chartHeight / 3);
      final value = (i * maxVal / 3).round();
      final textSpan = TextSpan(text: '$value', style: textStyle.copyWith(color: isDark ? Colors.white24 : Colors.black38));
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 8, yGrid - textPainter.height / 2)
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------
// Custom Painter for Neon Blue Line Chart
// ---------------------------------------------------------
class NeonLineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final List<String> weeks;
  final bool isDark;

  NeonLineChartPainter({
    required this.dataPoints,
    required this.weeks,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final double paddingBottom = 20.0;
    final double paddingLeft = 36.0;
    final double chartHeight = height - paddingBottom;
    final double chartWidth = width - paddingLeft;

    final double maxVal = dataPoints.reduce(math.max) * 1.15;
    final double xSegment = chartWidth / (dataPoints.length - 1);

    // Draw background grid lines (y axis horizontal lines)
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 4; i++) {
      final yGrid = chartHeight - (i * chartHeight / 3);
      canvas.drawLine(Offset(paddingLeft, yGrid), Offset(width, yGrid), gridPaint);
    }

    // Path calculation
    final path = Path();
    final List<Offset> points = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final double x = paddingLeft + (i * xSegment);
      final double y = chartHeight - (dataPoints[i] / maxVal * chartHeight);
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = points[i - 1].dx;
        final prevY = points[i - 1].dy;
        final controlX1 = prevX + xSegment / 2;
        final controlY1 = prevY;
        final controlX2 = x - xSegment / 2;
        final controlY2 = y;
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    final secondaryColor = isDark ? AppTheme.gradientEnd : const Color(0xFF0D9488);

    // Draw glowing neon line
    final linePaint = Paint()
      ..color = secondaryColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw dot nodes on each week
    final dotPaint = Paint()..color = secondaryColor;
    final dotBorderPaint = Paint()
      ..color = isDark ? Colors.black : Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var point in points) {
      canvas.drawCircle(point, 6.0, dotPaint);
      canvas.drawCircle(point, 6.0, dotBorderPaint);
    }

    // Draw data labels (X axis and values)
    final textStyle = TextStyle(
      color: isDark ? Colors.white60 : Colors.black54,
      fontSize: 10,
      fontFamily: 'Inter',
    );

    for (int i = 0; i < weeks.length; i++) {
      // Draw weeks labels on X axis
      final textSpan = TextSpan(text: weeks[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas, 
        Offset(points[i].dx - textPainter.width / 2, chartHeight + 6)
      );
    }

    // Y Axis indicators
    for (int i = 0; i < 4; i++) {
      final yGrid = chartHeight - (i * chartHeight / 3);
      final value = (i * maxVal / 3).round();
      final textSpan = TextSpan(text: '$value', style: textStyle.copyWith(color: isDark ? Colors.white24 : Colors.black38));
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 8, yGrid - textPainter.height / 2)
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
