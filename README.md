# aqutter-plugin-sqlite-drift

Aqutter plugin：**SQLite**。Dart 端以 [drift](https://pub.dev/packages/drift) 當 raw SQL 執行器，網頁端是 [Kysely](https://kysely.dev) 的 dialect。同一個 repo 同時是 npm 套件（網頁端）與 Dart 套件（Flutter 端）。

plugin id 是 `sqlite`（handler `sqlite.open`、`sqlite.exec`），套件名帶 `-drift`：**契約與實作分開**，日後換其他實作可沿用同一個 id 與契約，網頁程式不用改。

Kysely 擁有 schema 與 migration；drift 不定義 table、不做 migration，只提供序列化連線執行網頁送來的已編譯 SQL。

## 在 App 使用

```bash
aqutter plugin add aqutter-plugin-sqlite-drift
```

```ts
import { Kysely } from 'kysely'
import { AqutterSqliteDialect } from 'aqutter-plugin-sqlite-drift'

const db = new Kysely<Database>({
  dialect: new AqutterSqliteDialect({ name: 'app' }), // 檔案是 App 文件目錄下的 app.db
})
```

- `name`：檔案為 App 文件目錄下的 `${name}.db`；`path`：資料庫檔案的絕對路徑，提供時優先於 `name`。至少提供一個。
- 連線與 migration 由 App 自己管（例如 Kysely 的 `Migrator`）。
- **BLOB 直接用 `Uint8Array`**，不需要 base64：寫入時放進參數，讀出時欄位就是 `Uint8Array`。
- 交易照 Kysely 的寫法（`db.transaction().execute(...)`）；plugin 會把同一資料庫的語句依收到順序一個接一個執行。
- 不支援串流（`stream()` 會拋錯）。
- `kysely` 是 peerDependency，由 App 提供。

### 瀏覽器（純網頁）

本 plugin 只提供 Flutter 那一半。在瀏覽器（沒有 Flutter）用 sqlite-wasm 的版本需要 Web Worker 與打包設定，依賴 App 用的打包器，所以留在 App 自己（範本專案 `aqutter-nuxt-app` 的 `OpfsSqlKyselyDialect`）。用 `isFlutter()` 決定要用哪一個 dialect。

## 契約

| handler | 請求 | 回應 |
|---|---|---|
| `sqlite.open` | `{ name?: string, path?: string }`（至少一個） | `{ ok: true }` |
| `sqlite.exec` | `{ name: string, sql: string, bind: (null \| number \| string \| boolean \| Uint8Array)[] }` | 回傳資料列的語句（`select`、`pragma`、含 `returning`）：`{ rows }`；其他：`{ changes, insertId }` |

- `name`（exec）是連線鍵：開啟時的 `path`（有提供時）否則 `name`。
- 連線未開啟、SQL 錯誤：呼叫以 `HANDLER_FAILED` 失敗。
- 型別見 `src/index.ts`（`SqliteOpenRequest`、`SqliteExecRequest`、`SqliteExecResponse`），並以 `AqutterPluginRegistry` 併入 `callPlugin('sqlite', …)`。

## 實測

用範本專案的暫存複本在實機跑 release 版：資料庫操作經 Kysely dialect，走統一傳輸。

| 項目 | Android（ASUS_I006D） | Windows（桌機） |
|---|---|---|
| 建表、插入與查詢 | 通過 | 通過 |
| BLOB 1MB 來回 | 存成真正的 `blob`（`typeof(payload)`），讀回是 `Uint8Array`，內容一致 | 同左 |
| BLOB 1MB 寫入／讀回（各 20 次平均） | 11.1／8.3 ms | 24.6／21.1 ms |
| 交易：commit 與 rollback | commit 留下、rollback 不留 | 同左 |
| 同時送出 50 個 insert | 依序（`insertId` 連續），41.8 ms | 依序，478 ms |
| 未開啟的資料庫 | `HANDLER_FAILED` | `HANDLER_FAILED` |

- 各只跑一次；Linux、iOS、macOS 沒有量（iOS、macOS 與統一傳輸一起由使用者驗證，追蹤於 Aqutter/aqutter#21）。
- Windows 的 50 個 insert 明顯比 Android 慢，每次呼叫的固定成本較高；沒有深入追查。

## 從殼的內建 `db_open`／`db_exec` 遷移

這個 plugin 取代殼先前內建的資料庫 handler（已移除，沒有相容層）：

1. `aqutter plugin add aqutter-plugin-sqlite-drift`。
2. 網頁端把自己的 `FlutterSqlKyselyDialect`（或直接呼叫 `callFlutter('db_open' | 'db_exec')` 的程式）換成 `AqutterSqliteDialect`。
3. 資料庫檔案的位置與格式不變，既有資料庫可直接開啟。
4. **BLOB**：舊契約註解寫「以 base64 字串傳遞」，但殼並未解碼，BLOB 欄位可能是以 base64 **文字**存入的；新版直接存成 BLOB。既有的 base64 文字資料不會自動轉換，需要的 App 自己做一次轉換。

## 開發

```bash
pnpm install
pnpm typecheck
pnpm test
flutter pub get
flutter analyze
flutter test
```
