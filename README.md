# HDD RVI Test Script (PowerShell 版本)

## 📋 概述

這是一個 **HDD 可靠性驗證 (RVI: Reliability Verification Index) 測試工具**，用於對多個硬碟進行 I/O 性能測試、分析，並與基準值進行比較。

**主要功能：**
- ✅ 自動掃描系統硬碟並排除系統磁碟
- ✅ 關閉硬碟寫入快取（使用 `dskcache.exe`）
- ✅ 執行隨機寫入性能測試（使用 FIO）
- ✅ 與基準 IOPS 進行比較，自動判定 Pass/Fail
- ✅ 生成詳細的 CSV 測試報告
- ✅ 可選自動關機功能

---

## 🔧 系統要求

### 硬件
- Windows 操作系統（Windows Server 2012 或更新版本）
- 多個內部硬碟（SATA/SAS）

### 軟件
- **PowerShell 5.0 以上**
- **FIO (Flexible I/O Tester)** - Windows 版本
  - 下載：https://github.com/axboe/fio/releases
  - 或使用 Chocolatey 安裝：`choco install fio`
- **dskcache.exe** - 硬碟快取控制工具（必須放在腳本同目錄）
- **HDD_base.csv** - 硬碟基準 IOPS 參考表（可選，但建議有）

### 權限
- **需要以管理員身份執行 PowerShell**

---

## 📦 安裝步驟

### 1. 準備工作環境
```powershell
# 建立工作目錄
mkdir C:\HDD_RVI_Test
cd C:\HDD_RVI_Test
```

### 2. 放置必要的檔案
在 `C:\HDD_RVI_Test\` 目錄下放置：
- `HDD_RVI_Test.ps1` - 主腳本
- `dskcache.exe` - 硬碟快取控制工具
- `HDD_base.csv` - 硬碟基準 IOPS 參考表（可選）

### 3. 配置 HDD_base.csv（可選但建議）

CSV 格式示例：
```csv
SN_Prefix,Base_IOPS
ST1000DM,550
ST2000DM,520
WDC_WD,480
```

- 第一列：硬碟序列號前綴（取 "-" 前的部分）
- 第二列：該硬碟型號的基準 IOPS

### 4. 允許執行腳本
```powershell
# 以管理員身份打開 PowerShell，執行：
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

---

## 🚀 使用方法

### 基本執行
```powershell
# 以管理員身份打開 PowerShell，進入工作目錄
cd C:\HDD_RVI_Test

# 執行腳本
.\HDD_RVI_Test.ps1
```

### 選擇測試模式

腳本會提示選擇測試模式：

#### **模式 1: RVI 模式** （生產環境標準測試）
- Ramp Time: 300 秒（預熱時間）
- Runtime: 600 秒（實際測試時間）
- 約需 15 分鐘

**子選項：**
- **a) 全部硬碟** - 測試系統中所有非系統磁碟
  - 詢問：測試完後是否關機
- **b) 單一硬碟** - 選擇一個特定硬碟測試
- **c) 編號區段** - 指定硬碟號碼範圍測試
  - 詢問：測試完後是否關機

#### **模式 2: Debug 模式** （快速測試/調試用）
- Ramp Time: 30 秒
- Runtime: 300 秒
- 約需 5.5 分鐘

**子選項：**
- **b) 單一硬碟** - 選擇一個特定硬碟測試
- **c) 編號區段** - 指定硬碟號碼範圍測試

#### **模式 3: 離開**
- 退出程式

### 硬碟選擇示例

執行模式選擇後，會顯示可用硬碟清單：
```
📦 可選磁碟清單：
00) PhysicalDrive1           型號:ST1000DM010             介面:SATA
01) PhysicalDrive2           型號:WDC WD10EZEX            介面:SATA
02) PhysicalDrive3           型號:ST2000DM006             介面:SAS
```

根據編號選擇需要的硬碟。

---

## 📊 輸出結果

### 目錄結構

