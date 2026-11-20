<img src="https://raw.githubusercontent.com/DutchCodingCompany/deceiver/main/assets/deceiver_icon.svg" width="120" alt="Deceiver icon">

# deceiver

Configure and provide fake HTTP responses for Dart's
[`package:http`](https://pub.dev/packages/http) Client. Intercept requests
with path templates, toggle mocks at runtime, and passthrough unmatched calls
to the real HTTP client.

Inspired by [Charlatan](https://github.com/Betterment/charlatan) (for Dio),
Deceiver brings the same ergonomic fake-response pattern to `package:http`.

## Features

- Register fake responses by HTTP method and path template
- Response helpers for JSON, errors, and empty responses
- Sequential responses -- cycle through different responses on each call
- Random responses -- pick a response at random from a list
- Named scenarios -- define preset mock configurations and switch at runtime
- Passthrough unmatched requests to the real HTTP client
- Toggle all mocks on/off at runtime with a global switch
- Toggle individual mocks on/off without removing them
- Path parameters -- read `{id}` values in response builders
- Base URL and `on.at()` -- only mock requests to your own APIs, in every
  environment
- Request history -- check which requests were made, for example in tests
- DevTools extension -- toggle mocks and see the handled requests in Dart
  DevTools while the app runs
- Custom request matchers for advanced matching logic
- Async response builders for simulating delays or conditional logic
- Descriptive error messages when strict mode is enabled
- Drop-in replacement for `package:http` `Client`

## Installation

Deceiver needs Dart 3.13 or later (Flutter 3.47 or later).

If you only use Deceiver in tests, add it as a dev dependency:

```sh
dart pub add dev:deceiver
```

If your app uses it at runtime, for example to run against fake responses
in a debug build, add it as a regular dependency, because code in `lib/`
cannot import dev dependencies:

```sh
dart pub add deceiver
```

Make sure the mocks never end up active in a release build. In a Flutter
app you can, for example, only use the `DeceiverClient` in debug mode:

```dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

final Client httpClient = kDebugMode ? deceiver.client() : Client();
```

## Quick Start

```dart
import 'package:deceiver/deceiver.dart';

void main() async {
  final deceiver = Deceiver();

  // Register mock responses
  deceiver.on.get('/users', jsonResponse(body: [{'name': 'Bilbo'}]));
  deceiver.on.post('/users', jsonResponse(body: {'id': 1}, statusCode: 201));
  deceiver.on.delete('/users/{id}', emptyResponse());

  // Create a client and make requests
  final client = deceiver.client();

  final users = await client.get(Uri.parse('https://api.example.com/users'));
  print(users.body); // [{"name":"Bilbo"}]

  final created = await client.post(Uri.parse('https://api.example.com/users'));
  print(created.statusCode); // 201

  final deleted = await client.delete(Uri.parse('https://api.example.com/users/42'));
  print(deleted.statusCode); // 204

  client.close();
}
```

## Usage

### Registering fake responses

Use `deceiver.on.<method>(path, responseBuilder)` to register mocks for
each HTTP method:

```dart
final deceiver = Deceiver();

deceiver.on.get('/users', (req) => Response('[]', 200));
deceiver.on.post('/users', (req) => Response('{"id": 1}', 201));
deceiver.on.put('/users/{id}', (req) => Response('{"name": "updated"}', 200));
deceiver.on.delete('/users/{id}', (req) => Response('', 204));
deceiver.on.patch('/users/{id}', (req) => Response('{"name": "patched"}', 200));
deceiver.on.head('/users', (req) => Response('', 200));
```

A `{name}` placeholder matches exactly one path segment; every other
segment must match literally. A template like `/users/{id}` matches
`/users/42` and `/users/john@doe.com`, but **not** `/users/42/posts` or
`/users/`. Values are compared after percent-decoding, so encoded paths
such as `/users/Jos%C3%A9` match too.

Only the path is compared: the host, scheme and query of the request are
ignored. To match on the query, headers or body, use a
[custom matcher](#custom-matchers). Templates with a query, a fragment or
a placeholder that is not a whole segment (such as `{+path}`, `{?q}` or
`user-{id}`) throw an `ArgumentError` when you register them.

### Base URL

Pass a `baseUrl` to only handle requests to your own API. Mock paths are
then relative to the path of the base URL:

```dart
final deceiver = Deceiver(baseUrl: Uri.parse('https://api.example.com/v1'));
deceiver.on.get('/users', jsonResponse(body: [])); // GET /v1/users
```

Requests to another scheme, host or port, or outside the base path, always
go to the real HTTP client, even in strict mode, and are not recorded.
Without a `baseUrl`, mocks match requests to any host.

### Multiple APIs and environments

Use `on.at(url)` for an API other than the `baseUrl`, and a full URL as path
for an API with a fixed URL, such as a third-party service:

```dart
final deceiver = Deceiver(baseUrl: env.apiUrl);

deceiver.on.get('/users', ...);                     // your main API
deceiver.on.at(env.authUrl).post('/token', ...);    // a second API
deceiver.on.get('https://maps.example.com/geocode/{query}', ...); // fixed URL

deceiver.scenario('expired', (on) {
  on.at(env.authUrl).post('/token', errorResponse(401));
});
```

Requests to these URLs are handled by Deceiver as well: they count for
strict mode and are recorded. Each mock only matches requests to its own
API, so `/users` above doesn't match `https://auth.example.com/users`.

Apps often have different URLs for development, acceptance and production.
Don't hardcode those in the mocks: take them from the app's environment
configuration, and put the registration in a function that receives that
configuration:

```dart
void registerMocks(Deceiver deceiver, Env env) {
  deceiver.on.get('/users', ...);
  deceiver.on.at(env.authUrl).post('/token', ...);
}

final deceiver = Deceiver(baseUrl: env.apiUrl);
registerMocks(deceiver, env);
```

If the app can switch environments while it runs, reset Deceiver with the
new base URL and register the mocks again. Clients keep working:

```dart
void onEnvironmentChanged(Env env) {
  final scenario = deceiver.activeScenario;

  deceiver.reset(baseUrl: env.apiUrl);
  registerMocks(deceiver, env);

  // Optional: keep the active scenario.
  if (scenario != null && deceiver.scenarios.contains(scenario)) {
    deceiver.activateScenario(scenario);
  }
}
```

### Response helpers

For common response patterns, use the built-in helpers instead of
constructing `Response` objects manually:

```dart
// JSON response with automatic content-type header and encoding
deceiver.on.get('/users', jsonResponse(body: [{'name': 'Bilbo'}]));
deceiver.on.post('/users', jsonResponse(body: {'id': 1}, statusCode: 201));

// Error response with optional JSON message body
deceiver.on.get('/secret', errorResponse(403, message: 'Forbidden'));
deceiver.on.get('/missing', errorResponse(404));

// Empty response (defaults to 204 No Content)
deceiver.on.delete('/users/{id}', emptyResponse());
deceiver.on.post('/reset', emptyResponse(statusCode: 202));
```

All helpers accept an optional `headers` parameter for custom headers:

```dart
deceiver.on.get('/users', jsonResponse(
  body: [],
  headers: {'x-request-id': 'abc-123'},
));
```

### Dynamic responses

Response builders receive the full `Request` object, so you can build
responses based on the request body, headers, URL, or query parameters:

```dart
deceiver.on.post('/users', (req) {
  final body = req.body;
  if (body.isEmpty) {
    return Response('{"error": "name is required"}', 422);
  }
  return Response('{"id": 1, "name": "Bilbo"}', 201);
});
```

This also works for `MultipartRequest` and `StreamedRequest`: Deceiver reads
their body into memory first, so `req.body` and `req.bodyBytes` are
available in matchers and response builders.

### Path parameters

Read the values of `{name}` placeholders with `req.pathParameters`. Values
are percent-decoded:

```dart
deceiver.on.get('/users/{id}', (req) {
  final id = req.pathParameters['id']; // '42' for GET /users/42
  return Response('{"id": "$id"}', 200);
});
```

`pathParameters` is empty for mocks registered with `on.match()`.

### Custom matchers

When the built-in method + path matching is not enough, use `on.match()`
with an arbitrary predicate:

```dart
deceiver.on.match(
  (req) => req.method == 'GET' && req.url.queryParameters['q'] == 'dart',
  (req) => Response('{"results": ["dart"]}', 200),
  description: 'GET search?q=dart',
);
```

The `description` parameter is used in debug output and error messages.

### Async response builders

Response builders support `FutureOr<Response>`, so you can simulate
network delays or perform async work:

```dart
deceiver.on.get('/slow', (req) async {
  await Future.delayed(Duration(milliseconds: 500));
  return Response('{"status": "done"}', 200);
});
```

### Sequential responses

Return different responses on each successive call to the same endpoint.
After the last response, it cycles back to the first:

```dart
deceiver.on.get('/status', sequentialResponse([
  jsonResponse(body: {'status': 'loading'}),  // 1st call
  jsonResponse(body: {'status': 'ready'}),    // 2nd call
  errorResponse(500, message: 'Crash'),       // 3rd call
  // 4th call returns 'loading' again, and so on
]));
```

### Random responses

Pick a random response from a list on each call. Useful for simulating
flaky services:

```dart
deceiver.on.get('/flaky', randomResponse([
  jsonResponse(body: {'status': 'ok'}),
  errorResponse(503, message: 'Try again'),
  errorResponse(429, message: 'Rate limited'),
]));
```

For deterministic testing, pass a seeded `Random`:

```dart
import 'dart:math';

deceiver.on.get('/det', randomResponse(
  [jsonResponse(body: 'a'), jsonResponse(body: 'b')],
  random: Random(42),
));
```

### Named scenarios

Define preset mock configurations and switch between them at runtime.
Scenario mocks layer on top of base mocks -- they override matching
endpoints while unmatched endpoints fall through to the base mocks:

```dart
// Base mocks (always active)
deceiver.on.get('/users', jsonResponse(body: [{'name': 'Bilbo'}]));
deceiver.on.get('/posts', jsonResponse(body: []));

// Define scenarios
deceiver.scenario('happy', (on) {
  on.get('/users', jsonResponse(body: [
    {'name': 'Bilbo'},
    {'name': 'Frodo'},
    {'name': 'Samwise'},
  ]));
});

deceiver.scenario('error', (on) {
  on.get('/users', errorResponse(500, message: 'Server error'));
});

// Activate a scenario -- overrides base /users mock, /posts still uses base
deceiver.activateScenario('happy');

// Switch scenarios
deceiver.activateScenario('error');

// Deactivate -- back to base mocks only
deceiver.deactivateScenario();

// List available scenarios
print(deceiver.scenarios); // ['happy', 'error']
print(deceiver.activeScenario); // null or 'happy' or 'error'
```

### Passthrough for unmatched requests

By default, requests that don't match any registered mock are forwarded
to the real HTTP client:

```dart
final deceiver = Deceiver(); // onlyAllowMocks defaults to false
deceiver.on.get('/mocked', jsonResponse(body: {'mocked': true}));

final client = deceiver.client();

// This returns the mock response
await client.get(Uri.parse('https://api.example.com/mocked'));

// This goes to the real server
await client.get(Uri.parse('https://api.example.com/real-endpoint'));
```

You can also provide your own `Client` as the underlying real client:

```dart
final realClient = MyCustomHttpClient();
final client = deceiver.client(realClient);
```

### Strict mode (only allow mocks)

Set `onlyAllowMocks: true` to throw a `DeceiverException` when a request
doesn't match any mock. This is useful in tests to catch unexpected HTTP
calls. `DeceiverException` extends `ClientException` from `package:http`, so
code that already handles network errors handles it too:

```dart
final deceiver = Deceiver(
  options: DeceiverOptions(onlyAllowMocks: true),
);
deceiver.on.get('/users', jsonResponse(body: []));

final client = deceiver.client();

// This works fine
await client.get(Uri.parse('https://api.example.com/users'));

// This throws a DeceiverException with a helpful message:
//
//   DeceiverException: no matching mock found for:
//
//     GET https://api.example.com/unknown
//
//   Registered mocks:
//   Base mocks:
//     GET /users (enabled)
//
await client.get(Uri.parse('https://api.example.com/unknown'));
```

The query string is left out of the message, because it may contain
secrets such as access tokens.

Strict mode only applies while mocks are enabled. With
`deceiver.enabled = false`, every request goes to the real HTTP client.

### Runtime enable/disable

#### Global toggle

Disable all mocks at once. When disabled, every request goes to the
real HTTP client:

```dart
final deceiver = Deceiver();
deceiver.on.get('/users', jsonResponse(body: []));

final client = deceiver.client();

// Mocked response
await client.get(Uri.parse('https://api.example.com/users'));

// Disable all mocks -- requests go to the real client
deceiver.enabled = false;
await client.get(Uri.parse('https://api.example.com/users')); // real request

// Re-enable mocks
deceiver.enabled = true;
await client.get(Uri.parse('https://api.example.com/users')); // mocked again
```

#### Per-mock toggle

Disable individual mocks without removing them:

```dart
final deceiver = Deceiver();
deceiver.on.get('/users', jsonResponse(body: []));
deceiver.on.get('/posts', jsonResponse(body: []));

// Disable just the /users mock
deceiver.registrations.first.isEnabled = false;

final client = deceiver.client();

// /users goes to real client, /posts still returns the mock
await client.get(Uri.parse('https://api.example.com/users')); // real
await client.get(Uri.parse('https://api.example.com/posts')); // mocked
```

Turn every mock on or off at once, base and scenario mocks alike, with
`deceiver.setAllMocksEnabled(false)`. Then turn on only the ones you need.

### Recorded requests

`deceiver.requests` lists the requests Deceiver handled, in the order they
were answered. Each entry has the mock that answered it (`null` if no mock
matched), the `response` of the mock with its `duration`, the `timestamp`,
and the `error` when strict mode rejected the request or the mock threw.
Responses of the real HTTP client are not recorded. Use it to check which
requests your code made:

```dart
await userRepository.createUser('Bilbo');

final posts = deceiver.requests.where(
  (r) => r.request.method == 'POST' && r.request.url.path == '/users',
);
expect(posts, hasLength(1));
expect(posts.single.request.body, contains('Bilbo'));
```

Deceiver keeps the last 100 requests. Change that with
`DeceiverOptions(maxRecordedRequests: ...)`, or use `0` to record nothing.
Requests sent while `enabled` is `false` are not recorded. Call
`deceiver.clearRequests()` to empty the list; requests that are still being
answered at that moment are not recorded either.

### Resetting

`deceiver.reset()` removes all mocks, scenarios and recorded requests, for
example between tests. Options, `enabled` and existing clients keep working.
Pass `baseUrl` to change the base URL at the same time, see
[Multiple APIs and environments](#multiple-apis-and-environments):

```dart
tearDown(deceiver.reset);
```

### DevTools

Deceiver comes with a [Dart DevTools](https://docs.flutter.dev/tools/devtools)
extension. Open DevTools for an app that runs in debug or profile mode and
uses Deceiver, and open the **deceiver** tab (enable it in DevTools'
extensions menu the first time). There you can:

- turn all mocks on or off, and switch strict mode
- activate a scenario
- turn individual mocks on or off, including scenario mocks, and see what
  each mock responds (status code, headers and body)
- turn all mocks off at once ("Disable all"), to then turn on only the one
  you need
- see the handled requests live: which mock answered, the status code,
  duration, and request and response body

Requests without a mock show as passthrough; their real response is in
DevTools' Network tab. Mocked responses don't show up in the Network tab.

No setup is needed: every `Deceiver` shows up in DevTools by itself. With
more than one, give them a `name` to tell them apart:

```dart
final deceiver = Deceiver(name: 'Auth API');
```

Changes made in DevTools also show up in the `deceiver_flutter` panel, and
the other way around. Listen to changes yourself with
`deceiver.addListener()`.

### Controlling Deceiver from tools and AI agents

The DevTools extension talks to the app through `ext.deceiver.*` VM service
extensions. Anything that is connected to the VM service of a running app
can call them, without DevTools: test tools, scripts, or an AI agent with
the [Dart MCP server](https://dart.dev/tools/mcp-server) (its
`vm_service` tool, command `callMethod`). Like DevTools, this only works in
debug and profile builds.

Call `ext.deceiver.help` to get the list below from the app itself. All
parameters are strings. Every method except `help` and `getInstances` takes
`instance`, the id from `getInstances`; leave it out when the app has one
Deceiver.

| Method | Parameters | Does |
|---|---|---|
| `ext.deceiver.help` | | Lists the methods, parameters and events. |
| `ext.deceiver.getInstances` | | The Deceivers in the app: `id` and `name`. |
| `ext.deceiver.getState` | | Settings, base mocks and scenarios. Each mock has `id`, `description`, `enabled` and `response` (what it responds). |
| `ext.deceiver.setEnabled` | `enabled` | Turns all mocking on or off. |
| `ext.deceiver.setOnlyAllowMocks` | `enabled` | Strict mode. |
| `ext.deceiver.setActiveScenario` | `scenario` (leave out to deactivate) | Activates a scenario. |
| `ext.deceiver.setMockEnabled` | `enabled`, and `mock` (id) or `description` with optional `scenario` | Turns one mock on or off. |
| `ext.deceiver.setAllMocksEnabled` | `enabled` | Turns every mock on or off. |
| `ext.deceiver.getRequests` | | The handled requests: `method`, `url`, headers, bodies, `mock` (null: no mock), `statusCode`, `durationMicros`, `error`. |
| `ext.deceiver.clearRequests` | | Removes the recorded requests. |

The setters return the new state, like `getState`. Invalid parameters give
an error (code -32602) that says what to pass, for example the mocks that
exist when a description doesn't match.

The app also posts events on the `Extension` stream:
`deceiver:instancesChanged`, `deceiver:changed`, `deceiver:request` and
`deceiver:requestsCleared`.

For example, to only let `GET /users` fail with the `error` scenario and
check that the app called it:

```text
ext.deceiver.setAllMocksEnabled  {enabled: "false"}
ext.deceiver.setActiveScenario   {scenario: "error"}
ext.deceiver.setMockEnabled      {description: "GET /users", scenario: "error", enabled: "true"}
... use the app ...
ext.deceiver.getRequests         → requests[].mock.description == "GET /users", statusCode 500
```

These methods and their parameters stay compatible within a minor version.

For AI agents there is a skill that explains all of this, from setting up
Deceiver to testing with it:
[skills/deceiver](https://github.com/DutchCodingCompany/deceiver/tree/main/skills/deceiver).
Copy that folder into the skills folder of your agent, for example
`.claude/skills/` or `.agents/skills/` in your project.

### Inspecting mocks

`mock.responseInfo` tells what a mock responds, as far as known when it was
registered. The response helpers describe their status code, headers and
body; `sequentialResponse()` and `randomResponse()` list their `variants`.
Response builders of your own are `DeceiverResponseKind.custom`. The panel
of `deceiver_flutter` and the DevTools extension use it to show each mock:

```dart
deceiver.on.get('/users', jsonResponse(body: [{'name': 'Bilbo'}]));

final info = deceiver.registrations.single.responseInfo;
print(info.summary); // 200 · JSON · 1 item
print(info.body); // [{"name":"Bilbo"}]
```

### Debugging

List all registered mocks and their status:

```dart
final deceiver = Deceiver();
deceiver.on.get('/users', jsonResponse(body: []));
deceiver.on.post('/users', jsonResponse(body: {}, statusCode: 201));
deceiver.on.delete('/users/{id}', emptyResponse());

print(deceiver.toPrettyPrintedString());
// Output:
// Base mocks:
//   GET /users (enabled)
//   POST /users (enabled)
//   DELETE /users/{id} (enabled)
```

Access the registrations list programmatically:

```dart
for (final reg in deceiver.registrations) {
  print('${reg.description} - enabled: ${reg.isEnabled}');
}
```

## API Reference

| Class / Function | Description |
|---|---|
| `Deceiver` | Core orchestrator. Manages mock registrations and creates clients. |
| `DeceiverOptions` | Configuration: `onlyAllowMocks` controls strict mode, `maxRecordedRequests` the request history. |
| `DeceiverBuilder` | Fluent API accessed via `deceiver.on` for registering mocks. |
| `DeceiverClient` | The `package:http` client returned by `deceiver.client()`. |
| `DeceiverException` | Thrown in strict mode for unmatched requests. Extends `ClientException`. |
| `DeceiverRecordedRequest` | An entry of `deceiver.requests`: the request, the mock that answered it and its response. |
| `request.pathParameters` | Extension on `Request` with the values of the path placeholders. |
| `DeceiverData` | A single mock registration with matcher, builder, `responseInfo`, and `isEnabled` flag. |
| `DeceiverResponseInfo` | What a mock responds: `kind`, `statusCode`, `headers`, `body`, `variants` and a one-line `summary`. |
| `DeceiverResponseBuilder` | Typedef: `FutureOr<Response> Function(Request)` |
| `DeceiverRequestMatcher` | Typedef: `bool Function(Request)` |
| `jsonResponse()` | Helper: builds a JSON response with `content-type: application/json`. |
| `errorResponse()` | Helper: builds an error response with optional JSON message body. |
| `emptyResponse()` | Helper: builds an empty response (defaults to 204). |
| `sequentialResponse()` | Helper: cycles through a list of response builders on each call. |
| `randomResponse()` | Helper: picks a random response builder from a list on each call. |
| `matchAll()` | Composes multiple matchers with AND logic. |
| `matchMethod()` | Matches requests by HTTP method. |
| `matchPath()` | Matches requests by path template. |

## Contributing

Contributions are welcome. Please open an issue first to discuss the
change you'd like to make.

Before submitting a PR:

1. Run `dart format .` to format the code
2. Run `dart analyze` to check for issues
3. Run `dart test` to ensure all tests pass
