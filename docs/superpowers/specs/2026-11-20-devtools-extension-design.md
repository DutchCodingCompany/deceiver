# Deceiver DevTools extension — design (0.5.0)

## Intent

Control Deceiver and see what it handled from Dart DevTools while the app
runs in debug. Many apps don't embed `DeceiverPanel`, or the panel is only
reachable after login, so DevTools is a full alternative to the panel, not
just a viewer.

## Goals

- A "deceiver" tab in DevTools with a global **enabled** toggle, a **strict
  mode** toggle (`onlyAllowMocks`), scenario activate/deactivate, and
  per-mock enable toggles for base mocks and the mocks of every scenario.
- A live list of handled requests: method, URL, time, and which mock
  answered or "no mock". For mocked requests also the status code, duration,
  request body and response body. Without a mock: "passthrough", or the
  error in strict mode; no status or duration.
- Zero setup: works in any app that depends on `deceiver` and runs in debug
  or profile, Flutter web included.
- DevTools and the in-app panel stay in sync both ways.

## Non-goals

- Capturing real responses of passthrough requests. The Network tab already
  shows them, and buffering would change streaming behaviour.
- Reporting mocked requests to the DevTools Network tab via
  `package:http_profile` (mocked requests don't show up there today).
  Possible later.
- Editing responses or registering mocks from DevTools.
- Release builds (service extensions don't exist there).

## Anti-goals

- Changing app behaviour, or noticeable overhead while DevTools isn't
  connected.
- DevTools and the panel showing contradicting state.

## Approaches considered

How DevTools finds the `Deceiver`:

- **A. Automatic (chosen).** Every `Deceiver` registers itself on
  construction in a registry of weak references. The `ext.deceiver.*`
  service extensions are registered once per isolate, lazily. Multiple
  instances: a dropdown in DevTools, labelled with a new optional `name`
  constructor parameter, or else the `baseUrl`.
- **B. Explicit `deceiver.enableDevTools()`.** Rejected: forgetting it means
  DevTools shows nothing, exactly in the apps without a panel.
- **C. Via `DeceiverController` in `deceiver_flutter`.** Rejected: apps
  without a panel often don't depend on `deceiver_flutter`, and pure Dart
  is excluded.

## Design

### Core (`deceiver`)

- `Deceiver` gets `addListener`/`removeListener` (no Flutter dependency),
  notified on state changes: `enabled`, `options`, scenario
  define/activate/deactivate, `add`, `reset`, and `DeceiverData.isEnabled`
  (a setter that notifies its owning `Deceiver`, set in `add()` and
  `scenario()`). Recorded requests are pushed to DevTools separately, so the
  panel doesn't rebuild on every request.
- `DeceiverController` listens to its `Deceiver` and forwards to
  `notifyListeners`; removes the listener in `dispose`.
- `DeceiverRecordedRequest` gains `timestamp`, `response` and `duration`
  (null without a mock) and `error` (strict-mode exception, or what the
  response builder threw). Always recorded, also outside debug;
  `maxRecordedRequests` stays the limit (`0` turns it off).
- Service extensions (`dart:developer`) to list instances, get the state of
  one, set enabled/strict, activate/deactivate a scenario, toggle a mock
  (stable mock ids), and get/clear recorded requests. `postEvent` pushes
  state changes and new requests, only while DevTools listens.
- No redaction: DevTools is local and debug-only. Exception messages keep
  omitting the query, because they end up in logs and Sentry.

### Extension UI

- New Flutter web package `deceiver_devtools_extension/` in the workspace
  (`publish_to: none`) on `devtools_extensions`. The build goes with
  `dart run devtools_extensions build_and_copy` into
  `deceiver/extension/devtools/build`, next to `config.yaml` (name
  `deceiver`).
- Controls like the panel, plus a request list with a detail view.
- The `deceiver` README gets a DevTools section.

### Versions

`deceiver` and `deceiver_flutter` both go to 0.5.0, with CHANGELOG entries.

### Left to the builder

- Service extension names and JSON shapes; whether mock ids survive
  `reset()`.
- Whether the build output is committed or gitignored with `.pubignore`
  `!build`; CI validates with `devtools_extensions validate`.
- How large or binary bodies are shown (truncated).
- UI layout details.
