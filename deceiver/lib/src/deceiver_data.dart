import 'dart:async';

import 'package:http/http.dart';

import 'deceiver_exception.dart';
import 'deceiver_request_matchers.dart';
import 'deceiver_response_info.dart';

/// A function that builds a [Response] given a [Request].
///
/// Supports both sync and async response building via [FutureOr].
///
/// ```dart
/// // Sync
/// DeceiverResponseBuilder builder = (request) => Response('ok', 200);
///
/// // Async (e.g. simulate delay)
/// DeceiverResponseBuilder asyncBuilder = (request) async {
///   await Future.delayed(Duration(milliseconds: 100));
///   return Response('ok', 200);
/// };
/// ```
typedef DeceiverResponseBuilder = FutureOr<Response> Function(Request request);

/// A registered mock definition pairing a request matcher with a response
/// builder.
class DeceiverData {
  DeceiverData({
    required this.requestMatcher,
    required this.responseBuilder,
    required this.description,
    this._isEnabled = true,
    this.baseUrl,
    DeceiverResponseInfo? responseInfo,
  }) : responseInfo = responseInfo ?? responseInfoOf(responseBuilder);

  static int _nextId = 0;
  final int _id = _nextId++;
  void Function()? _onChanged;

  /// The base URL this mock was registered for with `on.at()` or with a full
  /// URL as path, or `null` if it is relative to `Deceiver.baseUrl`.
  ///
  /// Requests under this URL are handled by the `Deceiver`, even when they
  /// are outside `Deceiver.baseUrl`.
  final Uri? baseUrl;

  /// The matcher function that determines if a request should be intercepted.
  final DeceiverRequestMatcher requestMatcher;

  /// The function that builds the mock response.
  final DeceiverResponseBuilder responseBuilder;

  /// A human-readable description of this mock (e.g. "GET /users/{id}").
  final String description;

  /// What this mock responds, for example to show it in a debug panel.
  ///
  /// Known for the response helpers such as `jsonResponse()`. Response
  /// builders of your own are [DeceiverResponseKind.custom].
  final DeceiverResponseInfo responseInfo;

  /// Whether this individual mock is active. Set to `false` to disable
  /// without removing the registration.
  ///
  /// Changing it notifies the listeners of the `Deceiver` the mock is
  /// registered on.
  bool get isEnabled => _isEnabled;
  bool _isEnabled;

  set isEnabled(bool value) {
    if (_isEnabled == value) return;
    _isEnabled = value;
    _onChanged?.call();
  }
}

/// A unique id of [mock] within this isolate, used by DevTools.
int mockId(DeceiverData mock) => mock._id;

/// Sets the callback that is called when [DeceiverData.isEnabled] of [mock]
/// changes.
void setMockOnChanged(DeceiverData mock, void Function() onChanged) {
  mock._onChanged = onChanged;
}

/// A request handled by a `Deceiver`, see `Deceiver.requests`.
class DeceiverRecordedRequest {
  DeceiverRecordedRequest({
    required this.request,
    required this.mock,
    DateTime? timestamp,
    this.response,
    this.duration,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();

  /// The request. For streamed and multipart requests this is a copy with
  /// the body read into memory.
  final Request request;

  /// The mock that answered the request, or `null` if no mock matched. The
  /// request then went to the real HTTP client, or failed in strict mode.
  final DeceiverData? mock;

  /// When the `Deceiver` received the request.
  final DateTime timestamp;

  /// The response of the [mock], or `null` if no mock matched or the mock
  /// threw. Responses of the real HTTP client are not recorded.
  final Response? response;

  /// How long the [mock] took to build the response, or `null` if no mock
  /// matched.
  final Duration? duration;

  /// The error of the request: the [DeceiverException] thrown in strict mode
  /// when no mock matched, or what the [mock] threw. `null` otherwise.
  final Object? error;
}
