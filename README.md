# dev-setup

Windows 10/11 üzerinde WSL2 + Ubuntu + tam bir geliştirici ortamı (Node.js, Python/uv, git, GitHub CLI, Cloudflare wrangler, Claude Code + MCP sunucuları) kuran, proje bağımsız, tek seferlik kurulum scriptleri.

- İdempotent: her araç için önce "kurulu mu?" kontrolü yapar, eksikse kurar.
- WSL2 etkinleştirme reboot gerektirirse otomatik devam eder (tekrar elle başlatmaya gerek yok).
- Claude Code kurulup kurulmayacağını sorar.
- Login gerektirmeyen MCP sunucularını (filesystem, fetch, memory, sequential-thinking) toplu ekler.
- Login/API key gerektiren entegrasyonları (GitHub, Slack, Postgres, Cloudflare) tek tek sorar.

## Kullanım

1. Bu iki dosyayı **aynı klasöre** indirin:
   - `setup-all-in-one.ps1`
   - `ffdev-bootstrap.sh`

2. Windows'ta PowerShell'i **Yönetici olarak** açıp çalıştırın:

```powershell
powershell -ExecutionPolicy Bypass -File setup-all-in-one.ps1
```

Tek satırda indirip çalıştırmak için (PowerShell, yönetici):

```powershell
iwr -useb https://raw.githubusercontent.com/fckfavor/dev-setup/main/setup-all-in-one.ps1 -OutFile setup-all-in-one.ps1
iwr -useb https://raw.githubusercontent.com/fckfavor/dev-setup/main/ffdev-bootstrap.sh -OutFile ffdev-bootstrap.sh
powershell -ExecutionPolicy Bypass -File setup-all-in-one.ps1
```

## Neler kurulur

| Araç | Not |
|------|-----|
| WSL2 + Ubuntu | Windows özellik + dağıtım kurulumu |
| Node.js LTS | apt (nodesource) |
| Python3 + pip + uv | |
| git, build-essential | |
| GitHub CLI (`gh`) | opsiyonel login sorulur |
| Cloudflare CLI (`wrangler`) | opsiyonel login sorulur |
| Claude Code | opsiyonel, sorulur |
| MCP sunucuları | login gerektirmeyenler toplu, login gerektirenler tek tek sorulur |

## Lisans

MIT
