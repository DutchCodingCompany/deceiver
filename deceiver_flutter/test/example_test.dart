import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// The example is not a package of its own, so it can only be imported by path.
// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';
// ignore: avoid_relative_lib_imports
import '../example/lib/mocks.dart';

void main() {
  setUp(() {
    // The example uses one global Deceiver, so start every test fresh.
    controller.reset(baseUrl: Environment.production.apiUrl);
    registerMocks(deceiver, Environment.production);
  });

  Future<void> pumpExample(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp());
  }

  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Card));

  /// Sends the request of the card with [title] and returns the card.
  Future<Finder> send(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(
      find.text(title),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.descendant(of: card(title), matching: find.text('Send')),
    );
    await tester.pumpAndSettle();
    return card(title);
  }

  Finder textIn(Finder card, String text) =>
      find.descendant(of: card, matching: find.textContaining(text));

  testWidgets('lists the users with jsonResponse', (tester) async {
    await pumpExample(tester);

    final users = await send(tester, 'List users');

    expect(textIn(users, 'Mock: GET /users'), findsOneWidget);
    expect(textIn(users, '200 [{"id":1,"name":"Bilbo"}'), findsOneWidget);
  });

  testWidgets('reads path parameters and the request body', (tester) async {
    await pumpExample(tester);

    final user = await send(tester, 'Get user 42');
    expect(textIn(user, '404 {"error":"No user 42"}'), findsOneWidget);

    final create = await send(tester, 'Create a user without name');
    expect(
      textIn(create, '422 {"error":"Name cannot be blank"}'),
      findsOneWidget,
    );
  });

  testWidgets('a sequence returns the next response every call', (
    tester,
  ) async {
    await pumpExample(tester);

    await send(tester, 'Poll notifications');
    await send(tester, 'Poll notifications');
    final poll = await send(tester, 'Poll notifications');

    expect(textIn(poll, '500 {"error":"Server error"}'), findsOneWidget);
  });

  testWidgets('mocks another API with on.at()', (tester) async {
    await pumpExample(tester);

    final login = await send(tester, 'Log in');

    expect(
      textIn(login, 'Mock: POST https://auth.example.com/token'),
      findsOneWidget,
    );
    expect(textIn(login, '{"token":"abc"}'), findsOneWidget);
  });

  testWidgets('shows when no mock answers', (tester) async {
    await pumpExample(tester);

    final search = await send(tester, 'Search "orc"');

    expect(textIn(search, 'No mock'), findsOneWidget);
  });

  testWidgets('switches scenarios in the panel', (tester) async {
    await pumpExample(tester);

    await tester.tap(find.byTooltip('Deceiver panel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RadioListTile<String?>, 'error'));
    await tester.pumpAndSettle();
    tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
    await tester.pumpAndSettle();

    final users = await send(tester, 'List users');

    expect(textIn(users, '500 {"error":"Server error"}'), findsOneWidget);
  });

  testWidgets('switching the environment registers the mocks again', (
    tester,
  ) async {
    await pumpExample(tester);

    await tester.tap(find.byTooltip('Environment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('staging').last);
    await tester.pumpAndSettle();

    expect(deceiver.baseUrl, Environment.staging.apiUrl);
    final users = await send(tester, 'List users');
    expect(textIn(users, 'Test user'), findsOneWidget);
  });
}
