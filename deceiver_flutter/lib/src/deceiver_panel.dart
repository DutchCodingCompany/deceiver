import 'package:flutter/material.dart';

import 'deceiver_controller.dart';

/// A Material-styled control panel for managing [Deceiver] mock settings.
///
/// Displays global toggles (enabled, onlyAllowMocks), a scenario selector,
/// and a scrollable list of registered mocks with individual toggle switches.
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final registrations = controller.registrations;
        final scenarios = controller.scenarios;
        final activeScenario = controller.activeScenario;

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
              _SectionHeader(
                title: 'Scenarios',
                trailing: Text(
                  '${scenarios.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _ScenarioListTile(
                name: 'None (base only)',
                isActive: activeScenario == null,
                onTap: () => controller.deactivateScenario(),
              ),
              for (final name in scenarios)
                _ScenarioListTile(
                  name: name,
                  isActive: activeScenario == name,
                  onTap: () {
                    if (activeScenario == name) {
                      controller.deactivateScenario();
                    } else {
                      controller.activateScenario(name);
                    }
                  },
                ),
            ],

            // -- Registered Mocks --
            const Divider(),
            _SectionHeader(
              title: 'Registered Mocks',
              trailing: Text(
                '${registrations.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (registrations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Text(
                  'No mocks registered.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              )
            else
              for (var i = 0; i < registrations.length; i++)
                _MockListTile(
                  description: registrations[i].description,
                  isEnabled: registrations[i].isEnabled,
                  onChanged: (value) =>
                      controller.toggleMock(i, enabled: value),
                ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class _ScenarioListTile extends StatelessWidget {
  const _ScenarioListTile({
    required this.name,
    required this.isActive,
    required this.onTap,
  });

  final String name;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.38),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _MockListTile extends StatelessWidget {
  const _MockListTile({
    required this.description,
    required this.isEnabled,
    required this.onChanged,
  });

  final String description;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SwitchListTile(
      title: Text(
        description,
        style: TextStyle(
          fontFamily: 'monospace',
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
      onChanged: onChanged,
    );
  }
}
