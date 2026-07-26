with source as (
    select * from {{ source('raw', 'raw_billing') }}
)

select
    trim(bill_id)                             as bill_id,
    trim(patient_id)                          as patient_id,
    trim(treatment_id)                        as treatment_id,
    try_to_date(bill_date)                    as bill_date,
    try_to_decimal(amount, 12, 2)             as amount,
    trim(payment_method)                      as payment_method,
    trim(payment_status)                      as payment_status
from source
where bill_id is not null
qualify row_number() over (
    partition by bill_id order by _loaded_at desc
) = 1
