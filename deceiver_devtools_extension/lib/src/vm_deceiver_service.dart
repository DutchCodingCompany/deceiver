import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:vm_service/vm_service.dart';

import 'deceiver_service.dart';

/// A [DeceiverService] that uses the DevTools VM service connection.
class VmDeceiverService implements DeceiverService {
  VmDeceiverService() {
    unawaited(_connect());
  }

  final _events = StreamController<DeceiverEvent>.broadcast();
  StreamSubscription<Event>? _subscription;
  var _isolateGeneration = 0;

  @override
  Stream<DeceiverEvent> get events => _events.stream;

  Future<void> _connect() async {
    final service = await serviceManager.onServiceAvailable;
    _subscription = service.onExtensionEvent.listen((event) {
      final kind = event.extensionKind;
      if (kind == null || !kind.startsWith('deceiver:')) return;
      if (event.isolate?.id != _mainIsolateId) return;
      _events.add((kind: kind, data: event.extensionData?.data ?? const {}));
    });

    final mainIsolate = serviceManager.isolateManager.mainIsolate;
    mainIsolate.addListener(_waitForExtensions);
    _waitForExtensions();
  }

  String? get _mainIsolateId =>
      serviceManager.isolateManager.mainIsolate.value?.id;

  /// The extensions are registered when the app creates its first Deceiver.
  Future<void> _waitForExtensions() async {
    final generation = ++_isolateGeneration;
    if (_mainIsolateId == null) return;
    await serviceManager.serviceExtensionManager
        .waitForServiceExtensionAvailable('ext.deceiver.getInstances');
    if (generation != _isolateGeneration) return;
    _events.add((kind: instancesChangedEvent, data: const {}));
  }

  @override
  Future<Map<String, Object?>> call(
    String method, [
    Map<String, String> params = const {},
  ]) async {
    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      'ext.deceiver.$method',
      args: params,
    );
    return (response.json ?? const {}).cast();
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    serviceManager.isolateManager.mainIsolate.removeListener(
      _waitForExtensions,
    );
    unawaited(_events.close());
  }
}
