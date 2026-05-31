import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/stats_service.dart';
import '../models/stats_summary.dart';
import '../services/feedback_service.dart';
import 'admin_feedback_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  StatsSummary? _summary;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final profile = await ProfileService.getProfile();
      final summary = await StatsService.getSummary();
      if (mounted) {
        setState(() {
          _profileData = profile;
          _summary = summary;
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

    final name = _profileData?['fullName'] ?? 'Athlete';
    final email = _profileData?['email'] ?? 'athlete@email.com';
    final role = _profileData?['roleName'] ?? 'ROLE_USER';
    final isAdmin = role == 'ROLE_ADMIN';

    final workoutsCount = _summary?.totalWorkouts.toString() ?? '0';
    final streak = _summary?.currentStreak.toString() ?? '0';
    
    // Format calories to e.g. 4.2k or raw value if small
    String caloriesStr = '0';
    if (_summary != null) {
      final double cals = _summary!.totalCalories;
      if (cals >= 1000) {
        caloriesStr = '${(cals / 1000).toStringAsFixed(1)}k';
      } else {
        caloriesStr = cals.toStringAsFixed(0);
      }
    }

    return FadeTransition(
      opacity: _fadeIn,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gradientStart),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              children: [
                // 1. Header Title
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: isTablet ? 44 : 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 24),

                // 2. User Info Glassmorphic Card
                Container(
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
                      // Avatar
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.black,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getTextColor(context),
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.getSecondaryTextColor(context),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Row of Stats (Workouts, Calories, Streak)
                Row(
                  children: [
                    Expanded(child: _buildProfileStatCard(workoutsCount, 'Workouts')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProfileStatCard(caloriesStr, 'Calories')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProfileStatCard(streak, 'Streak')),
                  ],
                ),

                const SizedBox(height: 32),

                // 4. Upgrade Premium Card (PRO Banner)
                _buildPremiumBanner(isTablet),

                const SizedBox(height: 24),

                // 5. Menu List Items
                if (isAdmin) ...[
                  _buildMenuItem(
                    Icons.admin_panel_settings_rounded,
                    'Admin Feedback Panel',
                    true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AdminFeedbackScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _buildMenuItem(
                  Icons.chat_bubble_outline_rounded,
                  'Send Feedback to Admin',
                  false,
                  onTap: () => _showFeedbackSubmissionModal(context),
                ),
                const SizedBox(height: 12),
                _buildMenuItem(Icons.settings_rounded, 'Settings', false),
                const SizedBox(height: 12),
                _buildMenuItem(Icons.notifications_rounded, 'Notifications', false),
                const SizedBox(height: 12),
                _buildMenuItem(Icons.favorite_rounded, 'Favorites', false),
                const SizedBox(height: 12),
                _buildMenuItem(Icons.help_outline_rounded, 'Help Center', false),

                const SizedBox(height: 32),

          // 6. Personal Records Section
          Text(
            'Personal Records',
            style: TextStyle(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextColor(context),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          _buildRecordItem('Push Ups', '45 reps', '+5'),
          const SizedBox(height: 12),
          _buildRecordItem('Plank', '3:45 mins', '+15s'),

          const SizedBox(height: 36),

          // 7. Logout Button
          GestureDetector(
            onTap: () async {
              // Clear saved token
              await AuthService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.red.withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatCard(String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.getBorderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: primaryColor,
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

  Widget _buildPremiumBanner(bool isTablet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.gradientStart.withOpacity(0.18),
            AppTheme.gradientEnd.withOpacity(0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.gradientStart.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppTheme.gradientStart,
                size: 26,
              ),
              const SizedBox(width: 14),
              const Text(
                'Upgrade to Premium',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.gradientStart,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, bool highlight, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: highlight ? primaryColor.withOpacity(0.4) : AppTheme.getBorderColor(context),
            width: 1.5,
          ),
          boxShadow: highlight 
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.08),
                    blurRadius: 8,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: highlight ? primaryColor : AppTheme.getSecondaryTextColor(context),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: highlight ? primaryColor : AppTheme.getTextColor(context),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: highlight ? primaryColor.withOpacity(0.6) : AppTheme.getSecondaryTextColor(context).withOpacity(0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackSubmissionModal(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 28,
                left: 28,
                right: 28,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF131415),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Send Feedback',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We highly value your feedback to improve Gymtelligent.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.55),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'TITLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gradientStart,
                        letterSpacing: 1.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
                      decoration: InputDecoration(
                        hintText: 'Enter feedback title (e.g. Bug, Suggestion)',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                        filled: true,
                        fillColor: AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: AppTheme.gradientStart, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'MESSAGE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gradientStart,
                        letterSpacing: 1.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: contentController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts, suggestions or issues here...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                        filled: true,
                        fillColor: AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: AppTheme.gradientStart, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your message';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: isSubmitting
                          ? null
                          : () async {
                              if (formKey.currentState!.validate()) {
                                setModalState(() {
                                  isSubmitting = true;
                                });
                                final success = await FeedbackService.submitFeedback(
                                  title: titleController.text.trim(),
                                  content: contentController.text.trim(),
                                );
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Feedback submitted successfully! Thank you.'
                                            : 'Failed to submit feedback. Please try again.',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      backgroundColor: success ? AppTheme.gradientStart : Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: isSubmitting ? null : AppTheme.primaryGradient,
                          color: isSubmitting ? Colors.white12 : null,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSubmitting
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppTheme.gradientStart.withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                        ),
                        child: Center(
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'SUBMIT FEEDBACK',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontFamily: 'Inter',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecordItem(String exercise, String record, String increase) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gradientStart : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.getBorderColor(context),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.getSecondaryTextColor(context),
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextColor(context),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          Text(
            increase,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
