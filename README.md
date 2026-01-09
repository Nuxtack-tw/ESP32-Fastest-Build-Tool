# ESP32 Fastest Build Tool

[![Windows](https://img.shields.io/badge/Windows-10%2F11-blue?logo=windows)](https://www.microsoft.com/windows)
[![Arduino IDE](https://img.shields.io/badge/Arduino%20IDE-2.x-00979D?logo=arduino)](https://www.arduino.cc/en/software)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

使用 RAM Disk 加速 Arduino IDE 編譯，可獲得 **2-5 倍**的編譯速度提升。

## 📋 目錄

- [原理說明](#-原理說明)
- [系統需求](#-系統需求)
- [安裝 AIM Toolkit](#-安裝-aim-toolkit)
- [建立 RAM Disk](#-建立-ram-disk)
- [ESP32 Flash 分區規劃](#-esp32-flash-分區規劃)
- [FQBN 完整指南](#-fqbn-完整指南)
- [使用方式](#-使用方式)
- [效能比較](#-效能比較)
- [常見問題](#-常見問題)

---

## 💡 原理說明

Arduino IDE 編譯時會在以下位置產生大量暫存檔：

| 路徑 | 用途 |
|------|------|
| `%LOCALAPPDATA%\arduino\sketches` | 編譯輸出（.o、.elf、.bin） |
| `%LOCALAPPDATA%\Arduino15\staging` | 下載的核心/函式庫暫存 |

本專案透過 **符號連結（Symbolic Link）** 將這些目錄指向 RAM Disk，讓編譯過程中的大量讀寫操作在記憶體中完成，大幅提升速度。

---

## 🔧 系統需求

- Windows 10/11（64-bit）
- .NET Framework 4.8（Windows 10 1903+ 已內建）
- Arduino IDE 2.x
- 建議 8GB 以上記憶體

---

## 📦 安裝 AIM Toolkit

[AIM Toolkit](https://sourceforge.net/projects/aim-toolkit/) 是 ImDisk Toolkit 的後繼者，使用 Arsenal Image Mounter 驅動程式，解決了舊版在 Windows 10/11 24H2 的相容性問題。

### 下載與安裝

1. 前往 [SourceForge 下載頁面](https://sourceforge.net/projects/aim-toolkit/)
2. 下載最新版本 `AIM_Toolkit_xxxxxxxx.zip`
3. 解壓縮到固定位置（如 `C:\Tools\AIM_Toolkit\`）
4. 以**系統管理員身份**執行 `install.bat`
5. **重新啟動電腦**

### 驗證安裝

安裝完成後，可在裝置管理員的「存放控制器」中看到 **Arsenal Image Mounter**。

### 工具說明

| 檔案 | 用途 |
|------|------|
| `RamDiskUI.exe` | RAM Disk 圖形介面（推薦） |
| `RamDyn.exe` | 動態記憶體 RAM Disk（命令列） |
| `aim_ll.exe` | 靜態 RAM Disk（命令列） |

---

## 💾 建立 RAM Disk

### 方法一：圖形介面（推薦）

1. 以系統管理員身份執行 `RamDiskUI.exe`
2. 設定參數：
   - **Size**: `1024` MB（1GB，大多數專案足夠使用）
   - **Drive Letter**: `R:`
   - **File System**: `NTFS`
   - ☑️ Allocate Memory Dynamically
   - ☑️ Launch at Windows Startup
3. 點擊 **OK**

> 💡 **容量提示**：1GB 足夠大多數專案使用。如編譯大型專案時空間不足，可改為 2GB。

### 方法二：命令列

```batch
# 靜態 RAM Disk（立即佔用記憶體）
aim_ll.exe -a -o rem -s 1G -m R: -p "/fs:ntfs /q /y /v:RAMdisk"

# 動態 RAM Disk（按需佔用記憶體，推薦）
RamDyn.exe -s 1G -m R: -p "/fs:ntfs /q /y /v:RAMdisk"

# 卸載
aim_ll.exe -d -m R:
```

### 建議容量

| 使用情境 | 建議大小 |
|----------|----------|
| 一般專案（預設） | 1 GB |
| 大型專案或多專案同時編譯 | 2 GB |

> 💡 建議先使用 1GB，若編譯時出現空間不足再調整為 2GB。

---

## 📐 ESP32 Flash 分區規劃

### 什麼是 Partition Scheme？

ESP32 的 Flash 記憶體需要透過分區表（Partition Table）來規劃各區域的用途，包括：

- **app**：應用程式區（你的程式碼）
- **nvs**：非揮發性儲存區（WiFi 設定、使用者資料）
- **spiffs/fatfs**：檔案系統區（儲存檔案）
- **ota**：OTA 更新區（無線更新用）

### 預設分區方案

Arduino IDE 在 `Tools → Partition Scheme` 提供多種預設方案：

| 方案名稱 | APP 大小 | 檔案系統 | OTA | 適用情境 |
|----------|----------|----------|-----|----------|
| Default 4MB | 1.2 MB | 1.5 MB SPIFFS | ✓ | 一般專案 |
| No OTA (2MB APP/2MB SPIFFS) | 2 MB | 2 MB SPIFFS | ✗ | 大型程式，不需 OTA |
| Huge APP (3MB No OTA/1MB SPIFFS) | 3 MB | 1 MB SPIFFS | ✗ | 超大型程式 |
| Minimal SPIFFS | 1.9 MB | 190 KB | ✓ | 程式大、少量檔案 |
| No OTA (2MB APP/2MB FATFS) | 2 MB | 2 MB FATFS | ✗ | 需要 FAT 檔案系統 |

### 自定義分區表

當預設方案不符合需求時，可以建立自定義的 `partitions.csv`。

#### 步驟一：建立 partitions.csv

在專案資料夾（與 .ino 同目錄）建立 `partitions.csv` 檔案：

```csv
# ESP-IDF Partition Table
# Name,   Type, SubType, Offset,  Size,    Flags
nvs,      data, nvs,     0x9000,  0x5000,
otadata,  data, ota,     0xe000,  0x2000,
app0,     app,  ota_0,   0x10000, 0x200000,
spiffs,   data, spiffs,  0x210000,0x1F0000,
```

#### 分區表格式說明

| 欄位 | 說明 |
|------|------|
| Name | 分區名稱（最多 16 字元） |
| Type | `app`（應用程式）或 `data`（資料） |
| SubType | 子類型：`ota_0`、`ota_1`、`nvs`、`spiffs`、`fat` 等 |
| Offset | 起始位址（第一個分區必須從 `0x9000` 開始） |
| Size | 分區大小（可用 K、M 單位，如 `2M`、`512K`） |
| Flags | 旗標（通常留空） |

#### 範例：No OTA + 2MB APP + 2MB FATFS（適用 4MB Flash）

```csv
# Name,   Type, SubType, Offset,  Size,    Flags
nvs,      data, nvs,     0x9000,  0x5000,
otadata,  data, ota,     0xe000,  0x2000,
app0,     app,  ota_0,   0x10000, 0x200000,
fatfs,    data, fat,     0x210000,0x1F0000,
```

#### 範例：大型程式 + SPIFFS（適用 16MB Flash）

```csv
# Name,   Type, SubType, Offset,  Size,    Flags
nvs,      data, nvs,     0x9000,  0x5000,
otadata,  data, ota,     0xe000,  0x2000,
app0,     app,  ota_0,   0x10000, 0x300000,
spiffs,   data, spiffs,  0x310000,0xCF0000,
```

#### 範例：No OTA + 6MB APP + 2MB FATFS（適用 8MB Flash）

```csv
# Name,   Type, SubType, Offset,  Size,    Flags
nvs,      data, nvs,     0x9000,  0x5000,
otadata,  data, ota,     0xe000,  0x2000,
app0,     app,  ota_0,   0x10000, 0x5F0000,
fatfs,    data, fat,     0x600000,0x200000,
```

#### 範例：No OTA + 14MB APP + 2MB FATFS（適用 16MB Flash）

```csv
# Name,   Type, SubType, Offset,  Size,    Flags
nvs,      data, nvs,     0x9000,  0x5000,
otadata,  data, ota,     0xe000,  0x2000,
app0,     app,  ota_0,   0x10000, 0xDF0000,
fatfs,    data, fat,     0xE00000,0x200000,
```

#### 步驟二：編譯時套用

將 `partitions.csv` 放在專案目錄後，Arduino 編譯系統會**自動偵測並使用**，無需額外設定。

> ⚠️ **注意事項**：
> - APP 分區的 Offset 必須對齊到 64KB（0x10000）
> - 使用 Arduino CLI 時，需搭配 `--build-property` 參數指定 `build.partitions`
> - 分區總大小不可超過 Flash 容量

### 使用 Arduino CLI 指定自定義分區

```batch
arduino-cli compile --fqbn esp32:esp32:esp32s3 --build-property "build.partitions=partitions" MyProject.ino
```

或將自定義分區檔放到 ESP32 核心的分區目錄：

```
%LOCALAPPDATA%\Arduino15\packages\esp32\hardware\esp32\{version}\tools\partitions\
```

> 💡 `{version}` 是你安裝的 ESP32 核心版本號，例如 `3.0.0`、`3.1.0`。
> 完整路徑範例：`C:\Users\你的使用者名稱\AppData\Local\Arduino15\packages\esp32\hardware\esp32\3.0.0\tools\partitions\`

然後透過 FQBN 指定：

```batch
arduino-cli compile --fqbn "esp32:esp32:esp32s3:PartitionScheme=my_custom" MyProject.ino
```

---

## 📖 FQBN 完整指南

### 什麼是 FQBN？

**FQBN**（Fully Qualified Board Name）是 Arduino 用來精確識別開發板及其設定的標準格式。

### FQBN 格式

```
VENDOR:ARCHITECTURE:BOARD_ID[:MENU_ID=OPTION_ID[,MENU_ID=OPTION_ID...]]
```

| 欄位 | 說明 | 範例 |
|------|------|------|
| `VENDOR` | 開發板供應商 | `arduino`、`esp32`、`teensy` |
| `ARCHITECTURE` | 晶片架構 | `avr`、`esp32`、`samd` |
| `BOARD_ID` | 開發板型號 | `uno`、`esp32s3`、`nano` |
| `MENU_ID=OPTION_ID` | 選單選項（可選） | `CDCOnBoot=cdc`、`FlashSize=16M` |

### FQBN 範例

```bash
# Arduino UNO（無選項）
arduino:avr:uno

# Arduino Nano（指定處理器）
arduino:avr:nano:cpu=atmega328old

# ESP32-S3（多個選項，用逗號分隔）
esp32:esp32:esp32s3:CDCOnBoot=cdc,PartitionScheme=default,FlashSize=16M

# ESP8266（多個選項）
esp8266:esp8266:generic:xtal=160,baud=57600

# ESP32-S3 使用 No OTA 分區（2MB APP / 2MB FATFS）
esp32:esp32:esp32s3:PartitionScheme=no_ota,FlashSize=4M

# ESP32-S3 使用 Huge APP 分區（適合大型專案）
esp32:esp32:esp32s3:PartitionScheme=huge_app,FlashSize=16M
```

> ⚠️ **注意**：選項之間使用 **逗號** `,` 分隔，不是冒號 `:`

### 從 Arduino IDE 取得 FQBN

1. 開啟 Arduino IDE
2. 選擇目標開發板（Tools → Board）
3. 設定所有選單選項（Tools → 各項設定）
4. 前往 **File → Preferences**
5. 勾選 **Show verbose output during: ☑️ compilation**
6. 點擊 **OK**
7. 編譯任意程式（Sketch → Verify/Compile）
8. 在輸出視窗搜尋 `-fqbn=`

```
# 輸出範例（尋找 -fqbn= 後面的內容）
Compiling sketch...
"C:\Users\...\arduino-cli.exe" compile -fqbn=esp32:esp32:esp32s3:CDCOnBoot=default,PartitionScheme=no_ota ...
                                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                       這就是你的 FQBN
```

### ESP32-S3 常用選項對照表

| 選單名稱 | MENU_ID | 選項範例 |
|----------|---------|----------|
| USB CDC On Boot | `CDCOnBoot` | `default`（停用）、`cdc`（啟用） |
| Partition Scheme | `PartitionScheme` | `default`、`no_ota`、`huge_app`、`min_spiffs` |
| Upload Mode | `UploadMode` | `default`（UART）、`cdc`（USB） |
| CPU Frequency | `CPUFreq` | `240`、`160`、`80` |
| Flash Mode | `FlashMode` | `qio`、`dio`、`qout` |
| Flash Size | `FlashSize` | `4M`、`8M`、`16M` |
| PSRAM | `PSRAM` | `disabled`、`enabled`、`opi` |
| Upload Speed | `UploadSpeed` | `921600`、`460800`、`115200` |
| Debug Level | `DebugLevel` | `none`、`error`、`warn`、`info`、`debug`、`verbose` |

### 常用 PartitionScheme 選項

| 選項值 | 說明 |
|--------|------|
| `default` | 預設分區（含 OTA） |
| `no_ota` | 無 OTA（2MB APP / 2MB SPIFFS） |
| `huge_app` | 超大 APP（3MB APP / 1MB SPIFFS） |
| `min_spiffs` | 最小 SPIFFS（1.9MB APP / 190KB SPIFFS） |
| `fatfs` | 使用 FATFS 檔案系統 |

### 完整 ESP32-S3 FQBN 範例

```bash
# 標準設定：USB CDC 關閉、無 OTA 分區、16MB Flash、啟用 PSRAM
esp32:esp32:esp32s3:CDCOnBoot=default,PartitionScheme=no_ota,UploadMode=default,CPUFreq=240,FlashMode=qio,FlashSize=16M,UploadSpeed=921600,DebugLevel=none,PSRAM=enabled

# 大型專案：Huge APP 分區、8MB Flash
esp32:esp32:esp32s3:PartitionScheme=huge_app,FlashSize=8M,PSRAM=enabled

# 搭配自定義 partitions.csv（專案目錄中有 partitions.csv）
# 使用 --build-property 指定
arduino-cli compile --fqbn esp32:esp32:esp32s3 --build-property "build.partitions=partitions" MyProject.ino
```

---

## 🚀 使用方式

### 檔案說明

| 檔案 | 用途 | 執行方式 |
|------|------|----------|
| `RAMDisk.bat` | 建立符號連結 | 右鍵 → 以系統管理員身份執行 |
| `Restore.bat` | 還原預設設定 | 右鍵 → 以系統管理員身份執行 |
| `Build.bat` | Arduino CLI 編譯 | 拖放 .ino 檔案 或 命令列 |

### 步驟一：設定符號連結（只需執行一次）

```batch
# 確保 Arduino IDE 已關閉
# 確保 RAM Disk (R:) 已建立
# 右鍵以系統管理員身份執行
RAMDisk.bat
```

### 步驟二：編譯專案

```batch
# 方式一：拖放檔案
# 將 .ino 檔案拖放到 Build.bat 上

# 方式二：命令列
Build.bat MyProject.ino

# 方式三：指定 FQBN
Build.bat MyProject.ino "esp32:esp32:esp32s3:PartitionScheme=no_ota"
```

### 步驟三：還原（如需要）

`Restore.bat` 用於移除符號連結，將 Arduino IDE 還原為使用本機硬碟的預設設定。

**何時需要還原？**

| 情境 | 說明 |
|------|------|
| 移除 RAM Disk 軟體 | 卸載 AIM Toolkit 前必須先還原，否則符號連結會指向不存在的磁碟 |
| 排除編譯問題 | 懷疑 RAM Disk 造成編譯異常時，可暫時還原測試 |
| 不再使用此工具 | 想回復 Arduino IDE 原始狀態 |
| 更換 RAM Disk 磁碟代號 | 需先還原，再重新執行 RAMDisk.bat |

**還原後的影響：**
- Arduino IDE 的暫存檔會改存到本機硬碟（原始位置）
- 編譯速度會回到使用硬碟的速度
- 不影響你的專案檔案和程式碼

```batch
# 右鍵以系統管理員身份執行
Restore.bat
```

> 💡 **提示**：如果只是暫時不使用 RAM Disk，可以不執行還原。符號連結會持續存在，當 RAM Disk 再次掛載時會自動恢復運作。

---

## 📊 效能比較

以 ESP32-S3 完整編譯為例（非快取編譯）：

| 儲存媒體 | 編譯時間 | 相對速度 |
|----------|----------|----------|
| HDD 7200rpm | ~180 秒 | 1x |
| SATA SSD | ~90 秒 | 2x |
| NVMe SSD | ~60 秒 | 3x |
| **RAM Disk** | **~30 秒** | **6x** |

---

## ❓ 常見問題

### Q: 重開機後第一次編譯變慢？

**A**: 正常現象。RAM Disk 內容在重開機後會清空，第一次編譯需要重新產生快取。後續編譯會恢復快速。

### Q: 符號連結建立失敗？

**A**: 請確認：
1. 以系統管理員身份執行
2. Arduino IDE 已完全關閉
3. RAM Disk 格式為 NTFS

### Q: RAM Disk 空間不足？

**A**: 預設 1GB 足夠大多數專案。若編譯大型專案時空間不足，請將 RAM Disk 大小調整為 2GB。

### Q: Arduino CLI 找不到開發板？

**A**: 更新核心索引：
```batch
arduino-cli core update-index
arduino-cli core install esp32:esp32
```

### Q: 自定義 partitions.csv 沒有生效？

**A**: 請確認：
1. 檔案名稱必須是 `partitions.csv`
2. 檔案必須放在專案資料夾（與 .ino 同目錄）
3. 使用 Arduino CLI 時需加上 `--build-property "build.partitions=partitions"`

### Q: Windows 11 24H2 執行 RAM Disk 上的 exe 出現錯誤？

**A**: 這是已知問題。解決方法：
1. 以系統管理員身份執行
2. 參考 [Win11-RAMDisk-Admin-Fix](https://github.com/oood/Win11-RAMDisk-Admin-Fix)

### Q: AIM Toolkit 與 ImDisk Toolkit 有何不同？

**A**: AIM Toolkit 是 ImDisk Toolkit 的後繼者，使用新的 Arsenal Image Mounter 驅動程式，解決了舊版在新版 Windows 的相容性問題。建議使用 AIM Toolkit。

---

## 📄 License

MIT License

---

## 🔗 相關連結

- [AIM Toolkit](https://sourceforge.net/projects/aim-toolkit/) - RAM Disk 工具
- [Arduino CLI](https://arduino.github.io/arduino-cli/) - 命令列編譯工具
- [ESP32 Partition Table 文件](https://docs.espressif.com/projects/arduino-esp32/en/latest/tutorials/partition_table.html) - 官方分區表說明
- [Arduino Platform Specification](https://arduino.github.io/arduino-cli/latest/platform-specification/) - FQBN 規格說明
