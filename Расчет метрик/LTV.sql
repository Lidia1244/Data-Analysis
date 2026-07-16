-- 7. LTV КЛИЕНТА
-- накопленная сумма транзакций за весь период по сегментам карт
with tr_pr as (select 
    c.card_product_id,
    cp.product_name,
    count(ft.client_id) as all_client,
    sum(amount) as sum_transaction
from dds.fact_transactions ft
join dds.dim_cards c
on ft.client_id = c.client_id
join dds.dict_card_products cp
on c.card_product_id = cp.card_product_id
group by c.card_product_id,cp.product_name)
select 
    tr_pr.product_name,
    tr_pr.all_client,
    tr_pr.sum_transaction,
    round (tr_pr.sum_transaction / tr_pr.all_client, 2) as LTV
from tr_pr
order by LTV desc;
