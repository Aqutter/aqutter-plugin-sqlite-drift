import 'package:aqutter/aqutter.dart';

import 'sqlite_drift_manager.dart';

/// `sqlite` plugin 的 Dart 端：以 drift 提供 SQLite 資料庫的 raw SQL 執行器。
///
/// 網頁端經 `callPlugin('sqlite', 'open' | 'exec', …)`（通常由 Kysely dialect 代勞）呼叫 [handlers]。
/// 契約見網頁端套件的 `AqutterSqliteDialect` 與 `README.md`：
/// BLOB 直接以二進位（`Uint8List`）傳遞，每個資料庫一條序列化連線，同一資料庫的語句依收到順序執行。
class SqliteDriftPlugin extends AqutterPlugin {
  SqliteDriftPlugin({SqliteDriftManager? manager}) : _manager = manager ?? SqliteDriftManager();

  final SqliteDriftManager _manager;

  @override
  String get id => 'sqlite';

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'open': (payload) async {
          await _manager.open(
            name: payload['name'] as String?,
            path: payload['path'] as String?,
          );
          return {'ok': true};
        },
        'exec': (payload) async {
          final name = payload['name'] as String;
          final sql = payload['sql'] as String;
          final bind = (payload['bind'] as List<dynamic>?) ?? const [];
          return _manager.exec(name, sql, bind);
        },
      };

  @override
  void dispose() {
    _manager.closeAll();
  }
}
