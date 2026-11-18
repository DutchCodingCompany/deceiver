import 'dart:async';

import 'package:http/http.dart';

import 'deceiver_builder.dart';
import 'deceiver_client.dart';
import 'deceiver_data.dart';
import 'deceiver_exception.dart';

/// Configuration options for a [Deceiver] instance.
class DeceiverOptions {
  const DeceiverOptions({this.onlyAllowMocks = false});

  /// When `true`, requests that don't match any registered mock throw a
  /// [DeceiverException] with a descriptive message listing all registered
  /// mocks.
  ///
  /// When `false` (default), unmatched requests are forwarded to the real
  /// HTTP client.
  ///
  /// Has no effect while [Deceiver.enabled] is `false`: then every request
  /// goes to the real HTTP client.
  final bool onlyAllowMocks;

  /// Returns a copy of these options with the given fields replaced.
  DeceiverOptions copyWith({bool? onlyAllowMocks}) =>
      DeceiverOptions(onlyAllowMocks: onlyAllowMocks ?? this.onlyAllowMocks);
}

/// A fake HTTP response orchestrator.
///
/// Register mock responses using the fluent [on] builder, then create
/// a [DeceiverClient] via [client] that intercepts matching requests.
///
/// Supports named [scenario]s for grouping mock configurations that can
/// be switched at runtime. Scenario mocks take priority over base mocks.
///
/// ```dart
/// final deceiver = Deceiver();
/// deceiver.on.get('/api/users', (req) => Response('[]', 200));
/// deceiver.on.post('/api/users', (req) => Response('{"id": 1}', 201));
///
/// deceiver.scenario('error', (on) {
///   on.get('/api/users', errorResponse(500, message: 'Server error'));
/// });
///
/// final httpClient = deceiver.client();
/// final response = await httpClient.get(Uri.parse('https://example.com/api/users'));
/// // response.body == '[]'
///
/// deceiver.activateScenario('error');
/// final errorResponse = await httpClient.get(Uri.parse('https://example.com/api/users'));
/// // errorResponse.statusCode == 500
/// ```
class Deceiver {
  /// Creates a [Deceiver].
  ///
  /// When [baseUrl] is given, only requests to that scheme, host and port,
  /// and under its path, are handled. Paths of mocks registered via [on] and
  /// [scenario] are relative to the path of [baseUrl]. Other requests always
  /// go to the real HTTP client, even in strict mode, and are not recorded.
  ///
  /// ```dart
  /// final deceiver = Deceiver(baseUrl: Uri.parse('https://api.example.com/v1'));
  /// deceiver.on.get('/users', jsonResponse(body: [])); // GET /v1/users
  /// ```
  ///
  /// Throws an [ArgumentError] if [baseUrl] has no scheme or host, or has a
  /// query or fragment.
  Deceiver({this.options = const DeceiverOptions(), this.baseUrl}) {
    final url = baseUrl;
    if (url != null &&
        (!url.hasScheme ||
            url.host.isEmpty ||
            url.hasQuery ||
            url.hasFragment)) {
      throw ArgumentError.value(
        url,
        'baseUrl',
        'Must have a scheme and host, and no query or fragment',
      );
    }
  }

  /// The URL that all mocks are relative to, or `null` to handle requests to
  /// any host.
  final Uri? baseUrl;

  /// Configuration options controlling mock behavior.
  ///
  /// Can be reassigned at runtime to change behavior (e.g. toggling
  /// [DeceiverOptions.onlyAllowMocks]).
  DeceiverOptions options;

  /// Global toggle to enable or disable all mocks at runtime.
  ///
  /// When `false`, all requests are forwarded to the real HTTP client
  /// regardless of registered mocks.
  bool enabled = true;

  final List<DeceiverData> _data = [];
  final Map<String, List<DeceiverData>> _scenarios = {};
  String? _activeScenario;

  /// Creates a [DeceiverClient] that intercepts HTTP requests.
  ///
  /// If [client] is provided, it is used as the underlying real HTTP client
  /// for forwarding unmatched requests. Otherwise, a default [Client] is used.
  DeceiverClient client([Client? client]) =>
      DeceiverClient(client ?? Client(), this);

  /// Returns a [DeceiverBuilder] for fluent mock registration.
  ///
  /// Mocks registered here are the **base mocks** -- always active unless
  /// overridden by a scenario mock.
  ///
  /// ```dart
  /// deceiver.on.get('/users', (req) => Response('[]', 200));
  /// deceiver.on.post('/users', (req) => Response('{"id": 1}', 201));
  /// ```
  DeceiverBuilder get on => DeceiverBuilder(this);

  /// Whether requests to [url] are handled by this [Deceiver].
  ///
  /// Always `true` without a [baseUrl]. Otherwise [url] must have the same
  /// scheme, host and port as [baseUrl], and a path under its path.
  bool appliesTo(Uri url) {
    final base = baseUrl;
    if (base == null) return true;
    if (url.scheme != base.scheme ||
        url.host != base.host ||
        url.port != base.port) {
      return false;
    }

    final baseSegments = base.pathSegments.where((s) => s.isNotEmpty).toList();
    final segments = url.pathSegments;
    if (segments.length < baseSegments.length) return false;
    for (var i = 0; i < baseSegments.length; i++) {
      if (segments[i] != baseSegments[i]) return false;
    }
    return true;
  }

