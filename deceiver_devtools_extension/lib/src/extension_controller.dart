import 'dart:async';

import 'package:flutter/foundation.dart';

import 'deceiver_service.dart';
import 'models.dart';

/// The state of the DevTools extension: the Deceivers in the app, the
/// selected one with its mocks, and its recorded requests.
class ExtensionController extends ChangeNotifier {
  ExtensionController(this._service) {
    _subscription = _service.events.listen(_onEvent);
  }

  final DeceiverService _service;
  late final StreamSubscription<DeceiverEvent> _subscription;

  /// The Deceivers in the app. Empty until the app creates one.
  List<DeceiverInstance> instances = const [];

  /// The settings and mocks of the selected Deceiver.
  DeceiverState? state;

  /// The requests of the selected Deceiver, oldest first.
  List<RecordedRequest> requests = const [];

  /// The request shown in the details, if any.
  RecordedRequest? selectedRequest;

  /// The last error of a call to the app, shown until the next call.
  String? error;

  int? get selectedInstance => state?.instance;

  Future<void> loadInstances() => _run(() async {
    final result = await _service.call('getInstances');
    instances = [
      for (final json in result['instances'] as List)
        DeceiverInstance.fromJson((json as Map).cast()),
    ];
    final selected = instances
        .where((i) => i.id == selectedInstance)
        .firstOrNull;
    final instance = selected ?? instances.firstOrNull;
    if (instance == null) {
      state = null;
      requests = const [];
      selectedRequest = null;
    } else {
      await _load(instance.id, keepSelection: selected != null);
    }
  });

  Future<void> selectInstance(int id) => _run(() => _load(id));

  Future<void> _load(int id, {bool keepSelection = false}) async {
    final params = {'instance': '$id'};
    final [stateJson, requestsJson] = await Future.wait([
      _service.call('getState', params),
      _service.call('getRequests', params),
    ]);
    state = DeceiverState.fromJson(stateJson);
    requests = [
      for (final json in requestsJson['requests'] as List)
        RecordedRequest.fromJson((json as Map).cast()),
    ];
    final selectedId = keepSelection ? selectedRequest?.id : null;
    selectedRequest = requests.where((r) => r.id == selectedId).firstOrNull;
  }

  Future<void> setEnabled(bool enabled) =>
      _setState('setEnabled', {'enabled': '$enabled'});

  Future<void> setOnlyAllowMocks(bool enabled) =>
      _setState('setOnlyAllowMocks', {'enabled': '$enabled'});

  /// Activates the scenario with [name], or deactivates it when `null`.
  Future<void> setActiveScenario(String? name) =>
      _setState('setActiveScenario', {'scenario': ?name});

  Future<void> setMockEnabled(int mockId, bool enabled) =>
      _setState('setMockEnabled', {'mock': '$mockId', 'enabled': '$enabled'});

  Future<void> clearRequests() => _run(() async {
    final id = selectedInstance;
    if (id == null) return;
    await _service.call('clearRequests', {'instance': '$id'});
    requests = const [];
    selectedRequest = null;
  });

  void selectRequest(RecordedRequest? request) {
    selectedRequest = request;
    notifyListeners();
  }

  Future<void> _setState(String method, Map<String, String> params) =>
      _run(() async {
        final id = selectedInstance;
        if (id == null) return;
        final result = await _service.call(method, {
          'instance': '$id',
          ...params,
        });
        state = DeceiverState.fromJson(result);
      });

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      error = null;
    } on Object catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  void _onEvent(DeceiverEvent event) {
    final instance = event.data['instance'];
    switch (event.kind) {
      case instancesChangedEvent:
        unawaited(loadInstances());
      case 'deceiver:changed' when instance == selectedInstance:
        unawaited(
          _run(() async {
            final result = await _service.call('getState', {
              'instance': '$instance',
            });
            state = DeceiverState.fromJson(result);
          }),
        );
      case 'deceiver:request' when instance == selectedInstance:
        final request = RecordedRequest.fromJson(
          (event.data['request'] as Map).cast(),
        );
        // Already loaded when the event arrived during a load.
        if (requests.any((r) => r.id == request.id)) return;
        final max = state?.maxRecordedRequests ?? 100;
        final all = [...requests, request];
        requests = all.sublist((all.length - max).clamp(0, all.length));
        notifyListeners();
      case 'deceiver:requestsCleared' when instance == selectedInstance:
        requests = const [];
        selectedRequest = null;
        notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
