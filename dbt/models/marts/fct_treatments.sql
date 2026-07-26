-- Grain: 1 dòng = 1 lần điều trị (treatment).
-- Lấy patient_id, doctor_id qua appointment để tiện phân tích theo bệnh nhân/bác sĩ.
with treatments as (
    select * from {{ ref('stg_treatments') }}
),

appointments as (
    select appointment_id, patient_id, doctor_id
    from {{ ref('stg_appointments') }}
)

select
    t.treatment_id,
    t.appointment_id,
    a.patient_id,
    a.doctor_id,
    t.treatment_date            as date_key,
    t.treatment_type,
    t.description,
    t.cost
from treatments t
left join appointments a
    on t.appointment_id = a.appointment_id