  /// Registers a mock definition directly to the base mock list.
  void add(DeceiverData data) {
    _data.add(data);
  }

  /// Returns the list of base mock definitions.
  List<DeceiverData> get registrations => List.unmodifiable(_data);

  // ---------------------------------------------------------------------------
  // Scenarios
  // ---------------------------------------------------------------------------

  /// Defines a named scenario.
  ///
  /// The [configure] callback receives a [DeceiverBuilder] that writes mocks
  /// to the scenario's own list (not the base list). When the scenario is
  /// activated, its mocks take priority over base mocks.
  ///
  /// Calling [scenario] with an existing name replaces the previous
  /// definition.
  ///
  /// ```dart
  /// deceiver.scenario('happy', (on) {
  ///   on.get('/users', jsonResponse(body: [{'name': 'Bilbo'}]));
  ///   on.post('/users', jsonResponse(body: {'id': 1}, statusCode: 201));
  /// });
  ///
  /// deceiver.scenario('error', (on) {
  ///   on.get('/users', errorResponse(500, message: 'Server error'));
  /// });
  /// ```
  void scenario(String name, void Function(DeceiverBuilder on) configure) {
    final scenarioMocks = <DeceiverData>[];
    final builder = DeceiverBuilder.forList(scenarioMocks, baseUrl: baseUrl);
    configure(builder);
    _scenarios[name] = scenarioMocks;
  }

  /// Activates the scenario with the given [name].
  ///
  /// While active, the scenario's mocks are checked **before** base mocks.
  /// This means scenario mocks can override base mocks for the same endpoint.
  ///
  /// Throws [ArgumentError] if no scenario with [name] has been defined.
  void activateScenario(String name) {
    if (!_scenarios.containsKey(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'No scenario defined with this name. '
            'Available: ${_scenarios.keys.join(', ')}',
      );
    }
    _activeScenario = name;
  }

  /// Deactivates the current scenario, reverting to base mocks only.
  void deactivateScenario() {
    _activeScenario = null;
  }

  /// The name of the currently active scenario, or `null` if none is active.
  String? get activeScenario => _activeScenario;

  /// The list of defined scenario names.
  List<String> get scenarios => List.unmodifiable(_scenarios.keys);

  /// Returns the mock definitions for the given [scenarioName].
  ///
  /// Returns `null` if no scenario with that name exists.
  List<DeceiverData>? scenarioRegistrations(String scenarioName) {
    final mocks = _scenarios[scenarioName];
    return mocks != null ? List.unmodifiable(mocks) : null;
  }

  // ---------------------------------------------------------------------------
  // Response resolution
  // ---------------------------------------------------------------------------

  /// Attempts to find a matching mock for the given [request] and build the
  /// response.
  ///
  /// Resolution order:
  /// 1. If a scenario is active, its mocks are checked first.
  /// 2. Base mocks are checked next.
  ///
  /// Returns `null` if [enabled] is `false`, the request is outside
  /// [baseUrl] or no registered mock matches.
  Future<Response?> respond(Request request) async {
    if (!enabled || !appliesTo(request.url)) return null;

    // 1. Check active scenario mocks first.
    if (_activeScenario != null) {
      final scenarioMocks = _scenarios[_activeScenario];
      if (scenarioMocks != null) {
        for (final entry in scenarioMocks) {
          if (entry.isEnabled && entry.requestMatcher(request)) {
            return await entry.responseBuilder(request);
          }
        }
      }
    }

    // 2. Fall back to base mocks.
    for (final entry in _data) {
      if (entry.isEnabled && entry.requestMatcher(request)) {
        return await entry.responseBuilder(request);
      }
    }

    return null;
  }

  /// Returns a human-readable list of all registered mock definitions.
  ///
  /// Includes base mocks, scenario definitions, and the active scenario.
  String toPrettyPrintedString() {
    final buffer = StringBuffer();

    if (baseUrl != null) {
      buffer.writeln('Base URL: $baseUrl');
      buffer.writeln();
    }

    // Active scenario
    if (_activeScenario != null) {
      buffer.writeln('Active scenario: $_activeScenario');
      buffer.writeln();
    }

    // Base mocks
    buffer.writeln('Base mocks:');
    if (_data.isEmpty) {
      buffer.writeln('  (none)');
    } else {
      for (final d in _data) {
        final status = d.isEnabled ? 'enabled' : 'disabled';
        buffer.writeln('  ${d.description} ($status)');
      }
    }

    // Scenarios
    if (_scenarios.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Scenarios:');
      for (final entry in _scenarios.entries) {
        final active = entry.key == _activeScenario ? ' (active)' : '';
        buffer.writeln('  ${entry.key}$active:');
        for (final d in entry.value) {
          final status = d.isEnabled ? 'enabled' : 'disabled';
          buffer.writeln('    ${d.description} ($status)');
        }
      }
    }

    return buffer.toString().trimRight();
  }
}
