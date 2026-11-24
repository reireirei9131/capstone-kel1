# Jalankan dari folder 03-application-data (PowerShell). Butuh container capstone-postgres jalan.
docker run --rm --network capstone-net -v "${PWD}\db\migration:/flyway/sql" flyway/flyway:10 `
  -url=jdbc:postgresql://capstone-postgres:5432/capstone -user=capstone -password=capstone migrate
docker run --rm --network capstone-net -v "${PWD}\db\migration:/flyway/sql" flyway/flyway:10 `
  -url=jdbc:postgresql://capstone-postgres:5432/capstone -user=capstone -password=capstone info
