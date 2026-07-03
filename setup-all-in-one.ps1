# ff.dev — WSL2 + Ubuntu + gerekli araclar TEK SCRIPT kurulumu
# Windows PowerShell'i YONETICI olarak acip calistirin:
#   powershell -ExecutionPolicy Bypass -File setup-all-in-one.ps1
#
# Bu script: WSL2'yi etkinlestirir, Ubuntu'yu kurar, KULLANICI ETKILESIMI
# OLMADAN Ubuntu icine girip node/npm/git/gh/wrangler kurar. Tek eksiklik:
# Windows'ta WSL ozellikleri ilk kez etkinlesiyorsa bir reboot zorunlu
# (bu Windows'un kendi kisitlamasi, script bunu otomatik algilayip
# kendini reboot sonrasi devam edecek sekilde zamanlayici ile ayarlar).

$ErrorActionPreference = "Stop"
$ScriptPath = $MyInvocation.MyCommand.Path
$TaskName = "ffdev-wsl-setup-continue"

function Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Warn2($msg){ Write-Host "  ! $msg" -ForegroundColor Yellow }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "YONETICI PowerShell gerekli. Baslat -> PowerShell -> sag tik -> 'Yonetici olarak calistir'." -ForegroundColor Red
    exit 1
}

# ── 1) WSL + Sanal Makine Platformu ozellikleri ───────────────────────
Step "Windows ozellikleri kontrol ediliyor..."
$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
$vmFeature  = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
$needsReboot = $false

if ($wslFeature.State -ne "Enabled") {
    Warn2 "WSL etkinlestiriliyor..."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
    $needsReboot = $true
} else { Ok "WSL zaten etkin" }

if ($vmFeature.State -ne "Enabled") {
    Warn2 "Virtual Machine Platform etkinlestiriliyor..."
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
    $needsReboot = $true
} else { Ok "Virtual Machine Platform zaten etkin" }

if ($needsReboot) {
    Step "Reboot gerekiyor. Reboot sonrasi bu script OTOMATIK devam edecek sekilde ayarlaniyor..."
    $action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$ScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Ok "Otomatik devam gorevi olusturuldu (bir kereye mahsus, script sonunda kendini siler)"
    Write-Host ""
    Write-Host "Bilgisayar 10 saniye icinde yeniden baslatilacak. Yeniden acildiginda script kaldigi yerden devam edecek." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer
    exit 0
}

# Reboot sonrasi tekrar geldiysek zamanlanmis gorevi temizle
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# ── 2) WSL kernel guncelle + varsayilan surum 2 ───────────────────────
Step "WSL2 varsayilan surum olarak ayarlaniyor..."
wsl --update | Out-Null
wsl --set-default-version 2 | Out-Null
Ok "WSL2 aktif"

# ── 3) Ubuntu kur (kullanici etkilesimi olmadan, root ile) ────────────
Step "Ubuntu dagitimi kontrol ediliyor..."
$distros = (wsl -l -q 2>&1) -join "`n"

if ($distros -notmatch "Ubuntu") {
    Warn2 "Ubuntu kuruluyor (bu birkaç dakika surebilir)..."
    wsl --install -d Ubuntu --no-launch
    Start-Sleep -Seconds 5
    # Ilk açilista kullanici olusturma ekranini atlamak icin root ile baslatip
    # varsayilan kullaniciyi otomatik olusturuyoruz.
    wsl -d Ubuntu -u root -- bash -c "id ffdev &>/dev/null || useradd -m -s /bin/bash -G sudo ffdev; echo 'ffdev:ffdev' | chpasswd"
    wsl -d Ubuntu -u root -- bash -c "echo '[user]' > /etc/wsl.conf; echo 'default=ffdev' >> /etc/wsl.conf"
    wsl --terminate Ubuntu
    Ok "Ubuntu kuruldu, varsayilan kullanici: ffdev / sifre: ffdev (ilk girişte degistirin)"
} else {
    Ok "Ubuntu zaten kurulu"
}

wsl --set-version Ubuntu 2 2>&1 | Out-Null

# ── 4) Ubuntu icine gerekli araclari kur + Claude Code + MCP sorulari ─
# Bu bolum INTERAKTIF calisir: her arac icin var/yok kontrolu yapar,
# eksigi kurar; Claude Code kurulup kurulmayacagini ve giris gerektiren
# MCP/skill/pluginlerin hangilerinin ekleneceini SIZE sorar.
Step "Ubuntu icinde kontrol + kurulum basliyor (interaktif, sorulari cevaplayin)..."

# ffdev-bootstrap.sh iceriği bu ps1 ile birlikte dagitilir; ayni klasorde
# olmali. Yoksa script burada durur.
$bootstrapLocal = Join-Path (Split-Path -Parent $ScriptPath) "ffdev-bootstrap.sh"
if (-not (Test-Path $bootstrapLocal)) {
    Write-Host "HATA: ffdev-bootstrap.sh bulunamadi. Bu dosya setup-all-in-one.ps1 ile ayni klasorde olmali." -ForegroundColor Red
    exit 1
}

$bootstrapPath = "/tmp/ffdev-bootstrap.sh"
# Windows -> WSL dosya kopyasi (satir sonlarini LF'e cevirerek)
$content = Get-Content -Raw $bootstrapLocal
$content = $content -replace "`r`n", "`n"
$content | wsl -d Ubuntu -u root -- bash -c "cat > $bootstrapPath && chmod +x $bootstrapPath && chown `$(id -u ffdev 2>/dev/null || echo root):`$(id -g ffdev 2>/dev/null || echo root) $bootstrapPath"

# Interaktif calistir (sudo gereken yerler script icinde kendi sudo'sunu kullanir)
wsl -d Ubuntu -- bash $bootstrapPath

Ok "Ubuntu icindeki kurulum adimi tamamlandi"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host " TEK SCRIPT KURULUM TAMAMLANDI" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host " Ubuntu'yu acmak icin: wsl -d Ubuntu  (ya da Baslat menusunden Ubuntu)"
Write-Host " Detayli ozet ve eksik/kurulu durumu yukarida ffdev-bootstrap.sh ciktisinda."
Write-Host " gh/wrangler login sorulari ve Claude Code MCP baglantilari script icinde soruldu."
Write-Host " Claude Code kurulduysa: Ubuntu'da 'claude' yazip ilk girisi tamamlayin."
Write-Host "==================================================" -ForegroundColor Green
