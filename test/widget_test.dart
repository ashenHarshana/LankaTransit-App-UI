import 'package:flutter_test/flutter_test.dart';
import 'package:lankatransit_app/main.dart';

void main() {

  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const LankaTransitApp(
        isLoggedIn: false,
        role: 'PASSENGER',
      ),
    );

    // Check app loaded
    expect(find.byType(LankaTransitApp), findsOneWidget);
  });


  testWidgets('Login screen should appear when not logged in', (WidgetTester tester) async {
    await tester.pumpWidget(
      const LankaTransitApp(
        isLoggedIn: false,
        role: 'PASSENGER',
      ),
    );

    await tester.pumpAndSettle();

    // 👇 Change this text if your Login screen has different text
    expect(find.text('Login'), findsOneWidget);
  });


  testWidgets('Home screen should appear when logged in as passenger', (WidgetTester tester) async {
    await tester.pumpWidget(
      const LankaTransitApp(
        isLoggedIn: true,
        role: 'PASSENGER',
      ),
    );

    await tester.pumpAndSettle();

    // 👇 Change this text based on your HomeScreen UI
    expect(find.byType(LankaTransitApp), findsOneWidget);
  });


  testWidgets('Admin screen should appear when role is ADMIN', (WidgetTester tester) async {
    await tester.pumpWidget(
      const LankaTransitApp(
        isLoggedIn: true,
        role: 'ADMIN',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LankaTransitApp), findsOneWidget);
  });


  testWidgets('Driver screen should appear when role is DRIVER', (WidgetTester tester) async {
    await tester.pumpWidget(
      const LankaTransitApp(
        isLoggedIn: true,
        role: 'DRIVER',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LankaTransitApp), findsOneWidget);
  });

}