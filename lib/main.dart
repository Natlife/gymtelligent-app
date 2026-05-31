import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/exercise_library_screen.dart';
import 'services/api_client.dart';
import 'services/profile_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final token = await ApiClient.getToken();

  // Dynamically load initial theme based on user role if token exists
  if (token != null) {
    try {
      final profile = await ProfileService.getProfile();
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

  runApp(GymtelligentApp(
    initialScreen: token != null ? const ExerciseLibraryScreen() : const WelcomeScreen(),
  ));
}

class GymtelligentApp extends StatelessWidget {
  final Widget initialScreen;
  const GymtelligentApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: appThemeNotifier,
      builder: (context, currentTheme, child) {
        return MaterialApp(
          title: 'Gymtelligent',
          debugShowCheckedModeBanner: false,
          theme: currentTheme,
          home: initialScreen,
        );
      },
    );
  }
}
