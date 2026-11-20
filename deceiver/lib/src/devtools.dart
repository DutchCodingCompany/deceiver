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

/// The id of [deceiver] in DevTools, or `null` if it isn't registered.
int? devToolsId(Deceiver deceiver) => _instanceIds[deceiver];

/// Tells DevTools that the settings of [deceiver] changed.
void postDevToolsChanged(Deceiver deceiver) {
  final id = _instanceIds[deceiver];
  if (id != null) _post('deceiver:changed', {'instance': id});
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

  for (final method in devToolsMethods) {
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

/// The service extension methods, without the `ext.deceiver.` prefix.
const devToolsMethods = [
  'getInstances',
  'getState',
  'setEnabled',
  'setOnlyAllowMocks',
  'setActiveScenario',
  'setMockEnabled',
  'setAllMocksEnabled',
  'getRequests',
  'clearRequests',
];

/// Handles a call to the service extension `ext.deceiver.<method>`.
///
/// Throws an [ArgumentError] for invalid parameters.
Map<String, Object?> handleDevToolsCall(
  String method,
  Map<String, String> params,
) {
  if (method == 'getInstances') {
    return {
      'instances': [
        for (final MapEntry(key: id, value: ref) in _instances.entries)
          if (ref.target case final deceiver?)
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
      throw ArgumentError.value(method, 'method', 'Unknown method');
  }
  return stateToJson(deceiver);
}

Deceiver _instance(Map<String, String> params) {
  final id = int.tryParse(params['instance'] ?? '');
  final deceiver = _instances[id]?.target;
  if (deceiver == null) {
    throw ArgumentError.value(params['instance'], 'instance', 'No Deceiver');
  }
  return deceiver;
}

bool _bool(Map<String, String> params, String name) => switch (params[name]) {
  'true' => true,
  'false' => false,
  final value => throw ArgumentError.value(value, name, 'Must be true/false'),
};

DeceiverData _mock(Deceiver deceiver, Map<String, String> params) {
  final id = int.tryParse(params['mock'] ?? '');
  final mocks = [
    ...deceiver.registrations,
    for (final name in deceiver.scenarios)
      ...?deceiver.scenarioRegistrations(name),
  ];
  for (final mock in mocks) {
    if (mockId(mock) == id) return mock;
  }
  throw ArgumentError.value(params['mock'], 'mock', 'No mock');
}

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
