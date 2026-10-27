<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2610281520 - split-db-into-plugin
- Created: 2026-10-28
- Branch: feature/2610281520-split-db-into-plugin
- Issue: Aqutter/aqutter-plugin-sqlite-drift#1
- Milestone: N/A（未指定）
- Base Branch: main
- Status: In Progress
- Completed: [Wait for Finish]

## Goals
1. 把資料庫能力從殼拆成官方 plugin `aqutter-plugin-sqlite-drift`：殼不再依賴 `drift`、`sqlite3`（含其 Dart build hook 編原生程式）。
2. Dart 端（drift raw 執行器）與網頁端（Kysely dialect）成對發佈在同一個 plugin。
3. BLOB 欄位直接以二進位傳遞（統一傳輸支援），不經 base64。
4. 範本專案示範新用法；既有的資料庫檔案不需遷移。

## Architecture
- 現況：殼註冊內建 handler `db_open`、`db_exec`（`shell/lib/src/bridge/bridge_registry.dart` 的 `_registerDatabase`），實作在 `shell/lib/src/db/drift_executor.dart`（`DriftDatabaseManager`、單一序列化連線、raw SQL）；網頁端是範本專案的 `FlutterSqlKyselyDialect.ts`，以 `callFlutter(BridgeHandler.DbOpen／DbExec)` 呼叫。型別與 handler 名稱在 `aqutter-js` 的 `contract/bridge.ts`、`contract/table.ts`。
- 之後：plugin `sqlite` 以 `handlers`（`open`、`exec`）暴露同樣能力，drift 執行器搬進 plugin；網頁端的 dialect 搬進 plugin 的 npm 套件，改用 `callPlugin('sqlite', …)`。殼與 `aqutter-js` 不再有任何 DB 相關程式。
- 每個連線一個序列化佇列：統一傳輸會並行分派 handler，plugin 自己保證同一資料庫的語句順序。
- 沒有量測：移除 `drift` 與 `sqlite3` 後建置時間與體積實際少多少，Phase 3 會量（拆前後各建一次 release）。

## Cross-Repo Scope
- **本計畫所屬 repo**: `Aqutter/aqutter-plugin-sqlite-drift`
- **共用計畫 ID**: `2610281520-split-db-into-plugin`　**共用分支名**: `feature/2610281520-split-db-into-plugin`
- **參與 repo 與職責**（一 repo 一 issue，尚未建立者寫 `待建立`）:
  - `Aqutter/aqutter-plugin-sqlite-drift`（**新 repo**，契約正本）— Dart：`SqliteDriftPlugin`（drift 執行器、連線管理、每連線佇列）；npm：`AqutterSqliteDialect` 與型別。建立後依 Rule 15 為它初始化治理並放入同一份計畫。issue: `Aqutter/aqutter-plugin-sqlite-drift#1`
  - `Aqutter/aqutter-nuxt-app`（範本專案）— 改用 plugin：移除 `FlutterSqlKyselyDialect.ts`，改匯入 plugin 的 dialect；加入 plugin。issue: `Aqutter/aqutter-nuxt-app#6`
  - `Aqutter/aqutter`（殼）— 移除內建 DB handler、`DriftDatabaseManager`、`drift`／`sqlite3` 依賴。issue: `Aqutter/aqutter#24`
  - `Aqutter/aqutter-js` — 移除 `DbOpen`／`DbExec` 與三個型別及契約表項目。issue: `Aqutter/aqutter-js#8`
- **不變更**: `Aqutter/aqutter_core`、`Aqutter/aqutter-cli`（CLI 的 `plugin create`／`plugin add` 照舊使用）。
- **執行順序相依**: 契約凍結後，① 新 repo 實作 plugin；② 範本專案改用 plugin（此時殼仍有內建 handler，兩者並存不衝突）並驗證；③ 最後才移除殼與 `aqutter-js` 的內建項目（移除早於 plugin 可用會讓範本專案的資料庫壞掉）。建議合併順序：`aqutter-plugin-sqlite-drift` → `aqutter-nuxt-app` → `aqutter` → `aqutter-js`。
- **跨 repo 檔案指涉**: 範本專案的 `app/shared/types/FlutterSqlKyselyDialect.ts` 搬到新 repo 的 `src/`（內容改用 `callPlugin('sqlite', …)`）；殼的 `shell/lib/src/db/drift_executor.dart` 搬到新 repo 的 `lib/src/`。

