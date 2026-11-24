# Evidence 08 - Reliability & Recovery

> Isi bagian [ISI] hanya dengan data dari eksekusi sebenarnya (keluaran drill.ps1 dan failure-test.ps1). Jangan menulis angka yang tidak terukur.

**Catatan jujur:** backup dan restore dilakukan pada PostgreSQL lab di satu laptop (Docker). Ini membuktikan prosedur pemulihan data, bukan ketahanan terhadap kegagalan host atau lokasi.

## Field evidence

| Field | Isi |
|---|---|
| **Scope** | Basis data aplikasi ujian (PostgreSQL, database `capstone`): backup logis, restore ke database validasi terpisah (`capstone_restore_validation`), validasi; serta uji kegagalan layanan database terhadap API. |
| **Owner** | Azka Zufar Abrani (pelaksana); reviewer: Azka Zufar Abrani |
| **Source / version** | PostgreSQL 17.11 (database dan `pg_dump`, dari header arsip), `pg_dump -Fc` dan `pg_restore` dari container yang sama, Docker Desktop 4.35.1 (engine 27.3.1), repo commit [ISI hasil `git rev-parse --short HEAD`]. |
| **Timestamp** | 2026-11-24 (WIB, UTC+7). Drill: 11:21 sampai 11:23. Uji kegagalan 1: 10:16 sampai 10:22. Uji kegagalan 2: 11:09. |
| **Method** | `scripts/drill.ps1` (A sampai F) dan `scripts/failure-test.ps1`. Verifikasi memakai jumlah baris dan checksum md5 per tabel (`scripts/verify.sql`). |
| **Observation** | Lihat bagian di bawah. |
| **Interpretation** | Lihat bagian di bawah. |
| **Limitation** | Lihat bagian di bawah. |
| **Decision supported** | Strategi backup (jenis, frekuensi, lokasi) dan target RPO/RTO yang dipilih tim. |

## Daftar bukti

Nomor sama dengan label panel di `08_evidence.jpg`.

| # | Isi | Dari |
|---|---|---|
| 1 | Kondisi sebelum backup (baris dan checksum per tabel) | drill A |
| 2 | Backup: nama file, ukuran, SHA-256, isi arsip | drill B |
| 3 | Perubahan di database live setelah backup | drill C |
| 4 | Restore ke `capstone_restore_validation`: durasi dan `\dt` | drill D |
| 5 | Validasi: identik dengan saat backup, data bisnis (attempt dan skor) | drill E |
| 6 | Selisih database live vs hasil restore (data yang dibuat setelah backup) | drill E |
| 7 | Uji kegagalan 1, sebelum perbaikan: API mati dan tidak pulih | failure-test |
| 8 | Uji kegagalan 2, sesudah perbaikan: 503 lalu 200 | failure-test |
| 9 | Ringkasan: file backup, durasi restore, jeda | drill F |

