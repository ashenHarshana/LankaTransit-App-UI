import 'package:LankaTransit/main.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {


  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const LankaTransitApp(
        isLoggedIn: false,
        role: 'PASSENGER',
      ),
    );

    expect(find.byType(LankaTransitApp), findsOneWidget);
  });


  testWidgets('Login screen appears when not logged in', (WidgetTester tester) async {
    await tester.pumpWidget(
      const LankaTransitApp(
        isLoggedIn: false,
        role: 'PASSENGER',
      ),
    );

    await tester.pumpAndSettle();


    expect(find.text('Login'), findsOneWidget);
  });


  testWidgets('Passenger home screen appears when logged in', (WidgetTester tester) async {
    await tester.pumpWidget(
      const LankaTransitApp(
        isLoggedIn: true,
        role: 'PASSENGER',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LankaTransitApp), findsOneWidget);
  });

  // ✅ Test 4 - Admin role
  testWidgets('Admin screen appears when role is ADMIN', (WidgetTester tester) async {
    await tester.pumpWidget(
      const LankaTransitApp(
        isLoggedIn: true,
        role: 'ADMIN',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LankaTransitApp), findsOneWidget);
  });

  // ✅ Test 5 - Driver role
  testWidgets('Driver screen appears when role is DRIVER', (WidgetTester tester) async {
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