## Contract / 介面契約
- **契約正本 repo**: `Aqutter/aqutter-plugin-sqlite-drift`（新 repo，建立後以它為準；在那之前以本區塊為準）　**修訂號**: `rev 1`　**狀態**: `凍結（核准日 2026-10-28）`

### 1. plugin 與命名
| 項目 | 值 |
|---|---|
| plugin id | `sqlite`（與套件名分開：契約與實作分離，日後換其他實作可沿用同一個 id 與契約，網頁程式不用改） |
| Dart 套件／類別 | `aqutter_plugin_sqlite_drift`／`SqliteDriftPlugin` |
| npm 套件 | `aqutter-plugin-sqlite-drift` |
| handler | `sqlite.open`、`sqlite.exec`（取代內建 `db_open`、`db_exec`） |
| 支援平台 | 與殼相同（`supportedPlatforms` 為 null）；Web 沒有 `dart:io`，不適用 |

### 2. handler
**`sqlite.open`**：開啟（或取得既有）資料庫連線。
| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `name` | string | 否 | 資料庫名稱，檔案為 App 文件目錄下的 `${name}.db` |
| `path` | string | 否 | 資料庫檔案的絕對路徑；提供時優先於 `name` |

- `name` 與 `path` 至少提供一個，否則 `HANDLER_FAILED`（訊息 `sqlite.open requires either name or path`）。
- 連線鍵＝`path`（有提供時）否則 `name`；同一個鍵重複開啟回傳既有連線。
- 回傳 `{ ok: true }`。

**`sqlite.exec`**：對已開啟的連線執行**單句** SQL。
| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `name` | string | 是 | 連線鍵（開啟時的 `path` 或 `name`） |
| `sql` | string | 是 | 已編譯的單句 SQL |
| `bind` | array | 否（預設 `[]`） | 綁定參數；元素為 `null`、數字、字串、布林或二進位（見 §4） |

回應（皆為物件）：
| 語句 | 回應 |
|---|---|
| 回傳資料列的語句（trim 並轉小寫後以 `select` 或 `pragma` 開頭，或含 `returning`） | `{ rows: object[] }`，每列是 欄位名→值 |
| 其他語句 | `{ changes: int, insertId: int }`，取自同一連線緊接著執行的 `SELECT changes(), last_insert_rowid()` |

- 連線未開啟：`HANDLER_FAILED`（訊息 `Database "<鍵>" is not opened`）。SQL 錯誤：`HANDLER_FAILED`（訊息為 SQLite 的錯誤訊息）。

### 3. 順序與交易
- 每個資料庫**一條**序列化連線（非連線池）；同一資料庫的 `sqlite.exec` **依收到順序一個接一個**執行（plugin 以每個連線一個佇列保證，不依賴傳輸層的並行分派順序）。
- 交易由網頁端以 `sqlite.exec` 送 `BEGIN`／`COMMIT`／`ROLLBACK` 控制；因為是同一條序列化連線，語句順序與交易邊界成立。

### 4. 值的型別
| 方向 | JS | Dart／SQLite |
|---|---|---|
| `bind` | `null`、`number`、`string`、`boolean`、`Uint8Array`／`ArrayBuffer` | `null`、`int`／`double`、`String`、`bool`（存為 0／1）、`Uint8List`（BLOB） |
| `rows` 的欄位值 | `null`、`number`、`string`、`Uint8Array`（BLOB 欄位） | 反向對應 |

- **BLOB 直接傳二進位，不經 base64**。（rev 1 之前的契約註解寫「BLOB 以 base64 字串傳遞」，但實作並未解碼；見 `## Key Decisions`。）
- `BigInt` 不支援；超過 2^53 的整數會失去精度，與原行為相同。

### 5. 網頁端（npm 套件 `aqutter-plugin-sqlite-drift`）
| 匯出 | 說明 |
|---|---|
| `AqutterSqliteDialect` | Kysely `Dialect`，建構參數 `{ name?: string, path?: string }`（至少一個；`path` 優先）。使用 `SqliteAdapter`、`SqliteIntrospector`、`SqliteQueryCompiler`；`init` 時呼叫 `sqlite.open`，查詢與交易語句呼叫 `sqlite.exec`；`streamQuery` 不支援（拋錯） |
| 型別 | `SqliteOpenRequest`、`SqliteExecRequest`、`SqliteExecResponse`，並以 `AqutterPluginRegistry` 併入 `callPlugin('sqlite', …)` 的型別 |
| `sqlite` | 物件，含 `isSupported()` |
| 依賴 | `kysely` 為 peerDependency（由使用的 App 提供） |

