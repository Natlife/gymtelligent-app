import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/feedback_service.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _feedbacks = [];

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await FeedbackService.getAllFeedbacks();
      if (mounted) {
        setState(() {
          _feedbacks = list ?? [];
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

  void _showFeedbackDetail(Map<String, dynamic> feedback) {
    final senderName = feedback['senderName'] ?? 'Unknown User';
    final senderEmail = feedback['senderEmail'] ?? 'No Email';
    final title = feedback['title'] ?? 'Untitled';
    final content = feedback['content'] ?? '';
    final rawDate = feedback['createdAt'];
    
    String formattedDate = 'N/A';
    if (rawDate != null) {
      try {
        final parsed = DateTime.parse(rawDate);
        formattedDate = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} - ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.cyan : const Color(0xFF0D9488);
    final avatarBg = isDark ? const Color(0xFF0C2C29) : const Color(0xFFE0F2FE);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: primaryColor.withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Details
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: primaryColor,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getTextColor(context),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            senderEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getSecondaryTextColor(context),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Title
                Text(
                  'TITLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1.5,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextColor(context),
                    fontFamily: 'Inter',
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Content
                Text(
                  'FEEDBACK CONTENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1.5,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppTheme.getTextColor(context).withOpacity(0.85),
                        height: 1.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Date footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.getSecondaryTextColor(context).withOpacity(0.8),
                        fontFamily: 'Inter',
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.gradientStart.withOpacity(0.2),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: const Text(
                          'CLOSE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.cyan : const Color(0xFF0D9488);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.getTextColor(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'User Feedbacks',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextColor(context),
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: primaryColor),
            onPressed: _loadFeedbacks,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : _feedbacks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.feedback_outlined,
                        size: 64,
                        color: AppTheme.getSecondaryTextColor(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No feedbacks submitted yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.getSecondaryTextColor(context),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: _feedbacks.length,
                  itemBuilder: (context, index) {
                    final f = _feedbacks[index];
                    final title = f['title'] ?? 'Untitled';
                    final senderName = f['senderName'] ?? 'Athlete';
                    final rawDate = f['createdAt'];
                    
                    String formattedDate = '';
                    if (rawDate != null) {
                      try {
                        final parsed = DateTime.parse(rawDate);
                        formattedDate = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
                      } catch (_) {}
                    }

                    return GestureDetector(
                      onTap: () => _showFeedbackDetail(f),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.getBorderColor(context),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.02),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     title,
                                     maxLines: 1,
                                     overflow: TextOverflow.ellipsis,
                                     style: TextStyle(
                                       fontSize: 16,
                                       fontWeight: FontWeight.bold,
                                       color: AppTheme.getTextColor(context),
                                       fontFamily: 'Inter',
                                     ),
                                   ),
                                   const SizedBox(height: 4),
                                   Row(
                                     children: [
                                       Text(
                                         'By: $senderName',
                                         style: TextStyle(
                                           fontSize: 12,
                                           color: AppTheme.getSecondaryTextColor(context),
                                           fontFamily: 'Inter',
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       Text(
                                         '•',
                                         style: TextStyle(
                                           color: AppTheme.getSecondaryTextColor(context).withOpacity(0.5),
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       Text(
                                         formattedDate,
                                         style: TextStyle(
                                           fontSize: 11,
                                           color: AppTheme.getSecondaryTextColor(context).withOpacity(0.8),
                                           fontFamily: 'Inter',
                                         ),
                                       ),
                                     ],
                                   ),
                                 ],
                               ),
                             ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppTheme.getSecondaryTextColor(context).withOpacity(0.5),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
