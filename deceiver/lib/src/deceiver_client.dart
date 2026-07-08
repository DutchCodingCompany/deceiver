import 'package:http/http.dart';

import 'deceiver.dart';

/// An HTTP client that intercepts requests and returns mock responses
/// when a matching mock is registered in its [Deceiver] instance.
///
/// Extends [BaseClient] from `package:http`, so it can be used as a
/// drop-in replacement anywhere a [Client] is expected.
class DeceiverClient extends BaseClient {
  DeceiverClient(this._client, this._deceiver);

  final Client _client;
  final Deceiver _deceiver;

  @override
  void close() {
    _client.close();
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Convert BaseRequest to Request so matchers can inspect the body.
    final concreteRequest = _toRequest(request);

    // Attempt to find a matching mock response.
    final mockResponse = await _deceiver.respond(concreteRequest);

    if (mockResponse != null) {
      return _toStreamedResponse(mockResponse, request);
    }

    // No mock matched.
    if (_deceiver.options.onlyAllowMocks) {
      throw StateError(
        '\n'
        'Deceiver: no matching mock found for:\n'
        '\n'
        '  ${request.method.toUpperCase()} ${request.url}\n'
        '\n'
        'Registered mocks:\n'
        '${_deceiver.toPrettyPrintedString()}\n',
      );
    }

    // Passthrough to the real HTTP client.
    return _client.send(request);
  }

  /// Converts a [BaseRequest] into a concrete [Request] so that matchers
  /// can access the body, headers, method, and URL.
  Request _toRequest(BaseRequest baseRequest) {
    if (baseRequest is Request) {
      return baseRequest;
    }

    // For non-Request types (e.g. StreamedRequest, MultipartRequest),
    // create a Request with the method, URL, and headers so matchers
    // can still match on those properties.
    return Request(baseRequest.method, baseRequest.url)
      ..headers.addAll(baseRequest.headers);
  }

  /// Converts a [Response] into a [StreamedResponse] which is what
  /// [BaseClient.send] must return.
  StreamedResponse _toStreamedResponse(Response response, BaseRequest request) {
    final stream = ByteStream.fromBytes(response.bodyBytes);
    return StreamedResponse(
      stream,
      response.statusCode,
      headers: response.headers,
      request: request,
      contentLength: response.contentLength,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
