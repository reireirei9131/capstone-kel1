# Uji kegagalan: hentikan PostgreSQL saat API hidup, amati, nyalakan lagi, ukur pemulihan.
# Prasyarat: API versi containerize berjalan di http://172.22.65.161:3000 (Ubuntu: cd ~/capstone03/api; node server.js),
# Keycloak Up. Hanya untuk lab: jika Gitea memakai PostgreSQL yang sama, layanannya ikut terganggu sebentar.
$C = 'capstone-postgres'
$ready = 'http://172.22.65.161:3000/q/health/ready'
$rep   = 'http://172.22.65.161:3000/reports'
$tok = (curl.exe -s -X POST http://127.0.0.1:8081/realms/capstone/protocol/openid-connect/token -d client_id=capstone-app -d grant_type=password -d username=operator -d password=operator | ConvertFrom-Json).access_token
if (-not $tok) { Write-Host 'Gagal mengambil token (Keycloak Up?)' -ForegroundColor Red; return }
function Code($url, $hdr) {
  try { [int](Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $hdr -TimeoutSec 3).StatusCode }
  catch { if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'DOWN' } }
}
function Snap($fase) {
  [pscustomobject]@{ Waktu = (Get-Date -Format 'HH:mm:ss'); Fase = $fase; Ready = (Code $ready @{}); Reports = (Code $rep @{ Authorization = "Bearer $tok" }) }
}
$rows = @()
for ($i = 0; $i -lt 3; $i++) { $rows += Snap 'normal'; Start-Sleep 1 }
Write-Host "`nMenghentikan PostgreSQL ($(Get-Date -Format 'HH:mm:ss'))..." -ForegroundColor Yellow
docker stop $C | Out-Null
for ($i = 0; $i -lt 8; $i++) { $rows += Snap 'database mati'; Start-Sleep 1 }
Write-Host "Menyalakan PostgreSQL ($(Get-Date -Format 'HH:mm:ss'))..." -ForegroundColor Yellow
$tStart = Get-Date
docker start $C | Out-Null
$recovered = $null
for ($i = 0; $i -lt 60; $i++) {
  $s = Snap 'pemulihan'; $rows += $s
  if ($s.Ready -eq 200 -and $s.Reports -eq 200) { $recovered = Get-Date; break }
  Start-Sleep 1
}
$rows | Format-Table -AutoSize
if ($recovered) { 'API kembali sehat {0:N1} detik setelah docker start (tanpa restart API).' -f ($recovered - $tStart).TotalSeconds }
else { Write-Host 'API belum pulih dalam 60 detik. Periksa log API (nilai DOWN berarti proses API mati).' -ForegroundColor Red }
'Keterangan: 200 = sehat, 503 = database tidak tersedia (perilaku yang diharapkan), DOWN = proses API mati.'
