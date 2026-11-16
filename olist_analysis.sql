USE olist;

-- ==========================================
-- Question 1: TOP-5 Product categories with the highest revenue and sales volume
-- ==========================================

SELECT
    t.product_category_name_english AS category,
    COUNT(oi.order_item_id) AS sales_volume,
    SUM(oi.price) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
GROUP BY category
ORDER BY total_revenue DESC
LIMIT 5;


-- ==========================================
-- Question 2a: Overall Average Order Value (AOV)
-- ==========================================
SELECT
    ROUND(AVG(order_total), 2) AS overall_aov
FROM (
    SELECT order_id, SUM(payment_value) AS order_total
    FROM order_payments
    GROUP BY order_id
) AS order_totals;


-- ==========================================
-- Question 2b: AOV by customer state, TOP 5 states with highest AOV
-- ==========================================
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(AVG(order_totals.order_total), 2) AS aov
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN (
    SELECT order_id, SUM(payment_value) AS order_total
    FROM order_payments
    GROUP BY order_id
) AS order_totals ON o.order_id = order_totals.order_id
GROUP BY c.customer_state
ORDER BY aov DESC
LIMIT 5;

-- ==========================================
-- Question 2c: Average spend per order, by category
-- (Note: an order can contain multiple categories, 
-- so this measures category-level spend per order, not full order value)
-- ==========================================
SELECT
    t.product_category_name_english AS category,
    COUNT(DISTINCT oi.order_id) AS num_orders,
    ROUND(SUM(oi.price) / COUNT(DISTINCT oi.order_id), 2) AS avg_spend_per_order
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
GROUP BY category
ORDER BY avg_spend_per_order DESC
LIMIT 10;


-- ==========================================
-- Question 3: Repeat purchases vs. one-time customers
-- Note: customer_id is unique per order in this dataset; 
-- customer_unique_id identifies the actual person
-- ==========================================
SELECT
    purchase_frequency,
    COUNT(*) AS num_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS purchase_frequency
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
) AS customer_orders
GROUP BY purchase_frequency
ORDER BY purchase_frequency;


-- ==========================================
-- Question 4a: Delivery time vs. review score
-- Note: MySQL has no native CORR() function, so we compare 
-- average delivery time across review score groups
-- ==========================================
SELECT
    r.review_score,
    COUNT(*) AS num_orders,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_delivery_days
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score;


-- ==========================================
-- Question 4b: Pearson correlation coefficient (delivery time vs. review score)
-- ==========================================
SELECT
    (COUNT(*) * SUM(x * y) - SUM(x) * SUM(y)) /
    (SQRT(COUNT(*) * SUM(x * x) - POW(SUM(x), 2)) * SQRT(COUNT(*) * SUM(y * y) - POW(SUM(y), 2)))
    AS correlation_coefficient
FROM (
    SELECT
        DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS x,
        r.review_score AS y
    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
) AS delivery_reviews;



-- ==========================================
-- Question 5: Sellers with highest sales volume and best ratings
-- Note: reviews are given per order, not per seller. If an order 
-- contains items from multiple sellers, the review score is 
-- attributed to all of them equally, which may not reflect the 
-- actual seller responsible for the customer's experience.
-- ==========================================
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS num_orders,
    SUM(oi.price) AS total_revenue,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_items oi
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY oi.seller_id
HAVING num_orders >= 20
ORDER BY total_revenue DESC, avg_review_score DESC
LIMIT 10;



-- ==========================================
-- Question 6: Most used payment methods
-- ==========================================
SELECT
    payment_type,
    COUNT(*) AS num_payments,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_payments,
    ROUND(AVG(payment_value), 2) AS avg_payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY num_payments DESC;



-- ==========================================
-- Question 7a: Impact of delivery delay on review scores
-- ==========================================
SELECT
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On time or early'
    END AS delivery_status,
    COUNT(*) AS num_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;


-- ==========================================
-- Question 7b: Product categories with the lowest average review scores
-- ==========================================
SELECT
    t.product_category_name_english AS category,
    COUNT(DISTINCT r.review_id) AS num_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY category
HAVING num_reviews >= 30
ORDER BY avg_review_score ASC
LIMIT 10;


-- ==========================================
-- Question 7c: Price range vs. review scores
-- ==========================================
SELECT
    CASE 
        WHEN oi.price < 50 THEN '1. Under 50'
        WHEN oi.price < 100 THEN '2. 50-100'
        WHEN oi.price < 200 THEN '3. 100-200'
        WHEN oi.price < 500 THEN '4. 200-500'
        ELSE '5. Over 500'
    END AS price_range,
    COUNT(*) AS num_items,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_items oi
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY price_range
ORDER BY price_range;


