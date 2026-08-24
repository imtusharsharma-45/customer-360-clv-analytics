/*
=========================================================
PROJECT 3: CUSTOMER 360 & CLV ANALYTICS
SQL ANALYSIS
=========================================================

Database: Customer360
Platform: Microsoft SQL Server

Tables:
1. customers
2. orders
3. order_items
4. products

Objective:
Analyze customer behavior, purchasing patterns,
revenue, RFM metrics, retention and Customer Lifetime Value.

=========================================================
*/


/*
=========================================================
1. DATABASE & TABLE VALIDATION
=========================================================
*/

CREATE DATABASE customer_360;

USE customer_360;

SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

/*
=========================================================
2. ROW COUNT VALIDATION
=========================================================
*/

SELECT 'customers' AS table_name, COUNT(*) AS total_rows
FROM dbo.customers

UNION ALL

SELECT 'orders', COUNT(*)
FROM dbo.orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM dbo.order_items

UNION ALL

SELECT 'products', COUNT(*)
FROM dbo.products;

/*
=========================================================
3. DATA QUALITY CHECKS
=========================================================
*/

--Duplicate Customers
SELECT 
    customer_id,
    COUNT(*) AS duplicate_count
FROM dbo.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

--Duplicate Orders
SELECT 
    order_id,
    COUNT(*) AS duplicate_count
FROM dbo.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

--Missing Customer IDs
SELECT COUNT(*) AS missing_customer_id
FROM dbo.customers
WHERE customer_id IS NULL;

--Missing Order Customer IDs
SELECT COUNT(*) AS missing_order_id
FROM dbo.orders
WHERE customer_id is null;

--Missing Order Dates
SELECT COUNT(*) AS missing_order_count
from dbo.orders
WHERE order_date  IS NULL;

--Missing Product IDs
SELECT COUNT(*) AS missing_product_id
FROM dbo.products
WHERE product_id IS NULL;

--Missing Order Item Product IDs
SELECT 
    COUNT(*) AS missing_product_id
FROM dbo.order_items
WHERE product_id IS NULL;


--Duplicate Products
----Check for duplicate product IDs
SELECT 
    product_id,
    COUNT(*) AS duplicate_count
FROM dbo.products
GROUP BY product_id
HAVING COUNT(*) > 1;


SELECT TOP 5 *
FROM dbo.order_items;

---Check for duplicate order-product combinations
SELECT order_id,
        product_id,
		COUNT(*) AS duplicate_count
		FROM order_items
		GROUP BY order_id,
		         product_id
		HAVING COUNT(*) > 1 ;
	
--Inspect Duplicate Records
SELECT *
FROM dbo.order_items
WHERE order_id = 746978
  AND product_id = 501376;

-- Note:
-- Some order_id + product_id combinations appear multiple times.
-- However, these are not exact duplicate records because
-- unit_price and/or discount values differ.
-- Therefore, no duplicate records were removed.

/*
=========================================================
4. RELATIONSHIP & DATA INTEGRITY VALIDATION
=========================================================
*/

SELECT COUNT(*) AS invalid_customer_orders
FROM dbo.orders o
LEFT JOIN dbo.customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

--Check for order_items without a matching order

SELECT COUNT(*) AS invalid_order_items
FROM dbo.order_items oi
LEFT JOIN dbo.orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

--Check for order_items without a matching product

SELECT COUNT(*) AS invalid_product_items
FROM dbo.order_items oi
LEFT JOIN dbo.products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

/*
=========================================================
5. EXPLORATORY BUSINESS ANALYSIS
=========================================================
*/

--Order Status Distribution
SELECT order_status,
      COUNT(*) AS	total_order
	  FROM orders
	  GROUP BY order_status
	  ORDER BY total_order DESC;

--Calculate total revenue from order items
SELECT
   SUM(quantity * unit_price*(1-discount)) as total_revenue
   FROM dbo.order_items;

