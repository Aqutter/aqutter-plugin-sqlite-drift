# 2610271725 - fix-plan-dates

- Created: 2026-10-27 17:25 / Archived: 2026-10-27 18:10
- Issue: Aqutter/aqutter-plugin-sqlite-drift#3
- Milestone: N/A / Base Branch: main

## Summary
把統一傳輸與拆資料庫兩份計畫誤用的日期更正：機器日期是 2026-10-27，我誤用了 2026-10-28。計畫 ID 改為 `2610271120-unified-bridge-transport` 與 `2610271520-split-db-into-plugin`，歸檔與文件裡的 `2026-10-28` 改為 `2026-10-27`，量測結果檔改名；歷史事實（實際存在過的分支名、已合併 PR 與 issue 留言）不改，僅在各歸檔的 `## Deviations` 記對照。

## Cross-Repo Scope
- 共用計畫 ID `2610271725-fix-plan-dates`、共用分支名 `feature/2610271725-fix-plan-dates`；五個 repo 各自改自己的歸檔與文件，彼此獨立：`aqutter`、`aqutter_core`、`aqutter-js`、`aqutter-nuxt-app`、`aqutter-plugin-sqlite-drift`。`aqutter-cli` 沒有受影響的檔案。

## Key Decisions
- **[Phase 0]** 整合主幹 `main`；五個 repo milestone 皆不指定，base 為 `main`。
- **[原因]** 統一傳輸那份計畫起沒有核對機器日期。
- **[Q1]** 已寫在 GitHub issue 留言與 PR 描述裡的舊路徑不改，僅記錄。
- **[歷史事實]** 分支名與已合併 PR 的內容維持原樣。
- **[契約]** 無（只改文件與檔名）。
- **[完成後]** commit + 開 PR（併回 `main`）。

## Deviations
無。

## Impact Files
- `.kn-project/archive/2610271520-split-db-into-plugin.md`（原 `2610281520-…`）— 改名、ID 與日期更正、`## Deviations` 對照。

## Details
- 驗證：`git grep` 掃描，除了分支名與 `## Deviations` 的對照外沒有殘留的 `2026-10-28`、`2610281120`、`2610281520`；（aqutter）`wiki-lint.py` 通過。
