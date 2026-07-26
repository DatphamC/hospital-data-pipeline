with patients as (
    select * from {{ ref('stg_patients') }}
)

select
    patient_id,
    first_name,
    last_name,
    first_name || ' ' || last_name              as full_name,
    gender,
    date_of_birth,
    datediff('year', date_of_birth, current_date()) as age,
    address,
    contact_number,
    email,
    insurance_provider,
    insurance_number,
    registration_date
from patients
