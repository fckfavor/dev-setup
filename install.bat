@echo off
setlocal

:: ============================================================
:: dev-setup — tek tikla kurulum baslaticisi
:: Kullanici bu dosyayi indirip cift tiklar, gerisini bat halleder:
:: yonetici izni ister, script dosyalarini GitHub'dan indirir,
:: WSL2 + Ubuntu + dev ortami kurulumunu baslatir.
:: ============================================================

:: ── Yonetici kontrolu, degilse kendini yukseltilmis olarak yeniden baslat ──
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Yonetici izni gerekiyor, UAC penceresi acilacak...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================================
echo   dev-setup kurulumu baslatiliyor
echo ============================================================
echo.

set "WORKDIR=%~dp0dev-setup-files"
if not exist "%WORKDIR%" mkdir "%WORKDIR%"
cd /d "%WORKDIR%"

echo [1/2] Kurulum dosyalari indiriliyor...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/fckfavor/dev-setup/main/setup-all-in-one.ps1' -OutFile 'setup-all-in-one.ps1';" ^
  "Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/fckfavor/dev-setup/main/ffdev-bootstrap.sh' -OutFile 'ffdev-bootstrap.sh'"

if not exist "setup-all-in-one.ps1" (
    echo HATA: Dosyalar indirilemedi. Internet baglantinizi kontrol edin.
    pause
    exit /b 1
)

echo   Tamamlandi: %WORKDIR%
echo.
echo [2/2] Kurulum scripti calistiriliyor...
echo   ^(WSL2 etkinlestirmesi reboot gerektirirse bilgisayar otomatik
echo    yeniden baslar ve script kaldigi yerden devam eder^)
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "setup-all-in-one.ps1"

echo.
echo ============================================================
echo   install.bat tamamlandi.
echo ============================================================
pause
