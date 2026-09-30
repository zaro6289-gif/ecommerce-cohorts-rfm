-- Когортный анализ: доля клиентов когорты (месяц первой покупки),
-- совершивших покупку через N месяцев после первой
WITH first_purchase AS (
    SELECT customer_id,
           MIN(order_date) AS first_date
    FROM orders
    WHERE status = 'delivered'
    GROUP BY customer_id
),
activity AS (
    SELECT DISTINCT
        f.customer_id,
        strftime('%Y-%m', f.first_date) AS cohort,
        (CAST(strftime('%Y', o.order_date) AS INT) - CAST(strftime('%Y', f.first_date) AS INT)) * 12
      + (CAST(strftime('%m', o.order_date) AS INT) - CAST(strftime('%m', f.first_date) AS INT)) AS month_n
    FROM orders o
    JOIN first_purchase f USING (customer_id)
    WHERE o.status = 'delivered'
),
cohort_size AS (
    SELECT cohort, COUNT(*) AS size
    FROM activity
    WHERE month_n = 0
    GROUP BY cohort
)
SELECT
    a.cohort,
    s.size                                              AS cohort_size,
    a.month_n,
    COUNT(DISTINCT a.customer_id)                       AS active,
    ROUND(100.0 * COUNT(DISTINCT a.customer_id) / s.size, 1) AS retention_pct
FROM activity a
JOIN cohort_size s USING (cohort)
GROUP BY a.cohort, a.month_n
ORDER BY a.cohort, a.month_n;
