#!/usr/bin/env bash
# Cria o banco de TESTE (GIE_TEST) a partir dos mesmos scripts de produção e roda 99_testes.sql.
# Uso:  ./rodar_testes.sh [usuario_mysql]      (pede a senha se o usuário tiver)
set -euo pipefail
cd "$(dirname "$0")"
U="${1:-root}"
M="mysql -u$U --default-character-set=utf8mb4"

$M -e "DROP DATABASE IF EXISTS GIE_TEST"
for f in 01_schema.sql 02_views.sql 03_procedures.sql 04_seed_demo.sql; do
  sed 's/GIE_DATA/GIE_TEST/g' "$f" | $M > /dev/null
done
$M -t < 99_testes.sql
