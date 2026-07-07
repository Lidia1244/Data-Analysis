-- 6. RETENTION КЛИЕНТОВ ПО КОГОРТАМ

with ftr as (select 
    ft.client_id,
    date_trunc('month', min(transaction_dt))::date as first_month  -- зафиксировали первую транзакцию клиента
from dds.fact_transactions ft
group by ft.client_id),
all_cl as (select 
    distinct ft.client_id,
    date_trunc('month', transaction_dt)::date as last_month
from dds.fact_transactions ft
where status = 'success'),
-- количество клиентов в разрезе когорты
c_cl as (select 
  count(ftr.client_id) as count_cl,
  all_cl.last_month,
  ftr.first_month,
  EXTRACT(MONTH FROM AGE(all_cl.last_month, ftr.first_month))::INT +
        EXTRACT(YEAR FROM AGE(all_cl.last_month, ftr.first_month) )::INT * 12  AS period_number
from ftr
join all_cl on ftr.client_id = all_cl.client_id
where all_cl.last_month > ftr.first_month
group by all_cl.last_month,ftr.first_month),
--размер когорты
c_size as (select
    count(distinct ftr.client_id) as cohort_size,
    ftr.first_month
from ftr
group by ftr.first_month)
select
    c_cl.first_month,
    c_cl.last_month,
    c_cl.count_cl,
    c_cl.period_number,
    c_size.cohort_size,
    round(c_cl.count_cl * 100 / c_size.cohort_size, 2) as retention
from c_cl
join c_size on c_cl.first_month = c_size.first_month




        

    