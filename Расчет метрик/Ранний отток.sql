-- 9. КЛИЕНТЫ БЕЗ ТРАНЗАКЦИЙ (РАННИЙ СИГНАЛ ОТТОКА)
-- клиенты у которых была активность
-- но за последние 30/60/90 дней транзакций нет

with l_tr as (select 
    ft.client_id,
    max(ft.transaction_dt) as last_day,
    '2024-07-02' - max(ft.transaction_dt) as count_d
from dds.fact_transactions ft
group by ft.client_id)
select  
    ft.client_id,
    l_tr.last_day,
    case when l_tr.count_d <= 30 then '30d'
         when l_tr.count_d between 30 and 60 then '60d'
         when l_tr.count_d between 60 and 90 then '90d'
         else '90+'
    end
from dds.fact_transactions ft
join l_tr on ft.client_id = l_tr.client_id;