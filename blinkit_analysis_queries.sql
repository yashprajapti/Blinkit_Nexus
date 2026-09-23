-- Blinkit Data Analytics — SQL used in the analysis (DuckDB)
-- Views are created first, then one query per analysis step.

-- 1.4 Typed analysis views
CREATE OR REPLACE VIEW orders AS
SELECT order_id, customer_id,
       strptime(order_date, '%d-%m-%Y %H:%M')              AS order_ts,
       CAST(strptime(order_date, '%d-%m-%Y %H:%M') AS DATE) AS order_date,
       strptime(promised_delivery_time, '%d-%m-%Y %H:%M')   AS promised_ts,
       strptime(actual_delivery_time,  '%d-%m-%Y %H:%M')    AS actual_ts,
       delivery_status, order_total, payment_method, delivery_partner_id, store_id,
       CAST(delivery_time_minutes AS INTEGER)               AS delay_min,
       distance_km, reasons_if_delayed, customer_name,
       trim(area) AS area, pincode, customer_segment,
       CAST(registration_date AS DATE)                      AS registration_date,
       order_day_of_week, order_time_slot, order_value_segment,
       CASE WHEN is_weekend = 'Yes' THEN 1 ELSE 0 END       AS is_weekend
FROM orders_src;

-- 1.4 Typed analysis views
CREATE OR REPLACE VIEW items AS
SELECT order_id, product_id, quantity, unit_price, product_name, category, brand,
       price, mrp, margin_percentage, shelf_life_days, min_stock_level, max_stock_level, line_total,
       line_total * margin_percentage / 100.0 AS margin_value
FROM items_src;

-- 1.4 Typed analysis views
CREATE OR REPLACE VIEW feedback AS
SELECT feedback_id, order_id, customer_id, rating, feedback_category, sentiment,
       CAST(feedback_date AS DATE) AS feedback_date
FROM feedback_src;

-- 1.4 Typed analysis views
CREATE OR REPLACE VIEW f_sales AS
SELECT o.order_id, o.customer_id, o.order_ts, o.order_date,
       date_trunc('month', o.order_date)  AS order_month,
       extract(hour FROM o.order_ts)      AS order_hour,
       o.order_day_of_week, o.is_weekend, o.order_time_slot, o.order_value_segment,
       o.payment_method, o.customer_segment, o.registration_date, o.customer_name,
       o.area, g.state, g.zone, g.city_tier,
       i.product_id, i.product_name, i.category, i.brand,
       i.quantity, i.line_total AS revenue, i.margin_value, i.margin_percentage,
       i.price, i.mrp, i.shelf_life_days,
       o.delay_min, o.distance_km, o.delivery_status,
       CASE WHEN o.delivery_status = 'On Time' THEN 1 ELSE 0 END AS is_on_time_status,
       CASE WHEN o.delay_min > 0 THEN 1 ELSE 0 END               AS is_late_minutes,
       f.rating, f.sentiment, f.feedback_category
FROM orders o
JOIN items i    ON i.order_id = o.order_id
LEFT JOIN geo g ON g.area     = o.area
LEFT JOIN feedback f ON f.order_id = o.order_id;

-- 2.1 Row and key counts per table
SELECT 'orders'    AS table_name, COUNT(*) AS rows, COUNT(DISTINCT order_id)    AS unique_keys FROM orders
UNION ALL SELECT 'order_items', COUNT(*), COUNT(DISTINCT order_id)    FROM items
UNION ALL SELECT 'customers',   COUNT(*), COUNT(DISTINCT customer_id) FROM customers_src
UNION ALL SELECT 'products',    COUNT(*), COUNT(DISTINCT product_id)  FROM products_src
UNION ALL SELECT 'delivery',    COUNT(*), COUNT(DISTINCT order_id)    FROM delivery_src
UNION ALL SELECT 'feedback',    COUNT(*), COUNT(DISTINCT feedback_id) FROM feedback
ORDER BY table_name;

-- 2.2 Duplicate primary keys
WITH d AS (
  SELECT 'orders.order_id'       AS key_name, order_id::VARCHAR    AS key_value, COUNT(*) AS n FROM orders    GROUP BY 2
  UNION ALL SELECT 'customers.customer_id', customer_id::VARCHAR, COUNT(*) FROM customers_src GROUP BY 2
  UNION ALL SELECT 'products.product_id',   product_id::VARCHAR,  COUNT(*) FROM products_src  GROUP BY 2
  UNION ALL SELECT 'feedback.feedback_id',  feedback_id::VARCHAR, COUNT(*) FROM feedback      GROUP BY 2
)
SELECT key_name, COUNT(*) FILTER (WHERE n > 1) AS duplicate_keys, COUNT(*) AS distinct_keys
FROM d GROUP BY key_name ORDER BY key_name;

-- 2.4 Referential integrity
SELECT 'items.order_id -> orders'        AS relation, COUNT(*) AS orphan_rows FROM items i    LEFT JOIN orders o ON o.order_id = i.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'items.product_id -> products', COUNT(*) FROM items i     LEFT JOIN products_src p  ON p.product_id  = i.product_id  WHERE p.product_id  IS NULL
UNION ALL SELECT 'orders.customer_id -> customers', COUNT(*) FROM orders o LEFT JOIN customers_src c ON c.customer_id = o.customer_id WHERE c.customer_id IS NULL
UNION ALL SELECT 'delivery.order_id -> orders', COUNT(*) FROM delivery_src d LEFT JOIN orders o ON o.order_id = d.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'feedback.order_id -> orders', COUNT(*) FROM feedback f   LEFT JOIN orders o ON o.order_id = f.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'orders.area -> geo', COUNT(*) FROM orders o LEFT JOIN geo g ON g.area = o.area WHERE g.area IS NULL;

-- 2.5 Business rule checks
SELECT 'quantity <= 0'                      AS rule, COUNT(*) AS failing_rows FROM items WHERE quantity <= 0
UNION ALL SELECT 'unit price > MRP',              COUNT(*) FROM items  WHERE price > mrp
UNION ALL SELECT 'line total <> qty * price',     COUNT(*) FROM items  WHERE abs(line_total - quantity * price) > 0.01
UNION ALL SELECT 'delivery before order time',    COUNT(*) FROM orders WHERE actual_ts < order_ts
UNION ALL SELECT 'promised before order time',    COUNT(*) FROM orders WHERE promised_ts < order_ts
UNION ALL SELECT 'rating outside 1-5',            COUNT(*) FROM feedback WHERE rating < 1 OR rating > 5
UNION ALL SELECT 'shelf life <= 0',               COUNT(*) FROM products_src WHERE shelf_life_days <= 0
UNION ALL SELECT 'min stock > max stock',         COUNT(*) FROM products_src WHERE min_stock_level > max_stock_level
UNION ALL SELECT 'registration after first order',COUNT(*) FROM (
      SELECT customer_id, MIN(order_date) AS first_order, MIN(registration_date) AS reg FROM orders GROUP BY 1)
      WHERE reg > first_order;

