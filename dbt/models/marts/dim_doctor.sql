with doctors as (
    select * from {{ ref('stg_doctors') }}
)

select
    doctor_id,
    first_name,
    last_name,
    first_name || ' ' || last_name      as full_name,
    specialization,
    hospital_branch,
    years_experience,
    phone_number,
    email
from doctors