--Calculate revenue from delivered orders only
SELECT SUM(quantity*unit_price*(1-discount)) as delivered_revenue
             FROM orders O
			 JOIN order_items oi 
			 ON  o.order_id = oi.order_id
			 WHERE o.order_status = 'delivered';


--Calculate total customers
SELECT COUNT(DISTINCT customer_id) as total_customer
FROM dbo.customers;

---- Calculate customers who have placed at least one order
SELECT 
     COUNT(DISTINCT customer_id) AS customer_with_order
	 from orders;

--Calculate repeat customers (customers with more than one order)
SELECT 
    COUNT(*) AS repeat_customers
FROM (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS total_orders
    FROM dbo.orders
    GROUP BY customer_id
    HAVING COUNT(DISTINCT order_id) > 1
) AS customer_orders;

--Calculate repeat customer rate
SELECT 
    ROUND(
        CAST(7894 AS FLOAT) / 9147 * 100,
        2
    ) AS repeat_customer_rate_percent;


--Calculate average orders per purchasing customer
SELECT 
    ROUND(
        CAST(COUNT(*) AS FLOAT) / 
        COUNT(DISTINCT customer_id),
        2
    ) AS avg_orders_per_customer
FROM dbo.orders;

--Calculate Average Order Value for delivered orders

SELECT 
    ROUND(
        SUM(
            oi.quantity * oi.unit_price * (1 - oi.discount)
        ) 
        / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM dbo.orders o
JOIN dbo.order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered';


--Calculate delivered revenue by product category

SELECT 
    p.category,
    ROUND(
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount)),
        2
    ) AS delivered_revenue
FROM dbo.orders o
JOIN dbo.order_items oi
    ON o.order_id = oi.order_id
JOIN dbo.products p
    ON oi.product_id = p.product_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category
ORDER BY delivered_revenue DESC;

--Calculate delivered revenue by customer state

SELECT 
    c.customer_state,
    ROUND(
        SUM(
            oi.quantity * oi.unit_price * (1 - oi.discount)
        ),
        2
    ) AS delivered_revenue
FROM dbo.orders o
JOIN dbo.customers c
    ON o.customer_id = c.customer_id
JOIN dbo.order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY c.customer_state
ORDER BY delivered_revenue DESC;

--Identify top 10 customers by delivered revenue

SELECT TOP 10
    c.customer_id,
    c.customer_city,
    c.customer_state,
    ROUND(
        SUM(
            oi.quantity * oi.unit_price * (1 - oi.discount)
        ),
        2
    ) AS delivered_revenue
FROM dbo.orders o
JOIN dbo.customers c
    ON o.customer_id = c.customer_id
JOIN dbo.order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY 
    c.customer_id,
    c.customer_city,
    c.customer_state
ORDER BY delivered_revenue DESC;

--Calculate monthly delivered revenue trend

SELECT 
    YEAR(o.order_date) AS order_year,
    MONTH(o.order_date) AS order_month,
    ROUND(
        SUM(
            oi.quantity * oi.unit_price * (1 - oi.discount)
        ),
        2
    ) AS delivered_revenue
FROM dbo.orders o
JOIN dbo.order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY 
    YEAR(o.order_date),
    MONTH(o.order_date)
ORDER BY 
    order_year,
    order_month;

/*
=========================================================
6. CUSTOMER RFM ANALYSIS
=========================================================
*/

--Create customer-level RFM metrics

SELECT 
    o.customer_id,

    DATEDIFF(
        DAY,
        MAX(o.order_date),
        (SELECT MAX(order_date) FROM dbo.orders)
    ) AS recency_days,

    COUNT(DISTINCT o.order_id) AS frequency,

    ROUND(
        SUM(
            oi.quantity * oi.unit_price * (1 - oi.discount)
        ),
        2
    ) AS monetary_value

FROM dbo.orders o
JOIN dbo.order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'Delivered'

GROUP BY o.customer_id

ORDER BY monetary_value DESC;

--Calculate RFM scores using customer-level metrics

