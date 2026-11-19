import 'package:http/http.dart';

final _pathParameters = Expando<Map<String, String>>('pathParameters');

/// Gives response builders access to the values of path placeholders.
extension DeceiverPathParameters on Request {
  /// The values of the `{name}` placeholders in the path of the mock that
  /// answers this request.
  ///
  /// For `on.get('/users/{id}', ...)` and a request to `/users/42`, this is
  /// `{'id': '42'}`. Values are percent-decoded, so `/users/Jos%C3%A9` gives
  /// `{'id': 'José'}`.
  ///
  /// Empty for mocks registered with `on.match()`, and in request matchers.
  Map<String, String> get pathParameters => _pathParameters[this] ?? const {};
}

/// Sets the [DeceiverPathParameters.pathParameters] of [request].
void setPathParameters(Request request, Map<String, String> parameters) {
  _pathParameters[request] = Map.unmodifiable(parameters);
}
