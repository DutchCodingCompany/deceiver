/// An event the app sent with `postEvent`.
typedef DeceiverEvent = ({String kind, Map<String, Object?> data});

/// Sent by [DeceiverService.events] when the `ext.deceiver.*` service
/// extensions (re)appear, for example after a hot restart.
const instancesChangedEvent = 'deceiver:instancesChanged';

/// Talks to the `ext.deceiver.*` service extensions of the connected app.
abstract interface class DeceiverService {
  /// The `deceiver:*` events of the app.
  Stream<DeceiverEvent> get events;

  /// Calls `ext.deceiver.<method>` and returns its result.
  Future<Map<String, Object?>> call(
    String method, [
    Map<String, String> params = const {},
  ]);
}