-- 2.6 Order total in orders table vs sum of line items
WITH cmp AS (
  SELECT o.order_id, o.order_total, i.line_total,
         round(o.order_total - i.line_total, 2) AS diff
  FROM orders o JOIN items i ON i.order_id = o.order_id
)
SELECT COUNT(*) AS orders_compared,
       COUNT(*) FILTER (WHERE abs(diff) > 0.01) AS mismatched_orders,
       round(AVG(diff), 2)  AS avg_difference,
       round(SUM(order_total), 2) AS total_in_orders_table,
       round(SUM(line_total), 2)  AS total_in_items_table
FROM cmp;

-- 2.7 Items per order
SELECT items_per_order, COUNT(*) AS orders FROM (
  SELECT order_id, COUNT(*) AS items_per_order FROM items GROUP BY 1)
GROUP BY 1 ORDER BY 1;

-- 2.8 Customer segment label vs actual ordering behaviour
SELECT c.customer_segment                              AS label,
       COUNT(DISTINCT c.customer_id)                   AS customers_labelled,
       COUNT(DISTINCT o.customer_id)                   AS customers_who_ordered,
       COUNT(o.order_id)                               AS orders,
       round(SUM(o.order_total), 0)                    AS revenue,
       round(COUNT(o.order_id) * 1.0 / NULLIF(COUNT(DISTINCT o.customer_id), 0), 2) AS orders_per_buyer
FROM customers_src c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY 1 ORDER BY revenue DESC;

-- 2.9 Date coverage
SELECT MIN(order_date) AS first_order, MAX(order_date) AS last_order,
       date_diff('day', MIN(order_date), MAX(order_date)) AS days_covered,
       COUNT(DISTINCT order_date)  AS days_with_orders,
       COUNT(DISTINCT date_trunc('month', order_date)) AS months_covered
FROM orders;

-- 3.1 Headline figures
SELECT COUNT(DISTINCT order_id)              AS orders,
       COUNT(DISTINCT customer_id)           AS buying_customers,
       SUM(quantity)                         AS units,
       round(SUM(revenue), 2)                AS revenue,
       round(SUM(revenue) / COUNT(DISTINCT order_id), 2) AS avg_order_value,
       round(SUM(margin_value), 2)           AS gross_margin,
       round(100 * SUM(margin_value) / SUM(revenue), 2)  AS margin_pct,
       round(AVG(rating), 2)                 AS avg_rating
FROM f_sales;

-- 3.2 Monthly revenue with month-over-month growth
WITH m AS (
  SELECT order_month, COUNT(DISTINCT order_id) AS orders, SUM(revenue) AS revenue, SUM(quantity) AS units
  FROM f_sales GROUP BY 1)
SELECT strftime(order_month, '%Y-%m')                 AS month,
       orders, round(revenue, 0) AS revenue, units,
       round(revenue / orders, 0)                      AS aov,
       round(revenue - LAG(revenue) OVER (ORDER BY order_month), 0) AS revenue_change,
       round(100 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
             / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0), 2) AS mom_growth_pct,
       round(100 * (orders - LAG(orders) OVER (ORDER BY order_month))
             / NULLIF(LAG(orders) OVER (ORDER BY order_month), 0), 2)  AS mom_order_growth_pct
FROM m ORDER BY order_month;

