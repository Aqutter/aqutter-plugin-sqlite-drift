import 'dart:io';
import 'dart:typed_data';

import 'package:aqutter_plugin_sqlite_drift/aqutter_plugin_sqlite_drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late SqliteDriftPlugin plugin;

  Future<dynamic> open(Map<String, dynamic> payload) => plugin.handlers['open']!(payload);
  Future<dynamic> exec(String name, String sql, [List<dynamic> bind = const []]) =>
      plugin.handlers['exec']!({'name': name, 'sql': sql, 'bind': bind});

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sqlite_drift_test_');
    plugin = SqliteDriftPlugin(manager: SqliteDriftManager(documentsDir: () async => dir));
  });

  tearDown(() async {
    plugin.dispose();
    // 給關閉連線一點時間再清檔案
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('the id follows the naming rule and the handlers are open and exec', () {
    expect(plugin.id, 'sqlite');
    expect(plugin.handlers.keys, containsAll(['open', 'exec']));
  });

  group('open', () {
    test('needs a name or a path', () async {
      await expectLater(open({}), throwsArgumentError);
      await expectLater(open({'name': '', 'path': ''}), throwsArgumentError);
    });

    test('opens name.db in the documents directory and returns ok', () async {
      expect(await open({'name': 'app'}), {'ok': true});
      await exec('app', 'CREATE TABLE t (id INTEGER PRIMARY KEY)');
      expect(File('${dir.path}${Platform.pathSeparator}app.db').existsSync(), isTrue);
    });

    test('a path takes precedence over the name and is the connection key', () async {
      final path = '${dir.path}${Platform.pathSeparator}custom.sqlite';
      await open({'name': 'ignored', 'path': path});
      await exec(path, 'CREATE TABLE t (id INTEGER PRIMARY KEY)');
      expect(File(path).existsSync(), isTrue);
      expect(File('${dir.path}${Platform.pathSeparator}ignored.db').existsSync(), isFalse);
      await expectLater(exec('ignored', 'SELECT 1'), throwsStateError);
    });

    test('opening the same key twice reuses the connection', () async {
      await open({'name': 'app'});
      await exec('app', 'CREATE TABLE t (id INTEGER PRIMARY KEY)');
      await open({'name': 'app'});
      final result = await exec('app', 'SELECT count(*) AS n FROM t') as Map<String, dynamic>;
      expect((result['rows'] as List).single, {'n': 0});
    });
  });

  group('exec', () {
    setUp(() async {
      await open({'name': 'app'});
      await exec('app', 'CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT, avatar BLOB, score REAL)');
    });

    test('a statement on a database that is not opened fails', () async {
      await expectLater(exec('nope', 'SELECT 1'), throwsStateError);
    });

    test('an insert answers changes and insertId', () async {
      final result = await exec('app', 'INSERT INTO people (name) VALUES (?)', ['Ann']) as Map<String, dynamic>;
      expect(result['changes'], 1);
      expect(result['insertId'], 1);
      final second = await exec('app', 'INSERT INTO people (name) VALUES (?)', ['Bob']) as Map<String, dynamic>;
      expect(second['insertId'], 2);
    });

    test('an update answers the number of affected rows', () async {
      await exec('app', 'INSERT INTO people (name) VALUES (?), (?)', ['Ann', 'Bob']);
      final result = await exec('app', 'UPDATE people SET score = ?', [1.5]) as Map<String, dynamic>;
      expect(result['changes'], 2);
    });

    test('select and pragma answer rows keyed by column name', () async {
      await exec('app', 'INSERT INTO people (name, score) VALUES (?, ?)', ['Ann', 2.5]);
      final rows = (await exec('app', 'SELECT name, score FROM people') as Map<String, dynamic>)['rows'] as List;
      expect(rows.single, {'name': 'Ann', 'score': 2.5});
      final pragma = (await exec('app', 'PRAGMA table_info(people)') as Map<String, dynamic>)['rows'] as List;
      expect(pragma.length, 4);
    });

    test('a statement with RETURNING answers rows', () async {
      final result = await exec('app', 'INSERT INTO people (name) VALUES (?) RETURNING id, name', ['Ann']) as Map<String, dynamic>;
      expect((result['rows'] as List).single, {'id': 1, 'name': 'Ann'});
    });

    test('null and boolean parameters', () async {
      await exec('app', 'INSERT INTO people (name, score) VALUES (?, ?)', [null, true]);
      final rows = (await exec('app', 'SELECT name, score FROM people') as Map<String, dynamic>)['rows'] as List;
      expect(rows.single['name'], isNull);
      expect(rows.single['score'], 1);
    });

    test('BLOB goes in and comes out as bytes, not as base64 text', () async {
      final bytes = Uint8List.fromList([0, 1, 2, 250, 255]);
      await exec('app', 'INSERT INTO people (name, avatar) VALUES (?, ?)', ['Ann', bytes]);
      final rows = (await exec('app', 'SELECT avatar, typeof(avatar) AS kind FROM people') as Map<String, dynamic>)['rows'] as List;
      expect(rows.single['kind'], 'blob');
      expect(rows.single['avatar'], isA<Uint8List>());
      expect(rows.single['avatar'], bytes);
    });

    test('a failing statement answers an error and does not break the ones after it', () async {
      await expectLater(exec('app', 'INSERT INTO nope (x) VALUES (1)'), throwsA(anything));
      final result = await exec('app', 'INSERT INTO people (name) VALUES (?)', ['Ann']) as Map<String, dynamic>;
      expect(result['changes'], 1);
    });

    test('concurrent statements on one database run in the order they were issued', () async {
      // 全部同時送出（不 await 前一句）：佇列保證依呼叫順序執行
      final pending = <Future<dynamic>>[];
      for (var i = 1; i <= 25; i++) {
        pending.add(exec('app', 'INSERT INTO people (name, score) VALUES (?, ?)', ['p$i', i]));
      }
      final results = await Future.wait(pending);
      expect([for (final r in results) (r as Map)['insertId']], [for (var i = 1; i <= 25; i++) i]);
      final rows = (await exec('app', 'SELECT name FROM people ORDER BY id') as Map<String, dynamic>)['rows'] as List;
      expect([for (final row in rows) (row as Map)['name']], [for (var i = 1; i <= 25; i++) 'p$i']);
    });

    test('a transaction commits and a rolled back one leaves nothing', () async {
      await exec('app', 'BEGIN');
      await exec('app', 'INSERT INTO people (name) VALUES (?)', ['kept']);
      await exec('app', 'COMMIT');
      await exec('app', 'BEGIN');
      await exec('app', 'INSERT INTO people (name) VALUES (?)', ['gone']);
      await exec('app', 'ROLLBACK');
      final rows = (await exec('app', 'SELECT name FROM people') as Map<String, dynamic>)['rows'] as List;
      expect([for (final row in rows) (row as Map)['name']], ['kept']);
    });
  });

  test('two databases are independent', () async {
    await open({'name': 'a'});
    await open({'name': 'b'});
    await exec('a', 'CREATE TABLE t (x INTEGER)');
    await exec('a', 'INSERT INTO t (x) VALUES (1)');
    await expectLater(exec('b', 'SELECT * FROM t'), throwsA(anything));
  });
}
