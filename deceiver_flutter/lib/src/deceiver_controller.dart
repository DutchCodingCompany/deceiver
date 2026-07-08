import 'package:deceiver/deceiver.dart';
import 'package:flutter/foundation.dart';

/// A reactive wrapper around a [Deceiver] instance.
///
/// Exposes getters and setters that proxy to the underlying [Deceiver]
/// and call [notifyListeners] on changes, so Flutter widgets can rebuild
/// when mock settings change.
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
  DeceiverController(this.deceiver);

  /// The underlying [Deceiver] instance being controlled.
  final Deceiver deceiver;

  /// Whether all mocks are globally enabled.
  bool get enabled => deceiver.enabled;

  set enabled(bool value) {
    if (deceiver.enabled == value) return;
    deceiver.enabled = value;
    notifyListeners();
  }

  /// Whether unmatched requests should throw instead of passing through.
  bool get onlyAllowMocks => deceiver.options.onlyAllowMocks;

  set onlyAllowMocks(bool value) {
    if (deceiver.options.onlyAllowMocks == value) return;
    deceiver.options = DeceiverOptions(onlyAllowMocks: value);
    notifyListeners();
  }

  /// The list of registered mock definitions.
  List<DeceiverData> get registrations => deceiver.registrations;

  /// Toggles the [isEnabled] flag on the mock at the given [index].
  void toggleMock(int index, {required bool enabled}) {
    final mocks = deceiver.registrations;
    if (index < 0 || index >= mocks.length) return;
    if (mocks[index].isEnabled == enabled) return;
    mocks[index].isEnabled = enabled;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Scenarios
  // ---------------------------------------------------------------------------

  /// The list of defined scenario names.
  List<String> get scenarios => deceiver.scenarios;

  /// The currently active scenario name, or `null` if none is active.
  String? get activeScenario => deceiver.activeScenario;

  /// Activates the scenario with the given [name].
  ///
  /// Scenario mocks take priority over base mocks while active.
  void activateScenario(String name) {
    if (deceiver.activeScenario == name) return;
    deceiver.activateScenario(name);
    notifyListeners();
  }

  /// Deactivates the current scenario, reverting to base mocks only.
  void deactivateScenario() {
    if (deceiver.activeScenario == null) return;
    deceiver.deactivateScenario();
    notifyListeners();
  }
}
