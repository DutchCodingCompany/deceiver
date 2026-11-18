import 'package:http/http.dart';

import 'path_template.dart';

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
  final template = PathTemplate(path);
  return (request) => template.match(request.url) != null;
}
