import 'package:hydra_client/hydra_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('deleteCommitTx uses /commits/{txId}', () async {
    String? path;
    final mock = MockClient((request) async {
      path = request.url.path;
      return http.Response('ok', 200);
    });
    final config = HydraClientConfig(host: '127.0.0.1', port: 4001);
    final client = HydraHttpClient(config: config, httpClient: mock);
    addTearDown(client.close);

    await client.deleteCommitTx('deadbeef');
    expect(path, '/commits/deadbeef');
  });

  test('getSnapshotLastSeen hits /snapshot/last-seen', () async {
    String? path;
    final mock = MockClient((request) async {
      path = request.url.path;
      return http.Response('{}', 200);
    });
    final config = HydraClientConfig(host: 'h', port: 1);
    final client = HydraHttpClient(config: config, httpClient: mock);
    addTearDown(client.close);

    await client.getSnapshotLastSeen();
    expect(path, '/snapshot/last-seen');
  });

  test('postDecommit posts to /decommit', () async {
    String? path;
    String? body;
    final mock = MockClient((request) async {
      path = request.url.path;
      body = request.body;
      return http.Response('{}', 200);
    });
    final config = HydraClientConfig(host: 'h', port: 1);
    final client = HydraHttpClient(config: config, httpClient: mock);
    addTearDown(client.close);

    await client.postDecommit({'cborHex': 'ab', 'type': 'Tx ConwayEra'});
    expect(path, '/decommit');
    expect(body, contains('cborHex'));
  });

  test('httpUri builds scheme host port', () {
    final c = HydraClientConfig(host: 'example.com', port: 4001);
    expect(c.httpUri('/head').toString(), 'http://example.com:4001/head');
    final cs = HydraClientConfig(host: 'example.com', port: 4001, secure: true);
    expect(cs.httpUri('/snapshot').toString(), 'https://example.com:4001/snapshot');
  });
}
