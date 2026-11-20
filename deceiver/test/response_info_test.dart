import 'package:deceiver/deceiver.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  DeceiverResponseInfo infoOf(DeceiverResponseBuilder builder) {
    final deceiver = Deceiver()..on.get('/x', builder);
    return deceiver.registrations.single.responseInfo;
  }

  test('jsonResponse describes its status, headers and body', () {
    final info = infoOf(
      jsonResponse(
        body: [
          {'name': 'Bilbo'},
          {'name': 'Frodo'},
        ],
        statusCode: 201,
      ),
    );

    expect(info.kind, DeceiverResponseKind.json);
    expect(info.statusCode, 201);
    expect(info.headers, {'content-type': 'application/json'});
    expect(info.body, '[{"name":"Bilbo"},{"name":"Frodo"}]');
    expect(info.summary, '201 · JSON · 2 items');
  });

  test('summarises JSON objects, single items and scalars', () {
    expect(
      infoOf(jsonResponse(body: {'id': 1})).summary,
      '200 · JSON · 1 field',
    );
    expect(infoOf(jsonResponse(body: [1])).summary, '200 · JSON · 1 item');
    expect(infoOf(jsonResponse(body: 'ok')).summary, '200 · JSON · "ok"');
    expect(infoOf(jsonResponse()).summary, '200 · JSON');
  });

  test('jsonResponse still encodes the body on every request', () async {
    final users = <String>[];
    final deceiver = Deceiver()..on.get('/users', jsonResponse(body: users));
    users.add('Bilbo');

    final response = await deceiver.client().get(
      Uri.parse('https://x.com/users'),
    );

    expect(response.body, '["Bilbo"]');
  });

  test('errorResponse describes its message', () {
    final info = infoOf(errorResponse(500, message: 'Server error'));

    expect(info.kind, DeceiverResponseKind.error);
    expect(info.body, '{"error":"Server error"}');
    expect(info.summary, '500 · error: "Server error"');
    expect(infoOf(errorResponse(404)).summary, '404 · error');
  });

  test('emptyResponse describes its status', () {
    expect(infoOf(emptyResponse()).summary, '204 · empty');
  });

  test('sequential and random responses list their variants', () {
    final sequence = infoOf(
      sequentialResponse([
        jsonResponse(),
        errorResponse(500),
        (req) => Response('', 200),
      ]),
    );
    final random = infoOf(randomResponse([jsonResponse(), emptyResponse()]));

    expect(sequence.variants.map((v) => v.kind), [
      DeceiverResponseKind.json,
      DeceiverResponseKind.error,
      DeceiverResponseKind.custom,
    ]);
    expect(sequence.summary, 'sequence: 200 → 500 → ?');
    expect(random.summary, 'random: 200 | 204');
  });

  test('a builder of your own is custom', () {
    final info = infoOf((req) => Response('', 200));

    expect(info.kind, DeceiverResponseKind.custom);
    expect(info.summary, 'custom response');
  });

  test('works for on.match, scenarios and on.at', () {
    final deceiver = Deceiver()
      ..on.match((req) => true, emptyResponse())
      ..on.at(Uri.parse('https://auth.x.com')).post('/token', jsonResponse())
      ..scenario('s', (on) => on.get('/x', errorResponse(500)));

    expect(deceiver.registrations.map((m) => m.responseInfo.kind), [
      DeceiverResponseKind.empty,
      DeceiverResponseKind.json,
    ]);
    expect(
      deceiver.scenarioRegistrations('s')!.single.responseInfo.kind,
      DeceiverResponseKind.error,
    );
  });
}
