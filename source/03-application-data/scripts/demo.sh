#!/usr/bin/env bash
# Demo alur ujian + tes negatif. Jalankan di Ubuntu/WSL setelah API hidup (node server.js).
# Butuh: curl, jq. Password demo = username (realm kelas).
KC=http://127.0.0.1:8081/realms/capstone/protocol/openid-connect/token
API=http://127.0.0.1:3000
tok() { curl -s -X POST $KC -d client_id=capstone-app -d grant_type=password \
        -d username=$1 -d password=${2:-$1} | jq -r .access_token; }
call() { # method path token [json]
  curl -s -X $1 $API$2 -H "Authorization: Bearer $3" -H 'Content-Type: application/json' ${4:+-d "$4"}; }
say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

UA=$(tok usera); UB=$(tok userb); OP=$(tok operator)
AU=$(tok auditor); [ "$AU" = "null" ] && echo "(auditor belum bisa login: cek user/role/email-nama di Keycloak)"

say "1. Mulai ujian (usera, tenant-a)"
A=$(call POST /exams/1/start $UA); echo "$A" | jq; AID=$(echo "$A" | jq -r .id)
say "2. Autosave jawaban"
call PUT /attempts/$AID/answers $UA '{"question_id":1,"chosen_option":"A"}' | jq
call PUT /attempts/$AID/answers $UA '{"question_id":2,"chosen_option":"B"}' | jq
say "2b. Autosave ulang (upsert, ganti jawaban soal 2)"
call PUT /attempts/$AID/answers $UA '{"question_id":2,"chosen_option":"C"}' | jq
call PUT /attempts/$AID/answers $UA '{"question_id":2,"chosen_option":"B"}' | jq -c '{question_id,chosen_option}'
say "3. Submit -> skor"
call POST /attempts/$AID/submit $UA | jq
say "4. Laporan oleh operator (tenant-a)"
call GET /reports $OP | jq

say "5. Tenant-b: userb mengerjakan ujian 2"
B=$(call POST /exams/2/start $UB); echo "$B" | jq; BID=$(echo "$B" | jq -r .id)
call PUT /attempts/$BID/answers $UB '{"question_id":3,"chosen_option":"A"}' | jq -c .
call PUT /attempts/$BID/answers $UB '{"question_id":4,"chosen_option":"C"}' | jq -c .
call POST /attempts/$BID/submit $UB | jq
say "5b. Laporan auditor (tenant-b) - hanya data tenant-b"
call GET /reports $AU | jq

say "NEGATIF 1: userb mulai ujian milik tenant-a (harus 404)"
call POST /exams/1/start $UB | jq -c .
say "NEGATIF 2: userb mengubah attempt milik usera (harus 404)"
call PUT /attempts/$AID/answers $UB '{"question_id":1,"chosen_option":"B"}' | jq -c .
say "NEGATIF 3: usera mengakses laporan (role user, harus 403)"
call GET /reports $UA | jq -c .
say "NEGATIF 4: auditor mencoba memulai ujian (harus 403)"
call POST /exams/2/start $AU | jq -c .
say "NEGATIF 5: tanpa token (harus 401)"
call GET /reports "" | jq -c .
say "NEGATIF 6: submit dua kali (harus 404)"
call POST /attempts/$AID/submit $UA | jq -c .
