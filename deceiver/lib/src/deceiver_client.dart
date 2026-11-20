import 'package:http/http.dart';

import 'deceiver.dart';
import 'deceiver_exception.dart';

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
    if (!_deceiver.enabled || !_deceiver.appliesTo(request.url)) {
      return _client.send(request);
    }

    final concreteRequest = await _toRequest(request);

    // Attempt to find a matching mock response. In strict mode, throws when
    // no mock matches.
    final mockResponse = await respondOrThrow(
      _deceiver,
      concreteRequest,
      onNoMock: _deceiver.options.onlyAllowMocks
          ? () => _noMockException(request)
          : null,
    );

    if (mockResponse != null) {
      return _toStreamedResponse(mockResponse, request);
    }

    // Passthrough to the real HTTP client.
    return _client.send(concreteRequest);
  }

  DeceiverException _noMockException(BaseRequest request) {
    // The query is left out because it may contain secrets such as tokens.
    final url = request.url;
    final safeUrl = Uri(
      scheme: url.scheme,
      host: url.host,
      port: url.hasPort ? url.port : null,
      path: url.path,
    );
    return DeceiverException(
      'no matching mock found for:\n'
      '\n'
      '  ${request.method.toUpperCase()} $safeUrl'
      '${url.hasQuery ? ' (query omitted)' : ''}\n'
      '\n'
      'Registered mocks:\n'
      '${_deceiver.toPrettyPrintedString()}\n',
      safeUrl,
    );
  }

  /// Converts a [BaseRequest] into a [Request] so that matchers and response
  /// builders can read the body.
  ///
  /// The body of other request types (e.g. [StreamedRequest],
  /// [MultipartRequest]) is read into memory. Because a request can only be
  /// sent once, this copy is also what gets forwarded to the real client.
  Future<Request> _toRequest(BaseRequest baseRequest) async {
    if (baseRequest is Request) return baseRequest;

    final bodyBytes = await baseRequest.finalize().toBytes();
    return Request(baseRequest.method, baseRequest.url)
      ..headers.addAll(baseRequest.headers)
      ..bodyBytes = bodyBytes
      ..followRedirects = baseRequest.followRedirects
      ..maxRedirects = baseRequest.maxRedirects
      ..persistentConnection = baseRequest.persistentConnection;
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
