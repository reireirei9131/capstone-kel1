# Evidence 03 - Application & Data

**Kelompok 1** | Mata kuliah Cloud Computing, Final Capstone | Kasus: ujian daring multi-tenant

Ringkasan: alur ujian daring (login Keycloak -> mulai ujian -> autosave jawaban -> submit -> skor -> laporan)
berjalan untuk dua tenant, dan datanya tersimpan di PostgreSQL. Kolase bukti: `03_evidence.jpg`
(panel per nomor ada di folder `screenshots/`).

## Field evidence

| Field | Isi |
|---|---|
| **Scope** | API ujian (Node.js/Express), skema PostgreSQL 6 tabel + `flyway_schema_history`, Keycloak realm `capstone` (role dan group tenant). Tenancy memakai pendekatan Opsi A: implementasi tenancy dengan negative isolation test. |
| **Owner** | Azka Zaufar Abrani (2410512036), pelaksana. Reviewer: **[ISI nama reviewer dari anggota lain]**. Anggota kelompok: Azka Zaufar Abrani (2410512036), Andreya Naufal Subagyo (2410512154), Deo Putra Garcia (2410512118), Rafi Rei Riordan (2410512204). |
| **Source / version** | PostgreSQL 17.11 (image `postgres:17-alpine`), Flyway OSS 10.22.0, Keycloak 26.8.1, Node.js **[ISI hasil `node --version`]**, kode di `source/03-application-data/`, repo commit **[ISI hasil `git rev-parse --short HEAD`]**. Infrastruktur dari paket infrastruktur kelas (Docker Desktop di Windows). |
| **Timestamp** | Flyway dijalankan 11 Nov 2026 (kolom Installed On 12:20:48 dan 12:20:49, waktu database). Demo API dan screenshot Keycloak 12 Nov 2026 sekitar pukul 19:03-19:11 (waktu lokal laptop). Restart PostgreSQL 12 Nov 2026 pukul 19:18:11 (keluaran `Get-Date`). |
| **Method** | `scripts/run-flyway.ps1` (migrasi), konfigurasi manual di Keycloak Admin Console, `scripts/demo.sh` (alur ujian + 6 tes negatif), `scripts/db-proof.sql` lewat `docker exec ... psql` (bukti data), `docker restart capstone-postgres` (uji persistensi). |
| **Observation** | Lihat bagian di bawah. |
| **Interpretation** | Lihat bagian di bawah. |
| **Limitation** | Lihat bagian di bawah. |
| **Decision supported** | Memilih Opsi A (tenancy): kolom `tenant_id` di semua tabel selain `tenant`, tenant diambil dari group Keycloak pada token, setiap query difilter `tenant_id`. Memilih Flyway untuk migrasi yang dapat diulang. |

## Daftar bukti (nomor sesuai `03_evidence.jpg`)

| # | Isi | File panel |
|---|---|---|
| 1 | Output Flyway: 2 migrasi berhasil, tabel `info` | `01.png` |
| 2 | `\dt` (7 tabel) dan `flyway_schema_history` (2 baris, success = t) | `02.png` |
| 3 | Keycloak realm `capstone`: role `user`, `operator`, `admin`, `auditor` | `03.png` |
| 4 | Keycloak: anggota group `tenant-a` dan `tenant-b` | `04a.png`, `04b.png` |
| 5 | Alur ujian: start, autosave, upsert, submit, skor, laporan operator, tenant-b | `05a.png`-`05c.png` |
| 6 | Laporan auditor tenant-b dan 6 tes negatif | `06a.png`, `06b.png` |
| 7 | Data di database sebelum restart | `07a.png`, `07b.png` |
| 8 | Data sama setelah `docker restart capstone-postgres` | `08a.png`, `08b.png` |

## Observation (yang terlihat di bukti)

