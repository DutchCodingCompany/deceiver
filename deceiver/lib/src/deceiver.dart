import 'dart:async';
import 'dart:collection';

import 'package:http/http.dart';

import 'deceiver_builder.dart';
import 'deceiver_client.dart';
import 'deceiver_data.dart';
import 'deceiver_exception.dart';
import 'devtools.dart';
import 'path_template.dart';

/// Configuration options for a [Deceiver] instance.
class DeceiverOptions {
  const DeceiverOptions({
    this.onlyAllowMocks = false,
    this.maxRecordedRequests = 100,
  });

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

  /// The maximum number of requests kept in [Deceiver.requests]. When the
  /// limit is reached, the oldest request is dropped. Set to `0` to not
  /// record requests at all.
  final int maxRecordedRequests;

  /// Returns a copy of these options with the given fields replaced.
  DeceiverOptions copyWith({bool? onlyAllowMocks, int? maxRecordedRequests}) =>
      DeceiverOptions(
        onlyAllowMocks: onlyAllowMocks ?? this.onlyAllowMocks,
        maxRecordedRequests: maxRecordedRequests ?? this.maxRecordedRequests,
      );
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
  /// and under its path, are handled, plus requests to the URLs of mocks
  /// registered with `on.at()` or with a full URL as path. Paths of mocks
  /// registered via [on] and [scenario] are relative to [baseUrl]. Other
  /// requests always go to the real HTTP client, even in strict mode, and are
  /// not recorded.
  ///
  /// ```dart
  /// final deceiver = Deceiver(baseUrl: Uri.parse('https://api.example.com/v1'));
  /// deceiver.on.get('/users', jsonResponse(body: [])); // GET /v1/users
  /// ```
  ///
  /// The [name] is shown in DevTools to tell instances apart.
  ///
  /// Throws an [ArgumentError] if [baseUrl] has no scheme or host, or has a
  /// query or fragment.
  Deceiver({this._options = const DeceiverOptions(), Uri? baseUrl, this.name})
    : _baseUrl = baseUrl {
    if (baseUrl != null) checkBaseUrl(baseUrl, 'baseUrl');
    registerForDevTools(this);
  }

  /// The name shown in DevTools, or `null` to show the [baseUrl].
  final String? name;

  /// The URL that mocks are relative to, or `null` to handle requests to any
  /// host. Change it with [reset].
  Uri? get baseUrl => _baseUrl;
  Uri? _baseUrl;

  /// Configuration options controlling mock behavior.
  ///
  /// Can be reassigned at runtime to change behavior (e.g. toggling
  /// [DeceiverOptions.onlyAllowMocks]).
  DeceiverOptions get options => _options;
  DeceiverOptions _options;

  set options(DeceiverOptions value) {
    _options = value;
    _notifyListeners();
  }