### 6. 移除與相容性
- 殼移除內建 handler `db_open`、`db_exec`、`BridgeHandler.dbOpen／dbExec`、`DriftDatabaseManager` 與對 `drift`、`sqlite3` 的依賴；`aqutter-js` 移除 `BridgeHandler.DbOpen／DbExec` 與 `DbOpenRequest`、`DbExecRequest`、`DbExecResponse` 及其契約表項目。
- **破壞式變更**，不保留相容層：仍呼叫 `db_open`／`db_exec` 的網頁會得到 `HANDLER_NOT_FOUND`。
- 資料庫檔案位置與格式不變（App 文件目錄下的 `${name}.db`），既有資料庫檔案可直接被新 plugin 開啟。BLOB 以 base64 文字存入的既有資料不會自動轉換。

### 7. 變更紀錄
- _(尚無)_

## Impact Files
- `shell/lib/src/bridge/bridge_registry.dart`（`import '../db/drift_executor.dart'`、欄位 `_db`、`register()` 內對 `_registerDatabase()` 的呼叫、`_registerDatabase` 方法）— 移除。
- `shell/lib/src/bridge/bridge_names.dart:18-19`（`dbExec`、`dbOpen`）— 移除。
- `shell/lib/src/db/drift_executor.dart`（`DriftDatabaseManager`、`DriftConnection`，111 行）— 刪除（搬進新 repo）。
- `shell/pubspec.yaml:30-32`（`drift`、`sqlite3` 與註解）— 移除。
- `docs/plugins.md` — 補「官方 plugin」一節，列 `aqutter-plugin-sqlite-drift` 與其用法連結。
- `README.md`、`.kn-project/project.md`、`.kn-project/wiki/platform/architecture.md` — 內建 handler 清單與依賴描述更新（若提到）。
- `manifest/releases.json` — 合併後更新 ref。

## Open Questions / 待確認事項
> 以下項目需在對話中逐題確認，答案回填後才進入 Phase 3。

### Q1. 建立新 repo（對外動作） — 影響範圍：新 repo
- [x] 同意建立，公開性與其他 plugin 一致
- **決議**：名稱 `Aqutter/aqutter-plugin-sqlite-drift`（使用者指定，名稱中多一層向 drift 致意）；建立前不動，於 Phase 3 開工時才建立。　狀態：✅ 已確認

### Q2. BLOB 的處理 — 影響範圍：契約 §4
- [x] 直接傳二進位，不經 base64　(建議，理由：統一傳輸已支援；現況註解與實作不一致，BLOB 可能被當成 base64 文字存入)
- [ ] 維持 base64 字串（含補上解碼）
- **決議**：直接傳二進位　狀態：✅ 已確認

### Q3. 瀏覽器端的 wasm 版（`OpfsSqlKyselyDialect.ts` 與 `BaseSqliteDatabase` 的 web 分支）要不要放進 plugin？ — 影響範圍：範本專案、plugin
- [x] 不放，只搬 Flutter 那一半；wasm 與兩端切換維持在 App　(建議，理由：避免 plugin 多一個 wasm 依賴，範圍小)
- [ ] 一起放進 plugin，讓同一份程式在 Flutter 與瀏覽器都能跑
- **決議**：只搬 Flutter 那一半。使用者起初選了「一起放進 plugin」，檢視程式碼後（`BaseSqliteDatabase.ts` 用 Vue／Nuxt 的 `ref`、`OpfsSqlKyselyDialect.ts` 用 `new Worker(new URL(…, import.meta.url))`，綁定 Vue 與 Vite，違反框架中立）改回只搬 Flutter 一半。　狀態：✅ 已確認

### Q4. dialect 的匯出名稱 — 影響範圍：契約 §5、範本專案
- [x] `AqutterSqliteDialect`　(建議，理由：名稱不綁 Flutter，與 plugin 名一致)
- [ ] 維持 `FlutterSqlKyselyDialect`
- **決議**：`AqutterSqliteDialect`　狀態：✅ 已確認

### Q5. 執行時機 — 影響範圍：整個計畫
- [x] 等統一傳輸合併後再開工　(建議，理由：同一批檔案；plugin 要用新傳輸)
- [ ] 現在就以統一傳輸的分支為基礎開工
- **決議**：等統一傳輸合併後再開工；計畫先累積，Phase 0 的 Baseline Sync 屆時重做。　狀態：✅ 已確認

