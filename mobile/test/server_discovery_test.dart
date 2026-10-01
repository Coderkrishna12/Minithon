import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:privacyshield_mobile/services/server_discovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

MockClient _serverAt(String base) => MockClient((req) async {
      if (req.url.toString() == '$base/health') {
        return http.Response('{"status":"ok","service":"PrivacyShield API"}', 200);
      }
      throw http.ClientException('unreachable', req.url);
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalize turns a bare IP into a full API URL', () {
    expect(ServerDiscovery.normalize('192.168.1.5'), 'http://192.168.1.5:8000/api');
    expect(ServerDiscovery.normalize(' 192.168.1.5:9000 '), 'http://192.168.1.5:9000/api');
    expect(ServerDiscovery.normalize('http://10.0.0.7:8000/api/'), 'http://10.0.0.7:8000/api');
  });

  test('probe only accepts a PrivacyShield server', () async {
    final other = MockClient((_) async => http.Response('<html>router</html>', 200));
    expect(await http.runWithClient(() => ServerDiscovery.probe('http://192.168.1.1:8000/api'), () => other), isFalse);
    expect(
      await http.runWithClient(() => ServerDiscovery.probe('http://192.168.1.5:8000/api'), () => _serverAt('http://192.168.1.5:8000/api')),
      isTrue,
    );
  });

  test('discover prefers the saved server and remembers it', () async {
    SharedPreferences.setMockInitialValues({ServerDiscovery.prefsKey: 'http://192.168.1.20:8000/api'});
    final found = await http.runWithClient(ServerDiscovery.discover, () => _serverAt('http://192.168.1.20:8000/api'));
    expect(found, 'http://192.168.1.20:8000/api');
    expect(ServerDiscovery.baseUrl, found);
  });

  test('firstResponding finds the one host that answers in a subnet sweep', () async {
    final hosts = [for (var i = 1; i < 255; i++) 'http://192.168.1.$i:8000/api'];
    final found = await http.runWithClient(
      () => ServerDiscovery.firstResponding(hosts, timeout: const Duration(milliseconds: 200)),
      () => _serverAt('http://192.168.1.137:8000/api'),
    );
    expect(found, 'http://192.168.1.137:8000/api');
  });
}
