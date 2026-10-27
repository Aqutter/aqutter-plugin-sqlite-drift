import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 以 drift 作為「raw SQL 執行器」的最小資料庫。
///
/// 前端 Kysely 已擁有 schema 與 migration；drift 在此不定義 table、不做 migration，
/// 僅提供單一序列化連線執行前端傳來的已編譯 SQL。
class _RawDriftDatabase extends GeneratedDatabase {
  _RawDriftDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

/// 一條資料庫連線：單一序列化連線（非連線池）加上一個語句佇列。
///
/// 佇列保證同一資料庫的語句**依呼叫順序一個接一個**執行，不依賴上層傳輸是否並行分派 handler；
/// 手動 `BEGIN`／`COMMIT`／`ROLLBACK` 的語句順序與交易邊界因此成立。
class SqliteDriftConnection {
  SqliteDriftConnection(QueryExecutor executor) : _db = _RawDriftDatabase(executor);

  final _RawDriftDatabase _db;
  Future<void> _tail = Future<void>.value();

  /// 是否為需要取回資料列的語句（對齊前端 dialect 的判斷）。
  static bool isRowReturning(String sql) {
    final lower = sql.trimLeft().toLowerCase();
    return lower.startsWith('select') || lower.startsWith('pragma') || lower.contains('returning');
  }

  /// 把 [bind] 轉成 drift 的變數。`Uint8List` 是 BLOB；其餘（null、數字、字串、布林）原樣。
  static List<Variable> toVariables(List<dynamic> bind) {
    return [
      for (final value in bind)
        value is Uint8List ? Variable<Uint8List>(value) : Variable(value),
    ];
  }

  /// 執行單句 SQL，排在這條連線的佇列尾端；查詢回 `{rows}`，異動回 `{changes, insertId}`。
  Future<Map<String, dynamic>> exec(String sql, List<dynamic> bind) {
    final result = _tail.then((_) => _run(sql, bind));
    // 前一句失敗不能讓後面的語句跟著失敗：佇列只負責順序
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, dynamic>> _run(String sql, List<dynamic> bind) async {
    final variables = toVariables(bind);

    if (isRowReturning(sql)) {
      final rows = await _db.customSelect(sql, variables: variables).get();
      return {'rows': rows.map((row) => row.data).toList()};
    }

    await _db.customStatement(sql, bind);
    // changes() 與 last_insert_rowid() 反映同一連線上最近一次語句；佇列保證緊接著執行
    final meta = await _db.customSelect('SELECT changes() AS changes, last_insert_rowid() AS insertId').getSingle();
    return {
      'changes': meta.data['changes'],
      'insertId': meta.data['insertId'],
    };
  }

  Future<void> close() => _tail.then((_) => _db.close());
}

/// 管理多個具名 / 路徑指定的資料庫連線。
class SqliteDriftManager {
  /// [documentsDir] 解析 `${name}.db` 所在目錄；預設是 App 文件目錄，測試可換成暫存目錄。
  SqliteDriftManager({Future<Directory> Function()? documentsDir}) : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory {
    // 每個具名資料庫各有一個 [_RawDriftDatabase] 實例，是設計；關掉 drift 的「同一類別多個實例」警告
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  final Future<Directory> Function() _documentsDir;
  final Map<String, SqliteDriftConnection> _connections = {};

  /// 依 name（文件目錄下 `${name}.db`）或 path（絕對路徑）解析出連線鍵；path 優先。
  static String resolveKey(String? name, String? path) {
    if (path != null && path.isNotEmpty) {
      return path;
    }
    if (name != null && name.isNotEmpty) {
      return name;
    }
    throw ArgumentError('sqlite.open requires either name or path');
  }

  Future<String> _resolveFilePath(String? name, String? path) async {
    if (path != null && path.isNotEmpty) {
      return path;
    }
    final dir = await _documentsDir();
    return p.join(dir.path, '$name.db');
  }

  /// 開啟（或取得既有）資料庫連線。回傳連線鍵，供後續 [exec] 使用。
  Future<String> open({String? name, String? path}) async {
    final key = resolveKey(name, path);
    if (_connections.containsKey(key)) {
      return key;
    }
    final filePath = await _resolveFilePath(name, path);
    // 單一連線（非背景連線池），確保手動 BEGIN/COMMIT 的語句順序與交易正確
    _connections[key] = SqliteDriftConnection(NativeDatabase(File(filePath)));
    return key;
  }

  /// 對指定連線執行 SQL。
  Future<Map<String, dynamic>> exec(String key, String sql, List<dynamic> bind) {
    final connection = _connections[key];
    if (connection == null) {
      throw StateError('Database "$key" is not opened');
    }
    return connection.exec(sql, bind);
  }

  /// 關閉所有連線（plugin 結束時）。
  Future<void> closeAll() async {
    final connections = _connections.values.toList();
    _connections.clear();
    for (final connection in connections) {
      await connection.close();
    }
  }
}