## Observation
- Backup: `capstone-20261124-112108.dump`, 20825 bytes, SHA-256 `05922E5404532A3A2B127FB8BBDA22E45A3080D36CA3E84075000F652DEEC840`. Nama file memakai waktu mulai skrip (11:21:08); dump diambil pukul 11:22:39 WIB (04:22:39 UTC pada header arsip). Arsip dapat dibaca `pg_restore -l`: format CUSTOM, kompresi gzip, 66 TOC entries.
- Sebelum backup (panel 1): tenant 2, exam 2, question 4, attempt 9, answer 16, result 9, flyway_schema_history 2 baris. Di database hasil restore (panel 5): jumlah baris dan checksum md5 sama untuk ketujuh tabel. Perbandingan: identik.
- Data bisnis di database hasil restore (attempt + skor): sembilan attempt, attempt 1 sampai 8 bernilai 100.00 (tenant-a dan tenant-b bergantian), attempt 9 (tenant-a) bernilai 50.00. Attempt 9 dan 10 berasal dari `post-backup-user`, yaitu baris penanda yang dimasukkan drill pada panel C (attempt 9 dari run drill sebelumnya, tersisa di database live dan ikut terbackup di run ini), bukan hasil ujian nyata.
- Perubahan setelah backup: satu attempt dan satu result ditambahkan (attempt dan result menjadi 10 baris, panel 3). Di database hasil restore baris itu tidak ada (attempt dan result tetap 9; panel 6 menunjukkan hanya database live yang memiliki attempt 10 dan result 10).
- Durasi restore terukur: 1.1 detik (exit code 0, tujuh tabel kembali). Jeda backup sampai pemeriksaan menurut panel F (11:30:17): 456 detik, termasuk waktu menunggu screenshot tiap panel. Validasi pada panel E berlangsung pukul 11:23:32, sekitar 53 detik setelah backup (dari timestamp panel).
- Uji kegagalan 1 (API sebelum perbaikan, 10:16 WIB): saat PostgreSQL dihentikan (10:16:45), `/q/health/ready` menjawab 503 satu kali, lalu proses API mati (DOWN). Setelah PostgreSQL dinyalakan (10:17:26), API tetap DOWN lebih dari 60 detik dan tidak pulih. Log API: `ECONNREFUSED` pada handler `/reports`, yang tidak punya `try/catch`, sehingga error asinkron yang lolos mematikan proses Node 22.
- Perbaikan: `/reports` dibungkus `try/catch` (membalas 503), `ROLLBACK` pada handler submit diamankan, dan ditambahkan handler `unhandledRejection` sebagai jaring pengaman.
- Uji kegagalan 2 (API sesudah perbaikan, 11:09 WIB): PostgreSQL dihentikan pukul 11:09:33 dan dinyalakan pukul 11:09:42. `/q/health/ready` dan `/reports` menjawab 503 selama sekitar 9 detik, API tetap hidup. API sehat kembali (200) 2.4 detik setelah `docker start`, tanpa restart API.

## Interpretation
Checksum identik membuktikan data pulih utuh dari backup. Baris yang dibuat setelah backup tidak ikut pulih, sehingga data yang dibuat setelah backup hilang kalau restore dilakukan dari backup tersebut; dengan demikian RPO sama dengan jarak antar backup. Karena backup masih manual, RPO sebenarnya tidak terjamin. Durasi restore 1.1 detik mewakili RTO hanya untuk ukuran data lab. Pada uji kegagalan 2, 503 saat database mati menunjukkan kegagalan terkendali (proses API tidak mati) dan pemulihan otomatis begitu database kembali. Uji 1 menunjukkan bahwa tanpa perbaikan, satu jalur kode tanpa penanganan error cukup untuk mematikan seluruh API; temuan ini diperbaiki dan dibuktikan pada uji 2.

## Limitation
- Jeda 456 detik di panel F adalah jarak dalam simulasi (termasuk waktu menunggu screenshot), bukan klaim RPO.
- Dataset hanya beberapa baris, jadi durasi restore tidak mewakili data produksi.
- Backup disimpan di laptop yang sama dengan database (bukan lokasi terpisah), jadi tidak melindungi dari kehilangan perangkat.
- Backup dijalankan manual, belum terjadwal (CronJob atau Task Scheduler).
- Data Keycloak (realm, user) tidak ikut dibackup; realm dapat dipulihkan dari berkas import.
- Satu node, satu instance database: tidak ada bukti high availability.
- Restore dilakukan ke database terpisah di server yang sama (sesuai panduan), jadi kehilangan database live tidak disimulasikan dan RTO penuh belum teruji.
- Uji kegagalan hanya memantau `/q/health/ready` dan `/reports`. Alur mulai ujian, autosave, dan submit belum diuji saat database mati.
- Uji kegagalan memakai satu proses API tanpa replika, dengan gangguan database sekitar 9 detik (uji 2). Perilaku di Kubernetes (replicas: 2) belum diuji. Handler `unhandledRejection` hanya jaring pengaman: ia mencegah proses mati, tetapi tidak menjamin setiap request yang gagal dijawab dengan benar.

## Decision supported
Bukti ini mendukung keputusan tim tentang target RPO/RTO, frekuensi dan lokasi backup (misalnya `pg_dump` terjadwal ke volume terpisah), dan langkah lanjutan (CronJob di cluster, restore berkala, uji kegagalan untuk jalur ujian lainnya). Angka target yang dipilih belum ditentukan di dokumen ini: [ISI keputusan tim].
