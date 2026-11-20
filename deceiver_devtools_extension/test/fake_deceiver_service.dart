import 'dart:async';

import 'package:deceiver_devtools_extension/src/deceiver_service.dart';

/// A [DeceiverService] that answers like an app with one Deceiver.
class FakeDeceiverService implements DeceiverService {
  final _events = StreamController<DeceiverEvent>.broadcast(sync: true);
  final calls = <(String, Map<String, String>)>[];

  List<Map<String, Object?>> instances = [
    {'id': 1, 'name': 'API'},
  ];
  Map<String, Object?> state = fakeState();
  List<Map<String, Object?>> requests = [];

  @override
  Stream<DeceiverEvent> get events => _events.stream;

  void emit(String kind, [Map<String, Object?> data = const {}]) =>
      _events.add((kind: kind, data: data));

  @override
  Future<Map<String, Object?>> call(
    String method, [
    Map<String, String> params = const {},
  ]) async {
    calls.add((method, params));
    switch (method) {
      case 'getInstances':
        return {'instances': instances};
      case 'getRequests':
        return {'requests': requests};
      case 'clearRequests':
        requests = [];
        return {'requests': <Object?>[]};
      case 'setEnabled':
        state = {...state, 'enabled': params['enabled'] == 'true'};
      case 'setAllMocksEnabled':
        final enabled = params['enabled'] == 'true';
        Map<String, Object?> withEnabled(Object? mock) => {
          ...(mock as Map<String, Object?>),
          'enabled': enabled,
        };
        state = {
          ...state,
          'mocks': (state['mocks'] as List).map(withEnabled).toList(),
          'scenarios': [
            for (final scenario in state['scenarios'] as List)
              {
                ...(scenario as Map<String, Object?>),
                'mocks': (scenario['mocks'] as List).map(withEnabled).toList(),
              },
          ],
        };
      case 'setActiveScenario':
        state = {...state, 'activeScenario': params['scenario']};
    }
    return {...state, 'instance': int.parse(params['instance'] ?? '1')};
  }
}

Map<String, Object?> fakeState({bool enabled = true}) => {
  'instance': 1,
  'name': 'API',
  'baseUrl': 'https://api.x.com',
  'enabled': enabled,
  'onlyAllowMocks': false,
  'maxRecordedRequests': 2,
  'activeScenario': null,
  'mocks': [
    {
      'id': 10,
      'description': 'GET /users',
      'enabled': true,
      'baseUrl': null,
      'response': {
        'kind': 'json',
        'summary': '200 · JSON · 1 item',
        'statusCode': 200,
        'headers': {'content-type': 'application/json'},
        'body': '[{"name":"Bilbo"}]',
        'variants': <Object?>[],
      },
    },
  ],
  'scenarios': [
    {
      'name': 'error',
      'mocks': [
        {
          'id': 11,
          'description': 'GET /users',
          'enabled': true,
          'baseUrl': null,
          'response': {
            'kind': 'sequential',
            'summary': 'sequence: 200 → 500',
            'statusCode': null,
            'headers': <String, String>{},
            'body': null,
            'variants': [
              {
                'kind': 'empty',
                'summary': '200 · empty',
                'statusCode': 200,
                'headers': <String, String>{},
                'body': null,
                'variants': <Object?>[],
              },
              {
                'kind': 'error',
                'summary': '500 · error',
                'statusCode': 500,
                'headers': <String, String>{},
                'body': null,
                'variants': <Object?>[],
              },
            ],
          },
        },
      ],
    },
  ],
};

Map<String, Object?> fakeRequest(int id, {bool mocked = true}) => {
  'id': id,
  'timestamp': DateTime(2026, 11, 20, 10, 42, 3).millisecondsSinceEpoch,
  'method': 'GET',
  'url': 'https://api.x.com/users/$id',
  'requestHeaders': {'accept': 'application/json'},
  'requestBody': '',
  'mock': mocked ? {'id': 10, 'description': 'GET /users'} : null,
  'statusCode': mocked ? 200 : null,
  'responseHeaders': mocked ? {'content-type': 'application/json'} : null,
  'responseBody': mocked ? '{"name":"Bilbo"}' : null,
  'durationMicros': mocked ? 1500 : null,
  'error': null,
};
