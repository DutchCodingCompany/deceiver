import 'package:deceiver/deceiver.dart';
import 'package:deceiver_flutter/deceiver_flutter.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('DeceiverController', () {
    late Deceiver deceiver;
    late DeceiverController controller;

    setUp(() {
      deceiver = Deceiver();
      deceiver.on.get('/users', (req) => Response('', 200));
      deceiver.on.post('/users', (req) => Response('', 201));
      controller = DeceiverController(deceiver);
    });

    test('enabled proxies to deceiver', () {
      expect(controller.enabled, isTrue);

      controller.enabled = false;
      expect(deceiver.enabled, isFalse);

      controller.enabled = true;
      expect(deceiver.enabled, isTrue);
    });

    test('onlyAllowMocks proxies to deceiver options', () {
      expect(controller.onlyAllowMocks, isFalse);

      controller.onlyAllowMocks = true;
      expect(deceiver.options.onlyAllowMocks, isTrue);

      controller.onlyAllowMocks = false;
      expect(deceiver.options.onlyAllowMocks, isFalse);
    });

    test('registrations returns mock list', () {
      expect(controller.registrations, hasLength(2));
      expect(controller.registrations[0].description, 'GET /users');
      expect(controller.registrations[1].description, 'POST /users');
    });

    test('toggleMock updates isEnabled on the given mock', () {
      final mock = controller.registrations[0];
      expect(mock.isEnabled, isTrue);

      controller.toggleMock(mock, enabled: false);
      expect(deceiver.registrations[0].isEnabled, isFalse);
      expect(deceiver.registrations[1].isEnabled, isTrue);

      controller.toggleMock(mock, enabled: true);
      expect(deceiver.registrations[0].isEnabled, isTrue);
    });

    test('notifies listeners on enabled change', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.enabled = false;
      expect(notified, isTrue);
    });

    test('does not notify when value is unchanged', () {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.enabled = true; // already true
      controller.onlyAllowMocks = false; // already false
      controller.toggleMock(
        controller.registrations[0],
        enabled: true,
      ); // already true
      expect(notifyCount, 0);
    });

    test('notifies listeners on onlyAllowMocks change', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.onlyAllowMocks = true;
      expect(notified, isTrue);
    });

    test('notifies listeners on toggleMock', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.toggleMock(controller.registrations[0], enabled: false);
      expect(notified, isTrue);
    });
  });

  group('DeceiverPanel', () {
    late Deceiver deceiver;
    late DeceiverController controller;

    setUp(() {
      deceiver = Deceiver();
      deceiver.on.get('/users', (req) => Response('', 200));
      deceiver.on.post('/users/{id}', (req) => Response('', 200));
      deceiver.on.delete('/posts', (req) => Response('', 204));
      controller = DeceiverController(deceiver);
    });

    Widget buildPanel() {
      return MaterialApp(
        home: Scaffold(body: DeceiverPanel(controller: controller)),
      );
    }

    Finder switchFor(String title) =>
        find.widgetWithText(SwitchListTile, title);

    testWidgets('renders global settings section', (tester) async {
      await tester.pumpWidget(buildPanel());

      expect(find.text('Global Settings'), findsOneWidget);
      expect(find.text('Mocks enabled'), findsOneWidget);
      expect(find.text('Only allow mocks'), findsOneWidget);
    });

    testWidgets('renders base mocks section with count', (tester) async {
      await tester.pumpWidget(buildPanel());

      expect(find.text('Base Mocks'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // mock count
    });

    testWidgets('renders all mock descriptions', (tester) async {
      await tester.pumpWidget(buildPanel());

      expect(find.text('GET /users'), findsOneWidget);
      expect(find.text('POST /users/{id}'), findsOneWidget);
      expect(find.text('DELETE /posts'), findsOneWidget);
    });

    testWidgets('shows empty state when no mocks registered', (tester) async {
      final emptyDeceiver = Deceiver();
      final emptyController = DeceiverController(emptyDeceiver);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeceiverPanel(controller: emptyController)),
        ),
      );

      expect(find.text('No mocks registered.'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // count
    });

    testWidgets('toggling global enabled switch updates controller', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel());
      expect(controller.enabled, isTrue);

      await tester.tap(switchFor('Mocks enabled'));
      await tester.pump();

      expect(controller.enabled, isFalse);
    });

    testWidgets('toggling onlyAllowMocks switch updates controller', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel());
      expect(controller.onlyAllowMocks, isFalse);

      await tester.tap(switchFor('Only allow mocks'));
      await tester.pump();

      expect(controller.onlyAllowMocks, isTrue);
    });

    testWidgets('toggling a mock switch updates its isEnabled', (tester) async {
      await tester.pumpWidget(buildPanel());
      expect(controller.registrations[0].isEnabled, isTrue);

      await tester.tap(switchFor('GET /users'));
      await tester.pump();

      expect(controller.registrations[0].isEnabled, isFalse);
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('panel rebuilds when controller notifies', (tester) async {
      await tester.pumpWidget(buildPanel());

      // All three mocks should show "Enabled" subtitles.
      expect(find.text('Enabled'), findsNWidgets(3));

      // Programmatically disable first mock.
      controller.toggleMock(controller.registrations[0], enabled: false);
      await tester.pump();

      expect(find.text('Enabled'), findsNWidgets(2));
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('disabled mock shows cancel icon', (tester) async {
      controller.toggleMock(controller.registrations[0], enabled: false);
      await tester.pumpWidget(buildPanel());

      // Should have 2 check icons and 1 cancel icon.
      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('works in an app that uses package:flutter/material.dart', (
      tester,
    ) async {
      await tester.pumpWidget(
        legacy.MaterialApp(
          home: legacy.Scaffold(body: DeceiverPanel(controller: controller)),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('GET /users'), findsOneWidget);

      await tester.tap(switchFor('GET /users'));
      await tester.pump();

      expect(controller.registrations[0].isEnabled, isFalse);
    });
  });

  group('DeceiverController scenarios', () {
    late Deceiver deceiver;
    late DeceiverController controller;

    setUp(() {
      deceiver = Deceiver();
      deceiver.on.get('/users', (req) => Response('', 200));
      deceiver.scenario('happy', (on) {
        on.get('/users', jsonResponse(body: 'happy'));
      });
      deceiver.scenario('error', (on) {
        on.get('/users', errorResponse(500));
      });
      controller = DeceiverController(deceiver);
    });

    test('scenarios returns the list of scenario names', () {
      expect(controller.scenarios, ['happy', 'error']);
    });

    test('activeScenario is null by default', () {
      expect(controller.activeScenario, isNull);
    });

    test('activateScenario sets the active scenario', () {
      controller.activateScenario('happy');
      expect(controller.activeScenario, 'happy');
      expect(deceiver.activeScenario, 'happy');
    });

    test('deactivateScenario clears the active scenario', () {
      controller.activateScenario('happy');
      controller.deactivateScenario();
      expect(controller.activeScenario, isNull);
    });

    test('activeScenarioRegistrations follows the active scenario', () {
      expect(controller.activeScenarioRegistrations, isEmpty);

      controller.activateScenario('error');
      expect(controller.activeScenarioRegistrations, hasLength(1));
      expect(
        controller.activeScenarioRegistrations.first,
        same(deceiver.scenarioRegistrations('error')!.first),
      );
    });

    test('toggleMock works for scenario mocks', () {
      controller.activateScenario('error');
      final mock = controller.activeScenarioRegistrations.first;

      controller.toggleMock(mock, enabled: false);

      expect(deceiver.scenarioRegistrations('error')!.first.isEnabled, isFalse);
      expect(deceiver.registrations.first.isEnabled, isTrue);
    });

    test('activateScenario notifies listeners', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.activateScenario('happy');
      expect(notified, isTrue);
    });

    test('deactivateScenario notifies listeners', () {
      controller.activateScenario('happy');

      var notified = false;
      controller.addListener(() => notified = true);

      controller.deactivateScenario();
      expect(notified, isTrue);
    });

    test('does not notify when activating already active scenario', () {
      controller.activateScenario('happy');

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.activateScenario('happy'); // same
      expect(notifyCount, 0);
    });

    test('does not notify when deactivating with no active scenario', () {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.deactivateScenario(); // already null
      expect(notifyCount, 0);
    });
  });

  group('DeceiverPanel scenarios', () {
    late Deceiver deceiver;
    late DeceiverController controller;

    setUp(() {
      deceiver = Deceiver();
      deceiver.on.get('/users', (req) => Response('', 200));
      deceiver.scenario('happy', (on) {
        on.get('/users', jsonResponse(body: 'happy'));
        on.get('/posts', jsonResponse(body: []));
      });
      deceiver.scenario('error', (on) {
        on.get('/users', errorResponse(500));
      });
      controller = DeceiverController(deceiver);
    });

    Widget buildPanel() {
      return MaterialApp(
        home: Scaffold(body: DeceiverPanel(controller: controller)),
      );
    }

    String? selectedScenario(WidgetTester tester) => tester
        .widget<RadioGroup<String?>>(find.byType(RadioGroup<String?>))
        .groupValue;

    testWidgets('renders scenario section with header and count', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel());

      expect(find.text('Scenarios'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // scenario count
    });

    testWidgets('renders "None (base only)" option and all scenarios', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel());

      expect(find.text('None (base only)'), findsOneWidget);
      expect(find.text('happy'), findsOneWidget);
      expect(find.text('error'), findsOneWidget);
      expect(find.byType(RadioListTile<String?>), findsNWidgets(3));
    });

    testWidgets('does not show scenario section when no scenarios defined', (
      tester,
    ) async {
      final noScenarios = Deceiver();
      noScenarios.on.get('/users', (req) => Response('', 200));
      final ctrl = DeceiverController(noScenarios);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeceiverPanel(controller: ctrl)),
        ),
      );

      expect(find.text('Scenarios'), findsNothing);
      expect(find.text('None (base only)'), findsNothing);
    });

    testWidgets('"None (base only)" is selected by default', (tester) async {
      await tester.pumpWidget(buildPanel());

      expect(selectedScenario(tester), isNull);
      expect(find.textContaining('Scenario Mocks'), findsNothing);
    });

    testWidgets('tapping a scenario activates it', (tester) async {
      await tester.pumpWidget(buildPanel());

      await tester.tap(find.text('happy'));
      await tester.pump();

      expect(controller.activeScenario, 'happy');
      expect(selectedScenario(tester), 'happy');
    });

    testWidgets('tapping the active scenario deactivates it', (tester) async {
      controller.activateScenario('happy');
      await tester.pumpWidget(buildPanel());

      await tester.tap(find.text('happy'));
      await tester.pump();

      expect(controller.activeScenario, isNull);
    });

    testWidgets('tapping "None" deactivates the current scenario', (
      tester,
    ) async {
      controller.activateScenario('error');
      await tester.pumpWidget(buildPanel());

      await tester.tap(find.text('None (base only)'));
      await tester.pump();

      expect(controller.activeScenario, isNull);
    });

    testWidgets('switching between scenarios updates selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel());

      await tester.tap(find.text('happy'));
      await tester.pump();
      expect(controller.activeScenario, 'happy');

      await tester.tap(find.text('error'));
      await tester.pump();
      expect(controller.activeScenario, 'error');

      await tester.tap(find.text('None (base only)'));
      await tester.pump();
      expect(controller.activeScenario, isNull);
    });

    testWidgets('shows the mocks of the active scenario', (tester) async {
      // Tall enough to show the scenario mocks and the base mocks at once.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      controller.activateScenario('happy');
      await tester.pumpWidget(buildPanel());

      expect(find.text('Scenario Mocks: happy'), findsOneWidget);
      expect(find.text('GET /posts'), findsOneWidget);
      // GET /users is both a scenario mock and a base mock.
      expect(find.text('GET /users'), findsNWidgets(2));
    });

    testWidgets('toggling a scenario mock only changes that mock', (
      tester,
    ) async {
      controller.activateScenario('happy');
      await tester.pumpWidget(buildPanel());

      await tester.tap(find.widgetWithText(SwitchListTile, 'GET /posts'));
      await tester.pump();

      expect(deceiver.scenarioRegistrations('happy')![1].isEnabled, isFalse);
      expect(deceiver.registrations.single.isEnabled, isTrue);
    });
  });
}
