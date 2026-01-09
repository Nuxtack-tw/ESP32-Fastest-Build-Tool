@echo off
chcp 65001 >nul
setlocal

:: ============================================================
:: ESP32 Fastest Build Tool - 還原預設設定工具
:: https://github.com/Nuxtack-tw/ESP32-Fastest-Build-Tool
:: ============================================================

set "ARDUINO_SKETCHES=%LOCALAPPDATA%\arduino\sketches"
set "ARDUINO_STAGING=%LOCALAPPDATA%\Arduino15\staging"

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
echo        RAM Disk 還原預設設定工具
echo        Build: 2026-01-09
echo        Powered by Yuanpro@Nuxtack
echo ============================================================
echo.
echo 此工具將移除 RAM Disk 符號連結，還原為預設設定。
echo.
set /p "CONFIRM=確定要還原嗎？[Y/N]: "
if /i not "%CONFIRM%"=="Y" (
    echo 已取消。
    pause
    exit /b 0
)

echo.

:: 移除 sketches 符號連結
echo [處理中] 檢查 sketches 目錄...
fsutil reparsepoint query "%ARDUINO_SKETCHES%" >nul 2>&1
if %errorlevel% equ 0 (
    rmdir "%ARDUINO_SKETCHES%" 2>nul
    echo [✓] sketches 符號連結已移除
) else (
    echo [!] sketches 不是符號連結，跳過
)

:: 移除 staging 符號連結
echo [處理中] 檢查 staging 目錄...
fsutil reparsepoint query "%ARDUINO_STAGING%" >nul 2>&1
if %errorlevel% equ 0 (
    rmdir "%ARDUINO_STAGING%" 2>nul
    echo [✓] staging 符號連結已移除
) else (
    echo [!] staging 不是符號連結，跳過
)

:: 建立空目錄
echo.
echo [處理中] 建立預設目錄...
if not exist "%ARDUINO_SKETCHES%" (
    mkdir "%ARDUINO_SKETCHES%" 2>nul
    echo [✓] 已建立 sketches 目錄
)
if not exist "%ARDUINO_STAGING%" (
    mkdir "%ARDUINO_STAGING%" 2>nul
    echo [✓] 已建立 staging 目錄
)

echo.
echo ============================================================
echo   還原完成！
echo ============================================================
echo.
echo Arduino IDE 將在預設位置建立編譯快取。
echo.
pause
