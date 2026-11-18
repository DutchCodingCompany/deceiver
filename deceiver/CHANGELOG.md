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
