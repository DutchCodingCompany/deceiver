# Setting up Deceiver and writing mocks

Check the versions in the project's `pubspec.yaml` first. This describes
deceiver 0.5. When something here doesn't exist in the project's version,
read the package's README in the pub cache (Dart MCP: `read_package_uris`
with `package-root:deceiver/README.md`).

## In an app

Code in `lib/` can't import dev dependencies, so a Flutter app that mocks at
runtime adds both as regular dependencies:

```sh
flutter pub add deceiver deceiver_flutter
```

Only tests: `dart pub add dev:deceiver`.

Keep the mocks out of release builds by only using the Deceiver client in
debug mode:

```dart
import 'package:deceiver/deceiver.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

final deceiver = Deceiver(
  baseUrl: Uri.parse('https://api.example.com/v1'),
  name: 'Example API', // shown in DevTools, helps with several Deceivers
);

final Client httpClient = kDebugMode ? deceiver.client() : Client();
```

Pass that client to the code that makes requests (repositories, API
clients). Code that creates its own `Client()` bypasses Deceiver; find those
places when a request is never mocked. `deceiver.client(realClient)` wraps
an existing client (for example one with auth headers) for passthrough.

## Registering mocks

Paths are relative to `baseUrl` and use `{name}` placeholders for exactly one
path segment. The query string is not part of the template.

```dart
deceiver.on.get('/users', jsonResponse(body: [{'id': 1, 'name': 'Bilbo'}]));
deceiver.on.post('/users', jsonResponse(body: {'id': 2}, statusCode: 201));
deceiver.on.delete('/users/{id}', emptyResponse()); // 204
deceiver.on.get('/secret', errorResponse(403, message: 'Forbidden'));
// {"error":"Forbidden"}
```

Also `put`, `patch`, `head`. Prefer the helpers (`jsonResponse`,
`errorResponse`, `emptyResponse`, `sequentialResponse`, `randomResponse`):
the panel, DevTools and `getState` can show what they respond. A builder of
your own shows as `custom response`.

### Responses that depend on the request

A response builder is `FutureOr<Response> Function(Request)`:

```dart
deceiver.on.get('/users/{id}', (request) {
  final id = request.pathParameters['id']!; // percent-decoded
  final user = users[id];
  if (user == null) return errorResponse(404, message: 'Not found')(request);
  return jsonResponse(body: user)(request);
});

deceiver.on.post('/users', (request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return jsonResponse(body: {'id': 3, ...body}, statusCode: 201)(request);
});

// Slow response, to see loading states.
deceiver.on.get('/reports', (request) async {
  await Future<void>.delayed(const Duration(seconds: 2));
  return jsonResponse(body: [])(request);
});
```

### Changing responses

```dart
// 1st call, 2nd call, 3rd call, then from the start again.
deceiver.on.get('/status', sequentialResponse([
  jsonResponse(body: {'status': 'loading'}),
  jsonResponse(body: {'status': 'ready'}),
  errorResponse(500),
]));

// A random one each call; pass random: Random(seed) in tests.
deceiver.on.get('/flaky', randomResponse([jsonResponse(), errorResponse(503)]));
```

### Custom matchers

For anything a method and path can't express, like query parameters or
headers. Give it a description; it's how the mock shows up everywhere.

```dart
deceiver.on.match(
  (req) => req.method == 'GET' && req.url.queryParameters['q'] == 'dart',
  jsonResponse(body: {'results': []}),
  description: 'GET /search?q=dart',
);
```

### Other APIs

```dart
deceiver.on.at(Uri.parse('https://auth.example.com')).post('/token', jsonResponse(body: {'token': 'abc'}));
deceiver.on.get('https://maps.example.com/geocode', jsonResponse(body: {})); // fixed URL
```

Requests to these URLs are handled (and recorded, and strict) even though
they're outside `baseUrl`.

## Scenarios

A scenario is a named set of mocks that override the base mocks while it's
active. Register mocks for the endpoints that differ only; the rest falls
through to the base mocks.

```dart
deceiver.scenario('empty', (on) {
  on.get('/users', jsonResponse(body: []));
});
deceiver.scenario('error', (on) {
  on.get('/users', errorResponse(500, message: 'Server error'));
  on.at(authUrl).post('/token', errorResponse(401));
});

deceiver.activateScenario('error');
deceiver.deactivateScenario();
```

Good scenario names describe the app state a tester wants ("empty",
"error", "slow network", "logged out"), because that's what people pick in
the panel and DevTools.

## Runtime switches

```dart
deceiver.enabled = false; // everything to the real server
deceiver.options = deceiver.options.copyWith(onlyAllowMocks: true); // strict
deceiver.registrations.first.isEnabled = false; // one mock
deceiver.setAllMocksEnabled(false); // every mock, base and scenarios
```

## Switching environments

```dart
deceiver.reset(baseUrl: env.apiUrl); // removes mocks, scenarios, requests
registerMocks(deceiver, env);
```

Existing clients keep working. Keep the registrations in one function so
they can be registered again.

## The panel (deceiver_flutter)

```dart
final controller = DeceiverController(deceiver);

// For example in a debug drawer:
endDrawer: kDebugMode
    ? Drawer(child: SafeArea(child: DeceiverPanel(controller: controller)))
    : null,
```

The panel has the global switches, "Disable all", the scenarios, and every
mock with what it responds; tap a mock for its details. Changes made in code
or in DevTools show up in the panel. Without a panel, the DevTools
"deceiver" tab and the VM service methods do the same.

## Debugging

```dart
print(deceiver.toPrettyPrintedString()); // all mocks and their status
for (final mock in deceiver.registrations) {
  print('${mock.description}: ${mock.responseInfo.summary}');
}
```
