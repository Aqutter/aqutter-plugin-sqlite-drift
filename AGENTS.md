# AI Agents 治理與協作指南 (AGENTS.md)

這個資料夾 `.kn-project` 用於存放由 AI Agents 產生的開發文件，協助追蹤專案進度、設計決策與技術規格。

## 專案文件約定：`.kn-project/`

### 若技能清單裡有 `kn-project-precision-workflow-manager`

以該技能為準：任何新增、修改、修復、重構或規劃的任務（含「幫我改一下」這類口語），**必須先啟動它**並走完 Phase 0-5。不存在規模豁免，純錯字、純格式、只改一行也一樣。

- **Phase 2 鎖定**：計畫建立後必須停下，請使用者核准任務清單才能動手。
- **Phase 5 結案**：任務完成後必須請求歸檔許可，未經同意不得自行清理計畫。

### 若技能清單裡沒有

技能清單裡沒有就略過上一小節，**不要另外搜尋或嘗試安裝**，改照下面的最低規則：

1. **新計畫就建立計畫**：開始一項新工作前，先在 `.kn-project/plans/` 建立計畫資料夾與 `plan.md`（格式參考 `plans/` 或 `archive/` 內既有範例）。
2. **完成後歸檔並更新 wiki**：工作完成後，把計畫歸檔到 `.kn-project/archive/`，並更新 `.kn-project/wiki/` 中受影響的頁面。

為了讓不同工具與不同人留下的紀錄能互相讀取，請維持這四點：

- 計畫資料夾命名為 `plans/${YYMMDDHHmm}-${description}/`（時間戳 + kebab-case 描述）。
- `plan.md` 內含一行 `- Status: Planning | In Progress | Awaiting Archive`。
- 歸檔＝存成 `archive/${YYMMDDHHmm}-${description}.md`，並刪除原計畫資料夾；不要讓已歸檔的計畫留在 `plans/`。
- wiki 頁保留 `## Summary` 小節，檢索靠它。

## 📂 目錄結構

- `.kn-project/`: AI 治理與知識根目錄（所有文件直接收於此，不再有 `project/` 子層）。
  - `project.md`: 專案入口 (Portal)，提供 Wiki 快速導覽。
  - `wiki/`: 專案百科 (Graph 關聯系統)，收錄架構、技術棧與功能細節。
  - `plans/`: 進行中計畫（資料夾即索引；各計畫的 `plan.md` 內含 `- Status:` 行作為生命週期唯一真相來源，無獨立索引檔）。
  - `archive/`: 已完成計畫的歷史紀錄；資料夾即索引（檔名 = 時間戳 + 描述），無獨立索引檔。

---
[📈 專案入口](.kn-project/project.md)
