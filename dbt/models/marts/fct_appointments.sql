-- Grain: 1 dòng = 1 lịch hẹn (appointment).
with appointments as (
    select * from {{ ref('stg_appointments') }}
)

select
    appointment_id,
    patient_id,
    doctor_id,
    appointment_date            as date_key,
    appointment_time,
    reason_for_visit,
    status,
    iff(status = 'Completed', 1, 0)  as is_completed,
    iff(status = 'No-show', 1, 0)    as is_no_show,
    iff(status = 'Cancelled', 1, 0)  as is_cancelled,
    1                                as appointment_count
from appointments
