# ============================================================================
# HDD RVI Test Script (PowerShell Version)
# 磁碟性能測試腳本 - Windows PowerShell 版本
# ============================================================================

# 需要以管理員身份執行
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ 此腳本需要以管理員身份執行！" -ForegroundColor Red
    exit 1
}

# ============================================================================
# 磁碟掃描與快取關閉區塊
# ============================================================================

Write-Host "🔍 掃描系統硬碟裝置..." -ForegroundColor Cyan

# 取得 OS 所在磁碟編號
$osVolume = Get-Volume | Where-Object { $_.DriveLetter -eq [System.IO.Path]::GetPathRoot($PROFILE)[0] } | Select-Object -First 1
$systemDiskNumber = if ($osVolume) {
    Get-Disk | Where-Object { $_.Number -eq (Get-Partition -Volume $osVolume | Select-Object -First 1).DiskNumber } | Select-Object -ExpandProperty Number
} else {
    0
}

Write-Host "⛔ 排除 OS Disk：Disk $systemDiskNumber" -ForegroundColor Yellow

# 取得所有硬碟，排除系統磁碟
$allDisks = Get-Disk | Where-Object { $_.Number -ne $systemDiskNumber }
$disks = @()

foreach ($disk in $allDisks) {
    $diskNum = $disk.Number
    $diskName = "PhysicalDrive$diskNum"
    
    # 獲取硬碟型號
    $diskInfo = Get-WmiObject -ClassName Win32_DiskDrive | Where-Object { $_.Index -eq $diskNum }
    if ($diskInfo) {
        $model = $diskInfo.Model
        $busType = $disk.BusType
        
        # 排除移動設備（如 USB）
        if ($busType -ne "USB") {
            $disks += @{
                Number  = $diskNum
                Name    = $diskName
                Model   = $model
                BusType = $busType
            }
        }
    }
}

# 按磁碟號排序
$disks = $disks | Sort-Object { [int]$_.Number }

Write-Host "💡 關閉所有硬碟的寫入快取..." -ForegroundColor Cyan

# 檢查 dskcache.exe 是否存在
if (-not (Test-Path ".\dskcache.exe")) {
    Write-Host "⚠️  警告：dskcache.exe 不在當前目錄，請確保該文件存在" -ForegroundColor Yellow
    $dskCacheReady = $false
} else {
    $dskCacheReady = $true
}

foreach ($disk in $disks) {
    $diskName = $disk.Name
    
    if ($dskCacheReady) {
        Write-Host "⚙️  關閉 $diskName 的寫入快取..." -ForegroundColor Green
        & ".\dskcache.exe" -w $diskName 2>&1 | Out-Null
    }
}

# ============================================================================
# 模式選擇區塊
# ============================================================================

function Show-DiskList {
    Write-Host "📦 可選磁碟清單："
    for ($i = 0; $i -lt $disks.Count; $i++) {
        $disk = $disks[$i]
        $busType = switch ($disk.BusType) {
            "ATA" { "SATA" }
            "SCSI" { "SAS" }
            default { $disk.BusType }
        }
        Write-Host ("{0:D2}) {1,-20} 型號:{2,-25} 介面:{3}" -f $i, $disk.Name, $disk.Model, $busType)
    }
}

Write-Host ""
Write-Host "🧪 選擇測試模式" -ForegroundColor Cyan
Write-Host "1️⃣  RVI 模式：ramp=300, runtime=600"
Write-Host "   a) 全部硬碟"
Write-Host "   b) 單一硬碟"
Write-Host "   c) 編號區段"
Write-Host "2️⃣  Debug 模式：ramp=30, runtime=300"
Write-Host "   b) 單一硬碟"
Write-Host "   c) 編號區段"
Write-Host "3️⃣  離開"
$mode = Read-Host "請輸入主選項 (1/2/3)"

$rampTime = 0
$runtime = 0
$selectedDisks = @()
$shutdownChoice = 0

