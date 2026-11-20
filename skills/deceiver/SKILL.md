---
name: deceiver
description: Work with Deceiver, the fake HTTP response library for Dart's package:http (packages deceiver and deceiver_flutter). Turn mocks on or off, switch scenarios and check which requests a running Flutter or Dart app made, through the ext.deceiver.* VM service extensions with the Dart MCP server (vm_service callMethod) - for testing an app as an agent, putting it in an error, empty or slow state, or integration tests. Also covers setting Deceiver up in an app, writing mocks and scenarios, the deceiver_flutter panel, and using Deceiver in unit, widget and integration tests. Use this whenever a project depends on deceiver or deceiver_flutter, or the user wants to fake, stub or mock HTTP responses in a Flutter app, test an app against API errors or edge cases, or asks which mock answered a request, even if they don't say "Deceiver".
---

# Deceiver

Deceiver fakes HTTP responses for `package:http`. An app registers mocks on a
`Deceiver` and uses `deceiver.client()` as its HTTP client. Requests that
match an enabled mock get the fake response; others go to the real server
(passthrough), or throw a `DeceiverException` in strict mode.

How a request is answered, which you need to reason about any test:

1. Nothing is mocked while `enabled` is off: every request goes to the real
   server. Each mock also has its own enabled flag.
2. The mocks of the active scenario are tried first, then the base mocks. The
   first enabled mock that matches answers.
3. No match: passthrough, or in strict mode (`onlyAllowMocks`) an exception.
4. With a `baseUrl`, only requests under it (or under a mock registered with
   `on.at()` or a full URL) are handled at all.

## Pick the route

- **The app is running and you test it from outside** (you drive the UI, use
  Maestro or the widget inspector, or a person tests by hand): control
  Deceiver through the VM service. This is the main workflow below.
- **You write Dart test code** (unit, widget or `integration_test`): call the
  `Deceiver` directly in the test. It runs in the same process, so this is
  simpler and typed. Read `references/testing.md`.
- **You need to add or change mocks or scenarios in the code**, or set
  Deceiver up in an app: read `references/setup-and-mocks.md`.

## Control a running app

The app exposes `ext.deceiver.*` service extensions in debug and profile
builds. They are registered when the app creates its first `Deceiver`.

### 1. Connect

With the Dart MCP server:

- Apps started from an IDE or with DTD: `dtd` → `listDtdUris`, `connect`,
  then `listConnectedApps`.
