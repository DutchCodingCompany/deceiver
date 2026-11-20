import 'dart:convert';

import 'package:http/http.dart';

/// A request the example app can send, shown as a card.
class ExampleCall {
  const ExampleCall({
    required this.title,
    required this.description,
    required this.method,
    required this.url,
    this.body,
  });

  final String title;
  final String description;
  final String method;

  /// A path relative to the API URL, such as `/users`, or a full URL.
  final String url;

  final Object? body;

  /// The URL to send the request to, for the API URL of the environment.
  Uri resolve(Uri apiUrl) =>
      Uri.parse(url.startsWith('/') ? '$apiUrl$url' : url);

  Future<Response> send(Client client, Uri apiUrl) {
    final request = Request(method, resolve(apiUrl));
    if (body case final body?) {
      request
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    return client.send(request).then(Response.fromStream);
  }
}

/// The example calls, grouped by what they show.
const sections = <String, List<ExampleCall>>{
  'Response helpers': [
    ExampleCall(
      title: 'List users',
      description:
          'jsonResponse() with a list. Try the "empty", "error" '
          'and "slow network" scenarios.',
      method: 'GET',
      url: '/users',
    ),
    ExampleCall(
      title: 'Delete a user',
      description: 'emptyResponse(), a 204 without body.',
      method: 'DELETE',
      url: '/users/1',
    ),
  ],
  'Your own response builders': [
    ExampleCall(
      title: 'Get user 1',
      description: 'Reads {id} with request.pathParameters.',
      method: 'GET',
      url: '/users/1',
    ),
    ExampleCall(
      title: 'Get user 42',
      description: 'The same mock answers 404 for an unknown id.',
      method: 'GET',
      url: '/users/42',
    ),
    ExampleCall(
      title: 'Create a user',
      description: 'Reads the request body: 201 with a name.',
      method: 'POST',
      url: '/users',
      body: {'name': 'Samwise'},
    ),
    ExampleCall(
      title: 'Create a user without name',
      description: 'The same mock answers 422 without a name.',
      method: 'POST',
      url: '/users',
      body: {'name': ''},
    ),
    ExampleCall(
      title: 'Monthly report',
      description: 'An async builder that takes 2 seconds.',
      method: 'GET',
      url: '/reports/monthly',
    ),
  ],
  'Changing responses': [
    ExampleCall(
      title: 'Poll notifications',
      description:
          'sequentialResponse(): none, one, then a 500, and over '
          'again.',
      method: 'GET',
      url: '/notifications',
    ),
    ExampleCall(
      title: 'Weather',
      description: 'randomResponse(): ok, 503 or 429 at random.',
      method: 'GET',
      url: '/weather',
    ),
  ],
  'Matching': [
    ExampleCall(
      title: 'Search "hobbit"',
      description: 'on.match() with a custom matcher on the query.',
      method: 'GET',
      url: '/search?q=hobbit',
    ),
    ExampleCall(
      title: 'Search "orc"',
      description: 'The matcher doesn\'t match: no mock answers.',
      method: 'GET',
      url: '/search?q=orc',
    ),
  ],
  'Other APIs': [
    ExampleCall(
      title: 'Log in',
      description:
          'on.at(authUrl) mocks a second API. Try the "logged out" '
          'scenario.',
      method: 'POST',
      url: 'https://auth.example.com/token',
      body: {'user': 'bilbo', 'password': 'precious'},
    ),
    ExampleCall(
      title: 'Geocode',
      description: 'A mock with a full URL as path.',
      method: 'GET',
      url: 'https://maps.example.com/geocode?q=Amsterdam',
    ),
  ],
  'Without a mock': [
    ExampleCall(
      title: 'Not mocked',
      description:
          'No mock matches, so the request goes to the real '
          'server, which doesn\'t exist. Turn on "Only allow mocks" to get '
          'a DeceiverException instead.',
      method: 'GET',
      url: '/not-mocked',
    ),
  ],
};
