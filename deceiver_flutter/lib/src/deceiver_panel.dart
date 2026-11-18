import 'package:deceiver/deceiver.dart';
import 'package:material_ui/material_ui.dart';

import 'deceiver_controller.dart';

/// A Material-styled control panel for managing [Deceiver] mock settings.
///
/// Displays global toggles (enabled, onlyAllowMocks), a scenario selector,
/// the mocks of the active scenario and a scrollable list of base mocks,
/// each with an individual toggle switch.
///
/// Embed this widget in a debug drawer, settings page, or any route:
///
/// ```dart
/// final controller = DeceiverController(deceiver);
///
/// Scaffold(
///   appBar: AppBar(title: Text('Debug')),
///   body: DeceiverPanel(controller: controller),
/// );
/// ```
class DeceiverPanel extends StatelessWidget {
  /// Creates a panel for the given [controller].
  const DeceiverPanel({super.key, required this.controller});

  /// The controller managing the [Deceiver] instance.
  final DeceiverController controller;

  @override
  Widget build(BuildContext context) {
    // The panel brings its own Material, so it also works in apps that still
    // use package:flutter/material.dart, which has a separate Material type.
    return Material(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final registrations = controller.registrations;
          final scenarios = controller.scenarios;
          final activeScenario = controller.activeScenario;
          final scenarioRegistrations = controller.activeScenarioRegistrations;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // -- Global Settings --
              const _SectionHeader(title: 'Global Settings'),
              SwitchListTile(
                title: const Text('Mocks enabled'),
                subtitle: const Text(
                  'When disabled, all requests go to the real HTTP client',
                ),
                value: controller.enabled,
                onChanged: (value) => controller.enabled = value,
              ),
              SwitchListTile(
                title: const Text('Only allow mocks'),
                subtitle: const Text(
                  'When enabled, unmatched requests throw an error',
                ),
                value: controller.onlyAllowMocks,
                onChanged: (value) => controller.onlyAllowMocks = value,
              ),

              // -- Scenarios --
              if (scenarios.isNotEmpty) ...[
                const Divider(),
                _SectionHeader(title: 'Scenarios', count: scenarios.length),
                RadioGroup<String?>(
                  groupValue: activeScenario,
                  onChanged: (name) => name == null
                      ? controller.deactivateScenario()
                      : controller.activateScenario(name),
                  child: Column(
                    children: [
                      const RadioListTile<String?>(
                        value: null,
                        title: Text('None (base only)'),
                      ),
                      for (final name in scenarios)
                        RadioListTile<String?>(
                          value: name,
                          title: Text(name),
                          // Tapping the active scenario deactivates it.
                          toggleable: true,
                        ),
                    ],
                  ),
                ),
              ],

              // -- Scenario Mocks --
              if (activeScenario != null) ...[
                const Divider(),
                _SectionHeader(
                  title: 'Scenario Mocks: $activeScenario',
                  count: scenarioRegistrations.length,
                ),
                if (scenarioRegistrations.isEmpty)
                  const _EmptyState('No mocks in this scenario.')
                else
                  for (final mock in scenarioRegistrations)
                    _MockListTile(mock: mock, controller: controller),
              ],

              // -- Base Mocks --
              const Divider(),
              _SectionHeader(title: 'Base Mocks', count: registrations.length),
              if (registrations.isEmpty)
                const _EmptyState('No mocks registered.')
              else
                for (final mock in registrations)
                  _MockListTile(mock: mock, controller: controller),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (count != null)
            Text(
              '$count',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Text(message, style: const TextStyle(fontStyle: FontStyle.italic)),
    );
  }
}

class _MockListTile extends StatelessWidget {
  const _MockListTile({required this.mock, required this.controller});

  final DeceiverData mock;
  final DeceiverController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = mock.isEnabled;

    return SwitchListTile(
      title: Text(
        mock.description,
        style: TextStyle(
          fontFamily: 'monospace',
          // 'monospace' only exists on Android.
          fontFamilyFallback: const ['Menlo', 'Courier'],
          color: isEnabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      subtitle: Text(isEnabled ? 'Enabled' : 'Disabled'),
      secondary: Icon(
        isEnabled ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: isEnabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.38),
      ),
      value: isEnabled,
      onChanged: (value) => controller.toggleMock(mock, enabled: value),
    );
  }
}
