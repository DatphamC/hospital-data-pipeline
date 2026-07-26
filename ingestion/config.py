"""Đọc cấu hình Snowflake từ biến môi trường (.env)."""
import os
from pathlib import Path

from dotenv import load_dotenv

# Nạp .env ở thư mục gốc dự án
PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")

DATA_DIR = PROJECT_ROOT / "data"


def _require(key: str) -> str:
    value = os.getenv(key)
    if not value:
        raise RuntimeError(f"Thiếu biến môi trường {key}. Hãy tạo .env từ .env.example.")
    return value


SNOWFLAKE_CONFIG = {
    "account": _require("SNOWFLAKE_ACCOUNT"),
    "user": _require("SNOWFLAKE_USER"),
    "password": _require("SNOWFLAKE_PASSWORD"),
    "role": os.getenv("SNOWFLAKE_ROLE", "DBT_ROLE"),
    "warehouse": os.getenv("SNOWFLAKE_WAREHOUSE", "HOSPITAL_WH"),
    "database": os.getenv("SNOWFLAKE_DATABASE", "HOSPITAL"),
    "schema": os.getenv("SNOWFLAKE_RAW_SCHEMA", "RAW"),
}