WITH CustomerRFM AS (

    SELECT 
        o.customer_id,

        DATEDIFF(
            DAY,
            MAX(o.order_date),
            (SELECT MAX(order_date) FROM dbo.orders)
        ) AS recency_days,

        COUNT(DISTINCT o.order_id) AS frequency,

        SUM(
            oi.quantity * oi.unit_price * (1 - oi.discount)
        ) AS monetary_value

    FROM dbo.orders o
    JOIN dbo.order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'Delivered'

    GROUP BY o.customer_id
),

RFMScore AS (

    SELECT *,
    
        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary_value
        ) AS monetary_score

    FROM CustomerRFM
)

SELECT *
FROM RFMScore
ORDER BY monetary_value DESC;


-- 6.3 Create customer segments based on RFM scores

WITH CustomerRFM AS (

    SELECT 
        o.customer_id,

        DATEDIFF(
            DAY,
            MAX(o.order_date),
            (SELECT MAX(order_date) FROM dbo.orders)
        ) AS recency_days,

        COUNT(DISTINCT o.order_id) AS frequency,

        SUM(
            oi.quantity * oi.unit_price * (1 - oi.discount)
        ) AS monetary_value

    FROM dbo.orders o
    JOIN dbo.order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'Delivered'

    GROUP BY o.customer_id
),

RFMScore AS (

    SELECT *,
    
        6 - NTILE(5) OVER (ORDER BY recency_days ASC) AS recency_score,

        NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,

        NTILE(5) OVER (ORDER BY monetary_value ASC) AS monetary_score

    FROM CustomerRFM
)

SELECT 
    customer_id,
    recency_days,
    frequency,
    ROUND(monetary_value, 2) AS monetary_value,
    recency_score,
    frequency_score,
    monetary_score,

    CASE
        WHEN recency_score >= 4 
         AND frequency_score >= 4 
         AND monetary_score >= 4
            THEN 'Champions'

        WHEN frequency_score >= 4 
         AND monetary_score >= 3
            THEN 'Loyal Customers'

        WHEN recency_score >= 4 
         AND frequency_score >= 3
            THEN 'Potential Loyalists'

        WHEN recency_score <= 2
            THEN 'At Risk'

        ELSE 'Regular Customers'
    END AS customer_segment

FROM RFMScore;

--Customer segment summary

WITH CustomerRFM AS (

    SELECT 
        o.customer_id,

        DATEDIFF(
            DAY,
            MAX(o.order_date),
            (SELECT MAX(order_date) FROM dbo.orders)
        ) AS recency_days,

        COUNT(DISTINCT o.order_id) AS frequency,

        SUM(
            oi.quantity * oi.unit_price * (1 - oi.discount)
        ) AS monetary_value

    FROM dbo.orders o
    JOIN dbo.order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'Delivered'

    GROUP BY o.customer_id
),

RFMScore AS (

    SELECT *,
        6 - NTILE(5) OVER (ORDER BY recency_days ASC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS monetary_score
    FROM CustomerRFM
),

CustomerSegments AS (

    SELECT *,
        CASE
            WHEN recency_score >= 4 
             AND frequency_score >= 4 
             AND monetary_score >= 4
                THEN 'Champions'

            WHEN frequency_score >= 4 
             AND monetary_score >= 3
                THEN 'Loyal Customers'

            WHEN recency_score >= 4 
             AND frequency_score >= 3
                THEN 'Potential Loyalists'

            WHEN recency_score <= 2
                THEN 'At Risk'

            ELSE 'Regular Customers'
        END AS customer_segment

    FROM RFMScore
)

SELECT 
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(AVG(CAST(frequency AS FLOAT)), 2) AS avg_order_frequency,
    ROUND(SUM(monetary_value), 2) AS total_revenue
FROM CustomerSegments
GROUP BY customer_segment
ORDER BY total_revenue DESC;

/*
=========================================================================================================
Key business insight
Champions are the most valuable segment and generate the largest revenue.
At Risk is the largest customer segment, so retention campaigns could be valuable.
Loyal Customers + Champions should be targeted for retention and loyalty programs.
=========================================================================================================
*/

