  /// Global toggle to enable or disable all mocks at runtime.
  ///
  /// When `false`, all requests are forwarded to the real HTTP client
  /// regardless of registered mocks.
  bool get enabled => _enabled;
  bool _enabled = true;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _notifyListeners();
  }

  final List<void Function()> _listeners = [];

  /// Registers [listener] to be called when the mock settings change: the
  /// [enabled] flag, the [options], the registered mocks and scenarios, the
  /// active scenario, a [DeceiverData.isEnabled] flag, or a [reset].
  ///
  /// Recorded [requests] don't call the listeners.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Removes a listener registered with [addListener].
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
    postDevToolsChanged(this);
  }

  final List<DeceiverData> _data = [];
  final Map<String, List<DeceiverData>> _scenarios = {};
  String? _activeScenario;
  final _requests = ListQueue<DeceiverRecordedRequest>();

  /// Raised when the recorded requests are removed, so that requests that
  /// were still being answered at that moment are not recorded afterwards.
  var _requestsGeneration = 0;

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
  /// Always `true` without a [baseUrl]. Otherwise [url] must be under
  /// [baseUrl], or under the [DeceiverData.baseUrl] of a registered mock
  /// (in the base mocks or any scenario): it must have the same scheme, host
  /// and port, and a path under its path.
  bool appliesTo(Uri url) {
    final base = baseUrl;
    if (base == null || isUnderBaseUrl(url, base)) return true;

    return [
      ..._data,
      for (final mocks in _scenarios.values) ...mocks,
    ].any((mock) => mock.baseUrl != null && isUnderBaseUrl(url, mock.baseUrl!));
  }

  /// Registers a mock definition directly to the base mock list.
  void add(DeceiverData data) {
    setMockOnChanged(data, _notifyListeners);
    _data.add(data);
    _notifyListeners();
  }

  /// Sets [DeceiverData.isEnabled] of every mock: the base mocks and the
  /// mocks of all scenarios. Notifies the listeners once.
  ///
  /// For example, turn all mocks off and then only the one you need on:
  ///
  /// ```dart
  /// deceiver.setAllMocksEnabled(false);
  /// deceiver.registrations.first.isEnabled = true;
  /// ```
  void setAllMocksEnabled(bool enabled) {
    var changed = false;
    for (final mock in [
      ..._data,
      for (final mocks in _scenarios.values) ...mocks,
    ]) {
      changed = setMockEnabledQuietly(mock, enabled) || changed;
    }
    if (changed) _notifyListeners();
  }

  /// Returns the list of base mock definitions.
  List<DeceiverData> get registrations => List.unmodifiable(_data);

  /// Removes all base mocks, scenarios and recorded requests, and
  /// deactivates the active scenario.
  ///
  /// Pass [baseUrl] to change [baseUrl], for example when the app switches
  /// to another environment. Register the mocks again afterwards:
  ///
  /// ```dart
  /// deceiver.reset(baseUrl: env.apiUrl);
  /// registerMocks(deceiver, env);
  /// ```
  ///
  /// [options] and [enabled] are kept. Clients created with [client] keep
  /// working with the new mocks.
  ///
  /// Throws an [ArgumentError] if [baseUrl] has no scheme or host, or has a
  /// query or fragment.
  void reset({Uri? baseUrl}) {
    if (baseUrl != null) {
      checkBaseUrl(baseUrl, 'baseUrl');
      _baseUrl = baseUrl;
    }
    _data.clear();
    _scenarios.clear();
    _activeScenario = null;
    _requests.clear();
    _requestsGeneration++;
    _notifyListeners();
    postDevToolsRequestsCleared(this);
  }

  // ---------------------------------------------------------------------------
  // Recorded requests
  // ---------------------------------------------------------------------------

  /// The requests this [Deceiver] handled, in the order they were answered.
  ///
  /// Each entry has the mock that answered it, or `null` if no mock matched,
  /// and the response of the mock.
  /// Keeps at most [DeceiverOptions.maxRecordedRequests] requests. Requests
  /// sent while [enabled] is `false` or outside [baseUrl] are not recorded,
  /// nor requests that were still being answered when [clearRequests] or
  /// [reset] was called.
  ///
  /// ```dart
  /// final posts = deceiver.requests.where(
  ///   (r) => r.request.method == 'POST' && r.request.url.path == '/users',
  /// );
  /// expect(posts, hasLength(1));
  /// ```
  List<DeceiverRecordedRequest> get requests => List.unmodifiable(_requests);

  /// Removes all recorded [requests].
  void clearRequests() {
    _requests.clear();
    _requestsGeneration++;
    postDevToolsRequestsCleared(this);
  }

  /// Records [recorded], unless the requests were removed since
  /// [generation].
  void _record(DeceiverRecordedRequest recorded, int generation) {
    if (generation != _requestsGeneration) return;
    final max = options.maxRecordedRequests;
    if (max <= 0) return;
    _requests.addLast(recorded);
    while (_requests.length > max) {
      _requests.removeFirst();
    }
    postDevToolsRequest(this, recorded);
  }

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
    for (final mock in scenarioMocks) {
      setMockOnChanged(mock, _notifyListeners);
    }
    _scenarios[name] = scenarioMocks;
    _notifyListeners();
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
    if (_activeScenario == name) return;
    _activeScenario = name;
    _notifyListeners();
  }

  /// Deactivates the current scenario, reverting to base mocks only.
  void deactivateScenario() {
    if (_activeScenario == null) return;
    _activeScenario = null;
    _notifyListeners();
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
  Future<Response?> respond(Request request) => _respond(request);

  Future<Response?> _respond(
    Request request, {
    DeceiverException Function()? onNoMock,
  }) async {
    if (!enabled || !appliesTo(request.url)) return null;

    final timestamp = DateTime.now();
    final generation = _requestsGeneration;
    final mock = _findMock(request);
    if (mock == null) {
      final error = onNoMock?.call();
      _record(
        DeceiverRecordedRequest(
          request: request,
          mock: null,
          timestamp: timestamp,
          error: error,
        ),
        generation,
      );
      if (error != null) throw error;
      return null;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await mock.responseBuilder(request);
      _record(
        DeceiverRecordedRequest(
          request: request,
          mock: mock,
          timestamp: timestamp,
          response: response,
          duration: stopwatch.elapsed,
        ),
        generation,
      );
      return response;
    } catch (error) {
      _record(
        DeceiverRecordedRequest(
          request: request,
          mock: mock,
          timestamp: timestamp,
          duration: stopwatch.elapsed,
          error: error,
        ),
        generation,
      );
      rethrow;
    }
  }

  DeceiverData? _findMock(Request request) {
    final candidates = [..._scenarios[_activeScenario] ?? const [], ..._data];
    for (final entry in candidates) {
      if (entry.isEnabled && entry.requestMatcher(request)) return entry;
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

/// Like [Deceiver.respond], but throws the error of [onNoMock] when no mock
/// matches, and records that error with the request.
Future<Response?> respondOrThrow(
  Deceiver deceiver,
  Request request, {
  DeceiverException Function()? onNoMock,
}) => deceiver._respond(request, onNoMock: onNoMock);
