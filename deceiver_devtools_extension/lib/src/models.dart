// The JSON shapes come from deceiver/lib/src/devtools.dart.

/// A `Deceiver` in the connected app.
class DeceiverInstance {
  DeceiverInstance({required this.id, required this.name});

  factory DeceiverInstance.fromJson(Map<String, Object?> json) =>
      DeceiverInstance(id: json['id'] as int, name: json['name'] as String?);

  final int id;
  final String? name;

  String get label => name ?? 'Deceiver #$id';
}

/// A registered mock.
class MockInfo {
  MockInfo({
    required this.id,
    required this.description,
    required this.enabled,
  });

  factory MockInfo.fromJson(Map<String, Object?> json) => MockInfo(
    id: json['id'] as int,
    description: json['description'] as String,
    enabled: json['enabled'] as bool,
  );

  final int id;
  final String description;
  final bool enabled;
}

/// A scenario and its mocks.
class ScenarioInfo {
  ScenarioInfo({required this.name, required this.mocks});

  factory ScenarioInfo.fromJson(Map<String, Object?> json) =>
      ScenarioInfo(name: json['name'] as String, mocks: _mocks(json['mocks']));

  final String name;
  final List<MockInfo> mocks;
}

/// The settings and mocks of a `Deceiver`.
class DeceiverState {
  DeceiverState({
    required this.instance,
    required this.baseUrl,
    required this.enabled,
    required this.onlyAllowMocks,
    required this.maxRecordedRequests,
    required this.activeScenario,
    required this.mocks,
    required this.scenarios,
  });

  factory DeceiverState.fromJson(Map<String, Object?> json) => DeceiverState(
    instance: json['instance'] as int,
    baseUrl: json['baseUrl'] as String?,
    enabled: json['enabled'] as bool,
    onlyAllowMocks: json['onlyAllowMocks'] as bool,
    maxRecordedRequests: json['maxRecordedRequests'] as int,
    activeScenario: json['activeScenario'] as String?,
    mocks: _mocks(json['mocks']),
    scenarios: [
      for (final scenario in json['scenarios'] as List)
        ScenarioInfo.fromJson((scenario as Map).cast()),
    ],
  );

  final int instance;
  final String? baseUrl;
  final bool enabled;
  final bool onlyAllowMocks;
  final int maxRecordedRequests;
  final String? activeScenario;
  final List<MockInfo> mocks;
  final List<ScenarioInfo> scenarios;
}

List<MockInfo> _mocks(Object? json) => [
  for (final mock in json as List) MockInfo.fromJson((mock as Map).cast()),
];

/// A request the `Deceiver` handled.
class RecordedRequest {
  RecordedRequest({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    required this.requestHeaders,
    required this.requestBody,
    required this.mockDescription,
    required this.statusCode,
    required this.responseHeaders,
    required this.responseBody,
    required this.duration,
    required this.error,
  });

  factory RecordedRequest.fromJson(Map<String, Object?> json) {
    final mock = json['mock'] as Map?;
    final durationMicros = json['durationMicros'] as int?;
    return RecordedRequest(
      id: json['id'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      method: json['method'] as String,
      url: Uri.parse(json['url'] as String),
      requestHeaders: _headers(json['requestHeaders']),
      requestBody: json['requestBody'] as String? ?? '',
      mockDescription: mock?['description'] as String?,
      statusCode: json['statusCode'] as int?,
      responseHeaders: _headers(json['responseHeaders']),
      responseBody: json['responseBody'] as String?,
      duration: durationMicros == null
          ? null
          : Duration(microseconds: durationMicros),
      error: json['error'] as String?,
    );
  }

  final int id;
  final DateTime timestamp;
  final String method;
  final Uri url;
  final Map<String, String> requestHeaders;
  final String requestBody;

  /// The description of the mock that answered, or `null` without a mock.
  final String? mockDescription;
  final int? statusCode;
  final Map<String, String> responseHeaders;
  final String? responseBody;
  final Duration? duration;
  final String? error;

  bool get isMocked => mockDescription != null;
}

Map<String, String> _headers(Object? json) =>
    json == null ? const {} : (json as Map).cast<String, String>();
