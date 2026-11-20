import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'deceiver.dart';
import 'deceiver_data.dart';
import 'deceiver_response_info.dart';

// The DevTools extension (deceiver_devtools_extension) talks to the app via
// the `ext.deceiver.*` service extensions below, and listens to the
// `deceiver:*` events on the Extension stream.

const _isProduct = bool.fromEnvironment('dart.vm.product');
const _extensionPrefix = 'ext.deceiver.';

/// Bodies longer than this are truncated before they are sent to DevTools.
const maxDevToolsBodyLength = 64 * 1024;

final _instances = <int, WeakReference<Deceiver>>{};
final _instanceIds = Expando<int>();
var _nextInstanceId = 0;
final _requestIds = Expando<int>();
var _nextRequestId = 0;
var _extensionsRegistered = false;
final _changedPending = <int>{};

/// Whether DevTools listens to events. Replaced in tests.
bool Function() devToolsListening = () => developer.extensionStreamHasListener;

/// Sends an event to DevTools. Replaced in tests.
void Function(String kind, Map<String, Object?> data) devToolsPostEvent =
    developer.postEvent;

/// Makes [deceiver] available in DevTools.
void registerForDevTools(Deceiver deceiver) {
  if (_isProduct) return;
  _registerExtensions();

  _instances.removeWhere((_, ref) => ref.target == null);
  final id = _nextInstanceId++;
  _instanceIds[deceiver] = id;
  _instances[id] = WeakReference(deceiver);
  _post('deceiver:instancesChanged', {});
}

/// Forgets all registered Deceivers. Only for tests.
void resetDevToolsInstancesForTesting() => _instances.clear();

/// The id of [deceiver] in DevTools, or `null` if it isn't registered.
int? devToolsId(Deceiver deceiver) => _instanceIds[deceiver];

/// Tells DevTools that the settings of [deceiver] changed.
///
/// Changes in a row, such as registering all mocks at startup, are sent as
/// one event, because DevTools loads the whole state for each event.
void postDevToolsChanged(Deceiver deceiver) {
  final id = _instanceIds[deceiver];
  if (id == null || !devToolsListening() || !_changedPending.add(id)) return;
  scheduleMicrotask(() {
    _changedPending.remove(id);
    _post('deceiver:changed', {'instance': id});
  });
}

/// Tells DevTools that [deceiver] recorded [recorded].
void postDevToolsRequest(Deceiver deceiver, DeceiverRecordedRequest recorded) {
  final id = _instanceIds[deceiver];
  if (id == null || !devToolsListening()) return;
  devToolsPostEvent('deceiver:request', {
    'instance': id,
    'request': requestToJson(recorded),
  });
}

/// Tells DevTools that the recorded requests of [deceiver] were removed.
void postDevToolsRequestsCleared(Deceiver deceiver) {
  final id = _instanceIds[deceiver];
  if (id != null) _post('deceiver:requestsCleared', {'instance': id});
}

void _post(String kind, Map<String, Object?> data) {
  if (devToolsListening()) devToolsPostEvent(kind, data);
}

void _registerExtensions() {
  if (_extensionsRegistered) return;
  _extensionsRegistered = true;

  for (final method in devToolsMethods.keys) {
    developer.registerExtension('$_extensionPrefix$method', (_, params) async {
      try {
        final result = handleDevToolsCall(method, params);
        return developer.ServiceExtensionResponse.result(jsonEncode(result));
      } on ArgumentError catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          '${e.message}',
        );
      }
    });
  }
}

/// The service extension methods, without the `ext.deceiver.` prefix, with
/// their description and parameters. Returned by `ext.deceiver.help`.
///
/// Keep the README section "Controlling Deceiver from tools and AI agents"
/// and skills/deceiver in sync with this.
const devToolsMethods =
    <String, ({String description, Map<String, String> params})>{
      'help': (
        description: 'Lists these methods, their parameters and the events.',
        params: {},
      ),
      'getInstances': (
        description: 'Lists the Deceivers in the app: id and name.',
        params: {},
      ),
      'getState': (
        description:
            'The settings, the base mocks and the scenarios with their mocks. '
            'Each mock has an id, description, enabled flag and response info.',
        params: {},
      ),
      'setEnabled': (
        description:
            'Turns all mocking on or off. When off, every request goes to the '
            'real server; the mocks keep their own enabled flag.',
        params: {'enabled': 'true or false'},
      ),
      'setOnlyAllowMocks': (
        description:
            'Strict mode: when on, requests without a mock throw a '
            'DeceiverException instead of going to the real server.',
        params: {'enabled': 'true or false'},
      ),
      'setActiveScenario': (
        description:
            'Activates a scenario, whose mocks then override the base mocks. '
            'Leave out scenario to deactivate.',
        params: {'scenario': 'scenario name (optional)'},
      ),
      'setMockEnabled': (
        description:
            'Turns one mock on or off. Pass mock, or description with an '
            'optional scenario.',
        params: {
          'enabled': 'true or false',
          'mock': 'mock id from getState',
          'description': 'mock description, such as "GET /users/{id}"',
          'scenario':
              'with description: the scenario of the mock (optional, default '
              'the base mocks)',
        },
      ),
      'setAllMocksEnabled': (
        description:
            'Turns every mock on or off, base and scenario mocks alike. For '
            'example turn all off, then only the one you need on.',
        params: {'enabled': 'true or false'},
      ),
      'getRequests': (
        description:
            'The handled requests, oldest first: method, url, headers, body, '
            'the mock that answered (null: no mock), status code, response body, '
            'duration and error.',
        params: {},
      ),
      'clearRequests': (
        description: 'Removes the recorded requests.',
        params: {},
      ),
    };

