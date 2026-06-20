import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/exercise_library_screen.dart';
import 'services/api_client.dart';
import 'services/profile_service.dart';
import 'services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AnalyticsService.initialize();

  final token = await ApiClient.getToken();
  final hasSavedSession = token != null;

  if (hasSavedSession) {
    try {
      final profile = await ProfileService.getProfile();
      await AnalyticsService.applyUserContext(profile);
      if (profile != null && profile['roleName'] == 'ROLE_ADMIN') {
        appThemeNotifier.value = AppTheme.lightTheme;
      } else {
        appThemeNotifier.value = AppTheme.darkTheme;
      }
    } catch (_) {
      appThemeNotifier.value = AppTheme.darkTheme;
    }
  } else {
    appThemeNotifier.value = AppTheme.darkTheme;
  }

  runApp(
    GymtelligentApp(
      initialScreen: hasSavedSession
          ? const ExerciseLibraryScreen()
          : const WelcomeScreen(),
    ),
  );
}

class GymtelligentApp extends StatelessWidget {
  final Widget initialScreen;
  const GymtelligentApp({super.key, required this.initialScreen});
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = AnalyticsService.observer;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: appThemeNotifier,
      builder: (context, currentTheme, child) {
        return MaterialApp(
          title: 'Gymtelligent',
          debugShowCheckedModeBanner: false,
          theme: currentTheme,
          navigatorObservers: <NavigatorObserver>[GymtelligentApp.observer],

          home: initialScreen,
        );
      },
    );
  }
}
