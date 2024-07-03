-- A. Customer Nodes Exploration
-- 1. How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id)
FROM customer_nodes;

-- 2. What is the number of nodes per region?
SELECT region_name, COUNT(DISTINCT node_id)
FROM customer_nodes
LEFT JOIN regions
ON regions.region_id = customer_nodes.region_id
GROUP BY region_name
ORDER BY region_name;

-- 3. How many customers are allocated to each region?
SELECT region_name, COUNT(DISTINCT customer_id)
FROM customer_nodes
LEFT JOIN regions
ON regions.region_id = customer_nodes.region_id
GROUP BY region_name
ORDER BY region_name;
-- 4. How many days on average are customers reallocated to a different node?
-- Steps:
-- We can use the lead function to get the next node id and keep only the ones where ids dont match
-- Then we calculate the days between start_date and end_date and get the average 
WITH cte_next_node AS (
SELECT customer_id, node_id, SUM(DATEDIFF(end_date, start_date)) AS day_difference 
FROM customer_nodes
WHERE end_date != '9999-12-31'
GROUP BY customer_id, node_id)

SELECT AVG(day_difference)
FROM cte_next_node;

-- B. Customer Transactions
-- 1. What is the unique count and total amount for each transaction type?
SELECT txn_type, COUNT(*), SUM(txn_amount)
FROM customer_transactions
GROUP BY txn_type;

-- 2. What is the average total historical deposit counts and amounts for all customers?
WITH cte_average AS 
(SELECT customer_id, COUNT(*) AS deposit_count, AVG(txn_amount) AS average_amount
FROM customer_transactions
WHERE txn_type = 'deposit'
GROUP BY customer_id)

SELECT AVG(deposit_count), AVG(average_amount)
FROM cte_average;

-- 3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
WITH cte_monthly_actions AS
(SELECT customer_id, MONTH(txn_date) AS month_txn_date,
SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count,
SUM(CASE WHEN txn_type != 'deposit' THEN 1 ELSE 0 END) AS purchase_or_withdrawal_count
FROM customer_transactions
GROUP BY customer_id, MONTH(txn_date)
HAVING deposit_count>1 AND purchase_or_withdrawal_count=1)

SELECT month_txn_date, COUNT(DISTINCT customer_id)
FROM cte_monthly_actions
GROUP BY month_txn_date;
-- 4. What is the closing balance for each customer at the end of the month?
-- Steps:
-- Create a new column that multiples by -1 for withdrawal and purchase
-- Then calculate the rolling sum, this should only be grouped by customer_id
-- Give it a row number, row_number should be 1 for the last transaction of the month
-- Get the rows where row number is 1 
WITH cte AS 
(SELECT *, SUM(money_change) OVER(PARTITION BY customer_id ORDER BY txn_date) AS balance,
ROW_NUMBER() OVER(PARTITION BY customer_id, MONTH(txn_date) ORDER BY txn_date DESC) as rn
FROM
	(SELECT customer_id, txn_date, MONTH(txn_date) as mth, txn_amount,
	CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE txn_amount*(-1) END AS money_change
	FROM customer_transactions
	ORDER BY customer_id, txn_date) sub_money_change)

SELECT customer_id, mth, balance
FROM cte
WHERE rn=1
ORDER BY customer_id, mth;

-- 5. What is the percentage of customers who increase their closing balance by more than 5%?
-- Get the rolling sum as the last question 
-- Calculate first_value and last_value for each customer
-- Calculate the growth 
WITH cte AS 
(SELECT *, SUM(money_change) OVER(PARTITION BY customer_id ORDER BY txn_date) AS balance
FROM
	(SELECT customer_id, txn_date, MONTH(txn_date) as mth, txn_amount,
	CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE txn_amount*(-1) END AS money_change
	FROM customer_transactions
	WHERE customer_id = 429
	ORDER BY customer_id, txn_date) sub_money_change)

SELECT *,
FIRST_VALUE(balance) OVER(PARTITION BY customer_id ORDER BY txn_date) as first_balance,
LAST_VALUE(balance) OVER(PARTITION BY customer_id ORDER BY txn_date RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as last_balance
FROM cte


-- C. Data Allocation Challenge
-- To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:

-- Option 1: data is allocated based off the amount of money at the end of the previous month
-- Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
-- Option 3: data is updated real-time
-- For this multi-part challenge question - you have been requested to generate the following data elements to help the Data Bank team estimate how much data will need to be provisioned for each option:
-- running customer balance column that includes the impact each transaction
-- customer balance at the end of each month
-- minimum, average and maximum values of the running balance for each customer
-- Using all of the data available - how much data would have been required for each option on a monthly basis?