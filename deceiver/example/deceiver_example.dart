// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';

import 'package:deceiver/deceiver.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

void main() async {
  await basicUsage();
  await responseHelpers();
  await dynamicResponses();
  await customMatchers();
  await sequentialResponses();
  await randomResponses();
  await namedScenarios();
  await passthroughBehavior();
  await runtimeToggle();
  await perMockToggle();
  debugOutput();
}

/// Demonstrates basic mock registration and usage.
Future<void> basicUsage() async {
  print('=== Basic Usage ===\n');

  final deceiver = Deceiver();

  // Register mocks for different HTTP methods using path templates.
  deceiver.on.get('/users', (req) => Response('["Bilbo", "Frodo"]', 200));
  deceiver.on.post('/users', (req) => Response('{"id": 1}', 201));
  deceiver.on.delete('/users/{id}', (req) => Response('', 204));

  // Create a client -- use it exactly like a regular http Client.
  final client = deceiver.client();

  final users = await client.get(Uri.parse('https://api.example.com/users'));
  print('GET /users: ${users.statusCode} ${users.body}');
  // GET /users: 200 ["Bilbo", "Frodo"]

  final created = await client.post(Uri.parse('https://api.example.com/users'));
  print('POST /users: ${created.statusCode} ${created.body}');
  // POST /users: 201 {"id": 1}

  final deleted = await client.delete(
    Uri.parse('https://api.example.com/users/42'),
  );
  print('DELETE /users/42: ${deleted.statusCode}');
  // DELETE /users/42: 204

  client.close();
  print('');
}

/// Demonstrates the jsonResponse, errorResponse, and emptyResponse helpers.
Future<void> responseHelpers() async {
  print('=== Response Helpers ===\n');

  final deceiver = Deceiver();

  // jsonResponse: encodes body as JSON, sets content-type automatically.
  deceiver.on.get(
    '/users',
    jsonResponse(
      body: [
        {'name': 'Bilbo'},
        {'name': 'Frodo'},
      ],
    ),
  );

  // errorResponse: returns an error with an optional JSON message.
  deceiver.on.get('/secret', errorResponse(403, message: 'Forbidden'));

  // emptyResponse: returns an empty body (defaults to 204).
  deceiver.on.delete('/users/{id}', emptyResponse());

  final client = deceiver.client();

  final users = await client.get(Uri.parse('https://api.example.com/users'));
  print('GET /users: ${users.body}');
  print('  content-type: ${users.headers['content-type']}');
  // GET /users: [{"name":"Bilbo"},{"name":"Frodo"}]
  //   content-type: application/json

  final secret = await client.get(Uri.parse('https://api.example.com/secret'));
  print('GET /secret: ${secret.statusCode} ${secret.body}');
  // GET /secret: 403 {"error":"Forbidden"}

  final deleted = await client.delete(
    Uri.parse('https://api.example.com/users/7'),
  );
  print('DELETE /users/7: ${deleted.statusCode}');
  // DELETE /users/7: 204

  client.close();
  print('');
}

/// Demonstrates building responses based on the incoming request.
Future<void> dynamicResponses() async {
  print('=== Dynamic Responses ===\n');

  final deceiver = Deceiver();

  // Use the request body to determine the response.
  deceiver.on.post('/users', (req) {
    final data = json.decode(req.body) as Map<String, Object?>;
    final name = data['name'] as String?;

    if (name == null || name.isEmpty) {
      return Response(
        json.encode({
          'errors': {'name': 'cannot be blank'},
        }),
        422,
      );
    }

    return Response(json.encode({'id': 1, 'name': name}), 201);
  });

  final client = deceiver.client();

  // Missing name -> 422
  final bad = await client.post(
    Uri.parse('https://api.example.com/users'),
    body: json.encode({'name': ''}),
    headers: {'content-type': 'application/json'},
  );
  print('POST (empty name): ${bad.statusCode} ${bad.body}');
  // POST (empty name): 422 {"errors":{"name":"cannot be blank"}}

  // Valid name -> 201
  final good = await client.post(
    Uri.parse('https://api.example.com/users'),
    body: json.encode({'name': 'Samwise'}),
    headers: {'content-type': 'application/json'},
  );
  print('POST (valid name): ${good.statusCode} ${good.body}');
  // POST (valid name): 201 {"id":1,"name":"Samwise"}

  client.close();
  print('');
}

