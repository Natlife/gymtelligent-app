import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  static Future<void> initialize() async {
    await _analytics.setAnalyticsCollectionEnabled(true);
    await _analytics.logAppOpen();
  }

  static Future<void> applyUserContext(Map<String, dynamic>? profile) async {
    final role = profile?['roleName'] == 'ROLE_ADMIN' ? 'admin' : 'user';
    await _analytics.setUserProperty(name: 'user_role', value: role);

    final userId = _extractNonPiiUserId(profile);
    if (userId != null) {
      await _analytics.setUserId(id: userId);
    }
  }

  static Future<void> logLogin() async {
    await _analytics.logLogin(loginMethod: 'password');
  }

  static Future<void> logSignUp() async {
    await _analytics.logSignUp(signUpMethod: 'password');
  }

  static Future<void> logLogout() async {
    await _analytics.logEvent(name: 'logout');
    await _analytics.setUserId(id: null);
    await _analytics.setUserProperty(name: 'user_role', value: null);
  }

  static String? _extractNonPiiUserId(Map<String, dynamic>? profile) {
    if (profile == null) return null;

    final rawId = profile['id'] ?? profile['userId'];
    if (rawId == null) return null;

    final id = rawId.toString().trim();
    return id.isEmpty ? null : id;
  }
}
