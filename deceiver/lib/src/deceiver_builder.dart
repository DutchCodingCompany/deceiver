import 'deceiver.dart';
import 'deceiver_data.dart';
import 'deceiver_request_matchers.dart';
import 'path_parameters.dart';
import 'path_template.dart';

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
  ///
  /// Paths are relative to [Deceiver.baseUrl].
  DeceiverBuilder(Deceiver deceiver)
    : _addMock = deceiver.add,
      _basePath = _basePathOf(deceiver.baseUrl);

  /// Creates a builder that appends mocks to the given [target] list.
  ///
  /// Used internally by [Deceiver.scenario] to populate a scenario's mock
  /// list. Paths are relative to the path of [baseUrl], if given.
  DeceiverBuilder.forList(List<DeceiverData> target, {Uri? baseUrl})
    : _addMock = target.add,
      _basePath = _basePathOf(baseUrl);

  final void Function(DeceiverData data) _addMock;

  /// The path of the base URL without a trailing slash, or an empty string.
  final String _basePath;

  static String _basePathOf(Uri? baseUrl) {
    final path = baseUrl?.path ?? '';
    return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  }

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

  void _onPath(
    String method,
    String path,
    DeceiverResponseBuilder responseBuilder,
  ) {
    final template = PathTemplate(
      _basePath.isEmpty || path.startsWith('/')
          ? '$_basePath$path'
          : '$_basePath/$path',
    );
    _on(
      '$method $path',
      matchAll([
        matchMethod(method),
        (request) => template.match(request.url) != null,
      ]),
      (request) {
        setPathParameters(request, template.match(request.url) ?? const {});
        return responseBuilder(request);
      },
    );
  }

  /// Registers a mock for GET requests matching [path].
  ///
  /// See [matchPath] for the syntax of [path]. The response builder can read
  /// the placeholder values via [DeceiverPathParameters.pathParameters].
  void get(String path, DeceiverResponseBuilder responseBuilder) =>
      _onPath('GET', path, responseBuilder);

  /// Registers a mock for POST requests matching [path].
  ///
  /// See [matchPath] for the syntax of [path]. The response builder can read
  /// the placeholder values via [DeceiverPathParameters.pathParameters].
  void post(String path, DeceiverResponseBuilder responseBuilder) =>
      _onPath('POST', path, responseBuilder);

  /// Registers a mock for PUT requests matching [path].
  ///
  /// See [matchPath] for the syntax of [path]. The response builder can read
  /// the placeholder values via [DeceiverPathParameters.pathParameters].
  void put(String path, DeceiverResponseBuilder responseBuilder) =>
      _onPath('PUT', path, responseBuilder);

  /// Registers a mock for DELETE requests matching [path].
  ///
  /// See [matchPath] for the syntax of [path]. The response builder can read
  /// the placeholder values via [DeceiverPathParameters.pathParameters].
  void delete(String path, DeceiverResponseBuilder responseBuilder) =>
      _onPath('DELETE', path, responseBuilder);

  /// Registers a mock for PATCH requests matching [path].
  ///
  /// See [matchPath] for the syntax of [path]. The response builder can read
  /// the placeholder values via [DeceiverPathParameters.pathParameters].
  void patch(String path, DeceiverResponseBuilder responseBuilder) =>
      _onPath('PATCH', path, responseBuilder);

  /// Registers a mock for HEAD requests matching [path].
  ///
  /// See [matchPath] for the syntax of [path]. The response builder can read
  /// the placeholder values via [DeceiverPathParameters.pathParameters].
  void head(String path, DeceiverResponseBuilder responseBuilder) =>
      _onPath('HEAD', path, responseBuilder);

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