const _instanceParam =
    'Every method except help and getInstances takes instance, the id '
    'from getInstances. It may be left out when the app has one Deceiver.';

const _events = {
  'deceiver:instancesChanged': 'A Deceiver was created.',
  'deceiver:changed': 'The settings or mocks of instance changed.',
  'deceiver:request': 'instance handled request (as in getRequests).',
  'deceiver:requestsCleared': 'The requests of instance were removed.',
};

/// Handles a call to the service extension `ext.deceiver.<method>`.
///
/// Throws an [ArgumentError] for invalid parameters.
Map<String, Object?> handleDevToolsCall(
  String method,
  Map<String, String> params,
) {
  switch (method) {
    case 'help':
      return {
        'methods': {
          for (final MapEntry(key: name, value: spec)
              in devToolsMethods.entries)
            'ext.deceiver.$name': {
              'description': spec.description,
              'params': spec.params,
            },
        },
        'instance': _instanceParam,
        'events': _events,
      };
    case 'getInstances':
      return {
        'instances': [
          for (final (id, deceiver) in _living())
            {'id': id, 'name': deceiver.name ?? deceiver.baseUrl?.toString()},
        ],
      };
  }

  final deceiver = _instance(params);
  switch (method) {
    case 'getState':
      break;
    case 'setEnabled':
      deceiver.enabled = _bool(params, 'enabled');
    case 'setOnlyAllowMocks':
      deceiver.options = deceiver.options.copyWith(
        onlyAllowMocks: _bool(params, 'enabled'),
      );
    case 'setActiveScenario':
      final name = params['scenario'];
      if (name == null || name.isEmpty) {
        deceiver.deactivateScenario();
      } else {
        deceiver.activateScenario(name);
      }
    case 'setMockEnabled':
      _mock(deceiver, params).isEnabled = _bool(params, 'enabled');
    case 'setAllMocksEnabled':
      deceiver.setAllMocksEnabled(_bool(params, 'enabled'));
    case 'getRequests':
      return {'requests': deceiver.requests.map(requestToJson).toList()};
    case 'clearRequests':
      deceiver.clearRequests();
      return {'requests': <Object?>[]};
    default:
      throw ArgumentError(
        'Unknown method $method. Call ext.deceiver.help for the methods.',
      );
  }
  return stateToJson(deceiver);
}

List<(int, Deceiver)> _living() => [
  for (final MapEntry(key: id, value: ref) in _instances.entries)
    if (ref.target case final deceiver?) (id, deceiver),
];

Deceiver _instance(Map<String, String> params) {
  final living = _living();
  final param = params['instance'];
  if (param == null || param.isEmpty) {
    return switch (living) {
      [(_, final deceiver)] => deceiver,
      [] => throw ArgumentError('The app has not created a Deceiver yet.'),
      _ => throw ArgumentError(
        'The app has ${living.length} Deceivers, pass instance: '
        '${_describeInstances(living)}.',
      ),
    };
  }
  final id = int.tryParse(param);
  for (final (livingId, deceiver) in living) {
    if (livingId == id) return deceiver;
  }
  throw ArgumentError(
    'No Deceiver with instance $param. Instances: '
    '${_describeInstances(living)}.',
  );
}

String _describeInstances(List<(int, Deceiver)> living) => living
    .map((e) => '${e.$1} (${e.$2.name ?? e.$2.baseUrl ?? 'no name'})')
    .join(', ');

bool _bool(Map<String, String> params, String name) => switch (params[name]) {
  'true' => true,
  'false' => false,
  final value => throw ArgumentError(
    'Parameter $name must be true or false, got ${value ?? 'nothing'}.',
  ),
};

