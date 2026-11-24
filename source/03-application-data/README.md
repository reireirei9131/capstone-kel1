# 03-application-data - cara menjalankan

Prasyarat: infrastruktur paket kelas jalan (`postgres`, `keycloak`), Docker Desktop, Node.js, curl, jq.

1. Start (PowerShell, dari root paket kelas):
   `docker compose --env-file infrastructure\.env -f infrastructure\docker-compose.yml up -d postgres keycloak`
2. Migrasi: `scripts/run-flyway.ps1` (PowerShell) atau `scripts/run-flyway.sh` (Ubuntu), dari folder ini.
3. Keycloak (http://127.0.0.1:8081, admin/admin), realm `capstone`:
   - Buat realm role **auditor**.
   - Buat user **auditor**: isi Email, First name, Last name (wajib di Keycloak 26 agar bisa login), password `auditor` (Temporary Off), role `auditor`, group `tenant-b`.
   - Tambahkan user **operator** ke group `tenant-a`.
   - Clients -> capstone-app -> Client scopes -> capstone-app-dedicated -> Add mapper -> By configuration -> **Group Membership**: Token Claim Name `groups`, Full group path **Off**, Add to access token **On**.
   - Cek token `usera` memuat `"groups":["tenant-a"]`.
4. API: `cd api && npm install && node server.js`
5. Demo (terminal Ubuntu lain): `./scripts/demo.sh`
6. Bukti DB: `./scripts/db-proof.sh`; persistensi: `docker restart capstone-postgres`, tunggu 10 detik, ulangi db-proof.
7. Screenshot -> `screenshots/`, kolase:
   `cd screenshots && montage 0*.png -tile 2x -geometry 900x+8+8 -background white ../03_evidence.jpg`
8. Salin `db/`, `api/` (tanpa node_modules), `scripts/` ke `source/` repo.

## Catatan kredensial
Password `capstone` (database) dan password user demo (sama dengan username) adalah kredensial bawaan
paket infrastruktur kelas untuk lab lokal, bukan rahasia produksi. Jangan dipakai di luar lab.