執行完成後會生成帶時間戳的資料夾：
```
RVI_LOG_20260612_143025/
├── summary_20260612_143025.csv       # 測試摘要報告
├── fio_run_PhysicalDrive1.fio        # FIO 配置檔案
├── fio_result_PhysicalDrive1.json    # FIO 原始測試結果
├── fio_run_PhysicalDrive2.fio
├── fio_result_PhysicalDrive2.json
└── ...
```

### CSV 報告說明

**summary_YYYYMMDD_HHMMSS.csv** 格式：

| 欄位 | 說明 |
|------|------|
| Index | 硬碟序號 |
| Device | 硬碟設備名稱 (如 PhysicalDrive1) |
| SN | 硬碟序列號 |
| Interface | 硬碟介面 (SATA/SAS) |
| IOdepth | I/O 佇列深度 (目標硬碟為 8，其他為 1) |
| IOPS | 實測隨機寫入 IOPS |
| base_iops | 基準 IOPS (來自 HDD_base.csv) |
| Percentage | 性能下降百分比 = (基準值 - 實測值) / 基準值 × 100% |
| Pass/Fail | 測試結果 |

### Pass/Fail 判斷標準

- **SATA 硬碟**：Percentage ≤ 15% → PASS，否則 FAIL
- **SAS 硬碟**：Percentage ≤ 10% → PASS，否則 FAIL
- 如無 HDD_base.csv，結果為 N/A

### 範例報告
```csv
Index,Device,SN,Interface,IOdepth,IOPS,base_iops,Percentage,Pass/Fail
0,PhysicalDrive1,ST1000DM010-1234,SATA,8,520,550,5.45%,PASS
1,PhysicalDrive2,WDC_WD-5678,SATA,8,480,500,4.00%,PASS
2,PhysicalDrive3,ST2000DM006-9012,SAS,8,1850,1900,2.63%,PASS
```

---

## ⚠️ 重要注意事項

### 1. 管理員權限
腳本會檢查管理員身份，如果沒有以管理員身份執行，會自動退出。

### 2. 系統磁碟自動排除
腳本會自動偵測和排除 Windows 系統所在的磁碟，防止意外損害。

### 3. USB 設備自動排除
USB 硬碟會自動排除，只測試內部 SATA/SAS 硬碟。

### 4. FIO 引擎選擇
- Windows 版本使用 `windowsaio` 引擎（非 Linux 的 `libaio`）
- 某些 FIO 參數在 Windows 上可能不支持

### 5. 磁碟順序
所有操作都按磁碟編號遞增順序執行（PhysicalDrive1 → PhysicalDrive2 → ...）

### 6. 測試期間系統狀態
- 測試期間不應進行其他高 I/O 操作
- 建議關閉防毒軟體和備份工作
- 測試期間硬碟會滿負載運行

### 7. 自動關機
- 如選擇「待機 180 秒再關機」，系統會在測試完成後等待 180 秒才執行關機
- 這段時間可用於查看最終測試結果
- 執行 `shutdown /s /t 0` 命令進行立即關機

---

## 🐛 故障排除

### 問題 1: 「未找到 FIO 工具」

**原因：** FIO 未安裝或不在 PATH 環境變數中

**解決方案：**
```powershell
# 方案 A: 使用 Chocolatey 安裝
choco install fio

# 方案 B: 手動安裝並加入 PATH
# 1. 從 https://github.com/axboe/fio/releases 下載 FIO Windows 版本
# 2. 解壓到 C:\fio
# 3. 將 C:\fio 加入 PATH 環境變數
```

### 問題 2: 「dskcache.exe 不在當前目錄」

**原因：** dskcache.exe 未放在腳本目錄

**解決方案：**
- 確保 dskcache.exe 與 HDD_RVI_Test.ps1 在同一目錄
- 腳本會警告但繼續執行（快取關閉會跳過）

### 問題 3: 「執行原則不允許」

**原因：** PowerShell 執行原則限制

