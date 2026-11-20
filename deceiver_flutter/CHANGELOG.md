## 0.5.0

- `DeceiverController` listens to its `Deceiver`, so the panel also updates
  for changes made directly on the `Deceiver` or from the Deceiver DevTools
  extension. `dispose()` stops listening.
- Every mock shows what it responds, such as `200 · JSON · 2 items`. Tap a
  mock to see its status code, headers and body in a bottom sheet. Only the
  switch toggles a mock now, tapping the row opens the details.
- The mocks are listed in the order Deceiver looks for a match: the active
  scenario first, then the base mocks, then the other scenarios collapsed.
  A base mock overridden by the active scenario is marked `overridden`.
- Added `DeceiverController.scenarioRegistrations()` and `isOverridden()`.
- The example app shows what Deceiver can do: a card per feature (response
  helpers, path parameters, sequences, custom matchers, other APIs, slow
  responses, passthrough), four scenarios, and switching environments.
- Requires `deceiver` 0.5.0.

## 0.4.0

- Added `DeceiverController.reset()`, optionally with a new `baseUrl`.
- The panel starts with a header showing the Deceiver icon.
- Requires `deceiver` 0.4.0.

## 0.3.0

### Breaking

- Requires Flutter 3.47 or later.
- `DeceiverController.toggleMock()` takes the `DeceiverData` to toggle
  instead of an index, so it works for scenario mocks too.
- The panel uses `package:material_ui` instead of
  `package:flutter/material.dart`. In apps that still use
  `package:flutter/material.dart` it shows Material's default theme.
- The "Registered Mocks" section is now called "Base Mocks".

### Changes

- Added `DeceiverController.activeScenarioRegistrations`.
- While a scenario is active, the panel shows its mocks in a "Scenario Mocks"
  section, each with its own toggle.
- The scenario selector uses `RadioGroup` and `RadioListTile`, so screen
  readers announce it as a radio group.
- Mock descriptions fall back to Menlo or Courier on platforms without a
  `monospace` font, such as iOS.
- Requires `deceiver` 0.3.0.

## 0.2.0

- `DeceiverController` now exposes `scenarios`, `activeScenario`,
  `activateScenario()`, and `deactivateScenario()` with reactive
  notifications.
- `DeceiverPanel` now includes a Scenarios section with radio-style
  `ListTile` selection when scenarios are defined. Tap a scenario to
  activate it, tap again or "None (base only)" to deactivate.
- Scenario section is hidden when no scenarios are defined.

## 0.1.0

- Initial release.
- `DeceiverController` -- a `ChangeNotifier` wrapper around `Deceiver` with
  reactive getters/setters for `enabled`, `onlyAllowMocks`, and per-mock
  toggling via `toggleMock()`.
- `DeceiverPanel` -- a Material-styled widget displaying global toggles
  (mocks enabled, only allow mocks) and a scrollable list of registered
  mocks with individual toggle switches.
