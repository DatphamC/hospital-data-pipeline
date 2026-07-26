-- =====================================================================
-- Hospital Data Pipeline — Snowflake setup (chạy 1 lần)
-- Mở Snowsight -> Projects -> Worksheets -> dán file này -> Run All.
-- Phải chạy bằng role ACCOUNTADMIN.
-- Giá trị ở đây khớp với .env.example / dbt profiles.
-- =====================================================================

USE ROLE ACCOUNTADMIN;

-- 1) Warehouse (compute): nhỏ nhất + tự tắt sau 60s để tiết kiệm credit
CREATE WAREHOUSE IF NOT EXISTS HOSPITAL_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse cho hospital data pipeline';

-- 2) Database + 3 tầng schema (Medallion: RAW -> STAGING -> ANALYTICS)
CREATE DATABASE IF NOT EXISTS HOSPITAL;
CREATE SCHEMA IF NOT EXISTS HOSPITAL.RAW;        -- dữ liệu thô từ CSV
CREATE SCHEMA IF NOT EXISTS HOSPITAL.STAGING;    -- dbt: làm sạch
CREATE SCHEMA IF NOT EXISTS HOSPITAL.ANALYTICS;  -- dbt: star schema cho BI

-- 3) Role riêng cho pipeline (ingestion + dbt)
CREATE ROLE IF NOT EXISTS DBT_ROLE;

-- 4) Cấp quyền cho role
GRANT USAGE, OPERATE ON WAREHOUSE HOSPITAL_WH TO ROLE DBT_ROLE;

GRANT ALL ON DATABASE HOSPITAL                        TO ROLE DBT_ROLE;
GRANT ALL ON ALL SCHEMAS    IN DATABASE HOSPITAL      TO ROLE DBT_ROLE;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE HOSPITAL      TO ROLE DBT_ROLE;
GRANT ALL ON ALL TABLES     IN DATABASE HOSPITAL      TO ROLE DBT_ROLE;
GRANT ALL ON FUTURE TABLES  IN DATABASE HOSPITAL      TO ROLE DBT_ROLE;
GRANT ALL ON ALL VIEWS      IN DATABASE HOSPITAL      TO ROLE DBT_ROLE;
GRANT ALL ON FUTURE VIEWS   IN DATABASE HOSPITAL      TO ROLE DBT_ROLE;

-- 5) Gán role cho chính tài khoản đăng nhập của bạn
SET my_user = CURRENT_USER();
GRANT ROLE DBT_ROLE TO USER IDENTIFIER($my_user);

-- 6) Kiểm tra nhanh
USE ROLE DBT_ROLE;
USE WAREHOUSE HOSPITAL_WH;
SHOW SCHEMAS IN DATABASE HOSPITAL;   -- kỳ vọng: RAW, STAGING, ANALYTICS (+ INFORMATION_SCHEMA, PUBLIC)
