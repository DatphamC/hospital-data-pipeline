with source as (
    select * from {{ source('raw', 'raw_appointments') }}
)

select
    trim(appointment_id)                      as appointment_id,
    trim(patient_id)                          as patient_id,
    trim(doctor_id)                           as doctor_id,
    try_to_date(appointment_date)             as appointment_date,
    try_to_time(appointment_time)             as appointment_time,
    trim(reason_for_visit)                    as reason_for_visit,
    trim(status)                              as status
from source
where appointment_id is not null
qualify row_number() over (
    partition by appointment_id order by _loaded_at desc
) = 1
