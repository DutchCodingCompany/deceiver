import 'package:deceiver/deceiver.dart';
import 'package:deceiver/src/devtools.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  late List<(String, Map<String, Object?>)> events;

  setUp(() {
    events = [];
    devToolsListening = () => true;
    devToolsPostEvent = (kind, data) => events.add((kind, data));
  });

  tearDown(() {
    devToolsListening = () => false;
  });

  Map<String, Object?> call(
    String method,
    Deceiver deceiver, [
    Map<String, String> params = const {},
  ]) => handleDevToolsCall(method, {'instance': '${_id(deceiver)}', ...params});

  group('getInstances', () {
    test('lists living instances with their name or base URL', () {
      final named = Deceiver(name: 'Auth');
      final withBaseUrl = Deceiver(baseUrl: Uri.parse('https://api.x.com'));

      final instances =
          handleDevToolsCall('getInstances', {})['instances'] as List;

      expect(instances, contains(equals({'id': _id(named), 'name': 'Auth'})));
      expect(
        instances,
        contains(equals({'id': _id(withBaseUrl), 'name': 'https://api.x.com'})),
      );
    });

    test('tells DevTools about a new instance', () {
      Deceiver();

      expect(events.map((e) => e.$1), contains('deceiver:instancesChanged'));
    });
  });

  group('getState', () {
    test('returns the settings, mocks and scenarios', () {
      final deceiver = Deceiver();
      deceiver.on.get('/users', jsonResponse());
      deceiver.scenario('error', (on) => on.get('/users', errorResponse(500)));
      deceiver.activateScenario('error');

      final state = call('getState', deceiver);

      expect(state['enabled'], isTrue);
      expect(state['onlyAllowMocks'], isFalse);
      expect(state['activeScenario'], 'error');
      final mock = (state['mocks'] as List).single as Map;
      expect(mock['id'], isA<int>());
      expect(mock['description'], 'GET /users');
      expect(mock['enabled'], isTrue);
      final [scenario] = state['scenarios'] as List;
      expect(scenario['name'], 'error');
      final scenarioMock = (scenario['mocks'] as List).single as Map;
      expect(scenarioMock['response']['summary'], '500 · error');
    });

    test('includes what each mock responds', () {
      final deceiver = Deceiver();
      deceiver.on.get('/users', jsonResponse(body: ['Bilbo']));

      final mock = (call('getState', deceiver)['mocks'] as List).single as Map;

      expect(mock['response'], {
        'kind': 'json',
        'summary': '200 · JSON · 1 item',
        'statusCode': 200,
        'headers': {'content-type': 'application/json'},
        'body': '["Bilbo"]',
        'variants': <Object?>[],
      });
    });

    test('throws for an unknown instance', () {
      expect(
        () => handleDevToolsCall('getState', {'instance': '-1'}),
        throwsArgumentError,
      );
    });
  });

  group('setters', () {
    test('setEnabled and setOnlyAllowMocks change the settings', () {
      final deceiver = Deceiver();

      call('setEnabled', deceiver, {'enabled': 'false'});
      final state = call('setOnlyAllowMocks', deceiver, {'enabled': 'true'});

      expect(deceiver.enabled, isFalse);
      expect(deceiver.options.onlyAllowMocks, isTrue);
      expect(state['enabled'], isFalse);
      expect(state['onlyAllowMocks'], isTrue);
    });

    test('rejects invalid booleans', () {
      final deceiver = Deceiver();

      expect(
        () => call('setEnabled', deceiver, {'enabled': 'yes'}),
        throwsArgumentError,
      );
    });

    test('setActiveScenario activates and deactivates', () {
      final deceiver = Deceiver();
      deceiver.scenario('error', (on) {});

      call('setActiveScenario', deceiver, {'scenario': 'error'});
      expect(deceiver.activeScenario, 'error');

      call('setActiveScenario', deceiver);
      expect(deceiver.activeScenario, isNull);
    });

    test('setMockEnabled toggles base and scenario mocks', () {
      final deceiver = Deceiver();
      deceiver.on.get('/users', jsonResponse());
      deceiver.scenario('s', (on) => on.get('/posts', jsonResponse()));
      final state = call('getState', deceiver);
      final baseId = (state['mocks'] as List).single['id'];
      final scenarioMocks = (state['scenarios'] as List).single['mocks'];
      final scenarioId = (scenarioMocks as List).single['id'];

      call('setMockEnabled', deceiver, {'mock': '$baseId', 'enabled': 'false'});
      call('setMockEnabled', deceiver, {
        'mock': '$scenarioId',
        'enabled': 'false',
      });

      expect(deceiver.registrations.single.isEnabled, isFalse);
      expect(deceiver.scenarioRegistrations('s')!.single.isEnabled, isFalse);
    });

    test('setAllMocksEnabled toggles every mock', () {
      final deceiver = Deceiver();
      deceiver.on.get('/users', jsonResponse());
      deceiver.scenario('s', (on) => on.get('/posts', jsonResponse()));

      final state = call('setAllMocksEnabled', deceiver, {'enabled': 'false'});

      expect(deceiver.registrations.single.isEnabled, isFalse);
      expect(deceiver.scenarioRegistrations('s')!.single.isEnabled, isFalse);
      expect(((state['mocks'] as List).single as Map)['enabled'], isFalse);
    });

    test('tells DevTools that the settings changed', () {
      final deceiver = Deceiver();
      events.clear();

      deceiver.enabled = false;

      final (kind, data) = events.single;
      expect(kind, 'deceiver:changed');
      expect(data, {'instance': _id(deceiver)});
    });
  });

  group('requests', () {
    test('getRequests returns the recorded requests', () async {
      final deceiver = Deceiver();
      deceiver.on.post('/users', jsonResponse(body: {'id': 1}));
      final client = deceiver.client(
        MockClient((request) async => Response('real', 200)),
      );
      await client.post(Uri.parse('https://x.com/users'), body: 'Bilbo');
      await client.get(Uri.parse('https://x.com/other'));

      final requests = call('getRequests', deceiver)['requests'] as List;

      final [mocked, passthrough] = requests.cast<Map<String, Object?>>();
      expect(mocked['method'], 'POST');
      expect(mocked['url'], 'https://x.com/users');
      expect(mocked['requestBody'], 'Bilbo');
      expect(mocked['mock'], {'id': isA<int>(), 'description': 'POST /users'});
      expect(mocked['statusCode'], 200);
      expect(mocked['responseBody'], '{"id":1}');
      expect(mocked['durationMicros'], isA<int>());
      expect(passthrough['mock'], isNull);
      expect(passthrough['statusCode'], isNull);
      expect(passthrough['responseBody'], isNull);
    });

    test('pushes each new request to DevTools', () async {
      final deceiver = Deceiver();
      deceiver.on.get('/users', jsonResponse());

      await deceiver.client().get(Uri.parse('https://x.com/users'));

      final (kind, data) = events.last;
      expect(kind, 'deceiver:request');
      expect(data['instance'], _id(deceiver));
      expect((data['request'] as Map)['url'], 'https://x.com/users');
    });

    test('the pushed request has the same id as in getRequests', () async {
      final deceiver = Deceiver();
      deceiver.on.get('/users', jsonResponse());

      await deceiver.client().get(Uri.parse('https://x.com/users'));

      final pushed = events.last.$2['request'] as Map;
      final fetched =
          (call('getRequests', deceiver)['requests'] as List).single;
      expect(fetched['id'], pushed['id']);
    });

    test('clearRequests clears and tells DevTools', () async {
      final deceiver = Deceiver();
      deceiver.on.get('/users', jsonResponse());
      await deceiver.client().get(Uri.parse('https://x.com/users'));

      call('clearRequests', deceiver);

      expect(deceiver.requests, isEmpty);
      final (kind, data) = events.last;
      expect(kind, 'deceiver:requestsCleared');
      expect(data, {'instance': _id(deceiver)});
    });

    test('truncates long bodies', () async {
      final deceiver = Deceiver();
      deceiver.on.get('/big', (req) => Response('x' * 70000, 200));

      await deceiver.client().get(Uri.parse('https://x.com/big'));

      final request =
          (call('getRequests', deceiver)['requests'] as List).single;
      final body = request['responseBody'] as String;
      expect(body, startsWith('x' * maxDevToolsBodyLength));
      expect(body, endsWith('(truncated, 70000 bytes in total)'));
    });

    test('pushes nothing while DevTools is not listening', () async {
      devToolsListening = () => false;
      final deceiver = Deceiver();
      deceiver.on.get('/users', jsonResponse());

      await deceiver.client().get(Uri.parse('https://x.com/users'));

      expect(events, isEmpty);
    });
  });

  group('help', () {
    test('lists every method with its parameters, and the events', () {
      final help = handleDevToolsCall('help', {});

      final methods = help['methods'] as Map;
      expect(
        methods.keys,
        devToolsMethods.keys.map((name) => 'ext.deceiver.$name'),
      );
      expect(
        (methods['ext.deceiver.setMockEnabled'] as Map)['params'],
        containsPair('description', isA<String>()),
      );
      expect(help['instance'], contains('may be left out'));
      expect(help['events'], contains('deceiver:request'));
    });
  });

  group('instance', () {
    setUp(resetDevToolsInstancesForTesting);

    test('may be left out with one Deceiver', () {
      final deceiver = Deceiver();

      handleDevToolsCall('setEnabled', {'enabled': 'false'});

      expect(deceiver.enabled, isFalse);
    });

    test('is required with more Deceivers, listing them', () {
      Deceiver(name: 'API');
      Deceiver(name: 'Auth');

      expect(
        () => handleDevToolsCall('getState', {}),
        throwsA(
          isArgumentError.having(
            (e) => e.message,
            'message',
            allOf(
              contains('2 Deceivers'),
              contains('(API)'),
              contains('(Auth)'),
            ),
          ),
        ),
      );
    });

    test('explains when the app has no Deceiver yet', () {
      expect(
        () => handleDevToolsCall('getState', {}),
        throwsA(
          isArgumentError.having(
            (e) => e.message,
            'message',
            contains('not created a Deceiver'),
          ),
        ),
      );
    });
  });

  group('setMockEnabled by description', () {
    late Deceiver deceiver;

    setUp(() {
      resetDevToolsInstancesForTesting();
      deceiver = Deceiver();
      deceiver.on.get('/users', jsonResponse());
      deceiver.on.get('/posts', jsonResponse());
      deceiver.scenario('error', (on) {
        on.get('/users', errorResponse(500));
        on.get('/orders', errorResponse(500));
      });
    });

    Matcher error(String text) => throwsA(
      isArgumentError.having((e) => e.message, 'message', contains(text)),
    );

    test('finds a base mock, ignoring case', () {
      handleDevToolsCall('setMockEnabled', {
        'description': 'get /users',
        'enabled': 'false',
      });

      expect(deceiver.registrations.first.isEnabled, isFalse);
      expect(deceiver.scenarioRegistrations('error')!.first.isEnabled, isTrue);
    });

    test('finds a scenario mock with scenario', () {
      handleDevToolsCall('setMockEnabled', {
        'description': 'GET /users',
        'scenario': 'error',
        'enabled': 'false',
      });

      expect(deceiver.registrations.first.isEnabled, isTrue);
      expect(deceiver.scenarioRegistrations('error')!.first.isEnabled, isFalse);
    });

    test('lists the mocks and hints at the scenario when not found', () {
      expect(
        () => handleDevToolsCall('setMockEnabled', {
          'description': 'GET /orders',
          'enabled': 'false',
        }),
        allOf(error('"GET /posts"'), error('in scenario error: pass scenario')),
      );
    });

    test('asks for an id when the description is ambiguous', () {
      deceiver.on.get('/users', errorResponse(404));

      expect(
        () => handleDevToolsCall('setMockEnabled', {
          'description': 'GET /users',
          'enabled': 'false',
        }),
        error('2 mocks "GET /users"'),
      );
    });

    test('explains an unknown scenario', () {
      expect(
        () => handleDevToolsCall('setMockEnabled', {
          'description': 'GET /users',
          'scenario': 'nope',
          'enabled': 'false',
        }),
        error('Scenarios: error'),
      );
    });
  });
}

int _id(Deceiver deceiver) => devToolsId(deceiver)!;
