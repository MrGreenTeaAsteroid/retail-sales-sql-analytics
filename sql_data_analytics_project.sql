/*
===============================================================================
SQL Data Analytics Project (PostgreSQL Edition)
===============================================================================
A single, self-contained PostgreSQL script covering:
  0. Schema + table creation, helper functions, and data load
  1. Database exploration
  2. Dimensions exploration
  3. Date range exploration
  4. Measures exploration
  5. Magnitude analysis
  6. Ranking analysis
  7. Change-over-time analysis
  8. Cumulative analysis
  9. Performance analysis (YoY)
 10. Data segmentation
 11. Part-to-whole analysis
 12. Customer report (view)
 13. Product report (view)

Run with:  psql -d your_db -f sql_data_analytics_project.sql
(the \copy commands in section 0 expect a "datasets" folder next to this
file, containing dim_customers.csv, dim_products.csv, fact_sales.csv)

Originally written in T-SQL (SQL Server); ported to PostgreSQL syntax:
  TOP n            -> LIMIT n
  GETDATE()        -> CURRENT_DATE
  DATEDIFF(unit,..)-> EXTRACT()/date_trunc()/age() based expressions
  YEAR()/MONTH()   -> EXTRACT(YEAR/MONTH FROM ...)
  DATETRUNC()      -> date_trunc()
  FORMAT()         -> to_char()
  IF OBJECT_ID..GO -> DROP VIEW IF EXISTS
===============================================================================
*/

-- =============================================================================
-- 0. SCHEMA, TABLES, HELPER FUNCTIONS, AND DATA LOAD
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS gold;

DROP TABLE IF EXISTS gold.fact_sales;
DROP TABLE IF EXISTS gold.dim_products;
DROP TABLE IF EXISTS gold.dim_customers;

CREATE TABLE gold.dim_customers (
    customer_key     INT PRIMARY KEY,
    customer_id      INT,
    customer_number  VARCHAR(20),
    first_name       VARCHAR(50),
    last_name        VARCHAR(50),
    country          VARCHAR(50),
    marital_status   VARCHAR(20),
    gender           VARCHAR(20),
    birthdate        DATE,
    create_date      DATE
);

CREATE TABLE gold.dim_products (
    product_key      INT PRIMARY KEY,
    product_id       INT,
    product_number   VARCHAR(20),
    product_name     VARCHAR(100),
    category_id      VARCHAR(20),
    category         VARCHAR(50),
    subcategory      VARCHAR(50),
    maintenance      VARCHAR(10),
    cost             NUMERIC(10, 2),
    product_line     VARCHAR(20),
    start_date       DATE
);

CREATE TABLE gold.fact_sales (
    order_number     VARCHAR(20),
    product_key      INT REFERENCES gold.dim_products(product_key),
    customer_key     INT REFERENCES gold.dim_customers(customer_key),
    order_date       DATE,
    shipping_date    DATE,
    due_date         DATE,
    sales_amount     NUMERIC(10, 2),
    quantity         INT,
    price            NUMERIC(10, 2)
);

-- Helper functions to stand in for T-SQL's DATEDIFF(month/year, ...)
CREATE OR REPLACE FUNCTION gold.months_between(start_date DATE, end_date DATE)
RETURNS INT AS $$
    SELECT (EXTRACT(YEAR FROM age(end_date, start_date)) * 12
            + EXTRACT(MONTH FROM age(end_date, start_date)))::INT;
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION gold.years_between(start_date DATE, end_date DATE)
RETURNS INT AS $$
    SELECT EXTRACT(YEAR FROM age(end_date, start_date))::INT;
$$ LANGUAGE sql IMMUTABLE;

-- Load data (run this script with psql so \copy works; paths are relative
-- to a "datasets" folder placed next to this .sql file)
\copy gold.dim_customers FROM 'datasets/dim_customers.csv' WITH (FORMAT csv, HEADER true)
\copy gold.dim_products  FROM 'datasets/dim_products.csv'  WITH (FORMAT csv, HEADER true)
\copy gold.fact_sales    FROM 'datasets/fact_sales.csv'    WITH (FORMAT csv, HEADER true)


-- =============================================================================
-- 1. DATABASE EXPLORATION
-- =============================================================================

-- Retrieve a list of all tables in the database
SELECT
    table_catalog,
    table_schema,
    table_name,
    table_type
FROM information_schema.tables;

-- Retrieve all columns for a specific table (dim_customers)
SELECT
    column_name,
    data_type,
    is_nullable,
    character_maximum_length
FROM information_schema.columns
WHERE table_name = 'dim_customers';


-- =============================================================================
-- 2. DIMENSIONS EXPLORATION
-- =============================================================================

-- Retrieve a list of unique countries from which customers originate
SELECT DISTINCT
    country
FROM gold.dim_customers
ORDER BY country;

-- Retrieve a list of unique categories, subcategories, and products
SELECT DISTINCT
    category,
    subcategory,
    product_name
