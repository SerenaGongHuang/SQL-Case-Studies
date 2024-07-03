-- Data Cleansing
DROP TEMPORARY TABLE IF EXISTS clean_weekly_sales;

-- Create the temporary table with the desired transformations
CREATE TEMPORARY TABLE clean_weekly_sales AS
SELECT
  STR_TO_DATE(week_date, '%d/%m/%Y') AS week_date,
  WEEK(STR_TO_DATE(week_date, '%d/%m/%Y')) AS week_number,
  MONTH(STR_TO_DATE(week_date, '%d/%m/%Y')) AS month_number,
  YEAR(STR_TO_DATE(week_date, '%d/%m/%Y')) AS calendar_year,
  region, 
  platform, 
  segment,
  CASE 
    WHEN RIGHT(segment, 1) = '1' THEN 'Young Adults'
    WHEN RIGHT(segment, 1) = '2' THEN 'Middle Aged'
    WHEN RIGHT(segment, 1) IN ('3', '4') THEN 'Retirees'
    ELSE 'unknown' END AS age_band,
  CASE 
    WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
    WHEN LEFT(segment, 1) = 'F' THEN 'Families'
    ELSE 'unknown' END AS demographic,
  transactions,
  ROUND(sales / transactions, 2) AS avg_transaction,
  sales
FROM weekly_sales;

-- 2. Data Exploration
-- 1. What day of the week is used for each week_date value?
-- 2. What range of week numbers are missing from the dataset?
-- 3. How many total transactions were there for each year in the dataset?
SELECT calendar_year, SUM(transactions)
FROM clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;
-- 4. What is the total sales for each region for each month?
SELECT region, month_number, SUM(sales)
FROM clean_weekly_sales
GROUP BY region, month_number
ORDER BY region, month_number;
-- 5. What is the total count of transactions for each platform
SELECT platform, SUM(transactions) AS total_transactions
FROM clean_weekly_sales
GROUP BY platform;
-- 6. What is the percentage of sales for Retail vs Shopify for each month?
WITH cte_monthly_sales AS 
(SELECT calendar_year, month_number, platform, SUM(sales) AS sum_sales
FROM clean_weekly_sales
GROUP BY calendar_year, month_number, platform
ORDER BY calendar_year, month_number, platform)

SELECT calendar_year, month_number,
MAX(CASE WHEN platform ='Retail' THEN sum_sales ELSE NULL END)/SUM(sum_sales) AS retail_percentage,
MAX(CASE WHEN platform ='Shopify' THEN sum_sales ELSE NULL END)/SUM(sum_sales) AS shopify_percentage
FROM cte_monthly_sales
GROUP BY calendar_year, month_number
ORDER BY calendar_year, month_number;

-- 7. What is the percentage of sales by demographic for each year in the dataset?
WITH cte_yearly_sales AS 
(SELECT calendar_year, demographic, SUM(sales) AS sum_sales
FROM clean_weekly_sales
GROUP BY calendar_year, demographic
ORDER BY calendar_year, demographic)

SELECT calendar_year,
MAX(CASE WHEN demographic = 'Couples' THEN sum_sales END)/SUM(sum_sales) AS couples_percent,
MAX(CASE WHEN demographic = 'Families' THEN sum_sales END)/SUM(sum_sales) AS families_percent,
MAX(CASE WHEN demographic = 'unknown' THEN sum_sales END)/SUM(sum_sales) AS unknown_percent
FROM cte_yearly_sales
GROUP BY calendar_year
ORDER BY calendar_year;
-- 8. Which age_band and demographic values contribute the most to Retail sales?
SELECT age_band, demographic, SUM(sales)
FROM clean_weekly_sales
WHERE platform = 'Retail' AND age_band != 'unknown' AND demographic != 'unknown'
GROUP BY age_band, demographic
ORDER BY 3 DESC 
LIMIT 1;
-- 9. Can we use the avg_transaction column to find the average transaction size 
-- for each year for Retail vs Shopify? If not - how would you calculate it instead?
SELECT 
  calendar_year, 
  platform, 
  ROUND(AVG(avg_transaction),0) AS avg_transaction_row, 
  SUM(sales) / sum(transactions) AS avg_transaction_group
FROM clean_weekly_sales
GROUP BY calendar_year, platform
ORDER BY calendar_year, platform;

-- Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.
-- 1. What is the total sales for the 4 weeks before and after 2020-06-15? 
-- What is the growth or reduction rate in actual values and percentage of sales?
WITH packaging_sales AS (
  SELECT 
    week_date, 
    week_number, 
    SUM(sales) AS total_sales
  FROM clean_weekly_sales
  WHERE (week_number BETWEEN 21 AND 28) 
    AND (calendar_year = 2020)
  GROUP BY week_date, week_number
)
, before_after_changes AS (
  SELECT 
    SUM(CASE 
      WHEN week_number BETWEEN 21 AND 24 THEN total_sales END) AS before_packaging_sales,
    SUM(CASE 
      WHEN week_number BETWEEN 25 AND 28 THEN total_sales END) AS after_packaging_sales
  FROM packaging_sales
)

SELECT 
  after_packaging_sales - before_packaging_sales AS sales_variance, 
  ROUND(100 * 
    (after_packaging_sales - before_packaging_sales) 
    / before_packaging_sales,2) AS variance_percentage
FROM before_after_changes;
