import 'package:http/http.dart';

/// A function that determines whether a [Request] matches a given criteria.
typedef DeceiverRequestMatcher = bool Function(Request request);

/// Composes multiple matchers with AND logic. All matchers must match for
/// the composed matcher to return `true`.
DeceiverRequestMatcher matchAll(List<DeceiverRequestMatcher> matchers) =>
    (request) => matchers.every((matcher) => matcher(request));

/// Matches requests by HTTP method (case-insensitive).
DeceiverRequestMatcher matchMethod(String method) {
  final expected = method.toUpperCase();
  return (request) => request.method.toUpperCase() == expected;
}

/// Matches requests by URL path using a path template.
///
/// A `{name}` placeholder matches exactly one non-empty path segment. Every
/// other segment must match literally. Only the path of the request URL is
/// compared, so `/users/{id}` matches `https://any-host.com/users/42?page=2`,
/// but not `/users/42/posts` or `/users/`.
///
/// Segments are compared after percent-decoding, so `/users/{id}` also
/// matches `/users/john@doe.com` and `/users/Jos%C3%A9`.
///
/// Throws an [ArgumentError] if [path] contains a query, a fragment or a
/// placeholder that is not a whole `{name}` segment.
DeceiverRequestMatcher matchPath(String path) {
  final template = _parsePathTemplate(path);
  return (request) {
    final segments = request.url.pathSegments;
    if (segments.length != template.length) return false;
    for (var i = 0; i < template.length; i++) {
      final expected = template[i];
      final matches = expected == null
          ? segments[i].isNotEmpty
          : segments[i] == expected;
      if (!matches) return false;
    }
    return true;
  };
}

final _placeholder = RegExp(r'^\{[A-Za-z_][A-Za-z0-9_]*\}$');

/// Splits [path] into its segments: the decoded literal, or `null` for a
/// placeholder.
List<String?> _parsePathTemplate(String path) {
  if (path.contains('?') || path.contains('#')) {
    throw ArgumentError.value(
      path,
      'path',
      'Only the path is matched. Use on.match() to match on the query',
    );
  }

  final withoutLeadingSlash = path.startsWith('/') ? path.substring(1) : path;
  if (withoutLeadingSlash.isEmpty) return const [];

  return [
    for (final segment in withoutLeadingSlash.split('/'))
      if (_placeholder.hasMatch(segment))
        null
      else if (segment.contains('{') || segment.contains('}'))
        throw ArgumentError.value(
          path,
          'path',
          'Placeholders must be a whole segment like {id}, got "$segment"',
        )
      else
        _decodeSegment(segment),
  ];
}

/// Decodes [segment] the same way [Uri.pathSegments] does, so it accepts
/// both `café` and `caf%C3%A9`.
String _decodeSegment(String segment) {
  final decoded = Uri(path: '/$segment').pathSegments;
  return decoded.length == 1 ? decoded.single : segment;
}
