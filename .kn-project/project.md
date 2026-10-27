<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# aqutter-plugin-sqlite-drift

Aqutter plugin（Dart 套件 + TypeScript 封裝）：以 [drift](https://pub.dev/packages/drift) 提供 SQLite 資料庫——Dart 端是 raw SQL 執行器，網頁端是 Kysely dialect。由 `aqutter plugin add github:Aqutter/aqutter-plugin-sqlite-drift` 安裝到使用 Aqutter 的 App。詳見 [README.md](../README.md)。

plugin id 是 `sqlite`，套件名帶 `-drift`：契約（handler `sqlite.open`、`sqlite.exec`）與實作分開，日後換其他實作可沿用同一個 id 與契約。

## 保留鐵則

- **client 依賴來自 `Aqutter/aqutter-js`**：`package.json` 的 `@aqutter/aqutter` 以 `github:Aqutter/aqutter-js#<ref>` 安裝（開發依賴，peer 為可選）；對應框架版本見 `Aqutter/aqutter` 的 `manifest/releases.json`。
- **殼版本需與 App 相同**：`pubspec.yaml` 的 `aqutter` git ref 要與使用它的 App 一致。
- **開發階段版本統一為 `0.0.0`**。
- **框架中立**：網頁端只放 Kysely dialect 與型別，不依賴 Vue／Nuxt／特定打包器；`kysely` 是 peerDependency。瀏覽器 wasm 版留在使用的 App。

## 驗證

```bash
pnpm install
pnpm typecheck
flutter test
```