### Q6. plugin id —  影響範圍：契約 §1
- [x] `sqlite`（handler 為 `sqlite.open`、`sqlite.exec`）　(建議)
- [ ] 其他名稱
- **決議**：id `sqlite`；repo 與 npm 套件名 `aqutter-plugin-sqlite-drift`（`aqutter plugin create sqlite --dir aqutter-plugin-sqlite-drift --npm-name aqutter-plugin-sqlite-drift`）。　狀態：✅ 已確認

## Manual Follow-ups / 人工收尾事項
- **[合併後]** 既有 App 的網頁若直接呼叫 `db_open`／`db_exec`，要改用 `aqutter-plugin-sqlite-drift`（`aqutter plugin add sqlite`，並把 Kysely dialect 改匯入 `AqutterSqliteDialect`）— 見 plugin README 的遷移說明 — 屬各 App 自己的程式碼
- **[合併後]** 更新 manifest、移動各 repo 的 `0.0.0` tag、同步 `aqutter-cli` 快照、範本專案 `aqutter upgrade` — 沿用先前流程 — 對外動作，需使用者核准
- **[合併後]** 實測：範本專案的資料庫示範（`DatabaseDemoCard`）在 Android 與 Windows 的讀寫、交易、BLOB — 需要實機，由 agent 在 Android／Windows 做；iOS、macOS 由使用者驗證（與統一傳輸的驗證 Aqutter/aqutter#21 合併處理）

## Key Decisions
- **[Phase 0]** 整合主幹 `main`；四個 repo（`aqutter`、`aqutter-js`、`aqutter-nuxt-app`、新建的 `aqutter-plugin-sqlite-drift`）milestone 皆不指定，base 為 `main`。
- **[方向]** 使用者要求「殼瘦身」：殼的內建功能中依賴重、不是每個 App 都需要的，拆成官方 plugin，避免使用者改殼造成分岔、難以升版。資料庫（drift + sqlite3，含 Kysely dialect）是第一個。
- **[分層]** 內建 handler 的 Dart 實作本來就在殼；拆出後放進 plugin 的 Dart 套件，殼只剩 plugin 載入。`aqutter_core` 不變更。
- **[Q2]** BLOB 直接傳二進位（現況註解寫 base64 但實作沒有解碼）。
- **[Q3]** 只搬 Flutter 那一半；瀏覽器 wasm 版（`OpfsSqlKyselyDialect`、worker）與 `BaseSqliteDatabase`（Vue／Nuxt）留在 App——plugin 必須框架中立。
- **[Q4]** dialect 匯出名稱 `AqutterSqliteDialect`。
- **[Q6]** plugin id `sqlite`。
- **[Q1]** 新 repo 名稱 `Aqutter/aqutter-plugin-sqlite-drift`。
- **[Q5]** 等統一傳輸合併後再開工（現已合併，可開工）。
- **[順序]** 統一傳輸（`2610281120-unified-bridge-transport`）已於 2026-10-28 合併；Phase 0 的 Baseline Sync 已在合併後的 `main` 重做，上列程式碼佐證（`bridge_registry.dart`、`bridge_names.dart:18-19`、`contract/bridge.ts:26,28,342-370`、`contract/table.ts:34-36,110-111`、`BaseSqliteDatabase.ts:7,34,165`）已對照 `main` 重新確認，行號未變。plugin 的 handler 走新傳輸才能直接傳二進位。
- **[契約]** rev 1 凍結（2026-10-28）。
- **[完成後]** commit + 開 PR（併回 `main`；使用者核准時未更動預設）。
- **[執行模式]** 序列（依據：相依順序固定——新 repo 的 plugin → 範本專案 → 殼與 aqutter-js 的移除；環境不保證子 agent 能各自驗證）。

## Git Completion Policy
- PR 一律以 `--base main` 顯式指定 base。
- Issue 建立後，每個 commit 訊息與 PR body 含 `Closes #<N>`；歸檔後張貼結案留言，issue 在合併後清理時關閉。
- commit 自動；完成後的動作於核准閘決定。
- 跨 repo 時各自開自己的 PR；建議合併次序見 `## Cross-Repo Scope`。

## References
- 前置計畫：`2610281120-unified-bridge-transport`（統一傳輸，尚未合併）。