switch ($mode) {
    "1" {
        $rampTime = 300
        $runtime = 600
        $submode = Read-Host "請輸入子選項 (a/b/c)"
        
        switch ($submode) {
            "a" {
                $selectedDisks = $disks
                
                Write-Host ""
                Write-Host "🖥️  跑完測試後的動作？" -ForegroundColor Yellow
                Write-Host "1️⃣  跑完測試後待機 180 秒再關機"
                Write-Host "2️⃣  跑完測試後維持開機"
                $shutdownChoice = Read-Host "請輸入選項 (1/2)"
                
                if ($shutdownChoice -notmatch "^[12]$") {
                    Write-Host "❌ 無效選項" -ForegroundColor Red
                    exit 1
                }
            }
            "b" {
                Show-DiskList
                $idx = Read-Host "請輸入要測試的磁碟編號"
                
                if ($idx -match "^\d+$" -and $idx -ge 0 -and $idx -lt $disks.Count) {
                    $selectedDisks = @($disks[$idx])
                } else {
                    Write-Host "❌ 無效的磁碟編號" -ForegroundColor Red
                    exit 1
                }
            }
            "c" {
                Show-DiskList
                $start = [int](Read-Host "請輸入起始編號")
                $end = [int](Read-Host "請輸入結束編號")
                
                if ($start -ge 0 -and $end -lt $disks.Count -and $start -le $end) {
                    $selectedDisks = $disks[$start..$end]
                } else {
                    Write-Host "❌ 無效的編號範圍" -ForegroundColor Red
                    exit 1
                }
                
                Write-Host ""
                Write-Host "🖥️  跑完測試後的動作？" -ForegroundColor Yellow
                Write-Host "1️⃣  跑完測試後待機 180 秒再關機"
                Write-Host "2️⃣  跑完測試後維持開機"
                $shutdownChoice = Read-Host "請輸入選項 (1/2)"
                
                if ($shutdownChoice -notmatch "^[12]$") {
                    Write-Host "❌ 無效選項" -ForegroundColor Red
                    exit 1
                }
            }
            default {
                Write-Host "❌ 無效子選項" -ForegroundColor Red
                exit 1
            }
        }
    }
    "2" {
        $rampTime = 30
        $runtime = 300
        $submode = Read-Host "請輸入子選項 (b/c)"
        
        switch ($submode) {
            "b" {
                Show-DiskList
                $idx = Read-Host "請輸入要測試的磁碟編號"
                
                if ($idx -match "^\d+$" -and $idx -ge 0 -and $idx -lt $disks.Count) {
                    $selectedDisks = @($disks[$idx])
                } else {
                    Write-Host "❌ 無效的磁碟編號" -ForegroundColor Red
                    exit 1
                }
            }
            "c" {
                Show-DiskList
                $start = [int](Read-Host "請輸入起始編號")
                $end = [int](Read-Host "請輸入結束編號")
                
                if ($start -ge 0 -and $end -lt $disks.Count -and $start -le $end) {
                    $selectedDisks = $disks[$start..$end]
                } else {
                    Write-Host "❌ 無效的編號範圍" -ForegroundColor Red
                    exit 1
                }
            }
            default {
                Write-Host "❌ 無效子選項" -ForegroundColor Red
                exit 1
            }
        }
    }
    "3" {
        Write-Host "👋 離開程式" -ForegroundColor Green
        exit 0
    }
    default {
        Write-Host "❌ 無效選項" -ForegroundColor Red
        exit 1
    }
}

# ============================================================================
# 測試流程區塊
# ============================================================================

$maxDisks = 120
$total = [Math]::Min($selectedDisks.Count, $maxDisks)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$summaryFile = "summary_$timestamp.csv"
$logFolder = "RVI_LOG_$timestamp"

# 建立日誌資料夾
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

# 初始化 CSV 檔案
"Index,Device,SN,Interface,IOdepth,IOPS,base_iops,Percentage,Pass/Fail" | Out-File -FilePath $summaryFile -Encoding UTF8

