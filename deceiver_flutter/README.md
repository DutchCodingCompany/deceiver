# deceiver_flutter

A Flutter debug control panel for the
[Deceiver](https://pub.dev/packages/deceiver) HTTP mocking library.

Toggle mocks on/off at runtime, switch between strict and passthrough
modes, and manage individual mock registrations -- all from a Material
UI panel you can embed anywhere in your app.

## Features

- **Global toggle** -- enable/disable all mocks with a single switch
- **Strict mode toggle** -- switch `onlyAllowMocks` on/off at runtime
- **Per-mock toggles** -- enable/disable individual mock registrations
- **Mock list** -- see all registered mocks with their descriptions and status
- **Reactive** -- panel updates automatically when settings change
- **Material Design** -- uses standard Material widgets that follow your app's theme

## Installation

Add both `deceiver` and `deceiver_flutter` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  deceiver: ^1.0.0
  deceiver_flutter: ^0.1.0
```

## Quick Start

```dart
import 'package:deceiver/deceiver.dart';
import 'package:deceiver_flutter/deceiver_flutter.dart';
import 'package:flutter/material.dart';

// 1. Create a Deceiver instance and register mocks.
final deceiver = Deceiver();
// ... register mocks ...

// 2. Wrap it in a DeceiverController.
final controller = DeceiverController(deceiver);

// 3. Drop the panel into your widget tree.
Scaffold(
  appBar: AppBar(title: Text('Debug Panel')),
  body: DeceiverPanel(controller: controller),
);
```

## Usage

### Setting up the controller

`DeceiverController` is a `ChangeNotifier` that wraps a `Deceiver`
instance. It provides reactive getters and setters so the panel (and
any other listener) rebuilds when settings change.

```dart
final deceiver = Deceiver();
deceiver.on.get('/users', jsonResponse(body: []));
deceiver.on.post('/users', jsonResponse(body: {'id': 1}, statusCode: 201));
deceiver.on.delete('/users/{id}', emptyResponse());

final controller = DeceiverController(deceiver);
```

### Embedding the panel

`DeceiverPanel` is a standalone widget. Place it wherever makes sense
for your app -- a debug drawer, a settings route, a bottom sheet, etc.

```dart
// As a full page
Navigator.push(context, MaterialPageRoute(
  builder: (_) => Scaffold(
    appBar: AppBar(title: Text('Deceiver')),
    body: DeceiverPanel(controller: controller),
  ),
));

// In a debug drawer
Drawer(
  child: DeceiverPanel(controller: controller),
);

// In a bottom sheet
showModalBottomSheet(
  context: context,
  builder: (_) => DeceiverPanel(controller: controller),
);
```

### Using the controller programmatically

You can also use `DeceiverController` without the panel widget:

```dart
// Toggle all mocks
controller.enabled = false;

// Switch to strict mode
controller.onlyAllowMocks = true;

// Disable a specific mock
controller.toggleMock(0, enabled: false);

// Manage scenarios
controller.activateScenario('happy');
print(controller.activeScenario); // 'happy'
print(controller.scenarios); // ['happy', 'error']
controller.deactivateScenario();

// Listen for changes
controller.addListener(() {
  print('Mocks enabled: ${controller.enabled}');
});
```

### Panel layout

The panel displays up to three sections:

**Global Settings**
- **Mocks enabled** -- master switch for all mocks
- **Only allow mocks** -- when on, unmatched requests throw errors

**Scenarios** (only shown when scenarios are defined)
- **None (base only)** -- deactivates any active scenario
- One `ListTile` per defined scenario with radio-style selection
- Tap to activate; tap the active scenario to deactivate

**Registered Mocks**
- Each registered mock shown with its description (e.g. `GET /users`)
- Individual toggle switch per mock
- Status icon and label (Enabled / Disabled)
- Count badge in the section header

## API Reference

| Class | Description |
|---|---|
| `DeceiverController` | `ChangeNotifier` wrapping a `Deceiver` instance. Exposes `enabled`, `onlyAllowMocks`, `registrations`, `toggleMock()`, `scenarios`, `activeScenario`, `activateScenario()`, and `deactivateScenario()`. |
| `DeceiverPanel` | Material-styled widget that renders the full control panel. Takes a `DeceiverController`. |
