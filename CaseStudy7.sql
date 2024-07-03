-- High Level Sales Analysis
-- 1. What was the total quantity sold for all products?
SELECT product_name, SUM(qty) AS total_quantity
FROM sales s
LEFT JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY product_name;
-- 2. What is the total generated revenue for all products before discounts?
SELECT product_name, SUM(s.qty*s.price) AS total_revenue
FROM sales s
LEFT JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY product_name;
-- 3. What was the total discount amount for all products
SELECT product_name, SUM(s.qty*s.price*(s.discount/100)) AS total_discount
FROM sales s
LEFT JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY product_name;
-- Transaction Analysis
-- 1. How many unique transactions were there?
SELECT COUNT(DISTINCT txn_id)
FROM sales;
-- 2. What is the average unique products purchased in each transaction?
SELECT AVG(count_unique_products)
FROM
(SELECT COUNT(DISTINCT prod_id) AS count_unique_products
FROM sales
GROUP BY txn_id) AS sub_count;
-- 3. What are the 25th, 50th and 75th percentile values for the revenue per transaction?
-- Create a common table expression to calculate the revenue per transaction
WITH revenue_cte AS (
  SELECT 
    txn_id, 
    SUM(price * qty) AS revenue
  FROM balanced_tree.sales
  GROUP BY txn_id
),
-- Assign row numbers and calculate the count of total rows
revenue_ranks AS (
  SELECT 
    revenue,
    ROW_NUMBER() OVER (ORDER BY revenue) AS row_num,
    COUNT(*) OVER () AS total_rows
  FROM revenue_cte
)
-- Calculate the percentiles
SELECT 
  MAX(CASE WHEN row_num <= 0.25 * total_rows THEN revenue END) AS median_25th,
  MAX(CASE WHEN row_num <= 0.5 * total_rows THEN revenue END) AS median_50th,
  MAX(CASE WHEN row_num <= 0.75 * total_rows THEN revenue END) AS median_75th
FROM revenue_ranks;
-- 4. What is the average discount value per transaction?

-- 5. What is the percentage split of all transactions for members vs non-members?
-- 6. What is the average revenue for member transactions and non-member transactions?