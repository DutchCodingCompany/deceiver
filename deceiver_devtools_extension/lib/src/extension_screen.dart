import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import 'extension_controller.dart';
import 'models.dart';

/// The content of the "deceiver" tab in DevTools.
class ExtensionScreen extends StatelessWidget {
  const ExtensionScreen({super.key, required this.controller});

  final ExtensionController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.error case final error?)
              MaterialBanner(
                content: Text(error),
                actions: [
                  TextButton(
                    onPressed: controller.loadInstances,
                    child: const Text('Reload'),
                  ),
                ],
              ),
            if (state == null)
              const Expanded(child: _NoDeceiver())
            else ...[
              _Toolbar(controller: controller, state: state),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    densePadding,
                    0,
                    densePadding,
                    densePadding,
                  ),
                  // The details pane is always there, so the sizes the user
                  // dragged the panes to are kept.
                  child: SplitPane(
                    axis: Axis.horizontal,
                    initialFractions: const [0.25, 0.45, 0.3],
                    minSizes: const [180, 240, 180],
                    children: [
                      _MockList(controller: controller, state: state),
                      _RequestList(controller: controller),
                      _Details(controller: controller),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _NoDeceiver extends StatelessWidget {
  const _NoDeceiver();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No Deceiver found.\n\n'
          'A Deceiver shows up here as soon as the app creates one, '
          'while it runs in debug or profile mode.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.state});

  final ExtensionController controller;
  final DeceiverState state;

  @override
  Widget build(BuildContext context) {
    final instances = controller.instances;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 24,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (instances.length > 1)
            DropdownButton<int>(
              value: state.instance,
              items: [
                for (final instance in instances)
                  DropdownMenuItem(
                    value: instance.id,
                    child: Text(instance.label),
                  ),
              ],
              onChanged: (id) {
                if (id != null) controller.selectInstance(id);
              },
            )
          else if (state.baseUrl case final baseUrl?)
            Text(baseUrl, style: Theme.of(context).textTheme.titleSmall),
          _LabeledSwitch(
            label: 'Mocks enabled',
            tooltip: 'When off, all requests go to the real HTTP client',
            value: state.enabled,
            onChanged: controller.setEnabled,
          ),
          _LabeledSwitch(
            label: 'Only allow mocks',
            tooltip: 'When on, requests without a mock throw an error',
            value: state.onlyAllowMocks,
            onChanged: controller.setOnlyAllowMocks,
          ),
          if (state.scenarios.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Scenario'),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: state.activeScenario,
                  items: [
                    const DropdownMenuItem(child: Text('None')),
                    for (final scenario in state.scenarios)
                      DropdownMenuItem(
                        value: scenario.name,
                        child: Text(scenario.name),
                      ),
                  ],
                  onChanged: controller.setActiveScenario,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LabeledSwitch extends StatelessWidget {
  const _LabeledSwitch({
    required this.label,
    required this.tooltip,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String tooltip;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          _SmallSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A [Switch] scaled down to fit the dense DevTools UI.
class _SmallSwitch extends StatelessWidget {
  const _SmallSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: FittedBox(
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _MockList extends StatelessWidget {
  const _MockList({required this.controller, required this.state});

  final ExtensionController controller;
  final DeceiverState state;

  @override
  Widget build(BuildContext context) {
    return DevToolsAreaPane(
      header: const AreaPaneHeader(title: Text('Mocks')),
      child: _list(),
    );
  }

  Widget _list() {
    final active = state.active;
    final overriding = state.overridingDescriptions;
    return ListView(
      children: [
        // The order in which Deceiver looks for a matching mock.
        if (active != null) ...[
          _SectionHeader('Scenario: ${active.name} (active)'),
          if (active.mocks.isEmpty) _empty('No mocks in this scenario'),
          for (final mock in active.mocks) _mockTile(mock),
        ],
        const _SectionHeader('Base mocks'),
        if (state.mocks.isEmpty) _empty('No mocks'),
        for (final mock in state.mocks)
          _mockTile(mock, overridden: overriding.contains(mock.description)),
        for (final scenario in state.scenarios)
          if (scenario.name != state.activeScenario)
            ExpansionTile(
              key: PageStorageKey('scenario ${scenario.name}'),
              dense: true,
              title: Text('Scenario: ${scenario.name}'),
              subtitle: Text('${scenario.mocks.length} mocks, not active'),
              children: [for (final mock in scenario.mocks) _mockTile(mock)],
            ),
      ],
    );
  }

  Widget _empty(String text) => ListTile(dense: true, title: Text(text));

  Widget _mockTile(MockInfo mock, {bool overridden = false}) {
    final onChanged = state.enabled
        ? (bool enabled) => controller.setMockEnabled(mock.id, enabled)
        : null;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      selected: mock.id == controller.selectedMockId,
      title: Text(mock.description),
      subtitle: Text(
        [
          mock.response?.summary ?? 'custom response',
          if (overridden) 'overridden',
        ].join(' · '),
      ),
      trailing: _SmallSwitch(value: mock.enabled, onChanged: onChanged),
      onTap: () => controller.selectMock(mock.id),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.controller});

  final ExtensionController controller;

  @override
  Widget build(BuildContext context) {
    // Newest first.
    final requests = controller.requests.reversed.toList();
    return DevToolsAreaPane(
      header: AreaPaneHeader(
        title: Text('Requests (${requests.length})'),
        actions: [
          TextButton.icon(
            onPressed: requests.isEmpty ? null : controller.clearRequests,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear'),
          ),
        ],
      ),
      child: requests.isEmpty
          ? const Center(child: Text('No requests yet'))
          : ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return ListTile(
                  dense: true,
                  selected: request.id == controller.selectedRequest?.id,
                  leading: _StatusLabel(request),
                  title: Text('${request.method} ${request.url}'),
                  subtitle: Text(_summary(request)),
                  onTap: () => controller.selectRequest(request),
                );
              },
            ),
    );
  }

  static String _summary(RecordedRequest request) => [
    request.mockDescription ??
        (request.error == null ? 'No mock, passthrough' : 'No mock'),
    if (request.duration case final duration?) _duration(duration),
    _time(request.timestamp),
  ].join(' · ');
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel(this.request);

  final RecordedRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (text, color) = switch (request) {
      RecordedRequest(error: _?) => ('Error', colors.error),
      RecordedRequest(statusCode: final code?) => (
        '$code',
        code >= 400 ? colors.error : colors.primary,
      ),
      _ => ('Real', colors.outline),
    };
    return SizedBox(
      width: 48,
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.controller});

  final ExtensionController controller;

  @override
  Widget build(BuildContext context) {
    final request = controller.selectedRequest;
    final mockId = controller.selectedMockId;
    final mock = mockId == null ? null : controller.state?.findMock(mockId);
    return DevToolsAreaPane(
      header: AreaPaneHeader(
        title: const Text('Details'),
        actions: [
          if (request != null || mock != null)
            IconButton(
              tooltip: 'Clear selection',
              icon: const Icon(Icons.close),
              onPressed: () => controller.selectMock(null),
            ),
        ],
      ),
      child: switch ((request, mock)) {
        (final request?, _) => _requestDetails(context, request),
        (_, (final mock, final scenario)?) => _mockDetails(
          context,
          mock,
          scenario,
        ),
        _ => const Center(child: Text('Select a request or mock')),
      },
    );
  }

  Widget _requestDetails(BuildContext context, RecordedRequest request) {
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(defaultSpacing),
        children: [
          Text(
            '${request.method} ${request.url}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          _Field('Time', _time(request.timestamp)),
          _Field(
            'Mock',
            request.mockDescription ?? 'No mock, sent to the real HTTP client',
          ),
          if (request.statusCode case final code?) _Field('Status', '$code'),
          if (request.duration case final duration?)
            _Field('Duration', _duration(duration)),
          if (request.error case final error?) _Field('Error', error),
          _Block('Request headers', _headers(request.requestHeaders)),
          _Block('Request body', _pretty(request.requestBody)),
          if (request.isMocked) ...[
            _Block('Response headers', _headers(request.responseHeaders)),
            _Block('Response body', _pretty(request.responseBody ?? '')),
          ],
        ],
      ),
    );
  }

  Widget _mockDetails(BuildContext context, MockInfo mock, String? scenario) {
    final state = controller.state!;
    final overridden =
        scenario == null &&
        state.overridingDescriptions.contains(mock.description);
    final response = mock.response;
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(defaultSpacing),
        children: [
          Text(mock.description, style: Theme.of(context).textTheme.titleSmall),
          _Field(
            'Registered in',
            scenario == null
                ? 'Base mocks'
                : scenario == state.activeScenario
                ? 'Scenario $scenario (active)'
                : 'Scenario $scenario (not active)',
          ),
          if (mock.baseUrl case final baseUrl?) _Field('Base URL', baseUrl),
          _Field(
            'Enabled',
            [
              if (mock.enabled) 'yes' else 'no',
              if (overridden) 'overridden by scenario ${state.activeScenario}',
            ].join(', '),
          ),
          if (response == null)
            const _Field('Response', 'custom response')
          else
            ..._responseDetails(response),
        ],
      ),
    );
  }

  static List<Widget> _responseDetails(ResponseInfo response, [String? label]) {
    final prefix = label ?? 'Response';
    return [
      _Field(prefix, response.summary),
      if (response.kind == 'custom')
        const _Note(
          'A response builder of your own: what it returns is only known '
          'when it runs. See the requests it answered.',
        ),
      if (response.statusCode != null) ...[
        _Block('$prefix headers', _headers(response.headers)),
        _Block('$prefix body', _pretty(response.body ?? '')),
      ],
      for (final (index, variant) in response.variants.indexed)
        ..._responseDetails(
          variant,
          response.kind == 'sequential'
              ? 'Call ${index + 1}'
              : 'Option ${index + 1}',
        ),
    ];
  }

  static String _headers(Map<String, String> headers) =>
      [for (final MapEntry(:key, :value) in headers.entries) '$key: $value']
          .join('\n');

  static String _pretty(String body) {
    try {
      return FormattedJson.encoder.convert(jsonDecode(body));
    } on FormatException {
      return body;
    }
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.label, this.content);

  final String label;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Text(
              content.isEmpty ? '(empty)' : content,
              style: theme.fixedFontStyle,
            ),
          ),
        ],
      ),
    );
  }
}

String _duration(Duration duration) =>
    '${(duration.inMicroseconds / 1000).toStringAsFixed(1)} ms';

String _time(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