-- 3.3 Running revenue and share of total
WITH m AS (SELECT order_month, SUM(revenue) AS revenue FROM f_sales GROUP BY 1)
SELECT strftime(order_month, '%Y-%m') AS month,
       round(revenue, 0)              AS revenue,
       round(SUM(revenue) OVER (ORDER BY order_month ROWS UNBOUNDED PRECEDING), 0) AS running_revenue,
       round(100 * SUM(revenue) OVER (ORDER BY order_month ROWS UNBOUNDED PRECEDING)
             / SUM(revenue) OVER (), 2) AS running_share_pct,
       round(AVG(revenue) OVER (ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS moving_avg_3m
FROM m ORDER BY order_month;

-- 3.4 Revenue by category with contribution and rank
SELECT category,
       COUNT(DISTINCT order_id)                       AS orders,
       SUM(quantity)                                  AS units,
       round(SUM(revenue), 0)                         AS revenue,
       round(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share_pct,
       RANK() OVER (ORDER BY SUM(revenue) DESC)       AS revenue_rank,
       round(SUM(revenue) / COUNT(DISTINCT order_id), 0) AS aov,
       round(SUM(margin_value), 0)                    AS margin_value,
       RANK() OVER (ORDER BY SUM(margin_value) DESC)  AS margin_rank
FROM f_sales GROUP BY 1 ORDER BY revenue DESC;

-- 3.5 Top 15 products by revenue
SELECT DENSE_RANK() OVER (ORDER BY SUM(revenue) DESC) AS rnk,
       product_name, category,
       COUNT(DISTINCT order_id) AS orders, SUM(quantity) AS units,
       round(SUM(revenue), 0)   AS revenue,
       round(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS share_pct
FROM f_sales GROUP BY product_name, category ORDER BY revenue DESC LIMIT 15;

-- 3.6 Bottom 15 product codes by revenue
SELECT product_id, any_value(product_name) AS product_name, any_value(category) AS category,
       COUNT(DISTINCT order_id) AS orders, SUM(quantity) AS units, round(SUM(revenue), 0) AS revenue
FROM f_sales GROUP BY product_id ORDER BY revenue ASC LIMIT 15;

-- 3.7 Pareto check on product codes
WITH p AS (SELECT product_id, SUM(revenue) AS revenue FROM f_sales GROUP BY 1),
r AS (SELECT product_id, revenue,
             ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rn,
             SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) AS cum_rev,
             SUM(revenue) OVER () AS total_rev,
             COUNT(*) OVER () AS total_products FROM p)
SELECT share_of_products || '% of product codes' AS product_group,
       MIN(rn) AS codes_needed,
       round(100 * MAX(cum_rev) / MAX(total_rev), 2) AS revenue_share_pct
FROM (SELECT *, CASE WHEN rn <= 0.1 * total_products THEN 10
                     WHEN rn <= 0.2 * total_products THEN 20
                     WHEN rn <= 0.5 * total_products THEN 50
                     ELSE 100 END AS share_of_products FROM r)
GROUP BY share_of_products ORDER BY share_of_products;

-- 3.8 Number of product codes needed for 50, 70, 80 and 90 percent of revenue
WITH p AS (SELECT product_id, SUM(revenue) AS revenue FROM f_sales GROUP BY 1),
r AS (SELECT product_id, ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rn,
             100 * SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) / SUM(revenue) OVER () AS cum_pct
      FROM p)
SELECT t AS revenue_target_pct,
       MIN(rn) AS product_codes_needed,
       round(100.0 * MIN(rn) / (SELECT COUNT(*) FROM p), 1) AS pct_of_catalogue
FROM r, (SELECT unnest([50, 70, 80, 90]) AS t)
WHERE cum_pct >= t GROUP BY t ORDER BY t;

-- 3.9 Order value distribution
SELECT CASE WHEN revenue < 250 THEN 'a. under 250'
            WHEN revenue < 500 THEN 'b. 250-500'
            WHEN revenue < 750 THEN 'c. 500-750'
            WHEN revenue < 1000 THEN 'd. 750-1000'
            WHEN revenue < 1500 THEN 'e. 1000-1500'
            WHEN revenue < 2000 THEN 'f. 1500-2000'
            WHEN revenue < 3000 THEN 'g. 2000-3000'
            ELSE 'h. 3000 and above' END AS order_value_band,
       COUNT(*) AS orders,
       round(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS order_share_pct,
       round(SUM(revenue), 0) AS revenue,
       round(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share_pct
FROM f_sales GROUP BY 1 ORDER BY 1;

-- 3.10 Order value deciles
WITH d AS (SELECT order_id, revenue, NTILE(10) OVER (ORDER BY revenue) AS decile FROM f_sales)
SELECT decile, COUNT(*) AS orders,
       round(MIN(revenue), 0) AS min_value, round(MAX(revenue), 0) AS max_value,
       round(SUM(revenue), 0) AS revenue,
       round(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share_pct
FROM d GROUP BY decile ORDER BY decile;

-- 3.11 Category revenue by month
SELECT category,
       round(SUM(revenue) FILTER (WHERE order_month < DATE '2023-10-01'), 0) AS q_2023_early,
       round(SUM(revenue) FILTER (WHERE order_month BETWEEN DATE '2023-10-01' AND DATE '2024-03-01'), 0) AS oct23_mar24,
       round(SUM(revenue) FILTER (WHERE order_month BETWEEN DATE '2024-04-01' AND DATE '2024-11-01'), 0) AS apr24_nov24,
       round(SUM(revenue), 0) AS total_revenue
FROM f_sales GROUP BY category ORDER BY total_revenue DESC;

-- 3.12 Daily revenue outliers
WITH d AS (SELECT order_date, SUM(revenue) AS revenue, COUNT(*) AS orders FROM f_sales GROUP BY 1),
s AS (SELECT AVG(revenue) AS mu, stddev_samp(revenue) AS sd FROM d)
SELECT order_date, orders, round(revenue, 0) AS revenue,
       round((revenue - mu) / sd, 2) AS z_score
FROM d, s WHERE abs((revenue - mu) / sd) > 2
ORDER BY abs((revenue - mu) / sd) DESC LIMIT 12;

-- 4.1 Customer base summary
WITH c AS (
  SELECT customer_id, COUNT(DISTINCT order_id) AS orders, SUM(revenue) AS spend,
         MIN(order_date) AS first_order, MAX(order_date) AS last_order
  FROM f_sales GROUP BY 1)
SELECT (SELECT COUNT(*) FROM customers_src)               AS registered_customers,
       COUNT(*)                                           AS customers_who_ordered,
       COUNT(*) FILTER (WHERE orders = 1)                 AS one_order_only,
       COUNT(*) FILTER (WHERE orders >= 2)                AS repeat_customers,
       round(100.0 * COUNT(*) FILTER (WHERE orders >= 2) / COUNT(*), 2) AS repeat_rate_pct,
       round(AVG(orders), 2)                              AS avg_orders_per_customer,
       round(AVG(spend), 2)                               AS avg_spend_per_customer,
       round(SUM(spend) FILTER (WHERE orders >= 2) * 100.0 / SUM(spend), 2) AS repeat_revenue_share_pct
FROM c;

-- 4.2 Distribution of orders per customer
WITH c AS (SELECT customer_id, COUNT(DISTINCT order_id) AS orders, SUM(revenue) AS spend FROM f_sales GROUP BY 1)
SELECT orders AS orders_placed, COUNT(*) AS customers,
       round(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_share_pct,
       round(SUM(spend), 0) AS revenue,
       round(100 * SUM(spend) / SUM(SUM(spend)) OVER (), 2) AS revenue_share_pct
FROM c GROUP BY orders ORDER BY orders;

-- 4.3 Top 15 customers by spend
SELECT RANK() OVER (ORDER BY SUM(revenue) DESC) AS rnk,
       any_value(customer_name) AS customer, customer_id,
       any_value(state) AS state, any_value(customer_segment) AS label,
       COUNT(DISTINCT order_id) AS orders, round(SUM(revenue), 0) AS spend,
       round(AVG(revenue), 0) AS avg_order, MAX(order_date) AS last_order
FROM f_sales GROUP BY customer_id ORDER BY spend DESC LIMIT 15;

-- 4.4 Customer revenue concentration by decile
WITH c AS (SELECT customer_id, SUM(revenue) AS spend FROM f_sales GROUP BY 1),
d AS (SELECT customer_id, spend, NTILE(10) OVER (ORDER BY spend DESC) AS decile FROM c)
SELECT decile, COUNT(*) AS customers, round(SUM(spend), 0) AS revenue,
       round(100 * SUM(spend) / SUM(SUM(spend)) OVER (), 2) AS revenue_share_pct,
       round(100 * SUM(SUM(spend)) OVER (ORDER BY decile ROWS UNBOUNDED PRECEDING) / SUM(SUM(spend)) OVER (), 2) AS cumulative_share_pct
FROM d GROUP BY decile ORDER BY decile;

-- 4.5 New versus repeat revenue by month
WITH first_order AS (SELECT customer_id, MIN(order_date) AS first_date FROM f_sales GROUP BY 1),
tagged AS (
  SELECT s.order_month, s.revenue,
         CASE WHEN s.order_date = f.first_date THEN 'new' ELSE 'repeat' END AS customer_type
  FROM f_sales s JOIN first_order f ON f.customer_id = s.customer_id)
SELECT strftime(order_month, '%Y-%m') AS month,
       round(SUM(revenue) FILTER (WHERE customer_type = 'new'), 0)    AS new_customer_revenue,
       round(SUM(revenue) FILTER (WHERE customer_type = 'repeat'), 0) AS repeat_customer_revenue,
       round(100 * SUM(revenue) FILTER (WHERE customer_type = 'repeat') / SUM(revenue), 2) AS repeat_share_pct
FROM tagged GROUP BY order_month ORDER BY order_month;

-- 4.6 Gap between consecutive orders
WITH seq AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_no,
         LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_date
  FROM (SELECT DISTINCT customer_id, order_date FROM f_sales)),
gaps AS (SELECT order_no, date_diff('day', prev_date, order_date) AS gap_days FROM seq WHERE prev_date IS NOT NULL)
SELECT order_no AS order_number, COUNT(*) AS transitions,
       round(AVG(gap_days), 1) AS avg_gap_days,
       round(median(gap_days), 1) AS median_gap_days,
       MIN(gap_days) AS min_gap, MAX(gap_days) AS max_gap
FROM gaps WHERE order_no <= 6 GROUP BY order_no ORDER BY order_no;

-- 4.7 Monthly cohort retention
WITH first_order AS (SELECT customer_id, date_trunc('month', MIN(order_date)) AS cohort FROM f_sales GROUP BY 1),
activity AS (
  SELECT f.cohort, date_diff('month', f.cohort, s.order_month) AS month_index, s.customer_id
  FROM f_sales s JOIN first_order f ON f.customer_id = s.customer_id),
sized AS (SELECT cohort, COUNT(DISTINCT customer_id) AS cohort_size FROM activity WHERE month_index = 0 GROUP BY 1)
SELECT strftime(a.cohort, '%Y-%m') AS cohort_month, s.cohort_size,
       round(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_index = 1) / s.cohort_size, 1) AS m1_pct,
       round(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_index = 2) / s.cohort_size, 1) AS m2_pct,
       round(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_index = 3) / s.cohort_size, 1) AS m3_pct,
       round(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_index BETWEEN 4 AND 6) / s.cohort_size, 1) AS m4_m6_pct
FROM activity a JOIN sized s ON s.cohort = a.cohort
GROUP BY a.cohort, s.cohort_size ORDER BY a.cohort;

-- 4.8 Recency, frequency and monetary table
WITH base AS (SELECT MAX(order_date) AS as_of FROM f_sales)
SELECT s.customer_id,
       date_diff('day', MAX(s.order_date), (SELECT as_of FROM base)) AS recency_days,
       COUNT(DISTINCT s.order_id)  AS frequency,
       round(SUM(s.revenue), 2)    AS monetary,
       round(AVG(s.revenue), 2)    AS avg_order_value,
       date_diff('day', MIN(s.order_date), MAX(s.order_date)) AS tenure_days,
       any_value(s.zone) AS zone, any_value(s.customer_segment) AS label
FROM f_sales s GROUP BY s.customer_id;

-- 4.9 Customers who never ordered
SELECT c.customer_segment AS label, COUNT(*) AS never_ordered
FROM customers_src c LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL GROUP BY 1 ORDER BY never_ordered DESC;

-- 5.1 Funnel from registration to third order
WITH c AS (
  SELECT cs.customer_id, COUNT(DISTINCT o.order_id) AS orders
  FROM customers_src cs LEFT JOIN orders o ON o.customer_id = cs.customer_id GROUP BY 1)
SELECT 'Registered'       AS stage, COUNT(*) AS customers, 100.0 AS pct_of_registered FROM c
UNION ALL SELECT 'Placed 1st order', COUNT(*) FILTER (WHERE orders >= 1), round(100.0 * COUNT(*) FILTER (WHERE orders >= 1) / COUNT(*), 2) FROM c
UNION ALL SELECT 'Placed 2nd order', COUNT(*) FILTER (WHERE orders >= 2), round(100.0 * COUNT(*) FILTER (WHERE orders >= 2) / COUNT(*), 2) FROM c
UNION ALL SELECT 'Placed 3rd order', COUNT(*) FILTER (WHERE orders >= 3), round(100.0 * COUNT(*) FILTER (WHERE orders >= 3) / COUNT(*), 2) FROM c
UNION ALL SELECT 'Placed 4th order or more', COUNT(*) FILTER (WHERE orders >= 4), round(100.0 * COUNT(*) FILTER (WHERE orders >= 4) / COUNT(*), 2) FROM c;

-- 5.2 Drop-off between stages
WITH c AS (SELECT cs.customer_id, COUNT(DISTINCT o.order_id) AS orders
           FROM customers_src cs LEFT JOIN orders o ON o.customer_id = cs.customer_id GROUP BY 1)
SELECT COUNT(*) AS registered,
       COUNT(*) FILTER (WHERE orders >= 1) AS first_order,
       COUNT(*) FILTER (WHERE orders >= 2) AS second_order,
       COUNT(*) FILTER (WHERE orders >= 3) AS third_order FROM c;

-- 5.3 Days from registration to first order
WITH f AS (
  SELECT customer_id, MIN(order_date) AS first_order, MIN(registration_date) AS reg FROM orders GROUP BY 1)
SELECT CASE WHEN date_diff('day', reg, first_order) < 0 THEN 'a. order before registration (data issue)'
            WHEN date_diff('day', reg, first_order) <= 7   THEN 'b. within 7 days'
            WHEN date_diff('day', reg, first_order) <= 30  THEN 'c. 8 to 30 days'
            WHEN date_diff('day', reg, first_order) <= 90  THEN 'd. 31 to 90 days'
            ELSE 'e. more than 90 days' END AS activation_speed,
       COUNT(*) AS customers,
       round(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM f GROUP BY 1 ORDER BY 1;

-- 5.4 Gap to second order in bands
WITH seq AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_no,
         LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_date
  FROM (SELECT DISTINCT customer_id, order_date FROM f_sales)),
g AS (SELECT date_diff('day', prev_date, order_date) AS gap FROM seq WHERE order_no = 2)
SELECT CASE WHEN gap <= 30 THEN 'a. 0-30 days' WHEN gap <= 60 THEN 'b. 31-60 days'
            WHEN gap <= 90 THEN 'c. 61-90 days' WHEN gap <= 180 THEN 'd. 91-180 days'
            WHEN gap <= 365 THEN 'e. 181-365 days' ELSE 'f. over 365 days' END AS gap_band,
       COUNT(*) AS customers,
       round(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM g GROUP BY 1 ORDER BY 1;

-- 5.5 Repeat purchase curve (Kaplan-Meier estimate)
WITH seq AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_no
  FROM (SELECT DISTINCT customer_id, order_date FROM f_sales)),
f AS (SELECT customer_id, MIN(order_date) FILTER (WHERE order_no = 1) AS first_date,
             MIN(order_date) FILTER (WHERE order_no = 2) AS second_date
      FROM seq GROUP BY customer_id)
SELECT customer_id, first_date, second_date,
       (SELECT MAX(order_date) FROM f_sales) AS study_end FROM f;

-- 6.1 Category rank by revenue against rank by margin
WITH c AS (
  SELECT category, SUM(revenue) AS revenue, SUM(margin_value) AS margin_value,
         AVG(margin_percentage) AS margin_pct FROM f_sales GROUP BY 1)
SELECT category, round(revenue, 0) AS revenue, round(margin_pct, 1) AS margin_pct,
       round(margin_value, 0) AS margin_value,
       RANK() OVER (ORDER BY revenue DESC)      AS revenue_rank,
       RANK() OVER (ORDER BY margin_value DESC) AS margin_rank,
       RANK() OVER (ORDER BY revenue DESC) - RANK() OVER (ORDER BY margin_value DESC) AS rank_shift,
       round(100 * margin_value / SUM(margin_value) OVER (), 2) AS margin_share_pct
FROM c ORDER BY margin_value DESC;

-- 6.2 Top 3 products inside each category
WITH p AS (
  SELECT category, product_name, SUM(revenue) AS revenue, SUM(quantity) AS units
  FROM f_sales GROUP BY 1, 2),
r AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) AS rn,
             100 * revenue / SUM(revenue) OVER (PARTITION BY category) AS share_in_category
      FROM p)
