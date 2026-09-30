-- RFM-сегментация на дату анализа 2026-07-01
-- R — дней с последней покупки, F — число заказов, M — сумма покупок.
-- Каждая метрика делится на 3 группы по квантилям (NTILE), 3 = лучше.
WITH base AS (
    SELECT
        customer_id,
        CAST(julianday('2026-07-01') - julianday(MAX(order_date)) AS INT) AS recency,
        COUNT(*)                                                         AS frequency,
        SUM(amount)                                                      AS monetary
    FROM orders
    WHERE status = 'delivered'
    GROUP BY customer_id
),
scored AS (
    SELECT *,
        NTILE(3) OVER (ORDER BY recency DESC)  AS r,
        CASE WHEN frequency = 1 THEN 1
             WHEN frequency <= 3 THEN 2
             ELSE 3 END                         AS f,   -- F по порогам: у большинства 1 заказ
        NTILE(3) OVER (ORDER BY monetary)       AS m
    FROM base
)
SELECT
    customer_id, recency, frequency, ROUND(monetary) AS monetary, r, f, m,
    r || f || m AS rfm,
    CASE
        WHEN r = 3 AND f = 3                THEN 'Чемпионы'
        WHEN r >= 2 AND f >= 2              THEN 'Лояльные'
        WHEN r = 3 AND f = 1                THEN 'Новички'
        WHEN r = 1 AND f >= 2               THEN 'Под угрозой ухода'
        WHEN r = 2 AND f = 1                THEN 'Засыпающие'
        ELSE 'Потерянные'
    END AS segment
FROM scored;