**解決方案：**
```powershell
# 以管理員身份執行：
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

# 臨時方案：僅對此會話生效
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### 問題 4: 「找不到磁碟」或「無效的磁碟編號」

**原因：** 磁碟編號輸入錯誤或硬碟未被系統識別

**解決方案：**
```powershell
# 檢查已偵測的磁碟
Get-Disk | Select-Object Number, BusType, Model

# 確保在腳本顯示的磁碟列表中選擇有效編號
```

### 問題 5: FIO 測試失敗「無輸出檔案」

**原因：** 設備路徑格式不正確或 FIO 無權訪問硬碟

**解決方案：**
- 確保以管理員身份執行
- 檢查硬碟是否被其他程式佔用
- 檢查 FIO 版本是否與 Windows 版本相容

### 問題 6: 「無法解析 FIO 結果」

**原因：** FIO 輸出格式問題或 JSON 解析失敗

**解決方案：**
- 查看 `RVI_LOG_*/` 資料夾中的 FIO JSON 檔案
- 確認 JSON 格式正確
- 檢查硬碟型號是否在 HDD_base.csv 中有對應項目

---

## 📝 檔案說明

### HDD_RVI_Test.ps1
主要測試腳本，包含所有功能邏輯。

### dskcache.exe
硬碟快取控制工具，用於關閉/啟用硬碟寫入快取。

**命令行語法：**
```bash
dskcache.exe -w PhysicalDrive1      # 關閉 PhysicalDrive1 的寫入快取
dskcache.exe +w PhysicalDrive1      # 啟用 PhysicalDrive1 的寫入快取
```

### HDD_base.csv
硬碟基準 IOPS 參考表，格式為：
```
SN_Prefix,Base_IOPS
```

- 第一列：硬碟序列號前綴（例如 `ST1000DM`, `WDC_WD`）
- 第二列：該硬碟型號的基準 IOPS 值

### RVI_LOG_YYYYMMDD_HHMMSS/
測試結果輸出目錄，包含：
- CSV 摘要報告
- FIO 配置檔案
- FIO JSON 原始結果

---

## 💡 最佳實踐

### 1. 預先準備
```powershell
# 測試前檢查環境
Get-Disk                              # 確認硬碟識別
Test-Path ".\dskcache.exe"           # 確認快取工具
Test-Path ".\HDD_base.csv"           # 確認基準表
Get-Command fio                       # 確認 FIO 安裝
```

### 2. 測試流程
1. 關閉不必要的背景程式
2. 禁用防毒軟體（暫時）
3. 執行 Debug 模式進行初步測試
4. 根據結果調整參數，執行 RVI 模式

### 3. 結果分析
1. 檢查 CSV 摘要報告
2. 所有結果應為 PASS
3. 對於 FAIL 的硬碟，檢查 JSON 詳細結果
4. 考慮硬碟是否需要更換

### 4. 日誌保存
```powershell
# 將測試結果備份
Copy-Item "RVI_LOG_*" "D:\Backup\RVI_Results\" -Recurse
```

---

## 🔄 版本歷史

| 版本 | 日期 | 說明 |
|------|------|------|
| 1.0 | 2026-06-12 | 初版發布，支持 RVI 和 Debug 模式 |

---

## 📞 技術支援

### 常見問題檢查清單
- [ ] 以管理員身份執行
- [ ] FIO 已安裝並在 PATH 中
- [ ] dskcache.exe 在腳本同目錄
- [ ] HDD_base.csv 格式正確
- [ ] 磁碟編號輸入無誤
- [ ] Windows PowerShell 5.0+
- [ ] 系統磁碟未被選中

### 調試模式

如要查看詳細執行過程，可修改腳本中的日誌輸出：
```powershell
# 在測試區塊中添加詳細輸出
Write-Host "調試信息：$variable" -ForegroundColor Yellow
```

---

## 📄 授權

此腳本為內部工具，使用前請確認組織授權。

---

**最後更新：2026-06-12**