SELECT category, rn AS rank_in_category, product_name, round(revenue, 0) AS revenue,
       units, round(share_in_category, 1) AS share_in_category_pct
FROM r WHERE rn <= 3 ORDER BY category, rn;

-- 6.3 Product codes per product name
SELECT product_name, any_value(category) AS category,
       COUNT(DISTINCT product_id) AS product_codes,
       COUNT(DISTINCT order_id)   AS orders,
       round(SUM(revenue), 0)     AS revenue,
       round(SUM(revenue) / COUNT(DISTINCT product_id), 0) AS revenue_per_code
FROM f_sales GROUP BY product_name HAVING COUNT(DISTINCT product_id) > 1
ORDER BY product_codes DESC, revenue DESC LIMIT 15;

-- 6.4 ABC classification of product codes
WITH p AS (SELECT product_id, any_value(product_name) AS product_name, any_value(category) AS category,
                  SUM(revenue) AS revenue, SUM(quantity) AS units FROM f_sales GROUP BY product_id),
r AS (SELECT *, 100 * SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) / SUM(revenue) OVER () AS cum_pct
      FROM p)
SELECT *, CASE WHEN cum_pct <= 80 THEN 'A' WHEN cum_pct <= 95 THEN 'B' ELSE 'C' END AS abc_class FROM r;