/// Demonstrates custom request matchers with on.match().
Future<void> customMatchers() async {
  print('=== Custom Matchers ===\n');

  final deceiver = Deceiver();

  // Match by query parameter instead of path.
  deceiver.on.match(
    (req) => req.method == 'GET' && req.url.queryParameters['q'] == 'dart',
    jsonResponse(
      body: {
        'results': ['dart', 'dart:core'],
      },
    ),
    description: 'GET search?q=dart',
  );

  final client = deceiver.client();

  final result = await client.get(
    Uri.parse('https://api.example.com/search?q=dart'),
  );
  print('GET /search?q=dart: ${result.body}');
  // GET /search?q=dart: {"results":["dart","dart:core"]}

  client.close();
  print('');
}

/// Demonstrates sequential responses that cycle through a list.
Future<void> sequentialResponses() async {
  print('=== Sequential Responses ===\n');

  final deceiver = Deceiver();

  // Each call to GET /status returns the next response in the list.
  // After the last one, it cycles back to the first.
  deceiver.on.get(
    '/status',
    sequentialResponse([
      jsonResponse(body: {'status': 'loading'}),
      jsonResponse(body: {'status': 'ready'}),
      errorResponse(500, message: 'Crashed'),
    ]),
  );

  final client = deceiver.client();
  final uri = Uri.parse('https://api.example.com/status');

  for (var i = 0; i < 6; i++) {
    final r = await client.get(uri);
    print('Call ${i + 1}: ${r.statusCode} ${r.body}');
  }
  // Call 1: 200 {"status":"loading"}
  // Call 2: 200 {"status":"ready"}
  // Call 3: 500 {"error":"Crashed"}
  // Call 4: 200 {"status":"loading"}  (cycled)
  // Call 5: 200 {"status":"ready"}
  // Call 6: 500 {"error":"Crashed"}

  client.close();
  print('');
}

/// Demonstrates random responses picked from a list.
Future<void> randomResponses() async {
  print('=== Random Responses ===\n');

  final deceiver = Deceiver();

  // Each call picks a random response. Use a seeded Random for
  // deterministic results in tests.
  deceiver.on.get(
    '/flaky',
    randomResponse(
      [
        jsonResponse(body: {'status': 'ok'}),
        errorResponse(503, message: 'Try again'),
        errorResponse(429, message: 'Rate limited'),
      ],
      random: Random(42), // seeded for reproducible output
    ),
  );

  final client = deceiver.client();
  final uri = Uri.parse('https://api.example.com/flaky');

  for (var i = 0; i < 5; i++) {
    final r = await client.get(uri);
    print('Call ${i + 1}: ${r.statusCode} ${r.body}');
  }

  client.close();
  print('');
}

/// Demonstrates named scenarios for switching mock presets.
Future<void> namedScenarios() async {
  print('=== Named Scenarios ===\n');

  final deceiver = Deceiver();

  // Base mocks -- always active unless overridden by a scenario.
  deceiver.on.get(
    '/users',
    jsonResponse(
      body: [
        {'name': 'Bilbo'},
      ],
    ),
  );
  deceiver.on.get(
    '/posts',
    jsonResponse(
      body: [
        {'title': 'My Post'},
      ],
    ),
  );

  // Define scenarios that override specific endpoints.
  deceiver.scenario('happy', (on) {
    on.get(
      '/users',
      jsonResponse(
        body: [
          {'name': 'Bilbo'},
          {'name': 'Frodo'},
          {'name': 'Samwise'},
        ],
      ),
    );
    // /posts is NOT overridden -- falls through to base mock.
  });

  deceiver.scenario('error', (on) {
    on.get('/users', errorResponse(500, message: 'Server error'));
  });

  final client = deceiver.client();
  final usersUri = Uri.parse('https://api.example.com/users');
  final postsUri = Uri.parse('https://api.example.com/posts');

  // No scenario active -- base mocks only.
  var r = await client.get(usersUri);
  print('Base -> /users: ${r.body}');

  // Activate 'happy' scenario.
  deceiver.activateScenario('happy');
  r = await client.get(usersUri);
  print('Happy -> /users: ${r.body}');

  // /posts still falls through to base.
  r = await client.get(postsUri);
  print('Happy -> /posts: ${r.body}');

  // Switch to 'error' scenario.
  deceiver.activateScenario('error');
  r = await client.get(usersUri);
  print('Error -> /users: ${r.statusCode} ${r.body}');

  // Deactivate -- back to base.
  deceiver.deactivateScenario();
  r = await client.get(usersUri);
  print('Base again -> /users: ${r.body}');

  print('');
  print('Available scenarios: ${deceiver.scenarios}');
  print('Active scenario: ${deceiver.activeScenario}');

  client.close();
  print('');
}

