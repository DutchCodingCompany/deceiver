import 'package:deceiver/src/deceiver.dart';
import 'package:deceiver/src/deceiver_data.dart';
import 'package:deceiver/src/deceiver_request_matchers.dart';

/// Fluent API for registering mock HTTP responses.
///
/// When used via [Deceiver.on], mocks are added to the base mock list.
/// When used inside [Deceiver.scenario], mocks are added to the scenario's
/// list instead.
///
/// ```dart
/// final deceiver = Deceiver();
/// deceiver.on.get('/users', (req) => Response('[]', 200));
/// deceiver.on.post('/users', (req) => Response('{"id": 1}', 201));
/// deceiver.on.delete('/users/{id}', (req) => Response('', 204));
/// ```
class DeceiverBuilder {
  /// Creates a builder that adds mocks to the given [Deceiver]'s base list.
  DeceiverBuilder(Deceiver deceiver) : _addMock = deceiver.add;

  /// Creates a builder that appends mocks to the given [target] list.
  ///
  /// Used internally by [Deceiver.scenario] to populate a scenario's mock
  /// list.
  DeceiverBuilder.forList(List<DeceiverData> target) : _addMock = target.add;

  final void Function(DeceiverData data) _addMock;

  void _on(
    String description,
    DeceiverRequestMatcher requestMatcher,
    DeceiverResponseBuilder responseBuilder,
  ) {
    final data = DeceiverData(
      description: description,
      requestMatcher: requestMatcher,
      responseBuilder: responseBuilder,
    );
    _addMock(data);
  }

  /// Registers a mock for GET requests matching [path].
  void get(String path, DeceiverResponseBuilder responseBuilder) {
    _on(
      'GET $path',
      matchAll([matchMethod('GET'), matchPath(path)]),
      responseBuilder,
    );
  }

  /// Registers a mock for POST requests matching [path].
  void post(String path, DeceiverResponseBuilder responseBuilder) {
    _on(
      'POST $path',
      matchAll([matchMethod('POST'), matchPath(path)]),
      responseBuilder,
    );
  }

  /// Registers a mock for PUT requests matching [path].
  void put(String path, DeceiverResponseBuilder responseBuilder) {
    _on(
      'PUT $path',
      matchAll([matchMethod('PUT'), matchPath(path)]),
      responseBuilder,
    );
  }

  /// Registers a mock for DELETE requests matching [path].
  void delete(String path, DeceiverResponseBuilder responseBuilder) {
    _on(
      'DELETE $path',
      matchAll([matchMethod('DELETE'), matchPath(path)]),
      responseBuilder,
    );
  }

  /// Registers a mock for PATCH requests matching [path].
  void patch(String path, DeceiverResponseBuilder responseBuilder) {
    _on(
      'PATCH $path',
      matchAll([matchMethod('PATCH'), matchPath(path)]),
      responseBuilder,
    );
  }

  /// Registers a mock for HEAD requests matching [path].
  void head(String path, DeceiverResponseBuilder responseBuilder) {
    _on(
      'HEAD $path',
      matchAll([matchMethod('HEAD'), matchPath(path)]),
      responseBuilder,
    );
  }

  /// Registers a mock using a custom [requestMatcher].
  ///
  /// Use this when the built-in method+path matchers are insufficient.
  /// Provide a [description] for debugging output.
  ///
  /// ```dart
  /// deceiver.on.match(
  ///   (req) => req.method == 'GET' && req.url.queryParameters['q'] == 'dart',
  ///   (req) => Response('{"results": []}', 200),
  ///   description: 'GET with q=dart',
  /// );
  /// ```
  void match(
    DeceiverRequestMatcher requestMatcher,
    DeceiverResponseBuilder responseBuilder, {
    String description = 'Custom Matcher',
  }) {
    _on(description, requestMatcher, responseBuilder);
  }
}