FROM gold.dim_products
ORDER BY category, subcategory, product_name;


-- =============================================================================
-- 3. DATE RANGE EXPLORATION
-- =============================================================================

-- Determine the first and last order date and the total duration in months
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    gold.months_between(MIN(order_date), MAX(order_date)) AS order_range_months
FROM gold.fact_sales;

-- Find the youngest and oldest customer based on birthdate
SELECT
    MIN(birthdate) AS oldest_birthdate,
    gold.years_between(MIN(birthdate), CURRENT_DATE) AS oldest_age,
    MAX(birthdate) AS youngest_birthdate,
    gold.years_between(MAX(birthdate), CURRENT_DATE) AS youngest_age
FROM gold.dim_customers;


-- =============================================================================
-- 4. MEASURES EXPLORATION (KEY METRICS)
-- =============================================================================

-- Find the Total Sales
SELECT SUM(sales_amount) AS total_sales FROM gold.fact_sales;

-- Find how many items are sold
SELECT SUM(quantity) AS total_quantity FROM gold.fact_sales;

-- Find the average selling price
SELECT AVG(price) AS avg_price FROM gold.fact_sales;

-- Find the total number of orders
SELECT COUNT(order_number) AS total_orders FROM gold.fact_sales;
SELECT COUNT(DISTINCT order_number) AS total_orders FROM gold.fact_sales;

-- Find the total number of products
SELECT COUNT(product_name) AS total_products FROM gold.dim_products;

-- Find the total number of customers
SELECT COUNT(customer_key) AS total_customers FROM gold.dim_customers;

-- Find the total number of customers that has placed an order
SELECT COUNT(DISTINCT customer_key) AS total_customers FROM gold.fact_sales;

-- Generate a report that shows all key metrics of the business
SELECT 'Total Sales' AS measure_name, SUM(sales_amount) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity', SUM(quantity) FROM gold.fact_sales
UNION ALL
SELECT 'Average Price', AVG(price) FROM gold.fact_sales
UNION ALL
SELECT 'Total Orders', COUNT(DISTINCT order_number) FROM gold.fact_sales
UNION ALL
SELECT 'Total Products', COUNT(DISTINCT product_name) FROM gold.dim_products
UNION ALL
SELECT 'Total Customers', COUNT(customer_key) FROM gold.dim_customers;


-- =============================================================================
-- 5. MAGNITUDE ANALYSIS
-- =============================================================================

-- Find total customers by countries
SELECT
    country,
    COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;

-- Find total customers by gender
SELECT
    gender,
    COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY gender
ORDER BY total_customers DESC;

-- Find total products by category
SELECT
    category,
    COUNT(product_key) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;

-- What is the average cost in each category?
SELECT
    category,
    AVG(cost) AS avg_cost
FROM gold.dim_products
GROUP BY category
ORDER BY avg_cost DESC;

-- What is the total revenue generated for each category?
SELECT
    p.category,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;

-- What is the total revenue generated by each customer?
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY total_revenue DESC;

-- What is the distribution of sold items across countries?
SELECT
    c.country,
    SUM(f.quantity) AS total_sold_items
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY total_sold_items DESC;


-- =============================================================================
-- 6. RANKING ANALYSIS
-- =============================================================================

-- Which 5 products generate the highest revenue?
-- Simple ranking
SELECT
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC
LIMIT 5;

-- Complex but flexible ranking using window functions
SELECT *
FROM (
    SELECT
        p.product_name,
        SUM(f.sales_amount) AS total_revenue,
        RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_products
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.product_name
) AS ranked_products
WHERE rank_products <= 5;

-- What are the 5 worst-performing products in terms of sales?
SELECT
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_revenue
LIMIT 5;

-- Find the top 10 customers who have generated the highest revenue
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY total_revenue DESC
LIMIT 10;

-- The 3 customers with the fewest orders placed
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY total_orders
LIMIT 3;


-- =============================================================================
-- 7. CHANGE OVER TIME ANALYSIS
-- =============================================================================

-- Analyze sales performance over time
-- Quick date functions
SELECT
    EXTRACT(YEAR FROM order_date)::INT AS order_year,
    EXTRACT(MONTH FROM order_date)::INT AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
ORDER BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date);

-- date_trunc()
SELECT
    date_trunc('month', order_date) AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY date_trunc('month', order_date)
ORDER BY date_trunc('month', order_date);

-- to_char()
SELECT
    to_char(order_date, 'YYYY-Mon') AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY to_char(order_date, 'YYYY-Mon')
ORDER BY to_char(order_date, 'YYYY-Mon');


-- =============================================================================
-- 8. CUMULATIVE ANALYSIS
-- =============================================================================

-- Calculate the total sales per year
-- and the running total of sales over time
SELECT
    order_date,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,
    AVG(avg_price) OVER (ORDER BY order_date) AS moving_average_price
