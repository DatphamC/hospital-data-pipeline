-- Date dimension dựng từ khoảng thời gian thực tế trong dữ liệu.
with bounds as (
    select min(d) as min_date, max(d) as max_date
    from (
        select appointment_date as d from {{ ref('stg_appointments') }}
        union all select treatment_date   from {{ ref('stg_treatments') }}
        union all select bill_date         from {{ ref('stg_billing') }}
        union all select registration_date from {{ ref('stg_patients') }}
    )
    where d is not null
),

spine as (
    select date_day
    from (
        select dateadd(day, seq4(), (select min_date from bounds)) as date_day
        from table(generator(rowcount => 5000))
    )
    where date_day <= (select max_date from bounds)
)

select
    date_day                                as date_key,
    year(date_day)                          as year,
    quarter(date_day)                       as quarter,
    month(date_day)                         as month,
    monthname(date_day)                     as month_name,
    day(date_day)                           as day_of_month,
    dayofweek(date_day)                     as day_of_week,
    dayname(date_day)                       as day_name,
    weekofyear(date_day)                    as week_of_year,
    iff(dayofweek(date_day) in (0, 6), true, false) as is_weekend
from spine
