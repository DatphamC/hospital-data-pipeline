# 📘 Hướng dẫn theo dòng chảy dữ liệu (Data Pipeline Flow)

Tài liệu này đi **theo đúng đường đi của dữ liệu**, từ file CSV cho tới dashboard.
Mỗi chặng giải thích: *làm gì → file nào lo → gõ lệnh gì → kiểm tra ra sao → lỗi hay gặp*.
Mục tiêu: bạn vừa làm vừa hiểu, không chỉ copy.

```
 [data/*.csv]
      │  (1) Python đọc CSV, đẩy lên Snowflake
      ▼
 HOSPITAL.RAW.*           ← dữ liệu thô, y nguyên
      │  (2) dbt staging: làm sạch, ép kiểu
      ▼
 HOSPITAL.STAGING.stg_*   ← sạch, chuẩn hóa (view)
      │  (3) dbt marts: dựng star schema
      ▼
 HOSPITAL.ANALYTICS.dim_* / fct_*   ← sẵn sàng cho BI (table)
      │  (4) Power BI đọc
      ▼
 Dashboard KPI
```

> ⚙️ Chuẩn bị 1 lần trước khi bắt đầu (xem [README](../README.md) mục 1-2):
> cài [uv](https://docs.astral.sh/uv/) → `uv sync` (tạo `.venv` + cài dependencies),
> đăng ký Snowflake, chạy `setup/snowflake_setup.sql`, tạo `.env` và `dbt/profiles.yml` từ file mẫu.
>
> 💡 Trong tài liệu này, mọi lệnh `python`/`dbt` đều chạy qua **`uv run`** để dùng đúng
> môi trường dự án mà **không cần `source .venv/bin/activate`**.

---

## Chặng 0 — Điểm xuất phát: dữ liệu nguồn

📁 **File:** `data/patients.csv`, `doctors.csv`, `appointments.csv`, `treatments.csv`, `billing.csv`

Đây là dữ liệu "đầu vào" — giả lập việc export từ hệ thống ERP/Excel của bệnh viện.
5 bảng có quan hệ với nhau:

- `patients` (bệnh nhân) ──< `appointments` (lịch hẹn) >── `doctors` (bác sĩ)
- `appointments` ──< `treatments` (điều trị)
- `treatments` ──< `billing` (hóa đơn)

👉 **Việc cần làm:** chỉ cần xem qua cho quen.
```bash
head -3 data/patients.csv
```
**Kỳ vọng:** thấy dòng tiêu đề (`patient_id,first_name,...`) + vài dòng dữ liệu.

---

## Chặng 1 — CSV ➜ RAW (Python ingestion)

🎯 **Mục tiêu:** Đưa nguyên văn dữ liệu CSV lên Snowflake, **chưa biến đổi gì**.
Đây là tầng "bản sao an toàn" của dữ liệu gốc.

📁 **File phụ trách:**
- `ingestion/config.py` — đọc thông tin kết nối Snowflake từ `.env` (không hard-code mật khẩu).
- `ingestion/load_to_raw.py` — đọc từng CSV bằng `pandas`, rồi dùng
  `write_pandas()` của thư viện Snowflake để tạo bảng và nạp dữ liệu vào schema `RAW`.

**Cách hoạt động (đọc lướt `load_to_raw.py`):**
1. `pd.read_csv(..., dtype=str)` — đọc **mọi cột dạng text** để giữ đúng dữ liệu thô.
2. Thêm 2 cột metadata: `_LOADED_AT` (thời điểm nạp) và `_SOURCE_FILE` (nguồn).
3. `write_pandas(..., auto_create_table=True, overwrite=True)` — tự tạo bảng,
   và **ghi đè toàn bộ** mỗi lần chạy (full-refresh — đơn giản, hợp dữ liệu nhỏ).

▶️ **Lệnh chạy:**
```bash
uv run python ingestion/load_to_raw.py
```
**Kỳ vọng (terminal):**
```
Kết nối Snowflake...
  ✓ patients.csv -> RAW.RAW_PATIENTS (50 dòng)
  ✓ doctors.csv -> RAW.RAW_DOCTORS (10 dòng)
  ... (5 bảng)
Hoàn tất nạp dữ liệu vào RAW.
```
🔍 **Kiểm tra trong Snowsight:**
```sql
USE ROLE DBT_ROLE; USE WAREHOUSE HOSPITAL_WH;
SELECT * FROM HOSPITAL.RAW.RAW_PATIENTS LIMIT 5;
```

⚠️ **Lỗi hay gặp:**
- `Thiếu biến môi trường ...` → bạn chưa tạo/điền `.env`. Copy từ `.env.example`.
- `250001 Could not connect` → sai `SNOWFLAKE_ACCOUNT`. Phải dạng `ORG-ACCOUNT`.
- `Insufficient privileges` → chưa chạy `setup/snowflake_setup.sql` hoặc chưa `GRANT ROLE`.

---

## Chặng 2 — RAW ➜ STAGING (dbt làm sạch)

🎯 **Mục tiêu:** Làm sạch dữ liệu thô: ép kiểu (text → date/number), chuẩn hóa
chữ hoa/thường, bỏ khoảng trắng, **khử trùng lặp**. Đầu ra là các **view** (nhẹ, luôn tươi).

📁 **File phụ trách:**
- `dbt/models/staging/_sources.yml` — khai báo 5 bảng RAW là "nguồn" để dbt biết.
- `dbt/models/staging/stg_*.sql` — mỗi file làm sạch 1 bảng. Ví dụ `stg_patients.sql`:
  - `try_to_date(date_of_birth)` — ép text sang ngày (lỗi format → NULL, không vỡ).
  - `initcap(first_name)`, `lower(email)` — chuẩn hóa.
  - `qualify row_number() over (partition by patient_id order by _loaded_at desc) = 1`
    — nếu 1 bệnh nhân xuất hiện nhiều lần, **giữ bản mới nhất**.
- `dbt/models/staging/_staging.yml` — khai báo **tests** (unique, not_null, relationships).

**Khái niệm dbt cần nắm:**
- `{{ source('raw', 'raw_patients') }}` → trỏ tới bảng đã khai báo trong `_sources.yml`.
- `materialized = view` (đặt ở `dbt_project.yml`) → dbt tạo VIEW cho tầng staging.

▶️ **Lệnh chạy (chỉ tầng staging trước cho dễ quan sát):**
```bash
uv run dbt run  --project-dir dbt --profiles-dir dbt --select staging
uv run dbt test --project-dir dbt --profiles-dir dbt --select staging
```
**Kỳ vọng:** mỗi model in `OK created ... VIEW`; các test `PASS`.

🔍 **Kiểm tra trong Snowsight:**
```sql
SELECT * FROM HOSPITAL.STAGING.STG_PATIENTS LIMIT 5;   -- date_of_birth giờ là kiểu DATE
```

⚠️ **Lỗi hay gặp:**
- `Database Error ... does not exist` cho RAW → bạn chưa chạy xong Chặng 1.
- Test `not_null`/`unique` fail → dữ liệu nguồn có khóa trùng/thiếu; xem lại CSV.

---

## Chặng 3 — STAGING ➜ ANALYTICS (dbt dựng star schema)

🎯 **Mục tiêu:** Biến dữ liệu sạch thành **mô hình sao (star schema)** — chuẩn thiết kế
cho BI: các bảng *dimension* (chiều mô tả) vây quanh các bảng *fact* (sự kiện đo lường).

📁 **File phụ trách (`dbt/models/marts/`):**
| File | Loại | Vai trò |
|------|------|---------|
| `dim_patient.sql` | dimension | thông tin bệnh nhân (+ tính `age` từ ngày sinh) |
| `dim_doctor.sql` | dimension | thông tin bác sĩ |
| `dim_date.sql` | dimension | bảng lịch (year/quarter/month/weekend...) sinh tự động |
| `fct_appointments.sql` | fact | mỗi dòng = 1 lịch hẹn (+ cờ no-show/cancelled) |
| `fct_treatments.sql` | fact | mỗi dòng = 1 lần điều trị (+ chi phí) |
| `fct_billing.sql` | fact | mỗi dòng = 1 hóa đơn (+ số tiền theo trạng thái) |

**Khái niệm dbt cần nắm:**
- `{{ ref('stg_patients') }}` → trỏ tới model staging khác. dbt **tự sắp thứ tự chạy**
  dựa trên các `ref` này (gọi là *lineage / DAG*).
- `materialized = table` (cho marts) → tạo TABLE thật (BI query nhanh hơn view).
- `fct_treatments` join sang `stg_appointments` để lấy `patient_id`, `doctor_id`
  → ví dụ điển hình của "khóa ngoại" trong fact.

▶️ **Lệnh chạy:**
```bash
uv run dbt run  --project-dir dbt --profiles-dir dbt --select marts
uv run dbt test --project-dir dbt --profiles-dir dbt          # chạy hết test cho chắc
```
**Kỳ vọng:** 6 model tạo dạng `TABLE`; toàn bộ test `PASS`.

🔍 **Kiểm tra trong Snowsight:**
```sql
-- Doanh thu theo loại điều trị
SELECT treatment_type, SUM(cost) AS revenue
FROM HOSPITAL.ANALYTICS.FCT_TREATMENTS
GROUP BY 1 ORDER BY 2 DESC;
```

📊 **Xem sơ đồ quan hệ (lineage) — rất đẹp để bỏ vào CV:**
```bash
uv run dbt docs generate --project-dir dbt --profiles-dir dbt
uv run dbt docs serve    --project-dir dbt --profiles-dir dbt   # mở http://localhost:8080
```

---

## Chặng 4 — ANALYTICS ➜ Power BI (trực quan hóa)

🎯 **Mục tiêu:** Vẽ dashboard KPI từ các bảng `dim_*` / `fct_*`.

▶️ **Các bước trong Power BI Desktop:**
1. **Home → Get Data → Snowflake.**
2. Nhập **Server** = account identifier dạng `org-account.snowflakecomputing.com`,
   **Warehouse** = `HOSPITAL_WH`.
3. Chọn database `HOSPITAL` → schema `ANALYTICS` → tick các bảng `DIM_*`, `FCT_*`.
4. Chọn chế độ **Import** (đơn giản) → Load.
5. Sang tab **Model**: nối quan hệ (kéo khóa):
   - `FCT_APPOINTMENTS[patient_id]` → `DIM_PATIENT[patient_id]`
   - `FCT_APPOINTMENTS[doctor_id]` → `DIM_DOCTOR[doctor_id]`
   - `FCT_*[date_key]` → `DIM_DATE[date_key]`
   - `FCT_BILLING[treatment_id]` → `FCT_TREATMENTS[treatment_id]` (hoặc qua dim)
6. **Report:** kéo thả tạo biểu đồ.

📊 **KPI gợi ý:**
- Card: tổng lượt hẹn, tổng doanh thu, tỷ lệ no-show.
- Cột theo thời gian: lượt khám / doanh thu theo tháng (dùng `DIM_DATE`).
- Bar: doanh thu theo bác sĩ / theo loại điều trị.
- Donut: trạng thái thanh toán (Paid/Pending/Failed), giới tính bệnh nhân.

💾 Lưu file vào `dashboard/hospital_dashboard.pbix`. Để show CV miễn phí:
**File → Export → PDF**, hoặc Publish to web (cần tài khoản Power BI free).

---

## Chặng 5 — Tự động hóa & chạy lại (orchestration)

Sau khi từng chặng đã chạy tay OK, gộp lại 1 lệnh:
```bash
./run_pipeline.sh          # = load_to_raw.py  +  dbt run  +  dbt test
```
Lên lịch chạy hằng ngày bằng cron (mở bằng `crontab -e`):
```cron
0 6 * * * cd /path/to/hospital-data-pipeline && ./run_pipeline.sh >> logs/pipeline.log 2>&1
```
→ Mỗi 6h sáng pipeline tự refresh; Power BI chỉ cần **Refresh** là có số mới.

---

## 🧭 Thứ tự học đề xuất
1. Chặng 0–1: hiểu dữ liệu + đẩy lên RAW (Python).
2. Chặng 2: chạy riêng staging, so sánh RAW vs STAGING để thấy "làm sạch".
3. Chặng 3: dựng star schema, mở `dbt docs serve` xem lineage.
4. Chặng 4: nối Power BI, vẽ 2-3 biểu đồ đầu tiên.
5. Chặng 5: gộp `run_pipeline.sh` + cron.

Mỗi khi kẹt, đọc lại mục **⚠️ Lỗi hay gặp** ở chặng tương ứng.
