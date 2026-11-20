@TestOn('vm')
library;

import 'dart:async';
import 'dart:developer';
import 'dart:isolate' as isolate;

import 'package:deceiver/deceiver.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Talks to Deceiver over the VM service, the way DevTools or an AI agent
/// (for example with the Dart MCP server's vm_service tool) does.
void main() {
  late VmService vm;
  late String isolateId;

  setUpAll(() async {
    final info = await Service.controlWebServer(
      enable: true,
      silenceOutput: true,
    );
    vm = await vmServiceConnectUri(info.serverWebSocketUri!.toString());
    isolateId = Service.getIsolateId(isolate.Isolate.current)!;
  });

  tearDownAll(() => vm.dispose());

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, String> args = const {},
  ]) async {
    final response = await vm.callServiceExtension(
      'ext.deceiver.$method',
      isolateId: isolateId,
      args: args,
    );
    return response.json!;
  }

  test('an agent can set up mocks and check the requests', () async {
    final deceiver = Deceiver(name: 'E2E');
    deceiver.on.get('/users', jsonResponse(body: ['Bilbo']));
    deceiver.on.get('/posts', jsonResponse(body: []));
    deceiver.scenario('error', (on) {
      on.get('/users', errorResponse(500, message: 'Server error'));
    });
    final client = deceiver.client();

    final events = <String>[];
    final subscription = vm.onExtensionEvent.listen(
      (e) => events.add(e.extensionKind!),
    );
    await vm.streamListen(EventStreams.kExtension);

    // Discover what is possible.
    final help = await call('help');
    expect(help['methods'], contains('ext.deceiver.setMockEnabled'));

    // Find the instance, by name.
    final instances = (await call('getInstances'))['instances'] as List;
    final id = instances.lastWhere((i) => i['name'] == 'E2E')['id'];
    final instance = {'instance': '$id'};

    // Only GET /users, answered by the error scenario.
    await call('setAllMocksEnabled', {...instance, 'enabled': 'false'});
    await call('setActiveScenario', {...instance, 'scenario': 'error'});
    final state = await call('setMockEnabled', {
      ...instance,
      'description': 'GET /users',
      'scenario': 'error',
      'enabled': 'true',
    });
    expect(state['activeScenario'], 'error');

    final users = await client.get(Uri.parse('https://x.com/users'));
    expect(users.statusCode, 500);
    expect(deceiver.registrations.every((m) => !m.isEnabled), isTrue);

    // Check what the app sent and which mock answered.
    final requests = (await call('getRequests', instance))['requests'] as List;
    expect(requests.single['mock']['description'], 'GET /users');
    expect(requests.single['statusCode'], 500);

    // Wrong parameters give an error that explains what to pass.
    await expectLater(
      call('setMockEnabled', {...instance, 'description': 'GET /nope'}),
      throwsA(
        isA<RPCError>().having(
          (e) => e.details,
          'details',
          contains('Mocks there: "GET /users"'),
        ),
      ),
    );

    await pumpEventQueue();
    expect(events, containsAll(['deceiver:changed', 'deceiver:request']));
    await subscription.cancel();
    client.close();
  });
}
