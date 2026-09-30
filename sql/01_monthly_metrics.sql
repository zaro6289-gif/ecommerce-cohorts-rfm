-- Ключевые метрики по месяцам: выручка, заказы, покупатели, средний чек, рост MoM
-- Учитываем только доставленные заказы
WITH monthly AS (
    SELECT
        strftime('%Y-%m', order_date)      AS month,
        COUNT(*)                           AS orders,
        COUNT(DISTINCT customer_id)        AS buyers,
        SUM(amount)                        AS revenue
    FROM orders
    WHERE status = 'delivered'
    GROUP BY month
)
SELECT
    month,
    orders,
    buyers,
    ROUND(revenue)                                         AS revenue,
    ROUND(revenue * 1.0 / orders)                          AS avg_check,
    ROUND(100.0 * (revenue - LAG(revenue) OVER w)
          / LAG(revenue) OVER w, 1)                        AS revenue_mom_pct
FROM monthly
WINDOW w AS (ORDER BY month)
ORDER BY month;
