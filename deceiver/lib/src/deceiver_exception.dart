import 'package:http/http.dart';

/// Thrown when strict mode (`DeceiverOptions.onlyAllowMocks`) is enabled and
/// a request does not match any registered mock.
///
/// Extends [ClientException], so code that already handles network errors
/// from `package:http` handles this exception as well.
class DeceiverException extends ClientException {
  DeceiverException(super.message, [super.uri]);

  @override
  String toString() => 'DeceiverException: $message';
}
