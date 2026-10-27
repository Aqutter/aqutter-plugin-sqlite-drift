import 'dart:async';

import 'package:aqutter/aqutter.dart';
import 'package:flutter/widgets.dart';

/// `sqlite` plugin 的 Dart 端。
///
/// 網頁端經 `callPlugin('sqlite', 'ping', …)` 呼叫 [handlers]；
/// 本類別也示範主動對網頁派送事件（[attach]）與疊 UI（[buildOverlay]）。
class SqliteDriftPlugin extends AqutterPlugin {
  AqutterPluginContext? _context;
  Timer? _timer;
  int _count = 0;

  @override
  String get id => 'sqlite';

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'ping': (payload) async => {'echo': payload['message'] ?? ''},
      };

  @override
  void attach(AqutterPluginContext context) {
    _context = context;
    // 範例事件：每秒對網頁派送一次 tick。實際 plugin 請改成自己的事件來源。
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _count += 1;
      _context?.emit('tick', {'count': _count});
    });
  }

  @override
  Widget? buildOverlay(BuildContext context) => null;

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _context = null;
  }
}