FROM
(
    SELECT
        date_trunc('year', order_date) AS order_date,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY date_trunc('year', order_date)
) t;


-- =============================================================================
-- 9. PERFORMANCE ANALYSIS (YEAR-OVER-YEAR)
-- =============================================================================

/* Analyze the yearly performance of products by comparing their sales
to both the average sales performance of the product and the previous year's sales */
WITH yearly_product_sales AS (
    SELECT
        EXTRACT(YEAR FROM f.order_date)::INT AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY
        EXTRACT(YEAR FROM f.order_date),
        p.product_name
)
SELECT
    order_year,
    product_name,
    current_sales,
    AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
    CASE
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END AS avg_change,
    -- Year-over-Year Analysis
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
    CASE
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS py_change
FROM yearly_product_sales
ORDER BY product_name, order_year;


-- =============================================================================
-- 10. DATA SEGMENTATION ANALYSIS
-- =============================================================================

/* Segment products into cost ranges and
count how many products fall into each segment */
WITH product_segments AS (
    SELECT
        product_key,
        product_name,
        cost,
        CASE
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM gold.dim_products
)
SELECT
    cost_range,
    COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;

/* Group customers into three segments based on their spending behavior:
    - VIP: Customers with at least 12 months of history and spending more than 5,000.
    - Regular: Customers with at least 12 months of history but spending 5,000 or less.
    - New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group */
WITH customer_spending AS (
    SELECT
        c.customer_key,
        SUM(f.sales_amount) AS total_spending,
        MIN(order_date) AS first_order,
        MAX(order_date) AS last_order,
        gold.months_between(MIN(order_date), MAX(order_date)) AS lifespan
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT
        customer_key,
        CASE
            WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_spending
) AS segmented_customers
GROUP BY customer_segment
ORDER BY total_customers DESC;


-- =============================================================================
-- 11. PART-TO-WHOLE ANALYSIS
-- =============================================================================

-- Which categories contribute the most to overall sales?
WITH category_sales AS (
    SELECT
        p.category,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER () AS overall_sales,
    ROUND((total_sales::NUMERIC / SUM(total_sales) OVER ()) * 100, 2) AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;


-- =============================================================================
-- 12. CUSTOMER REPORT (VIEW)
-- =============================================================================
/*
Purpose:
    - This report consolidates key customer metrics and behaviors.
Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
    2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics: total orders, total sales, total
       quantity purchased, total products, lifespan (in months).
    4. Calculates KPIs: recency, average order value, average monthly spend.
*/

DROP VIEW IF EXISTS gold.report_customers;

CREATE VIEW gold.report_customers AS

WITH base_query AS (
/*---------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
---------------------------------------------------------------------------*/
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        gold.years_between(c.birthdate, CURRENT_DATE) AS age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE order_date IS NOT NULL
),

customer_aggregation AS (
/*---------------------------------------------------------------------------
2) Customer Aggregations: Summarizes key metrics at the customer level
---------------------------------------------------------------------------*/
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        gold.months_between(MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        age
)
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    last_order_date,
    gold.months_between(last_order_date, CURRENT_DATE) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    -- Average Order Value (AOV)
    CASE WHEN total_sales = 0 THEN 0
         ELSE total_sales / total_orders
    END AS avg_order_value,
    -- Average Monthly Spend
    CASE WHEN lifespan = 0 THEN total_sales
         ELSE total_sales / lifespan
    END AS avg_monthly_spend
FROM customer_aggregation;


-- =============================================================================
-- 13. PRODUCT REPORT (VIEW)
-- =============================================================================
/*
Purpose:
    - This report consolidates key product metrics and behaviors.
Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics: total orders, total sales, total
       quantity sold, total customers (unique), lifespan (in months).
    4. Calculates KPIs: recency, average order revenue (AOR), average monthly revenue.
*/

DROP VIEW IF EXISTS gold.report_products;

CREATE VIEW gold.report_products AS

WITH base_query AS (
/*---------------------------------------------------------------------------
1) Base Query: Retrieves core columns from fact_sales and dim_products
---------------------------------------------------------------------------*/
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE order_date IS NOT NULL  -- only consider valid sales dates
),

product_aggregations AS (
/*---------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the product level
---------------------------------------------------------------------------*/
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        gold.months_between(MIN(order_date), MAX(order_date)) AS lifespan,
        MAX(order_date) AS last_sale_date,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        ROUND(AVG(sales_amount::FLOAT / NULLIF(quantity, 0))::NUMERIC, 1) AS avg_selling_price
    FROM base_query
    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
)

/*---------------------------------------------------------------------------
3) Final Query: Combines all product results into one output
---------------------------------------------------------------------------*/
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,
    gold.months_between(last_sale_date, CURRENT_DATE) AS recency_in_months,
    CASE
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,
    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,
    -- Average Order Revenue (AOR)
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_revenue,
    -- Average Monthly Revenue
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_revenue
FROM product_aggregations;