/// Demonstrates passthrough behavior for unmatched requests.
Future<void> passthroughBehavior() async {
  print('=== Passthrough Behavior ===\n');

  final deceiver = Deceiver(); // onlyAllowMocks defaults to false
  deceiver.on.get('/mocked', jsonResponse(body: {'source': 'mock'}));

  // Provide a MockClient as the "real" client to demonstrate passthrough.
  final realClient = MockClient((request) async {
    return Response('{"source": "real", "path": "${request.url.path}"}', 200);
  });

  final client = deceiver.client(realClient);

  // Matched -> returns mock
  final mocked = await client.get(Uri.parse('https://api.example.com/mocked'));
  print('GET /mocked: ${mocked.body}');
  // GET /mocked: {"source":"mock"}

  // Not matched -> forwards to real client
  final real = await client.get(
    Uri.parse('https://api.example.com/real-endpoint'),
  );
  print('GET /real-endpoint: ${real.body}');
  // GET /real-endpoint: {"source": "real", "path": "/real-endpoint"}

  client.close();
  print('');
}

/// Demonstrates the global enabled toggle.
Future<void> runtimeToggle() async {
  print('=== Runtime Toggle (Global) ===\n');

  final deceiver = Deceiver();
  deceiver.on.get('/users', jsonResponse(body: {'source': 'mock'}));

  final realClient = MockClient((request) async {
    return Response('{"source": "real"}', 200);
  });
  final client = deceiver.client(realClient);

  // Mocks are enabled by default.
  var response = await client.get(Uri.parse('https://api.example.com/users'));
  print('enabled=true: ${response.body}');
  // enabled=true: {"source":"mock"}

  // Disable all mocks at runtime.
  deceiver.enabled = false;
  response = await client.get(Uri.parse('https://api.example.com/users'));
  print('enabled=false: ${response.body}');
  // enabled=false: {"source": "real"}

  // Re-enable mocks.
  deceiver.enabled = true;
  response = await client.get(Uri.parse('https://api.example.com/users'));
  print('enabled=true again: ${response.body}');
  // enabled=true again: {"source":"mock"}

  client.close();
  print('');
}

/// Demonstrates toggling individual mocks on and off.
Future<void> perMockToggle() async {
  print('=== Per-Mock Toggle ===\n');

  final deceiver = Deceiver();
  deceiver.on.get('/users', jsonResponse(body: {'endpoint': 'users'}));
  deceiver.on.get('/posts', jsonResponse(body: {'endpoint': 'posts'}));

  final realClient = MockClient((request) async {
    return Response('{"source": "real", "path": "${request.url.path}"}', 200);
  });
  final client = deceiver.client(realClient);

  // Both mocks active.
  var users = await client.get(Uri.parse('https://api.example.com/users'));
  var posts = await client.get(Uri.parse('https://api.example.com/posts'));
  print('Both enabled -> /users: ${users.body}');
  print('Both enabled -> /posts: ${posts.body}');

  // Disable just the /users mock.
  deceiver.registrations.first.isEnabled = false;

  users = await client.get(Uri.parse('https://api.example.com/users'));
  posts = await client.get(Uri.parse('https://api.example.com/posts'));
  print('/users disabled -> /users: ${users.body}');
  print('/users disabled -> /posts: ${posts.body}');
  // /users goes to real client, /posts still mocked

  client.close();
  print('');
}

/// Demonstrates debug output with toPrettyPrintedString().
void debugOutput() {
  print('=== Debug Output ===\n');

  final deceiver = Deceiver();
  deceiver.on.get('/users', jsonResponse(body: []));
  deceiver.on.post('/users', jsonResponse(body: {}, statusCode: 201));
  deceiver.on.delete('/users/{id}', emptyResponse());

  // Disable one mock to show status in output.
  deceiver.registrations.last.isEnabled = false;

  print(deceiver.toPrettyPrintedString());
  // Output:
  // Base mocks:
  //   GET /users (enabled)
  //   POST /users (enabled)
  //   DELETE /users/{id} (disabled)
}
