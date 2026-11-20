# Testing with Deceiver

In Dart test code, use the `Deceiver` directly. It runs in the same process
as the code under test, so there's no VM service, no string parameters and
no waiting for events. Use the VM service route (SKILL.md) only when the
test drives the app from outside: an agent, Maestro, Patrol's native
automation, or a person.

## Unit tests

Give the code under test a Deceiver client instead of a real one:

```dart
late Deceiver deceiver;
late UserRepository repository;

setUp(() {
  deceiver = Deceiver(options: const DeceiverOptions(onlyAllowMocks: true));
  repository = UserRepository(client: deceiver.client());
});

test('creates a user', () async {
  deceiver.on.post('/users', jsonResponse(body: {'id': 1}, statusCode: 201));

  await repository.createUser('Bilbo');

  final posts = deceiver.requests.where((r) => r.request.method == 'POST');
  expect(posts.single.request.body, contains('Bilbo'));
});

test('shows a server error', () async {
  deceiver.on.get('/users', errorResponse(500));

  expect(repository.getUsers(), throwsA(isA<ServerException>()));
});
```

Strict mode (`onlyAllowMocks: true`) makes an unexpected request fail with a
`DeceiverException` that lists the registered mocks, instead of reaching
the network. It extends `ClientException`, so code that handles network
errors handles it too; assert on it when that matters.

`deceiver.requests` has each handled request with the `mock` that answered
(or `null`), its `response`, `duration`, `timestamp` and `error`. Clear it
with `clearRequests()`, or everything with `reset()` (for example in
`tearDown`).

## Widget tests

Same as unit tests: inject `deceiver.client()` where the widget gets its
HTTP client. Async builders with `Future.delayed` use fake time in
`testWidgets`: advance it with `tester.pump(duration)`, or avoid delays in
widget tests.

## Integration tests (integration_test)

The test runs inside the app, so it can reach the app's Deceiver. Make it
reachable: a global, a getter on the app's dependency container, or a
parameter of the app's `main`/bootstrap function.

```dart
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;
import 'package:my_app/mocks.dart' show deceiver;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    deceiver.deactivateScenario();
    deceiver.setAllMocksEnabled(true);
    deceiver.clearRequests();
  });

  testWidgets('shows an error when loading users fails', (tester) async {
    deceiver.activateScenario('error');
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(
      deceiver.requests.map((r) => r.mock?.description),
      contains('GET /users'),
    );
  });
}
```

Reset the state in `setUp` (or `reset()` and register again): the Deceiver
is shared between tests in the same run, including sequence positions of
`sequentialResponse`.

When the app's Deceiver only exists in debug mode (`kDebugMode`), run
integration tests in debug mode, which `flutter test integration_test` does.

## Choosing mocks for a test

- Prefer scenarios the app already has; they're what testers use too.
- Add a scenario in the app's mocks when a state is useful beyond one test
  (see setup-and-mocks.md). Register one-off mocks in the test itself.
- To check that the app doesn't call an endpoint, look for its absence in
  `deceiver.requests`, with strict mode on so it can't silently pass through.
