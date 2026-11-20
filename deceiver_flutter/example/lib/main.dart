import 'package:deceiver_flutter/deceiver_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'mocks.dart';

final deceiver = createDeceiver(Environment.production);

final controller = DeceiverController(deceiver);

// Only use the mocks in debug builds.
final Client httpClient = kDebugMode ? deceiver.client() : Client();

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deceiver example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _environment = Environment.production;

  /// Switches to another API: removes all mocks, scenarios and recorded
  /// requests, and registers the mocks again for the new base URL.
  void _switchEnvironment(Environment environment) {
    controller.reset(baseUrl: environment.apiUrl);
    registerMocks(deceiver, environment);
    setState(() => _environment = environment);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deceiver example'),
        actions: [
          PopupMenuButton<Environment>(
            tooltip: 'Environment',
            icon: const Icon(Icons.public),
            initialValue: _environment,
            onSelected: _switchEnvironment,
            itemBuilder: (context) => [
              for (final environment in Environment.values)
                PopupMenuItem(
                  value: environment,
                  child: Text(environment.name),
                ),
            ],
          ),
          if (kDebugMode)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Deceiver panel',
                icon: const Icon(Icons.tune),
                onPressed: Scaffold.of(context).openEndDrawer,
              ),
            ),
        ],
      ),
      // Open the panel with the button in the app bar or by swiping from
      // the right edge.
      endDrawer: kDebugMode
          ? Drawer(
              child: SafeArea(child: DeceiverPanel(controller: controller)),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Intro(environment: _environment),
          for (final MapEntry(key: title, value: calls)
              in sections.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final call in calls)
              _CallCard(call: call, apiUrl: _environment.apiUrl),
          ],
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.environment});

  final Environment environment;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Send the requests below and see which mock answers. Change the '
          'mocks and scenarios in the Deceiver panel (top right), or in the '
          '"deceiver" tab of Dart DevTools.\n\n'
          'Environment: ${environment.name} (${environment.apiUrl})',
        ),
      ),
    );
  }
}

class _CallCard extends StatefulWidget {
  const _CallCard({required this.call, required this.apiUrl});

  final ExampleCall call;
  final Uri apiUrl;

  @override
  State<_CallCard> createState() => _CallCardState();
}

class _CallCardState extends State<_CallCard> {
  var _sending = false;
  _Result? _result;

  Future<void> _send() async {
    final call = widget.call;
    final url = call.resolve(widget.apiUrl);
    setState(() => _sending = true);
    final stopwatch = Stopwatch()..start();
    String outcome;
    try {
      final response = await call.send(httpClient, widget.apiUrl);
      outcome = '${response.statusCode} ${response.body}';
    } on ClientException catch (e) {
      outcome = '$e';
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _result = _Result(
        outcome: outcome,
        duration: stopwatch.elapsed,
        answeredBy: _answeredBy(call.method, url),
      );
    });
  }

  /// Which mock answered, from the requests Deceiver recorded.
  static String _answeredBy(String method, Uri url) {
    final recorded = deceiver.requests
        .where((r) => r.request.method == method && r.request.url == url)
        .lastOrNull;
    if (recorded == null) return 'Not handled by Deceiver';
    return switch (recorded.mock) {
      final mock? => 'Mock: ${mock.description}',
      null => 'No mock',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final call = widget.call;
    final result = _result;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(call.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(call.description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: _sending ? null : _send,
                  child: const Text('Send'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${call.method} ${call.url}', style: _monospace),
            if (_sending) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (result != null) ...[
              const SizedBox(height: 8),
              Text(
                '${result.answeredBy} · '
                '${result.duration.inMilliseconds} ms',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(result.outcome, style: _monospace, maxLines: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _Result {
  _Result({
    required this.outcome,
    required this.duration,
    required this.answeredBy,
  });

  final String outcome;
  final Duration duration;
  final String answeredBy;
}

// 'monospace' only exists on Android.
const _monospace = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier'],
  fontSize: 12,
);
