import 'dart:convert';

import 'package:deceiver/deceiver.dart';
import 'package:http/http.dart';

/// The environments the example app can run against. Each has its own API,
/// so switching resets the mocks with a new base URL.
enum Environment {
  production('https://api.example.com/v1'),
  staging('https://staging.api.example.com/v1');

  const Environment(this._apiUrl);

  final String _apiUrl;

  Uri get apiUrl => Uri.parse(_apiUrl);
}

/// A second API, for logging in. Mocked with `on.at()`.
final authUrl = Uri.parse('https://auth.example.com');

/// Creates the Deceiver of the example app with all its mocks.
Deceiver createDeceiver(Environment environment) {
  final deceiver = Deceiver(baseUrl: environment.apiUrl, name: 'Example API');
  registerMocks(deceiver, environment);
  return deceiver;
}

/// Registers the mocks for [environment]. Paths are relative to the base URL
/// of the Deceiver, such as `https://api.example.com/v1`.
void registerMocks(Deceiver deceiver, Environment environment) {
  final users = [
    {'id': 1, 'name': 'Bilbo'},
    {'id': 2, 'name': 'Frodo'},
    if (environment == Environment.staging) {'id': 3, 'name': 'Test user'},
  ];

  // Response helpers: a JSON list, and an empty 204.
  deceiver.on.get('/users', jsonResponse(body: users));
  deceiver.on.delete('/users/{id}', emptyResponse());

  // A response builder of your own, using the {id} path parameter.
  deceiver.on.get('/users/{id}', (request) {
    final id = int.tryParse(request.pathParameters['id']!);
    final user = users.where((u) => u['id'] == id).firstOrNull;
    if (user == null) {
      return errorResponse(404, message: 'No user $id')(request);
    }
    return jsonResponse(body: user)(request);
  });

  // Validates the request body: 422 without a name, 201 otherwise.
  deceiver.on.post('/users', (request) {
    final name = (jsonDecode(request.body) as Map)['name'] as String? ?? '';
    if (name.trim().isEmpty) {
      return errorResponse(422, message: 'Name cannot be blank')(request);
    }
    return jsonResponse(body: {'id': 4, 'name': name}, statusCode: 201)(
      request,
    );
  });

  // Polling: every call returns the next response, then it starts over.
  deceiver.on.get(
    '/notifications',
    sequentialResponse([
      jsonResponse(body: []),
      jsonResponse(
        body: [
          {'message': 'Gandalf is coming'},
        ],
      ),
      errorResponse(500, message: 'Server error'),
    ]),
  );

  // A flaky endpoint: a random response on every call.
  deceiver.on.get(
    '/weather',
    randomResponse([
      jsonResponse(body: {'forecast': 'Sunny in the Shire'}),
      errorResponse(503, message: 'Try again'),
      errorResponse(429, message: 'Rate limited'),
    ]),
  );

  // A custom matcher: matches on a query parameter instead of the path.
  deceiver.on.match(
    (request) =>
        request.method == 'GET' &&
        request.url.path.endsWith('/search') &&
        request.url.queryParameters['q'] == 'hobbit',
    jsonResponse(
      body: {
        'results': ['The Hobbit', 'The Hobbit: An Unexpected Journey'],
      },
    ),
    description: 'GET /search?q=hobbit',
  );

  // A slow response, to see loading states.
  deceiver.on.get('/reports/monthly', (request) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return jsonResponse(body: {'month': 'March', 'visitors': 1337})(request);
  });

  // Another API: paths are relative to authUrl.
  deceiver.on.at(authUrl).post('/token', jsonResponse(body: {'token': 'abc'}));

  // An API with a fixed URL: a full URL as path.
  deceiver.on.get(
    'https://maps.example.com/geocode',
    jsonResponse(body: {'lat': 52.37, 'lng': 4.89}),
  );

  // Scenarios override the base mocks while active.
  deceiver.scenario('empty', (on) {
    on.get('/users', jsonResponse(body: []));
    on.get('/notifications', jsonResponse(body: []));
  });
  deceiver.scenario('error', (on) {
    on.get('/users', errorResponse(500, message: 'Server error'));
    on.get('/users/{id}', errorResponse(500, message: 'Server error'));
  });
  deceiver.scenario('slow network', (on) {
    on.get('/users', (request) async {
      await Future<void>.delayed(const Duration(seconds: 3));
      return Response(jsonEncode(users), 200);
    });
  });
  deceiver.scenario('logged out', (on) {
    on
        .at(authUrl)
        .post('/token', errorResponse(401, message: 'Invalid credentials'));
  });
}
