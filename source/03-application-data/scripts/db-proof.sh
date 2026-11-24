#!/usr/bin/env bash
# Tidak perlu psql di host: pakai psql di dalam container.
docker exec -i capstone-postgres psql -U capstone -d capstone < "$(dirname "$0")/db-proof.sql"
