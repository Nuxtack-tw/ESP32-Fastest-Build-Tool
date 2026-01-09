@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================
:: ESP32 Fastest Build Tool - 符號連結設定工具
:: https://github.com/Nuxtack-tw/ESP32-Fastest-Build-Tool
::
:: RAM Disk 建議容量：1GB（大型專案可改為 2GB）
:: ============================================================

:: 設定區域
set "RAMDISK=R:"
set "ARDUINO_SKETCHES=%LOCALAPPDATA%\arduino\sketches"
set "ARDUINO_STAGING=%LOCALAPPDATA%\Arduino15\staging"
set "RAMDISK_SKETCHES=%RAMDISK%\arduino\sketches"
set "RAMDISK_STAGING=%RAMDISK%\arduino\staging"

:: 檢查管理員權限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [錯誤] 請以系統管理員身份執行！
    echo.
    echo 右鍵點擊此檔案，選擇「以系統管理員身份執行」
    pause
    exit /b 1
)

echo.
echo ============================================================
echo        ESP32 Fastest Build Tool v1.0
echo        RAM Disk 與 Windows符號連結設定工具
echo        Build: 2026-01-09
echo        Powered by Yuanpro@Nuxtack
echo ============================================================
echo.

:: 檢查 RAM Disk
if not exist "%RAMDISK%\" (
    echo [錯誤] RAM Disk ^(%RAMDISK%^) 不存在！
    echo.
    echo 請先使用 AIM Toolkit 建立 RAM Disk：
    echo   1. 執行 RamDiskUI.exe
    echo   2. 設定大小為 1GB（大型專案可改為 2GB）
    echo   3. 設定磁碟代號為 R:
    echo   4. 選擇 NTFS 檔案系統
    echo   5. 勾選 Launch at Windows Startup
    echo.
    pause
    exit /b 1
)
echo [✓] RAM Disk ^(%RAMDISK%^) 已就緒

:: 建立目錄結構
echo.
echo [處理中] 建立 RAM Disk 目錄結構...
if not exist "%RAMDISK_SKETCHES%" mkdir "%RAMDISK_SKETCHES%"
if not exist "%RAMDISK_STAGING%" mkdir "%RAMDISK_STAGING%"
echo [✓] 目錄結構建立完成

:: 處理 sketches 目錄
echo.
echo [處理中] 設定 sketches 符號連結...
call :CreateSymlink "%ARDUINO_SKETCHES%" "%RAMDISK_SKETCHES%"

:: 處理 staging 目錄
echo.
echo [處理中] 設定 staging 符號連結...
call :CreateSymlink "%ARDUINO_STAGING%" "%RAMDISK_STAGING%"

:: 完成
echo.
echo ============================================================
echo   設定完成！
echo ============================================================
echo.
echo 符號連結：
echo   %ARDUINO_SKETCHES%
echo     -^> %RAMDISK_SKETCHES%
echo.
echo   %ARDUINO_STAGING%
echo     -^> %RAMDISK_STAGING%
echo.
echo 注意事項：
echo   • 符號連結只需設定一次，重開機後仍有效
echo   • RAM Disk 內容會在重開機後清空（正常現象）
echo   • Arduino IDE 會自動重建編譯快取
echo.
pause
exit /b 0

:: ============================================================
:: 函式：建立符號連結
:: ============================================================
:CreateSymlink
set "ORIGINAL=%~1"
set "TARGET=%~2"

:: 檢查是否已是符號連結
fsutil reparsepoint query "%ORIGINAL%" >nul 2>&1
if %errorlevel% equ 0 (
    echo [!] 已存在符號連結，移除中...
    rmdir "%ORIGINAL%" 2>nul
)

:: 備份現有目錄
if exist "%ORIGINAL%\" (
    echo [!] 發現現有目錄，備份中...
    set "BACKUP=%ORIGINAL%.backup_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
    set "BACKUP=!BACKUP: =0!"
    move "%ORIGINAL%" "!BACKUP!" >nul 2>&1
    if exist "!BACKUP!" echo [✓] 已備份至: !BACKUP!
)

:: 確保父目錄存在
for %%i in ("%ORIGINAL%") do set "PARENT=%%~dpi"
if not exist "%PARENT%" mkdir "%PARENT%"

:: 建立符號連結
mklink /D "%ORIGINAL%" "%TARGET%" >nul 2>&1
if %errorlevel% equ 0 (
    echo [✓] 符號連結建立成功
) else (
    echo [錯誤] 建立失敗，請確認 Arduino IDE 已關閉
)
exit /b 0