DeceiverData _mock(Deceiver deceiver, Map<String, String> params) {
  if (params['mock'] case final idParam?) {
    final id = int.tryParse(idParam);
    for (final mock in _allMocks(deceiver)) {
      if (mockId(mock) == id) return mock;
    }
    throw ArgumentError('No mock with id $idParam. Call getState for the ids.');
  }

  final description = params['description']?.trim();
  if (description == null || description.isEmpty) {
    throw ArgumentError('Pass mock (an id) or description.');
  }
  final scenario = params['scenario'];
  final List<DeceiverData> scope;
  if (scenario == null || scenario.isEmpty) {
    scope = deceiver.registrations;
  } else {
    scope =
        deceiver.scenarioRegistrations(scenario) ??
        (throw ArgumentError(
          'No scenario $scenario. Scenarios: ${deceiver.scenarios.join(', ')}.',
        ));
  }
  final matches = [
    for (final mock in scope)
      if (mock.description.toLowerCase() == description.toLowerCase()) mock,
  ];
  final where = scenario == null || scenario.isEmpty
      ? 'the base mocks'
      : 'scenario $scenario';
  return switch (matches) {
    [final mock] => mock,
    [] => throw ArgumentError(
      'No mock "$description" in $where. Mocks there: '
      '${scope.map((m) => '"${m.description}"').join(', ')}.'
      '${_inScenarios(deceiver, description)}',
    ),
    _ => throw ArgumentError(
      '${matches.length} mocks "$description" in $where, pass mock with one '
      'of the ids: ${matches.map(mockId).join(', ')}.',
    ),
  };
}

/// A hint naming the scenarios that have a mock with [description].
String _inScenarios(Deceiver deceiver, String description) {
  final scenarios = [
    for (final name in deceiver.scenarios)
      if (deceiver
          .scenarioRegistrations(name)!
          .any((m) => m.description.toLowerCase() == description.toLowerCase()))
        name,
  ];
  if (scenarios.isEmpty) return '';
  return ' It is in scenario ${scenarios.join(', ')}: pass scenario.';
}

List<DeceiverData> _allMocks(Deceiver deceiver) => [
  ...deceiver.registrations,
  for (final name in deceiver.scenarios)
    ...?deceiver.scenarioRegistrations(name),
];

/// The settings and mocks of [deceiver], as sent to DevTools.
Map<String, Object?> stateToJson(Deceiver deceiver) => {
  'instance': _instanceIds[deceiver],
  'name': deceiver.name,
  'baseUrl': deceiver.baseUrl?.toString(),
  'enabled': deceiver.enabled,
  'onlyAllowMocks': deceiver.options.onlyAllowMocks,
  'maxRecordedRequests': deceiver.options.maxRecordedRequests,
  'activeScenario': deceiver.activeScenario,
  'mocks': deceiver.registrations.map(_mockToJson).toList(),
  'scenarios': [
    for (final name in deceiver.scenarios)
      {
        'name': name,
        'mocks': deceiver
            .scenarioRegistrations(name)!
            .map(_mockToJson)
            .toList(),
      },
  ],
};

Map<String, Object?> _mockToJson(DeceiverData mock) => {
  'id': mockId(mock),
  'description': mock.description,
  'enabled': mock.isEnabled,
  'baseUrl': mock.baseUrl?.toString(),
  'response': _responseInfoToJson(mock.responseInfo),
};

Map<String, Object?> _responseInfoToJson(DeceiverResponseInfo info) => {
  'kind': info.kind.name,
  'summary': info.summary,
  'statusCode': info.statusCode,
  'headers': info.headers,
  'body': info.body == null ? null : _body(utf8.encode(info.body!)),
  'variants': info.variants.map(_responseInfoToJson).toList(),
};

/// A recorded request, as sent to DevTools.
Map<String, Object?> requestToJson(DeceiverRecordedRequest recorded) {
  final request = recorded.request;
  final response = recorded.response;
  final mock = recorded.mock;
  return {
    'id': _requestIds[recorded] ??= _nextRequestId++,
    'timestamp': recorded.timestamp.millisecondsSinceEpoch,
    'method': request.method,
    'url': request.url.toString(),
    'requestHeaders': request.headers,
    'requestBody': _body(request.bodyBytes),
    'mock': mock == null
        ? null
        : {'id': mockId(mock), 'description': mock.description},
    'statusCode': response?.statusCode,
    'responseHeaders': response?.headers,
    'responseBody': response == null ? null : _body(response.bodyBytes),
    'durationMicros': recorded.duration?.inMicroseconds,
    'error': recorded.error?.toString(),
  };
}

String _body(List<int> bytes) {
  if (bytes.length <= maxDevToolsBodyLength) {
    return utf8.decode(bytes, allowMalformed: true);
  }
  final start = utf8.decode(
    bytes.sublist(0, maxDevToolsBodyLength),
    allowMalformed: true,
  );
  return '$start\n… (truncated, ${bytes.length} bytes in total)';
}
