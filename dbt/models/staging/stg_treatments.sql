with source as (
    select * from {{ source('raw', 'raw_treatments') }}
)

select
    trim(treatment_id)                        as treatment_id,
    trim(appointment_id)                      as appointment_id,
    trim(treatment_type)                      as treatment_type,
    trim(description)                         as description,
    try_to_decimal(cost, 12, 2)               as cost,
    try_to_date(treatment_date)               as treatment_date
from source
where treatment_id is not null
qualify row_number() over (
    partition by treatment_id order by _loaded_at desc
) = 1
