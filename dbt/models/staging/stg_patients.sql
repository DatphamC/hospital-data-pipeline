with source as (
    select * from {{ source('raw', 'raw_patients') }}
)

select
    trim(patient_id)                          as patient_id,
    initcap(trim(first_name))                 as first_name,
    initcap(trim(last_name))                  as last_name,
    upper(trim(gender))                       as gender,
    try_to_date(date_of_birth)                as date_of_birth,
    trim(contact_number)                      as contact_number,
    trim(address)                             as address,
    try_to_date(registration_date)            as registration_date,
    trim(insurance_provider)                  as insurance_provider,
    trim(insurance_number)                    as insurance_number,
    lower(trim(email))                        as email
from source
where patient_id is not null
qualify row_number() over (
    partition by patient_id order by _loaded_at desc
) = 1
