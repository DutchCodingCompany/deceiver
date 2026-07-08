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
