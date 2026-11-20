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
      expect(state['mocks'], [
        {'id': isA<int>(), 'description': 'GET /users', 'enabled': true},
      ]);
      expect(state['scenarios'], [
        {
          'name': 'error',
          'mocks': [
            {'id': isA<int>(), 'description': 'GET /users', 'enabled': true},
          ],
        },
      ]);
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
}

int _id(Deceiver deceiver) => devToolsId(deceiver)!;