- Otherwise connect to the VM service URI that `flutter run` prints ("A Dart
  VM Service on ... is available at: http://127.0.0.1:PORT/TOKEN=/"):
  `vm_service` → `connect` with that `appUri`. Clients want the WebSocket
  form: `http://127.0.0.1:PORT/TOKEN=/` becomes
  `ws://127.0.0.1:PORT/TOKEN=/ws` (without a token: `ws://127.0.0.1:PORT/ws`).

Service extensions run on an isolate: call `getVM` with `vm_service` →
`callMethod` and use the id of the main isolate (named `main`) as
`isolateId` in every call below.

Without the Dart MCP server, any VM service client works the same way, for
example `package:vm_service` (`callServiceExtension`) in a Dart script.

### 2. Look before you change

```
callMethod ext.deceiver.help         → methods, parameters, events
callMethod ext.deceiver.getState     → settings, base mocks, scenarios
callMethod ext.deceiver.getRequests  → what the app did so far
```

Keep the first `getState`: it's what you restore at the end. Read
`getRequests` before clearing anything when the user asks what the app did
(recently), because `clearRequests` throws that history away.

`getState` shows each mock's `description` (like `GET /users/{id}`),
`enabled`, and `response` with a `summary` (like `200 · JSON · 2 items`,
`500 · error: "Server error"`, `custom response`). Use it to find the mock
you need instead of guessing. All parameters are strings (`"true"`, not
`true`). Leave out `instance` when there is one Deceiver; with more,
`getInstances` gives the ids.

### 3. Put the app in the state you need

| Goal | Calls |
|---|---|
| Only one endpoint mocked | `setAllMocksEnabled {enabled: "false"}` (base and scenario mocks), then `setMockEnabled {description: "GET /users", enabled: "true"}` |
| A preset state (errors, empty lists) | `setActiveScenario {scenario: "error"}` (names from `getState`) |
| Only part of a scenario | Activate it, then turn off the scenario mocks you don't want: `setMockEnabled {description: "GET /users/{id}", scenario: "error", enabled: "false"}`. Those endpoints fall back to their base mock. |
| One endpoint fails, rest normal | If a scenario has the failing mock, use the row above. Otherwise the code needs a mock for it (see `references/setup-and-mocks.md`). |
| Real server for one endpoint | `setMockEnabled {description: "...", enabled: "false"}` |
| Find requests that have no mock | `setOnlyAllowMocks {enabled: "true"}`, use the app, look for errors |
| Everything real | `setEnabled {enabled: "false"}` |

A scenario often overrides more endpoints than the one you care about.
Check its mocks in `getState` before activating it, and turn off the ones
that would change more than the user asked for.

Every setter returns the new state, so check it instead of calling
`getState` again. Errors say what to pass: an unknown description lists the
mocks that exist and the scenarios that have it.

Deceiver doesn't trigger new requests itself. After a change, make the app
fetch again (pull to refresh, navigate, or hot restart; a hot restart also
resets all mocks to what the code registers).

### 4. Check what happened

```
callMethod ext.deceiver.clearRequests     (optional: a clean list from now on)
... act in the app, or wait for it ...
callMethod ext.deceiver.getRequests
```

Instead of clearing, you can also compare `timestamp`s (milliseconds since
the epoch) with when you made the change. To wait, use something outside the
VM service, like the shell's `sleep`.

Each request has `method`, `url`, `requestBody`, `mock` (`null`: no mock
answered, so it went to the real server or failed in strict mode),
`statusCode`, `responseBody`, `durationMicros` and `error`. Use it to verify
the app called what you expected, with the right body, and which mock
answered. Responses of the real server are not recorded: for a request
without a mock you can't tell from Deceiver whether the server answered or
the request failed; the app's own logs or the DevTools Network tab can.

### 5. Clean up

The state you set stays until the app restarts. Unless the user wants to
keep looking at it, put back exactly the state of your first `getState`, so
the next person or test doesn't start from a surprising state:

- `setEnabled`, `setOnlyAllowMocks` and `setActiveScenario` (empty when it
  was `null`) to their old values.
- The mocks: `setAllMocksEnabled {enabled: "true"}`, then `setMockEnabled`
  `{enabled: "false"}` with the `description` (and `scenario`) of each mock
  that was off at the start. Don't rely on the `mock` ids of the first
  `getState`: they change when the app registers its mocks again, for example
  after `reset()` when it switches environments.
- Compare a final `getState` with the first one.

A hot restart also resets everything, to what the code registers. If you
leave a changed state on purpose, tell the user what you changed and how to
undo it.

## When it doesn't work

- **`Method not found` (error -32601) for `ext.deceiver...`**: the
  extensions aren't registered. The app hasn't created a `Deceiver` yet
  (they're often created lazily, at first use), it's a release build, or
  you're on the wrong isolate. Use the app a bit and retry, check the build
  mode and the isolate.
- **Flutter web**: the extensions are only registered when the debugger is
  attached at the moment the first `Deceiver` is created.
- **`The app has 2 Deceivers, pass instance`**: pass `instance` with one of
  the listed ids.
- **A request still hits the wrong mock**: check the active scenario (it wins
  over the base mocks) and `baseUrl` (requests outside it are never mocked).
  `getRequests` shows which mock answered.
- **The DevTools "deceiver" tab is missing**: not needed for the VM service
  route. For Flutter web the tab only shows when the app is started from an
  IDE.

The full protocol, with the JSON of every answer and the events, is in
`references/runtime-control.md`.