# 檢查 FIO 是否安裝
if (-not (Get-Command fio -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 未找到 FIO 工具，請先安裝 FIO" -ForegroundColor Red
    exit 1
}

# 檢查是否存在 HDD_base.csv
$hddBaseExists = Test-Path "HDD_base.csv"
if (-not $hddBaseExists) {
    Write-Host "⚠️  警告：未找到 HDD_base.csv，無法進行 Pass/Fail 判斷" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🚀 開始執行 RVI 測試..." -ForegroundColor Cyan
Write-Host ""

for ($i = 0; $i -lt $total; $i++) {
    $targetDisk = $selectedDisks[$i]
    $target = $targetDisk.Name
    $targetNumber = $targetDisk.Number
    $busType = switch ($targetDisk.BusType) {
        "ATA" { "SATA" }
        "SCSI" { "SAS" }
        default { $targetDisk.BusType }
    }
    
    # 確定塊大小和設備名稱
    $bs = if ($busType -eq "SATA") { "6k" } else { "2k" }
    
    # 取得序列號
    $diskWmi = Get-WmiObject -ClassName Win32_DiskDrive | Where-Object { $_.Index -eq $targetNumber }
    $sn = if ($diskWmi.SerialNumber) { $diskWmi.SerialNumber } else { "UnknownSN" }
    
    $fioFile = "fio_run_$target.fio"
    $outputFile = "fio_result_$target.json"
    
    Write-Host "📄 準備測試硬碟 [$i]: $target (型號: $($targetDisk.Model))" -ForegroundColor Cyan
    
    # 建立 FIO 配置檔案頭部
    $fioConfig = @"
[global]
ioengine=windowsaio
direct=1
time_based=1
runtime=$runtime
ramp_time=$rampTime
group_reporting
numjobs=1
thread=1
random_generator=tausworthe64
new_group
"@

    # 添加每個硬碟的測試任務
    $jobCount = 0
    foreach ($disk in $disks) {
        $dev = $disk.Name
        $devNumber = $disk.Number
        $devPath = "\\.\$dev"
        
        # 設定目標硬碟的 IOdepth=8，其他硬碟 IOdepth=1
        $ioDepth = if ($dev -eq $target) { 8 } else { 1 }
        
        $diskBusType = switch ($disk.BusType) {
            "ATA" { "SATA" }
            "SCSI" { "SAS" }
            default { $disk.BusType }
        }
        
        # 塊大小
        $blockSize = if ($diskBusType -eq "SATA") { "6k" } else { "2k" }
        
        # 取得序列號
        $diskWmiInner = Get-WmiObject -ClassName Win32_DiskDrive | Where-Object { $_.Index -eq $devNumber }
        $snInner = if ($diskWmiInner.SerialNumber) { $diskWmiInner.SerialNumber } else { "UnknownSN" }
        
        $fioConfig += @"
`n[$dev]`nfilename=$devPath`nbs=$blockSize`nrw=randwrite`niodepth=$ioDepth`nname=$($dev)_test_SN_$snInner`n
"@
        
        $jobCount++
    }
    
    # 寫入 FIO 配置檔案
    $fioConfig | Out-File -FilePath $fioFile -Encoding UTF8 -NoNewline
    Write-Host "  ✅ 已寫入 $jobCount 個磁碟設定至 $fioFile" -ForegroundColor Green
    
    # 執行 FIO 測試
    Write-Host "  ⏳ 執行 FIO 測試（約需 $(($rampTime + $runtime)/60) 分鐘）..." -ForegroundColor Yellow
    fio $fioFile --output-format=json --output=$outputFile 2>&1 | Out-Null
    
    if (Test-Path $outputFile) {
        Write-Host "  ✅ 測試完成：$outputFile" -ForegroundColor Green
    } else {
        Write-Host "  ❌ 測試失敗：無輸出檔案" -ForegroundColor Red
        continue
    }
    
    # 解析 FIO 結果
    try {
        $fioResult = Get-Content $outputFile | ConvertFrom-Json
        $jobName = "$($target)_test_SN_$sn"
        $iops = $fioResult.jobs | Where-Object { $_.jobname -eq $jobName } | Select-Object -ExpandProperty write | Select-Object -ExpandProperty iops
        
        # 提取 SN 前綴（取 "-" 前）
        $snKey = $sn -split "-" | Select-Object -First 1
        
        # 從 HDD_base.csv 讀取基準 IOPS
        $baseIops = "N/A"
        if ($hddBaseExists) {
            $csvData = Import-Csv -Path "HDD_base.csv"
            $baseRecord = $csvData | Where-Object { $_[0] -eq $snKey }
            if ($baseRecord) {
                $baseIops = $baseRecord | Select-Object -ExpandProperty ($csvData[0].PSObject.Properties | Select-Object -Second 1).Name
            }
        }
        
        # 計算百分比和 Pass/Fail
        $percentage = "N/A"
        $passFail = "N/A"
        
        if ($baseIops -ne "N/A" -and $iops) {
            $baseIopsNum = [double]$baseIops
            $iopsNum = [double]$iops
            
            if ($baseIopsNum -gt 0) {
                $percentageNum = ($baseIopsNum - $iopsNum) / $baseIopsNum * 100
                $percentage = "{0:F2}%" -f $percentageNum
                
                if ($busType -eq "SATA" -and $percentageNum -le 15) {
                    $passFail = "PASS"
                } elseif ($busType -eq "SAS" -and $percentageNum -le 10) {
                    $passFail = "PASS"
                } elseif ($busType -eq "SATA" -or $busType -eq "SAS") {
                    $passFail = "FAIL"
                }
            }
        }
        
        # 輸出結果到 CSV
        "$i,$target,$sn,$busType,8,$iops,$baseIops,$percentage,$passFail" | Out-File -FilePath $summaryFile -Append -Encoding UTF8
        
        Write-Host "  📊 結果：IOPS=$iops, 基準=$baseIops, 變化=$percentage, 狀態=$passFail" -ForegroundColor Cyan
    }
    catch {
        Write-Host "  ⚠️  無法解析 FIO 結果：$_" -ForegroundColor Yellow
    }
    
    # 移動檔案到日誌資料夾
    Move-Item -Path $fioFile -Destination $logFolder -Force -ErrorAction SilentlyContinue
    Move-Item -Path $outputFile -Destination $logFolder -Force -ErrorAction SilentlyContinue
    
    Write-Host ""
}

# 移動摘要檔案到日誌資料夾
Move-Item -Path $summaryFile -Destination $logFolder -Force

Write-Host "📦 所有結果已匯出至資料夾：$logFolder\" -ForegroundColor Green

# ============================================================================
# 結束動作
# ============================================================================

if ($mode -eq "1" -and ($submode -eq "a" -or $submode -eq "c")) {
    if ($shutdownChoice -eq "1") {
        Write-Host ""
        Write-Host "⏳ 測試完成，系統將於 180 秒後自動關機..." -ForegroundColor Yellow
        Start-Sleep -Seconds 180
        
        Write-Host "🔌 執行關機命令..." -ForegroundColor Red
        shutdown /s /t 0
    } else {
        Write-Host ""
        Write-Host "✅ 測試完成，系統維持開機狀態" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "✅ 測試完成" -ForegroundColor Green
}
