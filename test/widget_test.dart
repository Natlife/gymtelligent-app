import 'package:flutter_test/flutter_test.dart';
import 'package:gymtelligent/main.dart';
import 'package:gymtelligent/screens/welcome_screen.dart';

void main() {
  testWidgets('Welcome Screen layout smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GymtelligentApp(initialScreen: WelcomeScreen()));

    // Verify that the welcome page elements are found
    expect(find.text('GYMTELLIGENT'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
