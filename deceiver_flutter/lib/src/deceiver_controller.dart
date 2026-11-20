import 'package:deceiver/deceiver.dart';
import 'package:flutter/foundation.dart';

/// A reactive wrapper around a [Deceiver] instance.
///
/// Exposes getters and setters that proxy to the underlying [Deceiver].
/// The controller listens to the [Deceiver] and calls [notifyListeners] on
/// every change, also changes made directly on the [Deceiver] or from
/// DevTools, so Flutter widgets rebuild when mock settings change.
///
/// ```dart
/// final deceiver = Deceiver();
/// deceiver.on.get('/users', jsonResponse(body: []));
///
/// final controller = DeceiverController(deceiver);
///
/// // Use with ListenableBuilder or DeceiverPanel
/// ListenableBuilder(
///   listenable: controller,
///   builder: (context, child) => Text('Enabled: ${controller.enabled}'),
/// );
/// ```
class DeceiverController extends ChangeNotifier {
  /// Creates a controller wrapping the given [deceiver] instance.
  DeceiverController(this.deceiver) {
    deceiver.addListener(_onDeceiverChanged);
  }

  /// The underlying [Deceiver] instance being controlled.
  final Deceiver deceiver;

  /// Whether all mocks are globally enabled.
  bool get enabled => deceiver.enabled;

  set enabled(bool value) {
    if (deceiver.enabled == value) return;
    deceiver.enabled = value;
  }

  /// Whether unmatched requests should throw instead of passing through.
  bool get onlyAllowMocks => deceiver.options.onlyAllowMocks;

  set onlyAllowMocks(bool value) {
    if (deceiver.options.onlyAllowMocks == value) return;
    deceiver.options = deceiver.options.copyWith(onlyAllowMocks: value);
  }

  /// The list of registered base mock definitions.
  List<DeceiverData> get registrations => deceiver.registrations;

  /// Removes all mocks, scenarios and recorded requests, and optionally
  /// changes the [Deceiver.baseUrl]. See [Deceiver.reset].
  void reset({Uri? baseUrl}) {
    deceiver.reset(baseUrl: baseUrl);
  }

  /// Sets the [DeceiverData.isEnabled] flag of [mock].
  ///
  /// Works for base mocks and scenario mocks alike.
  void toggleMock(DeceiverData mock, {required bool enabled}) {
    mock.isEnabled = enabled;
  }

  // ---------------------------------------------------------------------------
  // Scenarios
  // ---------------------------------------------------------------------------

  /// The list of defined scenario names.
  List<String> get scenarios => deceiver.scenarios;

  /// The currently active scenario name, or `null` if none is active.
  String? get activeScenario => deceiver.activeScenario;

  /// The mocks of the active scenario, or an empty list if none is active.
  List<DeceiverData> get activeScenarioRegistrations {
    final name = deceiver.activeScenario;
    if (name == null) return const [];
    return deceiver.scenarioRegistrations(name) ?? const [];
  }

  /// The mocks of the scenario with [name], or an empty list if there is no
  /// such scenario.
  List<DeceiverData> scenarioRegistrations(String name) =>
      deceiver.scenarioRegistrations(name) ?? const [];

  /// Whether [mock] is a base mock that an enabled mock of the active
  /// scenario with the same [DeceiverData.description] overrides.
  ///
  /// This compares descriptions, so it doesn't detect overrides between mocks
  /// registered with `on.match()`.
  bool isOverridden(DeceiverData mock) {
    if (!registrations.contains(mock)) return false;
    return activeScenarioRegistrations.any(
      (m) => m.isEnabled && m.description == mock.description,
    );
  }

  /// Activates the scenario with the given [name].
  ///
  /// Scenario mocks take priority over base mocks while active.
  void activateScenario(String name) {
    if (deceiver.activeScenario == name) return;
    deceiver.activateScenario(name);
  }

  /// Deactivates the current scenario, reverting to base mocks only.
  void deactivateScenario() {
    if (deceiver.activeScenario == null) return;
    deceiver.deactivateScenario();
  }

  void _onDeceiverChanged() => notifyListeners();

  @override
  void dispose() {
    deceiver.removeListener(_onDeceiverChanged);
    super.dispose();
  }
}
