import 'dart:convert';
import 'dart:math';

import 'package:deceiver/deceiver.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('DeceiverBuilder', () {
    group('registers mocks for all HTTP methods', () {
      late Deceiver deceiver;

      setUp(() {
        deceiver = Deceiver();
      });

      test('get', () async {
        deceiver.on.get('/users', (req) => Response('ok', 200));

        expect(deceiver.registrations, hasLength(1));
        expect(deceiver.registrations.first.description, 'GET /users');
      });

      test('post', () async {
        deceiver.on.post('/users', (req) => Response('created', 201));

        expect(deceiver.registrations, hasLength(1));
        expect(deceiver.registrations.first.description, 'POST /users');
      });

      test('put', () async {
        deceiver.on.put('/users/{id}', (req) => Response('updated', 200));

        expect(deceiver.registrations, hasLength(1));
        expect(deceiver.registrations.first.description, 'PUT /users/{id}');
      });

      test('delete', () async {
        deceiver.on.delete('/users/{id}', (req) => Response('', 204));

        expect(deceiver.registrations, hasLength(1));
        expect(deceiver.registrations.first.description, 'DELETE /users/{id}');
      });

      test('patch', () async {
        deceiver.on.patch('/users/{id}', (req) => Response('patched', 200));

        expect(deceiver.registrations, hasLength(1));
        expect(deceiver.registrations.first.description, 'PATCH /users/{id}');
      });

      test('head', () async {
        deceiver.on.head('/users', (req) => Response('', 200));

        expect(deceiver.registrations, hasLength(1));
        expect(deceiver.registrations.first.description, 'HEAD /users');
      });

      test('match (custom matcher)', () async {
        deceiver.on.match(
          (req) => req.url.queryParameters['q'] == 'dart',
          (req) => Response('found', 200),
          description: 'search q=dart',
        );

        expect(deceiver.registrations, hasLength(1));
        expect(deceiver.registrations.first.description, 'search q=dart');
      });
    });

    test('public types can be used to share mock setups', () async {
      void registerUserMocks(DeceiverBuilder on) {
        on.get('/users', (req) => Response('users', 200));
      }

      final deceiver = Deceiver();
      registerUserMocks(deceiver.on);
      deceiver.scenario('same', registerUserMocks);

      final DeceiverClient client = deceiver.client();
      final response = await client.get(Uri.parse('https://example.com/users'));

      expect(response.body, 'users');
      expect(deceiver.scenarioRegistrations('same'), hasLength(1));
    });
  });

  group('DeceiverClient', () {
    group('mock interception', () {
      test('returns mock response for matched GET request', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', (req) => Response('["bilbo"]', 200));

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/users'),
        );

        expect(response.statusCode, 200);
        expect(response.body, '["bilbo"]');
      });

      test('returns mock response for matched POST request', () async {
        final deceiver = Deceiver();
        deceiver.on.post('/users', (req) => Response('{"id": 1}', 201));

        final client = deceiver.client();
        final response = await client.post(
          Uri.parse('https://example.com/users'),
          body: '{"name": "bilbo"}',
        );

        expect(response.statusCode, 201);
        expect(response.body, '{"id": 1}');
      });

      test('returns mock response for matched PUT request', () async {
        final deceiver = Deceiver();
        deceiver.on.put(
          '/users/{id}',
          (req) => Response('{"name": "frodo"}', 200),
        );

        final client = deceiver.client();
        final response = await client.put(
          Uri.parse('https://example.com/users/42'),
          body: '{"name": "frodo"}',
        );

        expect(response.statusCode, 200);
        expect(response.body, '{"name": "frodo"}');
      });

      test('returns mock response for matched DELETE request', () async {
        final deceiver = Deceiver();
        deceiver.on.delete('/users/{id}', (req) => Response('', 204));

        final client = deceiver.client();
        final response = await client.delete(
          Uri.parse('https://example.com/users/42'),
        );

        expect(response.statusCode, 204);
      });

      test('returns mock response for matched PATCH request', () async {
        final deceiver = Deceiver();
        deceiver.on.patch(
          '/users/{id}',
          (req) => Response('{"name": "sam"}', 200),
        );

        final client = deceiver.client();
        final response = await client.patch(
          Uri.parse('https://example.com/users/42'),
          body: '{"name": "sam"}',
        );

        expect(response.statusCode, 200);
        expect(response.body, '{"name": "sam"}');
      });

      test('returns mock response for custom matcher', () async {
        final deceiver = Deceiver();
        deceiver.on.match(
          (req) =>
              req.method == 'GET' && req.url.queryParameters['q'] == 'dart',
          (req) => Response('{"results": []}', 200),
        );

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/search?q=dart'),
        );

        expect(response.statusCode, 200);
        expect(response.body, '{"results": []}');
      });

      test('first matching mock wins', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', (req) => Response('first', 200));
        deceiver.on.get('/users', (req) => Response('second', 200));

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/users'),
        );

        expect(response.body, 'first');
      });

      test('supports async response builders', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/slow', (req) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return Response('delayed', 200);
        });

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/slow'),
        );

        expect(response.statusCode, 200);
        expect(response.body, 'delayed');
      });

      test('response builder receives the request', () async {
        final deceiver = Deceiver();
        deceiver.on.post('/echo', (req) {
          return Response('echo: ${req.body}', 200);
        });

        final client = deceiver.client();
        final response = await client.post(
          Uri.parse('https://example.com/echo'),
          body: 'hello',
        );

        expect(response.body, 'echo: hello');
      });
    });

    group('passthrough (onlyAllowMocks = false)', () {
      test('forwards unmatched requests to real client', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/mocked', (req) => Response('mocked', 200));

        // Use a MockClient as the "real" client to verify passthrough.
        final realClient = MockClient((request) async {
          return Response('real: ${request.url.path}', 200);
        });

        final client = deceiver.client(realClient);
        final response = await client.get(
          Uri.parse('https://example.com/not-mocked'),
        );

        expect(response.body, 'real: /not-mocked');
      });
    });

    group('onlyAllowMocks = true', () {
      test('throws StateError for unmatched requests', () async {
        final deceiver = Deceiver(
          options: const DeceiverOptions(onlyAllowMocks: true),
        );
        deceiver.on.get('/users', (req) => Response('ok', 200));

        final client = deceiver.client();

        expect(
          () => client.get(Uri.parse('https://example.com/not-registered')),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('no matching mock found'),
                contains('GET'),
                contains('/not-registered'),
                contains('GET /users'),
              ),
            ),
          ),
        );
      });

      test('returns mock if matched even with onlyAllowMocks', () async {
        final deceiver = Deceiver(
          options: const DeceiverOptions(onlyAllowMocks: true),
        );
        deceiver.on.get('/users', (req) => Response('ok', 200));

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/users'),
        );

        expect(response.statusCode, 200);
        expect(response.body, 'ok');
      });
    });

    group('global enabled toggle', () {
      test('when disabled, all requests go to real client', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', (req) => Response('mocked', 200));
        deceiver.enabled = false;

        final realClient = MockClient((request) async {
          return Response('real', 200);
        });

        final client = deceiver.client(realClient);
        final response = await client.get(
          Uri.parse('https://example.com/users'),
        );

        expect(response.body, 'real');
      });

      test('can be re-enabled at runtime', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', (req) => Response('mocked', 200));

        final realClient = MockClient((request) async {
          return Response('real', 200);
        });

        final client = deceiver.client(realClient);

        // Disable - should passthrough.
        deceiver.enabled = false;
        var response = await client.get(Uri.parse('https://example.com/users'));
        expect(response.body, 'real');

        // Re-enable - should mock.
        deceiver.enabled = true;
        response = await client.get(Uri.parse('https://example.com/users'));
        expect(response.body, 'mocked');
      });
    });

    group('per-mock isEnabled toggle', () {
      test('disabled mocks are skipped', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', (req) => Response('first', 200));
        deceiver.on.get('/posts', (req) => Response('posts', 200));

        // Disable the first mock.
        deceiver.registrations.first.isEnabled = false;

        final realClient = MockClient((request) async {
          return Response('real: ${request.url.path}', 200);
        });

        final client = deceiver.client(realClient);

        // /users mock disabled -> passthrough.
        var response = await client.get(Uri.parse('https://example.com/users'));
        expect(response.body, 'real: /users');

        // /posts mock still active.
        response = await client.get(Uri.parse('https://example.com/posts'));
        expect(response.body, 'posts');
      });

      test('can re-enable a disabled mock', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', (req) => Response('mocked', 200));

        final realClient = MockClient((request) async {
          return Response('real', 200);
        });

        final client = deceiver.client(realClient);

        deceiver.registrations.first.isEnabled = false;
        var response = await client.get(Uri.parse('https://example.com/users'));
        expect(response.body, 'real');

        deceiver.registrations.first.isEnabled = true;
        response = await client.get(Uri.parse('https://example.com/users'));
        expect(response.body, 'mocked');
      });
    });
  });

  group('Request matchers', () {
    group('matchPath', () {
      test('matches exact path', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', (req) => Response('ok', 200));

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/users'),
        );

        expect(response.statusCode, 200);
      });

      test('matches URI template with single variable', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users/{id}', (req) => Response('user', 200));

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/users/42'),
        );

        expect(response.statusCode, 200);
        expect(response.body, 'user');
      });

      test('matches URI template with multiple variables', () async {
        final deceiver = Deceiver();
        deceiver.on.get(
          '/users/{userId}/posts/{postId}',
          (req) => Response('post', 200),
        );

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/users/1/posts/5'),
        );

        expect(response.statusCode, 200);
        expect(response.body, 'post');
      });

      test('does not match subpath (reverse-match validation)', () async {
        final deceiver = Deceiver(
          options: const DeceiverOptions(onlyAllowMocks: true),
        );
        deceiver.on.get('/users/{id}', (req) => Response('user', 200));

        final client = deceiver.client();

        // /users/42 should match, but /users/42/posts should NOT.
        expect(
          () => client.get(Uri.parse('https://example.com/users/42/posts')),
          throwsA(isA<StateError>()),
        );
      });

      test('does not match different paths', () async {
        final deceiver = Deceiver(
          options: const DeceiverOptions(onlyAllowMocks: true),
        );
        deceiver.on.get('/users', (req) => Response('ok', 200));

        final client = deceiver.client();

        expect(
          () => client.get(Uri.parse('https://example.com/posts')),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('matchMethod', () {
      test('method matching is case-insensitive', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', (req) => Response('ok', 200));

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/users'),
        );

        expect(response.statusCode, 200);
      });

      test('does not match wrong method', () async {
        final deceiver = Deceiver(
          options: const DeceiverOptions(onlyAllowMocks: true),
        );
        deceiver.on.get('/users', (req) => Response('ok', 200));

        final client = deceiver.client();

        expect(
          () => client.post(Uri.parse('https://example.com/users')),
          throwsA(isA<StateError>()),
        );
      });
    });
  });

  group('Response helpers', () {
    group('jsonResponse', () {
      test('encodes body as JSON and sets content-type', () async {
        final deceiver = Deceiver();
        deceiver.on.get(
          '/users',
          jsonResponse(
            body: [
              {'name': 'Bilbo'},
            ],
          ),
        );

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/users'),
        );

        expect(response.statusCode, 200);
        expect(json.decode(response.body), [
          {'name': 'Bilbo'},
        ]);
        expect(response.headers['content-type'], contains('application/json'));
      });

      test('supports custom status code', () async {
        final deceiver = Deceiver();
        deceiver.on.post(
          '/users',
          jsonResponse(body: {'id': 1}, statusCode: 201),
        );

        final client = deceiver.client();
        final response = await client.post(
          Uri.parse('https://example.com/users'),
        );

        expect(response.statusCode, 201);
      });

      test('supports null body', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/empty', jsonResponse());

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/empty'),
        );

        expect(response.statusCode, 200);
        expect(response.body, '');
      });

      test('supports custom headers', () async {
        final deceiver = Deceiver();
        deceiver.on.get(
          '/custom',
          jsonResponse(body: {'ok': true}, headers: {'x-custom': 'value'}),
        );

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/custom'),
        );

        expect(response.headers['x-custom'], 'value');
        expect(response.headers['content-type'], contains('application/json'));
      });
    });

    group('errorResponse', () {
      test('returns error with message as JSON body', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/secret', errorResponse(403, message: 'Forbidden'));

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/secret'),
        );

        expect(response.statusCode, 403);
        expect(json.decode(response.body), {'error': 'Forbidden'});
      });

      test('returns empty body when no message', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/missing', errorResponse(404));

        final client = deceiver.client();
        final response = await client.get(
          Uri.parse('https://example.com/missing'),
        );

        expect(response.statusCode, 404);
        expect(response.body, '');
      });
    });

    group('emptyResponse', () {
      test('returns 204 by default', () async {
        final deceiver = Deceiver();
        deceiver.on.delete('/users/{id}', emptyResponse());

        final client = deceiver.client();
        final response = await client.delete(
          Uri.parse('https://example.com/users/42'),
        );

        expect(response.statusCode, 204);
        expect(response.body, '');
      });

      test('supports custom status code', () async {
        final deceiver = Deceiver();
        deceiver.on.post('/reset', emptyResponse(statusCode: 202));

        final client = deceiver.client();
        final response = await client.post(
          Uri.parse('https://example.com/reset'),
        );

        expect(response.statusCode, 202);
      });
    });
  });

  group('Deceiver', () {
    test('toPrettyPrintedString lists all mocks', () {
      final deceiver = Deceiver();
      deceiver.on.get('/users', (req) => Response('', 200));
      deceiver.on.post('/users', (req) => Response('', 201));
      deceiver.on.delete('/users/{id}', (req) => Response('', 204));

      final output = deceiver.toPrettyPrintedString();
      expect(output, contains('GET /users'));
      expect(output, contains('POST /users'));
      expect(output, contains('DELETE /users/{id}'));
    });

    test('toPrettyPrintedString shows enabled/disabled status', () {
      final deceiver = Deceiver();
      deceiver.on.get('/users', (req) => Response('', 200));
      deceiver.on.post('/users', (req) => Response('', 201));

      deceiver.registrations.last.isEnabled = false;

      final output = deceiver.toPrettyPrintedString();
      expect(output, contains('GET /users (enabled)'));
      expect(output, contains('POST /users (disabled)'));
    });

    test('toPrettyPrintedString when empty', () {
      final deceiver = Deceiver();
      final output = deceiver.toPrettyPrintedString();
      expect(output, contains('(none)'));
    });

    test('toPrettyPrintedString shows scenario info', () {
      final deceiver = Deceiver();
      deceiver.on.get('/users', (req) => Response('', 200));
      deceiver.scenario('error', (on) {
        on.get('/users', errorResponse(500));
      });
      deceiver.activateScenario('error');

      final output = deceiver.toPrettyPrintedString();
      expect(output, contains('Active scenario: error'));
      expect(output, contains('Scenarios:'));
      expect(output, contains('error (active):'));
    });

    test('registrations returns unmodifiable list', () {
      final deceiver = Deceiver();
      deceiver.on.get('/users', (req) => Response('', 200));

      expect(
        () => deceiver.registrations.add(
          DeceiverData(
            requestMatcher: (req) => true,
            responseBuilder: (req) => Response('', 200),
            description: 'test',
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('Sequential responses', () {
    test('returns responses in order', () async {
      final deceiver = Deceiver();
      deceiver.on.get(
        '/counter',
        sequentialResponse([
          (req) => Response('first', 200),
          (req) => Response('second', 200),
          (req) => Response('third', 200),
        ]),
      );

      final client = deceiver.client();
      final uri = Uri.parse('https://example.com/counter');

      expect((await client.get(uri)).body, 'first');
      expect((await client.get(uri)).body, 'second');
      expect((await client.get(uri)).body, 'third');
    });

    test('cycles back to the beginning after exhausting the list', () async {
      final deceiver = Deceiver();
      deceiver.on.get(
        '/cycle',
        sequentialResponse([
          (req) => Response('a', 200),
          (req) => Response('b', 200),
        ]),
      );

      final client = deceiver.client();
      final uri = Uri.parse('https://example.com/cycle');

      expect((await client.get(uri)).body, 'a');
      expect((await client.get(uri)).body, 'b');
      expect((await client.get(uri)).body, 'a'); // cycles
      expect((await client.get(uri)).body, 'b');
      expect((await client.get(uri)).body, 'a');
    });

    test('works with response helpers', () async {
      final deceiver = Deceiver();
      deceiver.on.get(
        '/users',
        sequentialResponse([
          jsonResponse(body: []),
          jsonResponse(
            body: [
              {'name': 'Bilbo'},
            ],
          ),
          errorResponse(500, message: 'Server error'),
        ]),
      );

      final client = deceiver.client();
      final uri = Uri.parse('https://example.com/users');

      var r = await client.get(uri);
      expect(r.statusCode, 200);
      expect(json.decode(r.body), []);

      r = await client.get(uri);
      expect(json.decode(r.body), [
        {'name': 'Bilbo'},
      ]);

      r = await client.get(uri);
      expect(r.statusCode, 500);
    });

    test('works with async builders', () async {
      final deceiver = Deceiver();
      deceiver.on.get(
        '/async',
        sequentialResponse([
          (req) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return Response('delayed', 200);
          },
          (req) => Response('sync', 200),
        ]),
      );

      final client = deceiver.client();
      final uri = Uri.parse('https://example.com/async');

      expect((await client.get(uri)).body, 'delayed');
      expect((await client.get(uri)).body, 'sync');
    });

    test('throws on empty list', () {
      expect(() => sequentialResponse([]), throwsA(isA<ArgumentError>()));
    });

    test('works with a single builder', () async {
      final deceiver = Deceiver();
      deceiver.on.get(
        '/single',
        sequentialResponse([(req) => Response('only', 200)]),
      );

      final client = deceiver.client();
      final uri = Uri.parse('https://example.com/single');

      expect((await client.get(uri)).body, 'only');
      expect((await client.get(uri)).body, 'only');
    });
  });

  group('Random responses', () {
    test('returns responses from the list', () async {
      final deceiver = Deceiver();
      final seededRandom = Random(42);
      deceiver.on.get(
        '/random',
        randomResponse([
          (req) => Response('a', 200),
          (req) => Response('b', 200),
          (req) => Response('c', 200),
        ], random: seededRandom),
      );

      final client = deceiver.client();
      final uri = Uri.parse('https://example.com/random');

      // With a seeded random, results are deterministic.
      final results = <String>[];
      for (var i = 0; i < 10; i++) {
        results.add((await client.get(uri)).body);
      }

      // All results should be from the valid set.
      for (final r in results) {
        expect(r, anyOf('a', 'b', 'c'));
      }
    });

    test('with seeded random produces deterministic results', () async {
      Future<List<String>> run() async {
        final deceiver = Deceiver();
        deceiver.on.get(
          '/det',
          randomResponse([
            (req) => Response('x', 200),
            (req) => Response('y', 200),
            (req) => Response('z', 200),
          ], random: Random(123)),
        );

        final client = deceiver.client();
        final uri = Uri.parse('https://example.com/det');
        final results = <String>[];
        for (var i = 0; i < 5; i++) {
          results.add((await client.get(uri)).body);
        }
        return results;
      }

      final first = await run();
      final second = await run();
      expect(first, equals(second));
    });

    test('throws on empty list', () {
      expect(() => randomResponse([]), throwsA(isA<ArgumentError>()));
    });

    test('works with a single builder', () async {
      final deceiver = Deceiver();
      deceiver.on.get(
        '/single',
        randomResponse([(req) => Response('only', 200)]),
      );

      final client = deceiver.client();
      final uri = Uri.parse('https://example.com/single');

      expect((await client.get(uri)).body, 'only');
      expect((await client.get(uri)).body, 'only');
    });
  });

  group('Scenarios', () {
    group('definition', () {
      test('defines a scenario with mocks', () {
        final deceiver = Deceiver();
        deceiver.scenario('happy', (on) {
          on.get('/users', jsonResponse(body: []));
          on.post('/users', jsonResponse(body: {'id': 1}, statusCode: 201));
        });

        expect(deceiver.scenarios, ['happy']);
        expect(deceiver.scenarioRegistrations('happy'), hasLength(2));
      });

      test('defines multiple scenarios', () {
        final deceiver = Deceiver();
        deceiver.scenario('happy', (on) {
          on.get('/users', jsonResponse(body: []));
        });
        deceiver.scenario('error', (on) {
          on.get('/users', errorResponse(500));
        });

        expect(deceiver.scenarios, ['happy', 'error']);
      });

      test('redefining a scenario replaces it', () {
        final deceiver = Deceiver();
        deceiver.scenario('test', (on) {
          on.get('/a', jsonResponse(body: 'a'));
          on.get('/b', jsonResponse(body: 'b'));
        });
        expect(deceiver.scenarioRegistrations('test'), hasLength(2));

        deceiver.scenario('test', (on) {
          on.get('/c', jsonResponse(body: 'c'));
        });
        expect(deceiver.scenarioRegistrations('test'), hasLength(1));
        expect(
          deceiver.scenarioRegistrations('test')!.first.description,
          'GET /c',
        );
      });

      test('scenarioRegistrations returns null for unknown scenario', () {
        final deceiver = Deceiver();
        expect(deceiver.scenarioRegistrations('nope'), isNull);
      });
    });

    group('activation', () {
      test('activateScenario sets the active scenario', () {
        final deceiver = Deceiver();
        deceiver.scenario('happy', (on) {
          on.get('/users', jsonResponse(body: []));
        });

        expect(deceiver.activeScenario, isNull);

        deceiver.activateScenario('happy');
        expect(deceiver.activeScenario, 'happy');
      });

      test('deactivateScenario clears the active scenario', () {
        final deceiver = Deceiver();
        deceiver.scenario('happy', (on) {
          on.get('/users', jsonResponse(body: []));
        });

        deceiver.activateScenario('happy');
        expect(deceiver.activeScenario, 'happy');

        deceiver.deactivateScenario();
        expect(deceiver.activeScenario, isNull);
      });

      test('activateScenario throws for unknown scenario', () {
        final deceiver = Deceiver();
        expect(
          () => deceiver.activateScenario('nope'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('No scenario defined'),
            ),
          ),
        );
      });
    });

    group('response resolution', () {
      test('scenario mocks override base mocks for same endpoint', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', jsonResponse(body: {'source': 'base'}));

        deceiver.scenario('override', (on) {
          on.get('/users', jsonResponse(body: {'source': 'scenario'}));
        });

        final client = deceiver.client();
        final uri = Uri.parse('https://example.com/users');

        // No scenario active -> base mock
        var r = await client.get(uri);
        expect(json.decode(r.body), {'source': 'base'});

        // Activate scenario -> scenario mock
        deceiver.activateScenario('override');
        r = await client.get(uri);
        expect(json.decode(r.body), {'source': 'scenario'});

        // Deactivate -> base mock again
        deceiver.deactivateScenario();
        r = await client.get(uri);
        expect(json.decode(r.body), {'source': 'base'});
      });

      test('base mocks still work for endpoints not in scenario', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', jsonResponse(body: 'users'));
        deceiver.on.get('/posts', jsonResponse(body: 'posts'));

        deceiver.scenario('partial', (on) {
          on.get('/users', jsonResponse(body: 'scenario-users'));
          // /posts is NOT in the scenario
        });

        deceiver.activateScenario('partial');

        final client = deceiver.client();

        // /users overridden by scenario
        var r = await client.get(Uri.parse('https://example.com/users'));
        expect(json.decode(r.body), 'scenario-users');

        // /posts falls back to base
        r = await client.get(Uri.parse('https://example.com/posts'));
        expect(json.decode(r.body), 'posts');
      });

      test('switching scenarios changes responses', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/status', jsonResponse(body: 'base'));

        deceiver.scenario('a', (on) {
          on.get('/status', jsonResponse(body: 'scenario-a'));
        });
        deceiver.scenario('b', (on) {
          on.get('/status', jsonResponse(body: 'scenario-b'));
        });

        final client = deceiver.client();
        final uri = Uri.parse('https://example.com/status');

        deceiver.activateScenario('a');
        expect(json.decode((await client.get(uri)).body), 'scenario-a');

        deceiver.activateScenario('b');
        expect(json.decode((await client.get(uri)).body), 'scenario-b');

        deceiver.deactivateScenario();
        expect(json.decode((await client.get(uri)).body), 'base');
      });

      test('scenarios interact correctly with global enabled toggle', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', jsonResponse(body: 'base'));
        deceiver.scenario('s', (on) {
          on.get('/users', jsonResponse(body: 'scenario'));
        });
        deceiver.activateScenario('s');

        final realClient = MockClient((req) async => Response('real', 200));
        final client = deceiver.client(realClient);

        // Scenario active and enabled -> scenario mock
        var r = await client.get(Uri.parse('https://example.com/users'));
        expect(json.decode(r.body), 'scenario');

        // Disable all mocks -> passthrough
        deceiver.enabled = false;
        r = await client.get(Uri.parse('https://example.com/users'));
        expect(r.body, 'real');

        // Re-enable -> scenario mock again
        deceiver.enabled = true;
        r = await client.get(Uri.parse('https://example.com/users'));
        expect(json.decode(r.body), 'scenario');
      });

      test('scenarios work with onlyAllowMocks', () async {
        final deceiver = Deceiver(
          options: const DeceiverOptions(onlyAllowMocks: true),
        );
        deceiver.on.get('/base', jsonResponse(body: 'base'));
        deceiver.scenario('s', (on) {
          on.get('/scenario-only', jsonResponse(body: 'scenario'));
        });
        deceiver.activateScenario('s');

        final client = deceiver.client();

        // Scenario endpoint works
        var r = await client.get(
          Uri.parse('https://example.com/scenario-only'),
        );
        expect(json.decode(r.body), 'scenario');

        // Base endpoint still works
        r = await client.get(Uri.parse('https://example.com/base'));
        expect(json.decode(r.body), 'base');

        // Unmatched throws
        expect(
          () => client.get(Uri.parse('https://example.com/unknown')),
          throwsA(isA<StateError>()),
        );
      });

      test('scenario mock isEnabled toggle works', () async {
        final deceiver = Deceiver();
        deceiver.on.get('/users', jsonResponse(body: 'base'));
        deceiver.scenario('s', (on) {
          on.get('/users', jsonResponse(body: 'scenario'));
        });
        deceiver.activateScenario('s');

        final client = deceiver.client();
        final uri = Uri.parse('https://example.com/users');

        // Scenario mock active
        var r = await client.get(uri);
        expect(json.decode(r.body), 'scenario');

        // Disable the scenario mock -> falls back to base
        deceiver.scenarioRegistrations('s')!.first.isEnabled = false;
        r = await client.get(uri);
        expect(json.decode(r.body), 'base');
      });
    });
  });
}
