# Evidence 04 - Platform Kubernetes (Milestone M3)

Sistem: Platform Ujian Daring Multi-Tenant (kampus + lembaga sertifikasi)

> **Catatan jujur:** aplikasi ujian asli belum dipakai pada evidence ini.
> Workload yang dideploy adalah **aplikasi stand-in** (nginx:alpine dengan endpoint
> `/q/health/ready` dan `/q/health/live`) agar seluruh jalur platform dapat dibuktikan
> secara nyata. Evidence ini membuktikan **platform**, bukan perilaku aplikasi ujian.
> Untuk memakai aplikasi asli cukup mengganti satu baris `image:` di `app.yaml`.

## 1. Ringkasan evidence (9 field)

| Field | Isi |
| --- | --- |
| **Scope** | Container image, Deployment (2 replika), Service, Ingress, ConfigMap, readiness/liveness probe, resource requests/limits pada cluster k3d (1 server + 1 agent), namespace `capstone`. |
| **Owner** | Deo Putra Garcia (2410512118) - Platform & Delivery. |
| **Source / version** | Image `localhost:5001/capstone-app:v0.1.0`, digest `sha256:5772d161de9804a9ab1eb43680886887b468ddf5bd64a980ad7bb138f82f83bd`. k3d v5.9.0, k3s v1.35.5+k3s1, kubectl client v1.37.2, Docker 29.9.2, base image `nginx:alpine`. Commit repo: **-**. |
| **Timestamp** | 10 November 2026, 14:11 - 14:15 WIB (UTC+7). Panel tambahan: **10 November 2026, 14:24 - 14:25 WIB.**. |
| **Method** | Skrip `run-evidence.sh` menjalankan perintah satu per satu, tiap panel diberi `date` dan di-screenshot. Daftar perintah ada di bagian 2. |
| **Observation** | Lihat bagian 3. |
| **Interpretation** | Lihat bagian 4. |
| **Limitation** | Lihat bagian 5. |
| **Decision supported** | ADR-004 (aplikasi stateless dengan replika/HPA) dan pemilihan Kubernetes dibanding VM tunggal (bagian 1 dokumen bisnis). |

## 2. Metode dan file sumber

File di folder ini:

- `Dockerfile`, `default.conf`, `index.html` - pembuatan image stand-in.
- `app.yaml` - manifest deklaratif (Namespace, ConfigMap, Deployment, Service, Ingress).
- `run-evidence.sh` - skrip pengambilan evidence.
- `04_evidence.pdf` / `04_evidence.jpg` - kumpulan screenshot terminal.

Urutan panel:

1. Versi tools (`kubectl version`, `k3d version`, `docker --version`)
2. `kubectl get nodes -o wide`
3. `cat Dockerfile`, `docker build --provenance=false`, `docker push`, daftar tag registry
4. `kubectl apply -f app.yaml` dan `rollout status`
5. `kubectl -n capstone get all,ingress,configmap`
6. `kubectl describe deploy` (image, probes, resources)
7. `kubectl get deploy -o wide` dan `describe pod` (Image ID pod)
8. Akses ingress via `curl -H 'Host: capstone.localhost' http://127.0.0.1:8088/...`
9. Scale 2 -> 3 -> 2
10. Hapus satu pod (self-healing)
11. `rollout restart` dan `rollout history`

## 3. Observasi

- **Cluster:** dua node `Ready` (`k3d-capstone-server-0` control-plane, `k3d-capstone-agent-0`), k3s v1.35.5+k3s1.
- **Image:** build sukses, push ke registry lokal, daftar tag menunjukkan `v0.1.0`.
  Digest hasil push `5772d161...f83bd` **sama persis** dengan `Image ID` pada kedua pod.
  Tag tidak berubah isinya selama pengambilan evidence karena build memakai `--provenance=false`.
