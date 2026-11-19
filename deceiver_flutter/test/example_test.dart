import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// The example is not a package of its own, so it can only be imported by path.
// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';

void main() {
  testWidgets('example app loads users and switches scenarios', (tester) async {
    // Tall enough to show the scenarios in the drawer below the panel header.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('GET /users'));
    await tester.pumpAndSettle();
    expect(find.textContaining('200: [{"name":"Bilbo"}'), findsOneWidget);

    tester.state<ScaffoldState>(find.byType(Scaffold)).openEndDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('error'));
    await tester.pumpAndSettle();
    tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('GET /users'));
    await tester.pumpAndSettle();
    expect(find.text('500: {"error":"Server error"}'), findsOneWidget);
  });
}
