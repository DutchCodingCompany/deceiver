import 'package:http/http.dart';
import 'package:uri/uri.dart';

/// A function that determines whether a [Request] matches a given criteria.
typedef DeceiverRequestMatcher = bool Function(Request request);

/// Composes multiple matchers with AND logic. All matchers must match for
/// the composed matcher to return `true`.
DeceiverRequestMatcher matchAll(List<DeceiverRequestMatcher> matchers) =>
    (request) => matchers.every((matcher) => matcher(request));

/// Matches requests by HTTP method (case-insensitive).
DeceiverRequestMatcher matchMethod(String method) {
  return (request) => request.method.toLowerCase() == method.toLowerCase();
}

/// Matches requests by URL path using RFC 6570 URI templates.
///
/// Only the path component of the request URL is matched against the template,
/// so a template of `/users/{id}` will match `https://any-host.com/users/42`.
///
/// Includes reverse-match validation to ensure that `/goals/{id}` does not
/// incorrectly match `/goals/{id}/foo`.
DeceiverRequestMatcher matchPath(String path) {
  return (request) {
    // Compare against only the path portion of the request URL, so templates
    // like `/users/{id}` work regardless of host/scheme.
    final requestPath = Uri.parse(request.url.path);
    final template = UriTemplate(path);
    final parser = UriParser(template);

    if (!parser.matches(requestPath)) {
      return false;
    }

    // Reverse-parse validation: expand the parsed variables back into a URI
    // and confirm it matches the original. This prevents /goals/{id} from
    // matching /goals/{id}/foo.
    final vars = parser.parse(requestPath);
    final reversed = template.expand(vars);
    return reversed == requestPath.toString();
  };
}
