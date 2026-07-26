#!/usr/bin/env bash
# Chạy toàn bộ pipeline: ingest CSV -> RAW, rồi dbt transform + test.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Nạp biến môi trường để cả Python lẫn dbt dùng chung
if [ -f .env ]; then
    set -a; source .env; set +a
fi

echo "==> [1/3] Ingestion: CSV -> Snowflake RAW"
uv run python ingestion/load_to_raw.py

echo "==> [2/3] dbt run: RAW -> STAGING -> ANALYTICS"
uv run dbt run --project-dir dbt --profiles-dir dbt

echo "==> [3/3] dbt test"
uv run dbt test --project-dir dbt --profiles-dir dbt

echo "==> Pipeline hoàn tất."
