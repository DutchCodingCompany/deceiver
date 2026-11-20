import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart';

import 'deceiver_data.dart';
import 'deceiver_response_info.dart';

/// Creates a [DeceiverResponseBuilder] that returns a JSON response.
///
/// The [body] is encoded via [json.encode] and the `content-type` header
/// is set to `application/json`.
///
/// ```dart
/// deceiver.on.get('/users', jsonResponse(body: [{'name': 'Bilbo'}]));
/// deceiver.on.post('/users', jsonResponse(body: {'id': 1}, statusCode: 201));
/// ```
DeceiverResponseBuilder jsonResponse({
  Object? body,
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  final mergedHeaders = {'content-type': 'application/json', ...headers};
  return describeResponse(
    (request) => Response(
      body == null ? '' : json.encode(body),
      statusCode,
      headers: mergedHeaders,
    ),
    DeceiverResponseInfo(
      kind: DeceiverResponseKind.json,
      statusCode: statusCode,
      headers: mergedHeaders,
      body: _tryEncode(body),
    ),
  );
}

/// The [body] as JSON for [DeceiverResponseInfo.body], or `null` if it is
/// `null` or can't be encoded (the response then throws when it is built).
String? _tryEncode(Object? body) {
  if (body == null) return null;
  try {
    return json.encode(body);
  } on JsonUnsupportedObjectError {
    return null;
  }
}

/// Creates a [DeceiverResponseBuilder] that returns an error response.
///
/// Optionally provide a [message] which is included as a JSON body:
/// `{"error": "<message>"}`.
///
/// ```dart
/// deceiver.on.get('/secret', errorResponse(403, message: 'Forbidden'));
/// deceiver.on.get('/missing', errorResponse(404));
/// ```
DeceiverResponseBuilder errorResponse(
  int statusCode, {
  String? message,
  Map<String, String> headers = const {},
}) {
  final body = message == null ? '' : json.encode({'error': message});
  final responseHeaders = message == null
      ? headers
      : {'content-type': 'application/json', ...headers};
  return describeResponse(
    (request) => Response(body, statusCode, headers: responseHeaders),
    DeceiverResponseInfo(
      kind: DeceiverResponseKind.error,
      statusCode: statusCode,
      headers: responseHeaders,
      body: message == null ? null : body,
    ),
  );
}

/// Creates a [DeceiverResponseBuilder] that returns an empty response.
///
/// Defaults to HTTP 204 No Content.
///
/// ```dart
/// deceiver.on.delete('/users/{id}', emptyResponse());
/// ```
DeceiverResponseBuilder emptyResponse({
  int statusCode = 204,
  Map<String, String> headers = const {},
}) {
  return describeResponse(
    (request) => Response('', statusCode, headers: headers),
    DeceiverResponseInfo(
      kind: DeceiverResponseKind.empty,
      statusCode: statusCode,
      headers: headers,
    ),
  );
}

/// Creates a [DeceiverResponseBuilder] that cycles through [builders] in
/// order.
///
/// The first call returns the response from `builders[0]`, the second from
/// `builders[1]`, and so on. After the last builder is reached, it loops
/// back to the first.
///
/// ```dart
/// deceiver.on.get('/users', sequentialResponse([
///   jsonResponse(body: []),                        // 1st call
///   jsonResponse(body: [{'name': 'Bilbo'}]),       // 2nd call
///   errorResponse(500, message: 'Server error'),   // 3rd call
///   // 4th call loops back to the 1st response
/// ]));
/// ```
DeceiverResponseBuilder sequentialResponse(
  List<DeceiverResponseBuilder> builders,
) {
  if (builders.isEmpty) {
    throw ArgumentError.value(
      builders,
      'builders',
      'must contain at least one response builder',
    );
  }

  final copy = List.of(builders);
  var index = 0;
  return describeResponse(
    (request) {
      final builder = copy[index % copy.length];
      index++;
      return builder(request);
    },
    DeceiverResponseInfo(
      kind: DeceiverResponseKind.sequential,
      variants: copy.map(responseInfoOf).toList(),
    ),
  );
}

/// Creates a [DeceiverResponseBuilder] that picks a random builder from
/// [builders] on each call.
///
/// An optional [random] instance can be provided for deterministic testing.
///
/// ```dart
/// deceiver.on.get('/flaky', randomResponse([
///   jsonResponse(body: {'status': 'ok'}),
///   errorResponse(503, message: 'Try again'),
/// ]));
/// ```
DeceiverResponseBuilder randomResponse(
  List<DeceiverResponseBuilder> builders, {
  Random? random,
}) {
  if (builders.isEmpty) {
    throw ArgumentError.value(
      builders,
      'builders',
      'must contain at least one response builder',
    );
  }

  final copy = List.of(builders);
  final rng = random ?? Random();
  return describeResponse(
    (request) {
      final builder = copy[rng.nextInt(copy.length)];
      return builder(request);
    },
    DeceiverResponseInfo(
      kind: DeceiverResponseKind.random,
      variants: copy.map(responseInfoOf).toList(),
    ),
  );
}
