# Drill backup dan restore-validation, mengikuti panduan infrastruktur bagian 18:
# backup -> perubahan setelah backup -> restore ke database TERPISAH (capstone_restore_validation) -> validasi.
# Database live TIDAK ditimpa. Jalankan di PowerShell (Windows PowerShell 5.1 cukup); capstone-postgres harus Up.
$C = 'capstone-postgres'; $U = 'capstone'; $DB = 'capstone'; $VDB = 'capstone_restore_validation'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$out  = Join-Path (Split-Path -Parent $here) 'backups'
New-Item -ItemType Directory -Force $out | Out-Null
$ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
$dump = "$DB-$ts.dump"
function Step($t) { Write-Host ("`n=== {0} | {1} ===" -f $t, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan }
function Wait-Shot($m) { Read-Host "`n>> $m (Enter untuk lanjut)" | Out-Null }
function Get-State($db) { Get-Content (Join-Path $here 'verify.sql') | docker exec -i $C psql -U $U -d $db }

Step 'A. Kondisi database live SEBELUM backup (baris dan checksum per tabel)'
$v1 = Get-State $DB; $v1
$v1 | Out-File (Join-Path $out "stateA_before_backup_$ts.txt") -Encoding utf8
Wait-Shot 'Screenshot panel A'

Step 'B. Backup (pg_dump format custom)'
docker exec $C pg_dump -U $U -d $DB -Fc -f "/tmp/$dump"
if ($LASTEXITCODE -ne 0) { Write-Host 'pg_dump GAGAL, hentikan.' -ForegroundColor Red; return }
docker cp "${C}:/tmp/$dump" (Join-Path $out $dump)
$f = Get-Item (Join-Path $out $dump)
'{0}  {1} bytes' -f $f.Name, $f.Length
Get-FileHash $f.FullName -Algorithm SHA256 | Format-List Algorithm, Hash
'Isi arsip (15 baris pertama):'
docker exec $C pg_restore -l "/tmp/$dump" | Select-Object -First 15
$tBackup = Get-Date
Wait-Shot 'Screenshot panel B'

Step 'C. Perubahan di database live SETELAH backup'
@"
WITH a AS (INSERT INTO attempt(tenant_id,exam_id,user_id,submitted_at) VALUES ('tenant-a',1,'post-backup-user',now()) RETURNING id)
INSERT INTO result(tenant_id,attempt_id,score) SELECT 'tenant-a', id, 50 FROM a;
"@ | docker exec -i $C psql -U $U -d $DB
$v2 = Get-State $DB; $v2
Wait-Shot 'Screenshot panel C'

Step "D. RESTORE ke database terpisah $VDB (database live tidak disentuh)"
docker exec $C psql -U $U -d postgres -c "DROP DATABASE IF EXISTS $VDB;"
docker exec $C psql -U $U -d postgres -c "CREATE DATABASE $VDB OWNER $U;"
$sw = [Diagnostics.Stopwatch]::StartNew()
docker cp (Join-Path $out $dump) "${C}:/tmp/restore_$dump"
docker exec $C pg_restore -U $U -d $VDB --no-owner "/tmp/restore_$dump"
$code = $LASTEXITCODE
$sw.Stop()
'Restore selesai dalam {0:N1} detik (exit code {1})' -f $sw.Elapsed.TotalSeconds, $code
docker exec $C psql -U $U -d $VDB -c '\dt'
Wait-Shot 'Screenshot panel D'

Step 'E. VALIDASI hasil restore'
$v3 = Get-State $VDB; $v3
$v3 | Out-File (Join-Path $out "stateE_restored_$ts.txt") -Encoding utf8
$d13 = Compare-Object $v1 $v3
if (-not $d13) { Write-Host 'Hasil restore IDENTIK dengan kondisi saat backup (baris dan checksum sama).' -ForegroundColor Green }
else { Write-Host 'Hasil restore BEDA dari kondisi saat backup:' -ForegroundColor Red; $d13 }
Write-Host "`nData bisnis terpilih di database hasil restore (attempt + skor):"
'SELECT a.id AS attempt, a.tenant_id, r.score FROM attempt a JOIN result r ON r.attempt_id=a.id ORDER BY a.id;' | docker exec -i $C psql -U $U -d $VDB
Write-Host "`nPerbedaan database live (setelah perubahan) vs hasil restore = data yang dibuat setelah backup:"
Compare-Object $v2 $v3 | Format-Table -AutoSize
Wait-Shot 'Screenshot panel E'

Step 'F. Ringkasan'
'File backup      : {0} ({1} bytes)' -f $f.Name, $f.Length
'Durasi restore   : {0:N1} detik' -f $sw.Elapsed.TotalSeconds
'Jeda backup -> pemeriksaan: {0:N0} detik' -f ((Get-Date) - $tBackup).TotalSeconds
"Database validasi $VDB dibiarkan sebagai bukti. Hapus bila tidak perlu: docker exec $C psql -U $U -d postgres -c `"DROP DATABASE $VDB;`""
