@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================
:: ESP32 Fastest Build Tool - Arduino CLI 編譯工具
:: https://github.com/Nuxtack-tw/ESP32-Fastest-Build-Tool
::
:: RAM Disk 建議容量：1GB（大型專案可改為 2GB）
:: ============================================================

:: ==================== 設定區域 ====================

:: RAM Disk 位置
set "RAMDISK=R:"

:: 預設 FQBN（ESP32-S3 範例）
:: 格式: VENDOR:ARCHITECTURE:BOARD_ID[:MENU_ID=OPTION_ID,...]
:: 從 Arduino IDE 取得: File → Preferences → 勾選 verbose output → 編譯 → 搜尋 -fqbn=
set "DEFAULT_FQBN=esp32:esp32:esp32s3:CDCOnBoot=default,PartitionScheme=no_ota,UploadMode=default,CPUFreq=240,FlashMode=qio,FlashSize=16M,UploadSpeed=921600,DebugLevel=none,PSRAM=enabled"

:: 編譯輸出目錄
set "BUILD_DIR=%RAMDISK%\arduino-build"

:: ==================== 主程式 ====================

echo.
echo ============================================================
echo        ESP32 Fastest Build Tool v1.0
echo        Arduino CLI 編譯工具
echo        Build: 2026-01-09
echo        Powered by Yuanpro@Nuxtack
echo ============================================================

:: 檢查參數
if "%~1"=="" (
    echo.
    echo 用法: %~nx0 ^<sketch.ino^> [FQBN]
    echo.
    echo 範例:
    echo   %~nx0 MyProject.ino
    echo   %~nx0 MyProject.ino esp32:esp32:esp32s3
    echo   %~nx0 "C:\Projects\MyProject\MyProject.ino"
    echo.
    echo FQBN 格式:
    echo   VENDOR:ARCHITECTURE:BOARD_ID[:OPTION=VALUE,...]
    echo.
    echo FQBN 範例:
    echo   arduino:avr:uno
    echo   arduino:avr:nano:cpu=atmega328old
    echo   esp32:esp32:esp32s3:PartitionScheme=no_ota,FlashSize=16M
    echo.
    echo 取得 FQBN:
    echo   arduino-cli board listall
    echo   arduino-cli board details --fqbn esp32:esp32:esp32s3
    echo.
    echo 預設 FQBN:
    echo   %DEFAULT_FQBN%
    echo.
    echo 提示: 可直接將 .ino 檔案拖放到此批次檔上執行
    echo.
    pause
    exit /b 1
)

:: 取得 sketch 路徑
set "SKETCH=%~f1"

:: 檢查檔案
if not exist "%SKETCH%" (
    echo.
    echo [錯誤] 找不到: %SKETCH%
    pause
    exit /b 1
)

:: 取得 sketch 名稱
for %%i in ("%SKETCH%") do (
    set "SKETCH_DIR=%%~dpi"
    set "SKETCH_NAME=%%~ni"
)

:: 設定 FQBN
if "%~2"=="" (
    set "FQBN=%DEFAULT_FQBN%"
) else (
    set "FQBN=%~2"
)

:: 檢查 RAM Disk
if not exist "%RAMDISK%\" (
    echo.
    echo [警告] RAM Disk ^(%RAMDISK%^) 不存在，使用系統暫存目錄
    set "BUILD_DIR=%TEMP%\arduino-build"
)

:: 建立編譯目錄
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

:: 顯示資訊
echo.
echo [專案] %SKETCH_NAME%
echo [路徑] %SKETCH%
echo [輸出] %BUILD_DIR%\%SKETCH_NAME%
echo [FQBN] %FQBN%
echo.

:: 檢查 arduino-cli
where arduino-cli >nul 2>&1
if %errorlevel% neq 0 (
    echo [錯誤] 找不到 arduino-cli！
    echo.
    echo 安裝方式:
    echo   winget install ArduinoSA.ArduinoCLI
    echo.
    echo 或手動下載:
    echo   https://arduino.github.io/arduino-cli/
    echo.
    pause
    exit /b 1
)

:: 記錄開始時間
for /f "tokens=1-4 delims=:." %%a in ("%time%") do (
    set /a "START_S=(((%%a*60)+1%%b %% 100)*60+1%%c %% 100)"
)

:: 編譯
echo [編譯中] 請稍候...
echo ============================================================
echo.

arduino-cli compile ^
    --fqbn "%FQBN%" ^
    --build-path "%BUILD_DIR%\%SKETCH_NAME%" ^
    --build-cache-path "%BUILD_DIR%\cache" ^
    --warnings default ^
    "%SKETCH%"

set "RESULT=%errorlevel%"

echo.
echo ============================================================

:: 計算耗時
for /f "tokens=1-4 delims=:." %%a in ("%time%") do (
    set /a "END_S=(((%%a*60)+1%%b %% 100)*60+1%%c %% 100)"
)
set /a "ELAPSED=END_S-START_S"
if %ELAPSED% lss 0 set /a "ELAPSED+=86400"
set /a "ELAPSED_M=ELAPSED/60"
set /a "ELAPSED_S=ELAPSED%%60"

:: 結果
echo.
if %RESULT% equ 0 (
    echo [✓] 編譯成功！耗時: %ELAPSED_M% 分 %ELAPSED_S% 秒
    echo.
    
    :: 列出輸出檔案
    echo 輸出檔案:
    set "OUT_DIR=%BUILD_DIR%\%SKETCH_NAME%"
    if exist "!OUT_DIR!\%SKETCH_NAME%.ino.bin" (
        for %%f in ("!OUT_DIR!\%SKETCH_NAME%.ino.bin") do (
            echo   [BIN]  %%~nxf ^(%%~zf bytes^)
        )
    )
    if exist "!OUT_DIR!\%SKETCH_NAME%.ino.elf" (
        for %%f in ("!OUT_DIR!\%SKETCH_NAME%.ino.elf") do (
            echo   [ELF]  %%~nxf ^(%%~zf bytes^)
        )
    )
    if exist "!OUT_DIR!\%SKETCH_NAME%.ino.bootloader.bin" (
        echo   [BOOT] %SKETCH_NAME%.ino.bootloader.bin
    )
    if exist "!OUT_DIR!\%SKETCH_NAME%.ino.partitions.bin" (
        echo   [PART] %SKETCH_NAME%.ino.partitions.bin
    )
    
    echo.
    echo 檔案位置: %BUILD_DIR%\%SKETCH_NAME%\
    
    :: 詢問上傳
    echo.
    set /p "UPLOAD=上傳到開發板？[Y/N]: "
    if /i "!UPLOAD!"=="Y" call :Upload
) else (
    echo [✗] 編譯失敗 ^(錯誤碼: %RESULT%^)
    echo     耗時: %ELAPSED_M% 分 %ELAPSED_S% 秒
)

echo.
pause
exit /b %RESULT%

:: ============================================================
:: 函式：上傳
:: ============================================================
:Upload
echo.
echo [上傳中] 請稍候...

arduino-cli upload ^
    --fqbn "%FQBN%" ^
    --input-dir "%BUILD_DIR%\%SKETCH_NAME%" ^
    "%SKETCH%"

if %errorlevel% equ 0 (
    echo [✓] 上傳成功！
) else (
    echo [✗] 上傳失敗
)
exit /b 0
