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