-- ==========================================
-- Question 8: Month-over-month revenue growth
-- Uses LAG() to compare each month's revenue to the previous month
-- Note: excludes 2016-09, 2016-12 and 2018-09, which have only 
-- 1-2 residual orders (start/end of data collection) and distort 
-- the growth percentages
-- ==========================================
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY month
)
SELECT
    month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY month) AS previous_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY month)) 
        / LAG(total_revenue) OVER (ORDER BY month) * 100
    , 2) AS growth_pct
FROM monthly_revenue
ORDER BY month;

-- Confirm the actual date range in the dataset
SELECT
    MIN(order_purchase_timestamp) AS earliest_order,
    MAX(order_purchase_timestamp) AS latest_order
FROM orders;



-- ==========================================
-- Question 9: Top 3 products by revenue within each category
-- Uses RANK() with PARTITION BY to rank products separately 
-- inside each category
-- ==========================================
WITH product_revenue AS (
    SELECT
        t.product_category_name_english AS category,
        oi.product_id,
        SUM(oi.price) AS product_revenue,
        COUNT(*) AS units_sold
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    GROUP BY category, oi.product_id
),
ranked_products AS (
    SELECT
        category,
        product_id,
        product_revenue,
        units_sold,
        RANK() OVER (PARTITION BY category ORDER BY product_revenue DESC) AS rank_in_category
    FROM product_revenue
)
SELECT *
FROM ranked_products
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;



-- ==========================================
-- Question 10: Sales volume and delivery time by state
-- ==========================================
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS num_orders,
    SUM(oi.price) AS total_revenue,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_delivery_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- ==========================================
-- Question 11: Revenue share — repeat customers vs. one-time customers
-- Uses a CTE to classify each customer by purchase frequency, 
-- then aggregates revenue by group
-- ==========================================
WITH customer_purchases AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS num_orders,
        SUM(oi.price) AS customer_total_spend
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),
customer_segments AS (
    SELECT
        customer_unique_id,
        customer_total_spend,
        CASE 
            WHEN num_orders = 1 THEN 'One-time customer'
            ELSE 'Repeat customer'
        END AS customer_type
    FROM customer_purchases
)
SELECT
    customer_type,
    COUNT(*) AS num_customers,
    SUM(customer_total_spend) AS total_revenue,
    ROUND(SUM(customer_total_spend) * 100.0 / SUM(SUM(customer_total_spend)) OVER (), 2) AS pct_of_revenue,
    ROUND(AVG(customer_total_spend), 2) AS avg_spend_per_customer
FROM customer_segments
GROUP BY customer_type;

-- ==========================================
-- Question 12: Cumulative revenue (running total) and 50% milestone
-- Uses SUM() OVER (ORDER BY ...) to calculate running total by month
-- ==========================================
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY month
),
cumulative AS (
    SELECT
        month,
        total_revenue,
        SUM(total_revenue) OVER (ORDER BY month) AS running_total,
        SUM(total_revenue) OVER () AS grand_total
    FROM monthly_revenue
)
SELECT
    month,
    total_revenue,
    running_total,
    grand_total,
    ROUND(running_total * 100.0 / grand_total, 2) AS pct_of_total
FROM cumulative
ORDER BY month;


-- ==========================================
-- Question 13: Products priced above their category average
-- ==========================================
WITH category_avg AS (
    SELECT
        p.product_category_name,
        AVG(oi.price) AS category_avg_price
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.product_category_name
),
product_avg AS (
    SELECT
        p.product_category_name,
        oi.product_id,
        AVG(oi.price) AS product_avg_price
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.product_category_name, oi.product_id
)
SELECT
    t.product_category_name_english AS category,
    pa.product_id,
    ROUND(pa.product_avg_price, 2) AS product_avg_price,
    ROUND(ca.category_avg_price, 2) AS category_avg_price,
    ROUND(pa.product_avg_price - ca.category_avg_price, 2) AS price_diff,
    ROUND((pa.product_avg_price - ca.category_avg_price) / ca.category_avg_price * 100, 1) AS pct_above_category_avg
FROM product_avg pa
JOIN category_avg ca ON pa.product_category_name = ca.product_category_name
JOIN product_category_name_translation t ON pa.product_category_name = t.product_category_name
WHERE pa.product_avg_price > ca.category_avg_price
ORDER BY pct_above_category_avg DESC
LIMIT 15;