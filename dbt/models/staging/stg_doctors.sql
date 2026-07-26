with source as (
    select * from {{ source('raw', 'raw_doctors') }}
)

select
    trim(doctor_id)                           as doctor_id,
    initcap(trim(first_name))                 as first_name,
    initcap(trim(last_name))                  as last_name,
    trim(specialization)                      as specialization,
    trim(phone_number)                        as phone_number,
    try_to_number(years_experience)           as years_experience,
    trim(hospital_branch)                     as hospital_branch,
    lower(trim(email))                        as email
from source
where doctor_id is not null
qualify row_number() over (
    partition by doctor_id order by _loaded_at desc
) = 1