-- 6.5 XYZ classification on demand variability
SELECT product_id, order_month, SUM(quantity) AS units FROM f_sales GROUP BY 1, 2;

-- 6.7 Price band performance
SELECT CASE WHEN price < 50 THEN 'a. under 50' WHEN price < 100 THEN 'b. 50-100'
            WHEN price < 250 THEN 'c. 100-250' WHEN price < 500 THEN 'd. 250-500'
            ELSE 'e. 500 and above' END AS price_band,
       COUNT(DISTINCT product_id) AS product_codes, SUM(quantity) AS units,
       round(SUM(revenue), 0) AS revenue, round(AVG(price), 0) AS avg_price,
       round(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share_pct
FROM f_sales GROUP BY 1 ORDER BY 1;

-- 7.1 Revenue contribution of the weakest product codes
WITH p AS (SELECT product_id, any_value(product_name) AS product_name, any_value(category) AS category,
                  SUM(revenue) AS revenue, COUNT(DISTINCT order_id) AS orders FROM f_sales GROUP BY product_id),
r AS (SELECT *, NTILE(4) OVER (ORDER BY revenue) AS quartile FROM p)
SELECT quartile, COUNT(*) AS product_codes, round(SUM(revenue), 0) AS revenue,
       round(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share_pct,
       round(AVG(orders), 1) AS avg_orders_per_code
FROM r GROUP BY quartile ORDER BY quartile;

-- 7.2 Merge and review candidates
WITH p AS (SELECT product_id, any_value(product_name) AS product_name, any_value(category) AS category,
                  SUM(revenue) AS revenue, COUNT(DISTINCT order_id) AS orders FROM f_sales GROUP BY product_id),
n AS (SELECT product_name, COUNT(*) AS codes_for_name, SUM(revenue) AS name_revenue FROM p GROUP BY product_name)
SELECT p.product_id, p.product_name, p.category, p.orders, round(p.revenue, 0) AS revenue,
       n.codes_for_name, round(100 * p.revenue / n.name_revenue, 1) AS share_within_name,
       CASE WHEN n.codes_for_name > 1 AND 100 * p.revenue / n.name_revenue < 8 THEN 'merge into main code'
            WHEN p.orders <= 3 THEN 'review for removal'
            ELSE 'keep' END AS recommendation
FROM p JOIN n ON n.product_name = p.product_name;

-- 8.1 Delivery status against actual minutes
SELECT delivery_status,
       COUNT(*) AS orders,
       round(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct,
       round(AVG(delay_min), 2)  AS avg_minutes_vs_promise,
       MIN(delay_min) AS min_minutes, MAX(delay_min) AS max_minutes,
       COUNT(*) FILTER (WHERE delay_min > 0) AS arrived_after_promise
FROM f_sales GROUP BY 1 ORDER BY orders DESC;

-- 8.2 Promise accuracy summary
SELECT COUNT(*) AS orders,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_by_status_pct,
       round(100.0 * COUNT(*) FILTER (WHERE delay_min <= 0) / COUNT(*), 2)        AS on_or_before_promise_pct,
       round(100.0 * COUNT(*) FILTER (WHERE delay_min > 0) / COUNT(*), 2)         AS after_promise_pct,
       round(100.0 * COUNT(*) FILTER (WHERE delay_min > 10) / COUNT(*), 2)        AS more_than_10_min_late_pct,
       round(AVG(delay_min) FILTER (WHERE delay_min > 0), 2)                      AS avg_delay_when_late,
       round(quantile_cont(delay_min, 0.5), 1)  AS p50_minutes,
       round(quantile_cont(delay_min, 0.9), 1)  AS p90_minutes,
       round(quantile_cont(delay_min, 0.95), 1) AS p95_minutes
FROM f_sales;

-- 8.3 Distribution of minutes against promise
SELECT CASE WHEN delay_min <= -5 THEN 'a. 5 or more minutes early'
            WHEN delay_min < 0   THEN 'b. 1 to 4 minutes early'
            WHEN delay_min = 0   THEN 'c. exactly on promise'
            WHEN delay_min <= 5  THEN 'd. 1 to 5 minutes late'
            WHEN delay_min <= 10 THEN 'e. 6 to 10 minutes late'
            WHEN delay_min <= 20 THEN 'f. 11 to 20 minutes late'
            ELSE 'g. more than 20 minutes late' END AS band,
       COUNT(*) AS orders,
       round(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct,
       round(SUM(revenue), 0) AS revenue
FROM f_sales GROUP BY 1 ORDER BY 1;

-- 8.4 On-time rate by state
SELECT state, zone, COUNT(*) AS orders,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct,
       round(100.0 * COUNT(*) FILTER (WHERE delay_min > 10) / COUNT(*), 2)        AS very_late_pct,
       round(AVG(delay_min), 2) AS avg_minutes_vs_promise,
       round(AVG(distance_km), 2) AS avg_distance_km,
       RANK() OVER (ORDER BY 1.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*) DESC) AS rank_on_time
FROM f_sales GROUP BY state, zone HAVING COUNT(*) >= 30 ORDER BY on_time_pct DESC;

-- 8.5 On-time rate by month
SELECT strftime(order_month, '%Y-%m') AS month, COUNT(*) AS orders,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct,
       round(AVG(delay_min), 2) AS avg_minutes,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*)
             - LAG(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*)) OVER (ORDER BY order_month), 2) AS change_vs_prev_month
