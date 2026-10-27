import 'package:aqutter_plugin_sqlite_drift/aqutter_plugin_sqlite_drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ping echoes the message', () async {
    final plugin = SqliteDriftPlugin();
    final result = await plugin.handlers['ping']!({'message': 'hi'});
    expect(result, {'echo': 'hi'});
  });

  test('id follows the naming rule', () {
    expect(SqliteDriftPlugin().id, 'sqlite');
  });
}
