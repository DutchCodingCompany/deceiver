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
              const _Header(),

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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const CustomPaint(
            size: Size.square(40),
            painter: _DeceiverIconPainter(),
          ),
          const SizedBox(width: 12),
          Text('Deceiver', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// Paints the Deceiver icon: a real (navy) and a fake (cyan) briefcase being
/// swapped. Mirrors `assets/deceiver_icon.svg`, drawn on a 100×100 grid.
class _DeceiverIconPainter extends CustomPainter {
  const _DeceiverIconPainter();

  static const _background = Color(0xFF0175C2);
  static const _real = Color(0xFF0A1F3D);
  static const _fake = Color(0xFF13B9FD);
  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);

    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, 100, 100, const Radius.circular(22)),
      Paint()..color = _background,
    );

    _paintBriefcase(canvas, const Offset(0, -4), _real);
    _paintBriefcase(canvas, const Offset(44, 44), _fake);

    final arrow = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(58, 20)
          ..quadraticBezierTo(80, 18, 80, 38),
        arrow,
      )
      ..drawPath(
        Path()
          ..moveTo(42, 82)
          ..quadraticBezierTo(20, 84, 20, 64),
        arrow,
      );

    final arrowHead = Paint()..color = _white;
    canvas
      ..drawPath(
        Path()
          ..moveTo(72.5, 34.5)
          ..lineTo(87.5, 34.5)
          ..lineTo(80, 47.5)
          ..close(),
        arrowHead,
      )
      ..drawPath(
        Path()
          ..moveTo(12.5, 67.5)
          ..lineTo(27.5, 67.5)
          ..lineTo(20, 54.5)
          ..close(),
        arrowHead,
      );
  }

  void _paintBriefcase(Canvas canvas, Offset offset, Color color) {
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..scale(0.56)
      ..drawRRect(
        RRect.fromLTRBR(37, 20, 63, 38, const Radius.circular(5)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      )
      ..drawRRect(
        RRect.fromLTRBR(14, 34, 86, 84, const Radius.circular(8)),
        Paint()..color = color,
      )
      ..drawLine(
        const Offset(14, 54),
        const Offset(86, 54),
        Paint()
          ..color = _white.withValues(alpha: 0.5)
          ..strokeWidth = 3,
      )
      ..drawRRect(
        RRect.fromLTRBR(44, 49, 56, 59, const Radius.circular(2)),
        Paint()..color = _white,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_DeceiverIconPainter oldDelegate) => false;
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
