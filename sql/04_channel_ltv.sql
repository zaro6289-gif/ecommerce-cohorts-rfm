-- Качество каналов привлечения: доля повторных покупателей и LTV за 6 месяцев
-- Берём только клиентов, пришедших до 2025-12-31, чтобы у всех было 6 месяцев истории
WITH first_purchase AS (
    SELECT customer_id, MIN(order_date) AS first_date
    FROM orders
    WHERE status = 'delivered'
    GROUP BY customer_id
),
ltv AS (
    SELECT
        c.channel,
        f.customer_id,
        SUM(o.amount)  AS revenue_6m,
        COUNT(*)       AS orders_6m
    FROM first_purchase f
    JOIN customers c USING (customer_id)
    JOIN orders o
      ON o.customer_id = f.customer_id
     AND o.status = 'delivered'
     AND o.order_date < date(f.first_date, '+6 months')
    WHERE f.first_date <= '2025-12-31'
    GROUP BY c.channel, f.customer_id
)
SELECT
    channel,
    COUNT(*)                                             AS customers,
    ROUND(100.0 * AVG(orders_6m > 1), 1)                AS repeat_rate_pct,
    ROUND(AVG(orders_6m), 2)                             AS orders_per_customer,
    ROUND(AVG(revenue_6m))                               AS ltv_6m
FROM ltv
GROUP BY channel
ORDER BY ltv_6m DESC;
