import 'dart:async';

import 'package:http/http.dart';

import 'deceiver_request_matchers.dart';

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
    this.isEnabled = true,
    this.baseUrl,
  });

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

  /// Whether this individual mock is active. Set to `false` to disable
  /// without removing the registration.
  bool isEnabled;
}

/// A request handled by a `Deceiver`, see `Deceiver.requests`.
class DeceiverRecordedRequest {
  DeceiverRecordedRequest({required this.request, required this.mock});

  /// The request. For streamed and multipart requests this is a copy with
  /// the body read into memory.
  final Request request;

  /// The mock that answered the request, or `null` if no mock matched. The
  /// request then went to the real HTTP client, or failed in strict mode.
  final DeceiverData? mock;
}
