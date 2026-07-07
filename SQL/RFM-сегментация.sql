-- RFM-сегментация клиентов: 
-- Recency (давность последней транзакции), 
-- Frequency (количество транзакций) 
-- Monetary (сумма) — базовый инструмент для сегментации клиентской базы

WITH rfm_raw AS (
    SELECT
        c.client_id,
        c.full_name,
        COUNT(t.transaction_id)                                    AS frequency,
        SUM(t.amount)                                              AS monetary,
        MAX(t.transaction_dttm::DATE)                              AS last_tx_dt,
        CURRENT_DATE - MAX(t.transaction_dttm::DATE)               AS recency_days
    FROM dds.fact_transactions t
    JOIN dds.dim_clients c ON c.client_id = t.client_id
    WHERE t.status      = 'success'
      AND t.is_deleted  = FALSE
      AND c.is_deleted  = FALSE
    GROUP BY c.client_id, c.full_name
),
rfm_scores AS (
    SELECT
        client_id,
        full_name,
        recency_days,
        frequency,
        monetary,
        -- R: чем меньше дней — тем лучше (5 лучший)
        NTILE(5) OVER (ORDER BY recency_days  DESC) AS r_score,
        -- F: чем больше транзакций — тем лучше
        NTILE(5) OVER (ORDER BY frequency ASC)  AS f_score,
        -- M: чем больше сумма — тем лучше
        NTILE(5) OVER (ORDER BY monetary ASC)  AS m_score
    FROM rfm_raw
),
rfm_final AS (
    SELECT
        client_id,
        full_name,
        recency_days,
        frequency,
        ROUND(monetary, 2)                         AS monetary,
        r_score,
        f_score,
        m_score,
        (r_score + f_score + m_score)              AS rfm_total,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Чемпионы'
            WHEN r_score >= 3 AND f_score >= 3                   THEN 'Лояльные'
            WHEN r_score >= 4 AND f_score <= 2                   THEN 'Новые'
            WHEN r_score <= 2 AND f_score >= 3                   THEN 'Под риском оттока'
            WHEN r_score <= 2 AND f_score <= 2                   THEN 'Спящие'
            ELSE 'Потенциально лояльные'
        END                                        AS rfm_segment
    FROM rfm_scores
)
SELECT
    rfm_segment,
    COUNT(client_id)            AS clients_cnt,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency),    1) AS avg_frequency,
    ROUND(AVG(monetary),     2) AS avg_monetary,
    ROUND(SUM(monetary),     2) AS total_monetary
FROM rfm_final
GROUP BY rfm_segment
ORDER BY total_monetary DESC;