1. **Migrasi (#1, #2).** Flyway menerapkan 2 migrasi (`V1 init schema`, `V2 seed data`) ke schema `public`, berakhir di versi 2.
   Database berisi 7 tabel: `answer`, `attempt`, `exam`, `flyway_schema_history`, `question`, `result`, `tenant`.
   `flyway_schema_history` memuat 2 baris dengan `success = t`.
2. **Role dan tenant (#3, #4).** Realm `capstone` memiliki role `user`, `operator`, `admin`, dan `auditor` (role `auditor` ditambahkan kelompok).
   Group `tenant-a` beranggotakan `operator` dan `usera`; group `tenant-b` beranggotakan `auditor` dan `userb`.
3. **Alur ujian (#5).** `usera` (tenant-a) memulai ujian 1 (attempt 1), menyimpan jawaban soal 1 = A dan soal 2 = B,
   lalu mengganti jawaban soal 2 menjadi C dan kembali ke B pada baris yang sama (id jawaban 2, bukan baris baru, sehingga upsert bekerja).
   Submit menghasilkan skor 100.00. Laporan `operator` (tenant-a) berisi 1 baris. `userb` (tenant-b) mengerjakan ujian 2
   (attempt 2), skor 100.00.
4. **Isolasi dan otorisasi (#6).** Laporan `auditor` hanya berisi attempt tenant-b. Hasil tes negatif:
   userb memulai ujian tenant-a -> `exam not found`; userb mengubah attempt milik usera -> `attempt/question not found or closed`;
   usera membuka laporan -> `forbidden`; auditor memulai ujian -> `forbidden`; tanpa token -> `invalid token`;
   submit dua kali -> `attempt not found or already submitted`.
5. **Data tersimpan (#7).** Tabel `attempt` + `result`: attempt 1 (tenant-a) dan attempt 2 (tenant-b), masing-masing skor 100.00.
   Tabel `answer`: 4 baris (2 per tenant), jumlah per tenant 2 dan 2.
6. **Persistensi (#8).** Setelah `docker restart capstone-postgres` (19:18:11) dan jeda 15 detik, query yang sama menghasilkan
   data identik dengan #7 (7 tabel, 2 migrasi, attempt 1 dan 2, 4 jawaban).

## Interpretation

Setiap langkah alur ujian meninggalkan baris di `attempt`, `answer`, dan `result` dengan `tenant_id` yang sesuai. Tenant ditentukan dari
group pada token Keycloak, bukan dari input pengguna, dan query selalu memakai `tenant_id` tersebut, sehingga pengguna tenant lain menerima
404 atau 403 untuk data yang bukan miliknya. Role menentukan aksi: hanya `user` yang dapat mengerjakan ujian, sedangkan `operator`, `admin`,
dan `auditor` dapat membaca laporan. Data bertahan setelah restart karena PostgreSQL memakai volume Docker. Skema dibuat lewat Flyway,
sehingga dapat direproduksi di lingkungan lain.

## Limitation

- Isolasi tenant ditegakkan di lapisan aplikasi (filter `tenant_id`); belum memakai PostgreSQL Row-Level Security.
- Skor baru diuji dengan semua jawaban benar (100.00); skenario sebagian benar atau tidak dijawab belum didemokan.
- Role `admin` (Admin institusi) belum diperagakan di demo; yang didemokan adalah `user`, `operator`, dan `auditor`.
- Kolom waktu bertipe `TIMESTAMP` tanpa zona waktu. Akibatnya jam pada respons API (misalnya `05:00:08Z`) berbeda 7 jam dari jam
  yang tersimpan di database (`12:00:08`) karena Node.js menafsirkannya sebagai waktu lokal. Nilai di database yang benar (UTC).
  Perbaikan yang direncanakan: migrasi `V3` yang mengubah kolom ke `TIMESTAMPTZ`.
- Belum ada antarmuka web; demo dilakukan lewat API (`curl`). Kredensial demo hanya untuk lab lokal.
- Data bukti berasal dari satu kali eksekusi demo pada satu mesin.

## Cara mengulang

Lihat `source/03-application-data/README.md`.
