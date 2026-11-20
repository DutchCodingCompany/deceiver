## 0.5.0

- Dart DevTools extension: a "deceiver" tab to turn mocks on and off,
  switch strict mode and scenarios, and see the handled requests live,
  including the response of the mock. Works without setup for every
  `Deceiver` in an app that runs in debug or profile mode.
- `Deceiver(name: ...)` names an instance in DevTools.
- Tools and AI agents can control Deceiver in a running app through the
  same `ext.deceiver.*` VM service extensions as DevTools, for example with
  the Dart MCP server. `ext.deceiver.help` lists them, `instance` may be
  left out with one Deceiver, and `setMockEnabled` also takes a
  `description` (and `scenario`). Errors say what to pass. Documented in the
  README; there is also an agent skill in `skills/deceiver`.
- `deceiver.setAllMocksEnabled()` turns every mock on or off, base and
  scenario mocks alike, for example to then turn on only the one you need.
  The DevTools extension has a "Disable all" / "Enable all" button.
- `DeceiverData.responseInfo` tells what a mock responds: the status code,
  headers and body of `jsonResponse()`, `errorResponse()` and
  `emptyResponse()`, the variants of `sequentialResponse()` and
  `randomResponse()`, or `custom` for a builder of your own. The DevTools
  extension shows it for every mock.
- The example also covers path parameters, strict mode, base URLs and
  multiple APIs, recorded requests, `reset()`, listeners and `responseInfo`.
- `deceiver.addListener()` and `removeListener()`: get notified when
  `enabled`, `options`, the mocks, the scenarios, the active scenario or a
  mock's `isEnabled` change.
- `DeceiverRecordedRequest` has the `response` and `duration` of the mock,
  the `timestamp`, and the `error` of strict mode or of a mock that threw.
  Requests are recorded when the mock has answered, so `deceiver.requests`
  is in the order the requests were answered. Requests that are still being
  answered during `clearRequests()` or `reset()` are not recorded.

## 0.4.0

- `request.pathParameters` gives response builders the values of the
  `{name}` placeholders in the path, percent-decoded.
- `Deceiver(baseUrl: ...)` only handles requests to that scheme, host, port
  and path. Mock paths are relative to the base URL. Other requests always go
  to the real client, even in strict mode. Added `Deceiver.appliesTo()`.
- `deceiver.requests` records the handled requests together with the mock
  that answered them. Keeps the last 100 by default; change this with
  `DeceiverOptions.maxRecordedRequests`. Added `clearRequests()`.
- `on.at(url)` registers mocks for another API, also inside scenarios. A
  full URL as path (`on.get('https://maps.example.com/geocode')`) registers
  a mock for an API with a fixed URL. Requests to these URLs count for strict
  mode and are recorded. Added `DeceiverData.baseUrl`.
- `deceiver.reset()` removes all mocks, scenarios and recorded requests.
  `reset(baseUrl: ...)` also changes the base URL, for example when the app
  switches environments.
- A path that looks like a URL but isn't valid (`http:/x.com`) throws an
  `ArgumentError` instead of never matching.

## 0.3.0

### Breaking

- Requires Dart 3.13 or later (Flutter 3.47 or later).
- `matchPath()` (and so `on.get()`, `on.post()`, etc.) uses simple path
  templates instead of RFC 6570 URI templates. A `{name}` placeholder matches
  exactly one path segment. Templates with a query, a fragment or a
  placeholder that is not a whole segment (`{+path}`, `{?q}`, `user-{id}`)
  now throw an `ArgumentError` when registering.
- Strict mode (`onlyAllowMocks`) throws a `DeceiverException` instead of a
  `StateError`. `DeceiverException` extends `ClientException`, so code that
  handles network errors handles it too. The message leaves out the query
  string, because it may contain secrets.

### Fixes

- Path placeholders now match values with encoded or reserved characters,
  such as `/users/john@doe.com`, `/slots/2026-11-18T10:00` and
  `/search/new%20york`. These used to fall through to the real client.
- With `enabled = false`, requests go to the real client even when
  `onlyAllowMocks` is `true`. They used to throw.
- Matchers and response builders can read the body of `MultipartRequest` and
  `StreamedRequest`. It used to be empty.
- `DeceiverBuilder` and `DeceiverClient` are exported from
  `package:deceiver/deceiver.dart`.
- `sequentialResponse()` and `randomResponse()` copy the list of builders, so
  later changes to that list don't affect them.

### Other changes

- Added `DeceiverOptions.copyWith()`.
- Removed the dependency on `package:uri`.

## 0.2.0

- `sequentialResponse()` helper -- cycle through a list of response builders
  on each successive call, looping back to the start after the last one.
- `randomResponse()` helper -- pick a random response builder from a list
  on each call. Accepts an optional `Random` for deterministic testing.
- Named scenarios via `deceiver.scenario(name, configure)` -- define preset
  mock configurations and switch between them at runtime.
- Scenario mocks layer on top of base mocks, overriding matching endpoints
  while unmatched endpoints fall through to base mocks.
- `activateScenario()`, `deactivateScenario()`, `activeScenario`, and
  `scenarios` getter for scenario management.
- `scenarioRegistrations()` for inspecting a scenario's mock list.
- `toPrettyPrintedString()` now includes scenario information.
- `DeceiverBuilder.forList()` constructor for building mocks into arbitrary
  lists (used internally by scenarios).

## 0.1.0

- Initial release.
- `Deceiver` class for managing mock HTTP response registrations.
- `DeceiverClient` extending `BaseClient` from `package:http` with
  request interception and optional passthrough to a real HTTP client.
- Fluent registration API via `deceiver.on.get()`, `.post()`, `.put()`,
  `.delete()`, `.patch()`, `.head()`, and `.match()` for custom matchers.
- URI template path matching (RFC 6570) with reverse-match validation.
- Response helpers: `jsonResponse()`, `errorResponse()`, `emptyResponse()`.
- `FutureOr<Response>` support for async response builders.
- Global `enabled` toggle to disable all mocks at runtime.
- Per-mock `isEnabled` toggle to disable individual registrations.
- `onlyAllowMocks` strict mode that throws `StateError` with descriptive
  error messages for unmatched requests.
- `toPrettyPrintedString()` for debug output of all registered mocks.
