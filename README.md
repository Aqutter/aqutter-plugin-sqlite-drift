# aqutter-plugin-sqlite-drift

Aqutter plugin：`sqlite`。同一個 repo 同時是 npm 套件（網頁端 API）與 Dart 套件（Flutter 端）。

## 結構

| 路徑 | 用途 |
|---|---|
| `aqutter-plugin.json` | 描述檔：id 與 Dart 端類別，`aqutter plugin add` 讀它 |
| `src/index.ts` | 網頁端 API 與型別契約（併入 `AqutterPluginRegistry`） |
| `lib/` | Dart 端：實作 `AqutterPlugin` 的類別 |

## 在 App 使用

```bash
aqutter plugin add aqutter-plugin-sqlite-drift
```

```ts
import { sqlite } from 'aqutter-plugin-sqlite-drift'

const { echo } = await sqlite.ping('hello')
```

## 開發

```bash
pnpm install
pnpm typecheck
flutter pub get
flutter test
```

網頁端 TypeScript 以原始碼發佈（`exports` 指向 `src/`），由使用端的打包器編譯。
