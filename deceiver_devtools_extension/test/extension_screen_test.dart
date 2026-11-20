import 'package:devtools_app_shared/ui.dart';
import 'package:deceiver_devtools_extension/src/extension_controller.dart';
import 'package:deceiver_devtools_extension/src/extension_screen.dart';
// devtools_app_shared still builds on package:flutter/material.dart, so its
// theme and widgets don't work with package:material_ui.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_deceiver_service.dart';

void main() {
  late FakeDeceiverService service;
  late ExtensionController controller;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await controller.loadInstances();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExtensionScreen(controller: controller)),
      ),
    );
  }

  setUp(() {
    service = FakeDeceiverService();
    controller = ExtensionController(service);
  });

  testWidgets('explains what to do without a Deceiver', (tester) async {
    service.instances = [];

    await pumpScreen(tester);

    expect(find.textContaining('No Deceiver found'), findsOneWidget);
  });

  testWidgets('shows the settings, mocks and scenarios', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Mocks enabled'), findsOneWidget);
    expect(find.text('Only allow mocks'), findsOneWidget);
    expect(find.text('Base mocks'), findsOneWidget);
    expect(find.text('Scenario: error'), findsOneWidget);
    expect(find.text('200 · JSON · 1 item'), findsOneWidget);
    // The inactive scenario is collapsed.
    expect(find.text('GET /users'), findsOneWidget);
    expect(find.text('1 mocks, not active'), findsOneWidget);
  });

  testWidgets('lists the active scenario first and marks overridden mocks', (
    tester,
  ) async {
    service.state = {...fakeState(), 'activeScenario': 'error'};
    await pumpScreen(tester);

    final scenarioTop = tester.getTopLeft(
      find.text('Scenario: error (active)'),
    );
    final baseTop = tester.getTopLeft(find.text('Base mocks'));
    expect(scenarioTop.dy, lessThan(baseTop.dy));
    expect(find.text('sequence: 200 → 500'), findsOneWidget);
    expect(find.text('200 · JSON · 1 item · overridden'), findsOneWidget);
  });

  testWidgets('toggling the global switch calls the app', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(service.calls.last.$1, 'setEnabled');
    expect(controller.state?.enabled, isFalse);
  });

  testWidgets('the small switch toggles a mock', (tester) async {
    await pumpScreen(tester);
    final mockSwitch = find.byType(Switch).last;

    final switchBox = find.ancestor(
      of: mockSwitch,
      matching: find.byType(FittedBox),
    );
    expect(tester.getSize(switchBox).height, lessThan(24));

    await tester.tap(mockSwitch);
    await tester.pumpAndSettle();

    final (method, params) = service.calls.last;
    expect(method, 'setMockEnabled');
    expect(params, {'instance': '1', 'mock': '10', 'enabled': 'false'});
  });

  testWidgets('Disable all and Enable all toggle every mock', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Disable all'));
    await tester.pumpAndSettle();

    final (method, params) = service.calls.last;
    expect(method, 'setAllMocksEnabled');
    expect(params, {'instance': '1', 'enabled': 'false'});
    expect(controller.state!.allMocks.any((m) => m.enabled), isFalse);
    expect(find.text('Enable all'), findsOneWidget);

    await tester.tap(find.text('Enable all'));
    await tester.pumpAndSettle();

    expect(controller.state!.allMocks.every((m) => m.enabled), isTrue);
  });

  testWidgets('tapping a mock shows what it responds', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('GET /users'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.textContaining('Base mocks', findRichText: true), findsWidgets);
    expect(find.text('Response body'), findsOneWidget);
    expect(find.textContaining('"name": "Bilbo"'), findsOneWidget);
    expect(service.calls.last.$1, isNot('setMockEnabled'));
  });

  testWidgets('shows the variants of a sequence', (tester) async {
    service.state = {...fakeState(), 'activeScenario': 'error'};
    await pumpScreen(tester);

    await tester.tap(find.text('GET /users').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Call 1: 200 · empty', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Call 2: 500 · error', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shows requests and their details', (tester) async {
    service.requests = [fakeRequest(1), fakeRequest(2, mocked: false)];
    await pumpScreen(tester);

    expect(find.text('Requests (2)'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('Real'), findsOneWidget);
    expect(find.textContaining('No mock, passthrough'), findsOneWidget);

    await tester.tap(find.text('GET https://api.x.com/users/1'));
    await tester.pumpAndSettle();

    expect(find.text('Response body'), findsOneWidget);
    expect(find.textContaining('"name": "Bilbo"'), findsOneWidget);
  });

  testWidgets('shows a placeholder until a request is selected', (
    tester,
  ) async {
    service.requests = [fakeRequest(1)];
    await pumpScreen(tester);

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Select a request or mock'), findsOneWidget);

    await tester.tap(find.text('GET https://api.x.com/users/1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear selection'));
    await tester.pumpAndSettle();

    expect(find.text('Select a request or mock'), findsOneWidget);
  });

  testWidgets('the panes can be resized by dragging', (tester) async {
    await pumpScreen(tester);
    final splitPane = tester.widget<SplitPane>(find.byType(SplitPane));
    final mocksPane = find.byType(DevToolsAreaPane).first;
    final widthBefore = tester.getSize(mocksPane).width;

    await tester.drag(
      find.byKey(splitPane.dividerKey(0)),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(mocksPane).width, greaterThan(widthBefore + 90));
  });

  testWidgets('Clear removes the requests', (tester) async {
    service.requests = [fakeRequest(1)];
    await pumpScreen(tester);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('No requests yet'), findsOneWidget);
  });
}