- **Workload:** 2 pod `1/1 Running`, Deployment `2/2`, Service ClusterIP port 80, Ingress kelas `traefik` host `capstone.localhost`, ConfigMap `capstone-app-config`.
- **Konfigurasi di Deployment:** readiness `/q/health/ready` (delay 3s, period 5s), liveness `/q/health/live` (delay 10s, period 10s), requests 100m CPU / 192Mi, limits 500m CPU / 512Mi.
- **Scale:** setelah `--replicas=3`, pod baru langsung `0/1 ContainerCreating` (1 detik) dan baru `1/1 Running` pada detik ke-13. Setelah dikembalikan ke 2, Deployment `2/2`.
- **Hapus pod:** satu pod dihapus pada 14:14:39. Pod lama `Terminating`, pod pengganti `ContainerCreating`, dan 16 detik kemudian dua pod kembali `1/1 Running`.
- **Rollout restart:** selesai dengan sukses, `rollout history` menunjukkan revision 1 dan 2.
- **Akses ingress (panel 8):** pada percobaan pertama (14:13:58 WIB) `curl` mengembalikan `Empty reply from server`, dan kolom ADDRESS ingress masih kosong pada panel sebelumnya.
  Percobaan ulang setelah Traefik siap: **pada 14:24:40 WIB Traefik berstatus Running, ADDRESS ingress terisi, dan curl ke http://127.0.0.1:8088/q/health/ready (header Host: capstone.localhost) mengembalikan HTTP/1.1 200 OK dengan {"status":"UP"}. Kegagalan pada 14:13:58 disebabkan Traefik belum siap.**.
  Pemeriksaan selama hapus pod dengan ingress siap: **pada 14:25:23 WIB satu pod dihapus; sepuluh permintaan berturut-turut selama 10 detik semuanya HTTP 200, dan pod pengganti kembali 1/1 Running dalam 14 detik.**.

## 4. Interpretasi

- Digest image yang sama di registry dan di pod membuktikan bahwa yang berjalan adalah artefak yang dibangun, bukan image lain dengan tag sama.
- Pod baru yang `0/1` sebelum `1/1` menunjukkan **readiness probe** menahan pod dari endpoint Service sampai aplikasinya siap. Ini melindungi peserta ujian agar tidak diarahkan ke replika yang belum siap.
- Pengganti pod yang muncul otomatis setelah penghapusan menunjukkan **reconciliation** Deployment (self-healing sederhana), relevan dengan QS2 pada dokumen arsitektur.
- Requests/limits memberi dasar awal untuk analisis kapasitas (M8). Nilainya masih nilai awal dari template dan belum diukur.
- Manifest deklaratif menunjukkan state yang diinginkan dapat diterapkan ulang, selaras dengan rencana GitOps (ADR-006).

## 5. Limitasi

- Workload adalah **stand-in nginx**, bukan aplikasi ujian. Tidak ada bukti perilaku bisnis, database, OIDC, maupun autosave di evidence ini.
- Cluster hanya **1 server + 1 agent** pada satu laptop. Hasil ini **bukan bukti high availability**. Penggantian satu pod hanya membuktikan self-healing tingkat pod.
- Kontinuitas layanan selama penghapusan pod hanya dapat diklaim sejauh panel tambahan_2 menunjukkannya. Panel pertama saat itu tidak valid karena ingress belum siap.
- Versi kubectl client (v1.37.2) berbeda dua minor dari server (v1.35.5), di luar rentang dukungan resmi (+/-1). Tidak menimbulkan masalah pada perintah yang dipakai, tetapi perlu dicatat.
- Pada pengambilan sebelumnya (di luar evidence ini) tag `v0.1.0` yang sama sempat menghasilkan digest berbeda karena attestation BuildKit. Ini menunjukkan tag yang mutable tidak cukup sebagai bukti immutability. Pipeline CI (M4) akan memakai tag berbasis SHA Git.
- Evidence berupa screenshot terminal. Nilai pembuktian bertambah karena disertai `Dockerfile`, manifest, dan skrip yang dapat dijalankan ulang.

## 6. Keputusan yang didukung

- Mempertahankan Kubernetes (k3d/k3s) dengan aplikasi stateless dan beberapa replika (ADR-004).
- Menetapkan readiness/liveness probe dan resources sebagai bagian wajib manifest.
- Meneruskan ke M4: image bertag SHA Git dan manifest dikelola lewat repositori GitOps.
