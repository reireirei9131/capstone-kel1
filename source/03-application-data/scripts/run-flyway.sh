#!/usr/bin/env bash
# Jalankan dari folder 03-application-data (Ubuntu/WSL/Arch).
for cmd in migrate info; do
docker run --rm --network capstone-net -v "$(pwd)/db/migration:/flyway/sql" flyway/flyway:10 \
  -url=jdbc:postgresql://capstone-postgres:5432/capstone -user=capstone -password=capstone $cmd
done
