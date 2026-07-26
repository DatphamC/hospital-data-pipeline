-- Grain: 1 dòng = 1 hóa đơn (bill).
with billing as (
    select * from {{ ref('stg_billing') }}
)

select
    bill_id,
    patient_id,
    treatment_id,
    bill_date                   as date_key,
    amount,
    payment_method,
    payment_status,
    iff(payment_status = 'Paid', amount, 0)     as amount_paid,
    iff(payment_status = 'Pending', amount, 0)  as amount_pending,
    iff(payment_status = 'Failed', amount, 0)   as amount_failed
from billing
