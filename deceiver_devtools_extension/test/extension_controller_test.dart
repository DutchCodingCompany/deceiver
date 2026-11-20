import 'package:deceiver_devtools_extension/src/deceiver_service.dart';
import 'package:deceiver_devtools_extension/src/extension_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_deceiver_service.dart';

void main() {
  late FakeDeceiverService service;
  late ExtensionController controller;

  setUp(() {
    service = FakeDeceiverService();
    controller = ExtensionController(service);
  });

  test('loads the first instance with its state and requests', () async {
    service.requests = [fakeRequest(1)];

    await controller.loadInstances();

    expect(controller.instances.single.label, 'API');
    expect(controller.state?.instance, 1);
    expect(controller.state?.mocks.single.description, 'GET /users');
    expect(controller.requests.single.statusCode, 200);
    expect(controller.error, isNull);
  });

  test('shows no state without instances', () async {
    service.instances = [];

    await controller.loadInstances();

    expect(controller.state, isNull);
  });

  test('loads the instances when the extensions appear', () async {
    service.emit(instancesChangedEvent);
    await pumpEventQueue();

    expect(controller.state, isNotNull);
  });

  test('setters send the instance and use the returned state', () async {
    await controller.loadInstances();

    await controller.setEnabled(false);

    final (method, params) = service.calls.last;
    expect(method, 'setEnabled');
    expect(params, {'instance': '1', 'enabled': 'false'});
    expect(controller.state?.enabled, isFalse);
  });

  test('setActiveScenario(null) sends no scenario', () async {
    await controller.loadInstances();

    await controller.setActiveScenario(null);

    final (method, params) = service.calls.last;
    expect(method, 'setActiveScenario');
    expect(params, {'instance': '1'});
  });

  test('reloads the state when the app changes it', () async {
    await controller.loadInstances();
    service.state = fakeState(enabled: false);

    service.emit('deceiver:changed', {'instance': 1});
    await pumpEventQueue();

    expect(controller.state?.enabled, isFalse);
  });

  test('ignores changes of other instances', () async {
    await controller.loadInstances();
    service.calls.clear();

    service.emit('deceiver:changed', {'instance': 2});
    await pumpEventQueue();

    expect(service.calls, isEmpty);
  });

  test('adds pushed requests, keeping maxRecordedRequests', () async {
    await controller.loadInstances();

    for (final id in [1, 2, 3]) {
      service.emit('deceiver:request', {
        'instance': 1,
        'request': fakeRequest(id),
      });
    }

    expect(controller.requests.map((r) => r.id), [2, 3]);
  });

  test('skips pushed requests that were already loaded', () async {
    service.requests = [fakeRequest(1)];
    await controller.loadInstances();

    service.emit('deceiver:request', {
      'instance': 1,
      'request': fakeRequest(1),
    });

    expect(controller.requests, hasLength(1));
  });

  test('clears the requests when the app clears them', () async {
    service.requests = [fakeRequest(1)];
    await controller.loadInstances();
    controller.selectRequest(controller.requests.single);

    service.emit('deceiver:requestsCleared', {'instance': 1});

    expect(controller.requests, isEmpty);
    expect(controller.selectedRequest, isNull);
  });

  test('selecting a mock or a request deselects the other', () async {
    service.requests = [fakeRequest(1)];
    await controller.loadInstances();

    controller.selectRequest(controller.requests.single);
    controller.selectMock(10);
    expect(controller.selectedRequest, isNull);
    expect(controller.state?.findMock(10)?.$1.description, 'GET /users');

    controller.selectRequest(controller.requests.single);
    expect(controller.selectedMockId, isNull);
  });

  test('findMock tells where a mock is registered', () async {
    await controller.loadInstances();

    expect(controller.state?.findMock(10)?.$2, isNull);
    expect(controller.state?.findMock(11)?.$2, 'error');
    expect(controller.state?.findMock(99), isNull);
  });

  test('shows the error of a failed call', () async {
    final failing = _FailingService();
    final controller = ExtensionController(failing);

    await controller.loadInstances();

    expect(controller.error, contains('connection lost'));
  });
}

class _FailingService extends FakeDeceiverService {
  @override
  Future<Map<String, Object?>> call(
    String method, [
    Map<String, String> params = const {},
  ]) async => throw Exception('connection lost');
}
