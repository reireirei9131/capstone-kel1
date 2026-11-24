# 08 - Reliability & Recovery (cara menjalankan)

Prasyarat: Docker Desktop jalan; `capstone-postgres` dan `capstone-keycloak` Up; database berisi data demo 03.

## 1. Drill backup dan restore-validation (PowerShell, dari folder ini)
Mengikuti panduan infrastruktur bagian 18: restore ke database terpisah `capstone_restore_validation`, database live tidak ditimpa.
Skrip resmi dosen juga ada di paket infrastruktur (`scripts/backup-postgres.ps1`, `scripts/restore-postgres-validation.ps1`); skrip ini meniru langkahnya dan memakai `docker exec`, jadi jalan di Windows PowerShell 5.1.
    powershell -ExecutionPolicy Bypass -File scripts\drill.ps1
Skrip berhenti di tiap panel (A sampai F). Ambil screenshot lalu tekan Enter. File backup tersimpan di `backups\`.

## 2. Uji kegagalan database (butuh API versi containerize)
Ubuntu: `cd ~/capstone03/api && node server.js` (biarkan terbuka). Lalu PowerShell:
    powershell -ExecutionPolicy Bypass -File scripts\failure-test.ps1
Screenshot tabel hasilnya.

## 3. Susun evidence
Gabungkan screenshot jadi `08_evidence.jpg`, isi `[ISI]` di `08_evidence.md` dari keluaran asli. Jangan commit folder `backups\` (berisi data).

## Catatan alamat API
failure-test.ps1 memakai IP WSL milik pelaksana (172.22.65.161) di baris 5 dan 6. Di laptop lain atau setelah WSL restart, cek IP dengan `wsl -d Ubuntu hostname -I`, lalu ganti alamat itu di skrip.
