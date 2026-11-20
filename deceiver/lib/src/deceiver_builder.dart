import 'package:http/http.dart';

import 'deceiver.dart';
import 'deceiver_data.dart';
import 'deceiver_request_matchers.dart';
import 'deceiver_response_info.dart';
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
///
/// Paths are relative to [Deceiver.baseUrl]. Use [at] for another API, or
/// pass a full URL as path for an API with a fixed URL:
///
/// ```dart
/// deceiver.on.at(env.authUrl).post('/token', jsonResponse(body: {}));
/// deceiver.on.get('https://maps.example.com/geocode', jsonResponse(body: {}));
/// ```
class DeceiverBuilder {
  /// Creates a builder that adds mocks to the given [Deceiver]'s base list.
  ///
  /// Paths are relative to [Deceiver.baseUrl].
  DeceiverBuilder(Deceiver deceiver)
    : _addMock = deceiver.add,
      _baseUrl = deceiver.baseUrl,
      _isAt = false;

  /// Creates a builder that appends mocks to the given [target] list.
  ///
  /// Used internally by [Deceiver.scenario] to populate a scenario's mock
  /// list. Paths are relative to [baseUrl], if given.
  DeceiverBuilder.forList(List<DeceiverData> target, {this._baseUrl})
    : _addMock = target.add,
      _isAt = false;

  DeceiverBuilder._at(this._addMock, Uri this._baseUrl) : _isAt = true;

  final void Function(DeceiverData data) _addMock;

  /// The URL paths are relative to, or `null` to match any host.
  final Uri? _baseUrl;

  /// Whether this builder was created with [at].
  final bool _isAt;

  static final _fullUrl = RegExp(
    r'^([a-zA-Z][a-zA-Z0-9+.\-]*)://([^/?#]*)(.*)$',
  );
  static final _looksLikeUrl = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:/');

  /// Returns a builder that registers mocks relative to [baseUrl] instead of
  /// [Deceiver.baseUrl], for example for a second API.
  ///
  /// Requests under [baseUrl] are handled by the [Deceiver] (strict mode,
  /// recorded requests), even when they are outside [Deceiver.baseUrl].
  ///
  /// ```dart
  /// deceiver.on.at(env.authUrl).post('/token', jsonResponse(body: {}));
  ///
  /// deceiver.scenario('expired', (on) {
  ///   on.at(env.authUrl).post('/token', errorResponse(401));
  /// });
  /// ```
  ///
  /// Throws an [ArgumentError] if [baseUrl] has no scheme or host, or has a
  /// query or fragment.
  DeceiverBuilder at(Uri baseUrl) {
    checkBaseUrl(baseUrl, 'baseUrl');
    return DeceiverBuilder._at(_addMock, baseUrl);
  }

  void _on(
    String description,
    DeceiverRequestMatcher requestMatcher,
    DeceiverResponseBuilder responseBuilder, {
    Uri? baseUrl,
    DeceiverResponseInfo? responseInfo,
  }) {
    final data = DeceiverData(
      description: description,
      requestMatcher: requestMatcher,
      responseBuilder: responseBuilder,
      baseUrl: baseUrl,
      responseInfo: responseInfo,
    );
    _addMock(data);
  }

  void _onPath(
    String method,
    String path,
    DeceiverResponseBuilder responseBuilder,
  ) {
    final Uri? base;
    final String templatePath;
    final String description;
    final bool isOwnBase;

    if (_fullUrl.firstMatch(path) case final match?) {
      base = Uri.parse('${match.group(1)}://${match.group(2)}');
      checkBaseUrl(base, 'path');
      final rest = match.group(3)!;
      templatePath = rest.isEmpty ? '/' : rest;
      description = '$method $path';
      isOwnBase = true;
    } else if (_looksLikeUrl.hasMatch(path)) {
      throw ArgumentError.value(
        path,
        'path',
        'Looks like a URL, but is not a valid one. Use scheme://host/path',
      );
    } else {
      base = _baseUrl;
      final basePath = _withoutTrailingSlash(base?.path ?? '');
      final relativePath = path.startsWith('/') || basePath.isEmpty
          ? path
          : '/$path';
      templatePath = '$basePath$relativePath';
      isOwnBase = _isAt;
      description = _isAt
          ? '$method ${_withoutTrailingSlash('$base')}$relativePath'
          : '$method $path';
    }

    final template = PathTemplate(templatePath);
    Map<String, String>? match(Request request) {
      if (base != null && !isUnderBaseUrl(request.url, base)) return null;
      return template.match(request.url);
    }

    _on(
      description,
      matchAll([matchMethod(method), (request) => match(request) != null]),
      (request) {
        setPathParameters(request, match(request) ?? const {});
        return responseBuilder(request);
      },
      baseUrl: isOwnBase ? base : null,
      // The builder above wraps responseBuilder, so take its info here.
      responseInfo: responseInfoOf(responseBuilder),
    );
  }

  static String _withoutTrailingSlash(String path) =>
      path.endsWith('/') ? path.substring(0, path.length - 1) : path;

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