FROM f_sales GROUP BY order_month ORDER BY order_month;

-- 8.6 On-time rate by hour and time slot
SELECT order_time_slot, COUNT(*) AS orders,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct,
       round(AVG(delay_min), 2) AS avg_minutes,
       round(AVG(distance_km), 2) AS avg_distance_km,
       round(AVG(rating), 2) AS avg_rating
FROM f_sales GROUP BY 1 ORDER BY on_time_pct;

-- 8.7 Delay against distance
SELECT CASE WHEN distance_km < 1 THEN 'a. under 1 km' WHEN distance_km < 2 THEN 'b. 1-2 km'
            WHEN distance_km < 5 THEN 'c. 2-5 km' ELSE 'd. 5 km and above' END AS distance_band,
       COUNT(*) AS orders, round(AVG(delay_min), 2) AS avg_minutes_vs_promise,
       round(100.0 * COUNT(*) FILTER (WHERE delay_min > 0) / COUNT(*), 2) AS late_pct,
       round(AVG(rating), 2) AS avg_rating
FROM f_sales GROUP BY 1 ORDER BY 1;

-- 8.9 Proposed delivery promise by zone
SELECT zone, COUNT(*) AS orders,
       round(AVG(date_diff('minute', order_ts, promised_ts)), 1)  AS current_promise_min,
       round(AVG(date_diff('minute', order_ts, actual_ts)), 1)    AS actual_avg_min,
       round(quantile_cont(date_diff('minute', order_ts, actual_ts), 0.80), 0) AS p80_actual_min,
       round(quantile_cont(date_diff('minute', order_ts, actual_ts), 0.90), 0) AS p90_actual_min,
       round(quantile_cont(date_diff('minute', order_ts, actual_ts), 0.95), 0) AS p95_actual_min
FROM orders o JOIN geo g ON g.area = o.area GROUP BY zone ORDER BY p90_actual_min DESC;

-- 8.10 Share of orders met under each candidate promise
WITH t AS (SELECT date_diff('minute', order_ts, actual_ts) AS actual_min FROM orders)
SELECT p AS promise_minutes,
       round(100.0 * COUNT(*) FILTER (WHERE actual_min <= p) / COUNT(*), 2) AS orders_met_pct
FROM t, (SELECT unnest([10, 12, 15, 18, 20, 25, 30]) AS p) GROUP BY p ORDER BY p;

-- 8.11 Late delivery model
SELECT is_late_minutes AS late, distance_km, order_hour, revenue, is_weekend,
       CASE WHEN zone = 'South' THEN 1 ELSE 0 END AS zone_south,
       CASE WHEN zone = 'North' THEN 1 ELSE 0 END AS zone_north,
       CASE WHEN zone = 'East'  THEN 1 ELSE 0 END AS zone_east
FROM f_sales WHERE distance_km IS NOT NULL;

-- 9.1 Stock cover against shelf life
SELECT p.product_id, p.product_name, p.category, p.price, p.shelf_life_days,
       p.min_stock_level, p.max_stock_level,
       COALESCE(i.units_sold, 0)        AS units_sold,
       COALESCE(i.revenue, 0)           AS revenue,
       round(i.avg_monthly_demand, 2)   AS avg_monthly_demand,
       round(p.shelf_life_days / 30.44, 2) AS shelf_life_months,
       round(i.stock_cover_months_at_min, 2) AS stock_cover_months
FROM products_src p LEFT JOIN inventory_src i ON i.product_id = p.product_id;

-- 9.1b Demand figures cross-checked against the order data
WITH period AS (SELECT COUNT(DISTINCT date_trunc('month', order_date)) AS months FROM f_sales),
sold AS (SELECT product_id, SUM(quantity) AS units_sold FROM f_sales GROUP BY 1)
SELECT i.product_id, i.units_sold AS units_in_inventory_sheet, s.units_sold AS units_in_orders,
       round(i.avg_monthly_demand, 3) AS demand_in_sheet,
       round(s.units_sold * 1.0 / (SELECT months FROM period), 3) AS demand_recomputed
FROM inventory_src i JOIN sold s ON s.product_id = i.product_id;

