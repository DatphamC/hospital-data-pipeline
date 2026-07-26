"""Nạp các file CSV trong data/ vào tầng RAW của Snowflake.

Mỗi CSV -> 1 bảng RAW.RAW_<TÊN>. Toàn bộ cột đọc dạng text (raw, không ép kiểu)
để giữ đúng tinh thần tầng RAW; việc làm sạch/ép kiểu để dbt lo ở tầng STAGING.
Thêm 2 cột metadata: _LOADED_AT, _SOURCE_FILE.
"""
import sys
from datetime import datetime, timezone

import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas

from config import DATA_DIR, SNOWFLAKE_CONFIG

# Tên file CSV (không đuôi) -> tên bảng RAW
TABLES = {
    "patients": "RAW_PATIENTS",
    "doctors": "RAW_DOCTORS",
    "appointments": "RAW_APPOINTMENTS",
    "treatments": "RAW_TREATMENTS",
    "billing": "RAW_BILLING",
}


def load_csv(conn, csv_name: str, table_name: str) -> int:
    csv_path = DATA_DIR / f"{csv_name}.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Không tìm thấy {csv_path}")

    # Đọc tất cả cột dạng string để bảo toàn dữ liệu thô
    df = pd.read_csv(csv_path, dtype=str)
    df.columns = [c.upper() for c in df.columns]
    df["_LOADED_AT"] = datetime.now(timezone.utc).isoformat()
    df["_SOURCE_FILE"] = f"{csv_name}.csv"

    write_pandas(
        conn,
        df,
        table_name=table_name,
        auto_create_table=True,
        overwrite=True,  # full refresh: thay toàn bộ bảng mỗi lần chạy
        quote_identifiers=False,
    )
    return len(df)


def main() -> None:
    print("Kết nối Snowflake...")
    conn = snowflake.connector.connect(**SNOWFLAKE_CONFIG)
    try:
        for csv_name, table_name in TABLES.items():
            rows = load_csv(conn, csv_name, table_name)
            print(f"  ✓ {csv_name}.csv -> {SNOWFLAKE_CONFIG['schema']}.{table_name} ({rows} dòng)")
        print("Hoàn tất nạp dữ liệu vào RAW.")
    finally:
        conn.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"LỖI: {exc}", file=sys.stderr)
        sys.exit(1)
