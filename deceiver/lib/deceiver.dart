/// Deceiver - a fake HTTP response library for Dart's `package:http`.
///
/// Register mock responses for HTTP requests and optionally allow unmatched
/// requests to pass through to the real HTTP client.
///
/// ```dart
/// import 'package:deceiver/deceiver.dart';
///
/// final deceiver = Deceiver();
/// deceiver.on.get('/api/users', jsonResponse(body: [{'name': 'Bilbo'}]));
/// deceiver.on.post('/api/users', jsonResponse(body: {'id': 1}, statusCode: 201));
/// deceiver.on.delete('/api/users/{id}', emptyResponse());
///
/// final client = deceiver.client();
/// ```
library;

export 'src/deceiver.dart';
export 'src/deceiver_builder.dart';
export 'src/deceiver_client.dart';
export 'src/deceiver_data.dart'
    show DeceiverData, DeceiverRecordedRequest, DeceiverResponseBuilder;
export 'src/deceiver_exception.dart';
export 'src/deceiver_request_matchers.dart';
export 'src/deceiver_response_helpers.dart';
export 'src/path_parameters.dart' show DeceiverPathParameters;