-- 10.1 Payment method performance
SELECT payment_method, COUNT(*) AS orders,
       round(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS order_share_pct,
       round(SUM(revenue), 0) AS revenue,
       round(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share_pct,
       round(AVG(revenue), 0) AS avg_order_value,
       round(AVG(rating), 2) AS avg_rating,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct
FROM f_sales GROUP BY 1 ORDER BY revenue DESC;

-- 10.2 Payment method by customer label
SELECT customer_segment AS label,
       COUNT(*) FILTER (WHERE payment_method = 'Cash')   AS cash,
       COUNT(*) FILTER (WHERE payment_method = 'Card')   AS card,
       COUNT(*) FILTER (WHERE payment_method = 'UPI')    AS upi,
       COUNT(*) FILTER (WHERE payment_method = 'Wallet') AS wallet,
       round(100.0 * COUNT(*) FILTER (WHERE payment_method = 'Cash') / COUNT(*), 1) AS cash_share_pct
FROM f_sales GROUP BY 1 ORDER BY label;

-- 10.3 Payment mix by zone
SELECT zone, COUNT(*) AS orders,
       round(100.0 * COUNT(*) FILTER (WHERE payment_method = 'Cash') / COUNT(*), 1)   AS cash_pct,
       round(100.0 * COUNT(*) FILTER (WHERE payment_method = 'UPI') / COUNT(*), 1)    AS upi_pct,
       round(100.0 * COUNT(*) FILTER (WHERE payment_method = 'Card') / COUNT(*), 1)   AS card_pct,
       round(100.0 * COUNT(*) FILTER (WHERE payment_method = 'Wallet') / COUNT(*), 1) AS wallet_pct,
       round(AVG(revenue), 0) AS aov
FROM f_sales GROUP BY zone ORDER BY orders DESC;

-- 10.4 Payment method against order value band
SELECT payment_method, order_value_segment, COUNT(*) AS orders FROM f_sales GROUP BY 1, 2;

-- 10.5 Payment share over time
SELECT strftime(order_month, '%Y-%m') AS month,
       round(100.0 * COUNT(*) FILTER (WHERE payment_method = 'UPI') / COUNT(*), 1)  AS upi_pct,
       round(100.0 * COUNT(*) FILTER (WHERE payment_method = 'Cash') / COUNT(*), 1) AS cash_pct,
       round(100.0 * COUNT(*) FILTER (WHERE payment_method = 'Card') / COUNT(*), 1) AS card_pct,
       round(100.0 * COUNT(*) FILTER (WHERE payment_method = 'Wallet') / COUNT(*), 1) AS wallet_pct
FROM f_sales GROUP BY order_month ORDER BY order_month;

-- 11.1 Rating distribution
SELECT rating, COUNT(*) AS reviews,
       round(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct,
       round(AVG(revenue), 0) AS avg_order_value,
       round(AVG(delay_min), 2) AS avg_minutes_vs_promise
FROM f_sales WHERE rating IS NOT NULL GROUP BY rating ORDER BY rating;

-- 11.2 Sentiment by feedback topic
SELECT feedback_category AS topic, COUNT(*) AS reviews,
       COUNT(*) FILTER (WHERE sentiment = 'Positive') AS positive,
       COUNT(*) FILTER (WHERE sentiment = 'Neutral')  AS neutral,
       COUNT(*) FILTER (WHERE sentiment = 'Negative') AS negative,
       round(100.0 * COUNT(*) FILTER (WHERE sentiment = 'Negative') / COUNT(*), 1) AS negative_pct,
       round(AVG(rating), 2) AS avg_rating
FROM f_sales WHERE feedback_category IS NOT NULL GROUP BY 1 ORDER BY negative_pct DESC;

-- 11.3 Rating by delivery status
SELECT delivery_status, COUNT(*) AS reviews, round(AVG(rating), 3) AS avg_rating,
       round(stddev_samp(rating), 3) AS sd_rating,
       round(100.0 * COUNT(*) FILTER (WHERE rating <= 2) / COUNT(*), 2) AS low_rating_pct,
       round(100.0 * COUNT(*) FILTER (WHERE sentiment = 'Negative') / COUNT(*), 2) AS negative_pct
FROM f_sales WHERE rating IS NOT NULL GROUP BY 1 ORDER BY avg_rating DESC;

-- 11.5 Rating by delay band
SELECT CASE WHEN delay_min <= 0 THEN 'a. on or before promise'
            WHEN delay_min <= 10 THEN 'b. 1-10 minutes late'
            WHEN delay_min <= 20 THEN 'c. 11-20 minutes late'
            ELSE 'd. more than 20 minutes late' END AS delay_band,
       COUNT(*) AS reviews, round(AVG(rating), 3) AS avg_rating,
       round(100.0 * COUNT(*) FILTER (WHERE sentiment = 'Negative') / COUNT(*), 2) AS negative_pct
FROM f_sales WHERE rating IS NOT NULL GROUP BY 1 ORDER BY 1;

-- 11.6 Rating by category and by zone
SELECT category, round(AVG(rating), 3) AS avg_rating, COUNT(*) AS reviews,
       round(100.0 * COUNT(*) FILTER (WHERE rating <= 2) / COUNT(*), 2) AS low_rating_pct
FROM f_sales WHERE rating IS NOT NULL GROUP BY 1 ORDER BY avg_rating DESC;

-- 11.7 Repeat behaviour of customers who left a low rating
WITH low AS (SELECT DISTINCT customer_id FROM f_sales WHERE rating <= 2),
o AS (SELECT customer_id, COUNT(DISTINCT order_id) AS orders FROM f_sales GROUP BY 1)
SELECT CASE WHEN l.customer_id IS NULL THEN 'no low rating given' ELSE 'gave a rating of 1 or 2' END AS customer_group,
       COUNT(*) AS customers, round(AVG(o.orders), 2) AS avg_orders,
       round(100.0 * COUNT(*) FILTER (WHERE o.orders >= 2) / COUNT(*), 2) AS repeat_rate_pct
FROM o LEFT JOIN low l ON l.customer_id = o.customer_id GROUP BY 1;

-- 12.1 Orders by hour
SELECT order_hour, COUNT(*) AS orders, round(SUM(revenue), 0) AS revenue,
       round(AVG(revenue), 0) AS aov,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct,
       round(AVG(delay_min), 2) AS avg_minutes
FROM f_sales GROUP BY order_hour ORDER BY order_hour;

-- 12.2 Time slots corrected for slot length
WITH s AS (
  SELECT order_time_slot, COUNT(*) AS orders, SUM(revenue) AS revenue,
         COUNT(DISTINCT order_hour) AS hours_in_slot FROM f_sales GROUP BY 1)
SELECT order_time_slot AS slot, hours_in_slot, orders,
       round(100.0 * orders / SUM(orders) OVER (), 2) AS order_share_pct,
       round(orders * 1.0 / hours_in_slot, 1) AS orders_per_hour,
       round(revenue, 0) AS revenue,
       round(revenue / hours_in_slot, 0) AS revenue_per_hour
FROM s ORDER BY orders_per_hour DESC;

-- 12.3 Orders by day of week
SELECT order_day_of_week AS day, COUNT(*) AS orders,
       COUNT(DISTINCT order_date) AS calendar_days,
       round(COUNT(*) * 1.0 / COUNT(DISTINCT order_date), 1) AS orders_per_day,
       round(SUM(revenue), 0) AS revenue, round(AVG(revenue), 0) AS aov,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct
FROM f_sales GROUP BY 1 ORDER BY orders_per_day DESC;

-- 12.4 Weekday against weekend
SELECT order_date, is_weekend, COUNT(*) AS orders, SUM(revenue) AS revenue
FROM f_sales GROUP BY 1, 2;

-- 12.5 Demand map by day and hour
SELECT order_day_of_week AS day, order_hour, COUNT(*) AS orders FROM f_sales GROUP BY 1, 2;

-- 12.6 Three-hour rolling demand window
WITH h AS (SELECT order_hour, COUNT(*) AS orders FROM f_sales GROUP BY 1),
w AS (SELECT order_hour, orders,
             SUM(orders) OVER (ORDER BY order_hour ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS rolling_3h_orders
      FROM h)
SELECT order_hour AS window_centre_hour, orders, rolling_3h_orders,
       RANK() OVER (ORDER BY rolling_3h_orders DESC) AS window_rank
FROM w ORDER BY window_rank LIMIT 8;

-- 13.1 Zone summary
SELECT zone, COUNT(DISTINCT state) AS states, COUNT(DISTINCT area) AS cities,
       COUNT(*) AS orders, COUNT(DISTINCT customer_id) AS customers,
       round(SUM(revenue), 0) AS revenue,
       round(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share_pct,
       round(AVG(revenue), 0) AS aov,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct,
       round(AVG(rating), 2) AS avg_rating
FROM f_sales GROUP BY zone ORDER BY revenue DESC;

-- 13.2 State level metrics
WITH cust AS (
  SELECT state, customer_id, COUNT(DISTINCT order_id) AS orders FROM f_sales GROUP BY 1, 2)
SELECT s.state, any_value(s.zone) AS zone,
       COUNT(*) AS orders, COUNT(DISTINCT s.customer_id) AS customers,
       round(SUM(s.revenue), 0) AS revenue,
       round(100 * SUM(s.revenue) / SUM(SUM(s.revenue)) OVER (), 2) AS revenue_share_pct,
       round(AVG(s.revenue), 0) AS aov,
       round(100.0 * COUNT(*) FILTER (WHERE s.is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct,
       round(AVG(s.rating), 2) AS avg_rating,
       round(100.0 * (SELECT COUNT(*) FROM cust c WHERE c.state = s.state AND c.orders >= 2)
             / NULLIF((SELECT COUNT(*) FROM cust c WHERE c.state = s.state), 0), 2) AS repeat_rate_pct
FROM f_sales s GROUP BY s.state ORDER BY revenue DESC;

-- 13.5 City tier performance
SELECT city_tier, COUNT(DISTINCT area) AS cities, COUNT(*) AS orders,
       round(SUM(revenue), 0) AS revenue, round(AVG(revenue), 0) AS aov,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct,
       round(AVG(rating), 2) AS avg_rating
FROM f_sales GROUP BY city_tier ORDER BY revenue DESC;

-- 13.6 Top cities
SELECT area AS city, any_value(state) AS state, COUNT(*) AS orders,
       round(SUM(revenue), 0) AS revenue, round(AVG(revenue), 0) AS aov,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct
FROM f_sales GROUP BY area HAVING COUNT(*) >= 20 ORDER BY revenue DESC LIMIT 15;

-- 14.1 Concentration of revenue in large orders
SELECT CASE WHEN revenue >= 1000 THEN 'order of 1000 and above' ELSE 'order below 1000' END AS order_group,
       COUNT(*) AS orders, round(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS order_share_pct,
       round(SUM(revenue), 0) AS revenue,
       round(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share_pct,
       round(100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*), 2) AS on_time_pct,
       round(AVG(delay_min), 2) AS avg_minutes, round(AVG(rating), 2) AS avg_rating
FROM f_sales GROUP BY 1;

-- 14.2 Revenue at risk from late large orders
SELECT CASE WHEN revenue >= 1000 THEN 'large order' ELSE 'small order' END AS order_group,
       round(SUM(revenue) FILTER (WHERE delay_min > 0), 0)  AS revenue_delivered_late,
       round(SUM(revenue) FILTER (WHERE delay_min > 10), 0) AS revenue_more_than_10_min_late,
       COUNT(*) FILTER (WHERE delay_min > 10) AS orders_more_than_10_min_late
FROM f_sales GROUP BY 1;

-- 14.3 Do high-value customers stay high-value
WITH halves AS (
  SELECT customer_id,
         SUM(revenue) FILTER (WHERE order_date <  DATE '2024-03-01') AS spend_first_half,
         SUM(revenue) FILTER (WHERE order_date >= DATE '2024-03-01') AS spend_second_half
  FROM f_sales GROUP BY customer_id),
ranked AS (
  SELECT *, NTILE(5) OVER (ORDER BY spend_first_half DESC) AS quintile_first_half
  FROM halves WHERE spend_first_half IS NOT NULL)
SELECT quintile_first_half, COUNT(*) AS customers,
       round(AVG(spend_first_half), 0) AS avg_spend_first_half,
       round(AVG(COALESCE(spend_second_half, 0)), 0) AS avg_spend_second_half,
       round(100.0 * COUNT(*) FILTER (WHERE spend_second_half IS NOT NULL) / COUNT(*), 2) AS still_active_pct
FROM ranked GROUP BY 1 ORDER BY 1;

-- 15.4 Category demand forecast with backtesting
SELECT category, order_month, SUM(quantity) AS units FROM f_sales
WHERE order_month BETWEEN DATE '2023-04-01' AND DATE '2024-10-01' GROUP BY 1, 2 ORDER BY 1, 2;

-- 15.8 Correlation between order level measures
SELECT revenue, quantity, price, mrp, distance_km, delay_min, rating, order_hour, shelf_life_days FROM f_sales;

-- 16.6 Cohort retention
WITH first_order AS (SELECT customer_id, date_trunc('month', MIN(order_date)) AS cohort FROM f_sales GROUP BY 1),
activity AS (SELECT f.cohort, date_diff('month', f.cohort, s.order_month) AS month_index, s.customer_id
             FROM f_sales s JOIN first_order f ON f.customer_id = s.customer_id)
SELECT cohort, month_index, COUNT(DISTINCT customer_id) AS customers FROM activity GROUP BY 1, 2;

-- 16.9 On-time rate by state
SELECT state, COUNT(*) AS orders,
       100.0 * COUNT(*) FILTER (WHERE is_on_time_status = 1) / COUNT(*) AS on_time
FROM f_sales GROUP BY 1 HAVING COUNT(*) >= 30 ORDER BY on_time;

-- 17.1 Summary of findings
WITH c AS (SELECT customer_id, COUNT(DISTINCT order_id) o, SUM(revenue) s FROM f_sales GROUP BY 1) SELECT 100.0*SUM(s) FILTER (WHERE o>=2)/SUM(s) AS v FROM c;

-- 17.1 Summary of findings
WITH s AS (SELECT customer_id, order_date, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) rn, LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) prev FROM (SELECT DISTINCT customer_id, order_date FROM f_sales)) SELECT median(date_diff('day', prev, order_date)) AS v FROM s WHERE rn = 2;

-- 17.1 Summary of findings
WITH s AS (SELECT order_time_slot, COUNT(*) o, COUNT(DISTINCT order_hour) h FROM f_sales GROUP BY 1) SELECT MIN(o/h) AS a, MAX(o/h) AS b FROM s;

-- 17.2 Export analysis outputs
SELECT strftime(order_month,'%Y-%m') AS month, COUNT(DISTINCT order_id) AS orders,
         round(SUM(revenue),2) AS revenue, round(SUM(margin_value),2) AS margin FROM f_sales GROUP BY 1 ORDER BY 1;

-- 17.2 Export analysis outputs
SELECT category, COUNT(DISTINCT order_id) AS orders, round(SUM(revenue),2) AS revenue,
         round(SUM(margin_value),2) AS margin FROM f_sales GROUP BY 1 ORDER BY revenue DESC;
