# Tasks for 2610281520

## Phase 1 — 契約（已凍結 rev 1）
- [x] 凍結契約 rev 1，各 repo 的 `## Contract` 逐字相同

## Phase 2 — plugin 實作（依賴 Contract §1–§5）
- [x] `SqliteDriftPlugin`：drift 執行器（搬自殼的 `drift_executor.dart`）、`sqlite.open`、`sqlite.exec`、每連線一個佇列、BLOB 二進位
- [x] Dart 測試：開啟規則、查詢與異動回應、交易、BLOB 來回、佇列順序、未開啟的錯誤
- [x] `AqutterSqliteDialect` 與型別（搬自範本專案的 `FlutterSqlKyselyDialect.ts`，改用 `callPlugin('sqlite', …)`）
- [x] TS 測試：dialect 對假的 `callPlugin`；`pnpm typecheck`
- [x] README（用法、遷移說明、框架中立的打包提醒）

## Phase 3 — 驗證
- [x] `flutter analyze`、`flutter test`
- [ ] 在範本專案以 Android 與 Windows 實機驗證（由範本專案的計畫負責）
