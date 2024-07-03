-- B. Data Analysis Questions
-- 1. How many customers has Foodie-Fi ever had?
SELECT COUNT(DISTINCT customer_id)
FROM subscriptions;

-- 2. What is the monthly distribution of trial plan start_date values for our dataset 
-- - use the start of the month as the group by value
SELECT MONTH(start_date) as month_start, COUNT(*)
FROM subscriptions
WHERE plan_id = 0
GROUP BY month_start
ORDER BY month_start;

-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
-- Steps: 
-- Get the records where the start_date >= 2021-01-01
-- Group by the plan id, count the instances 
-- Join with plans table to get plan name 
SELECT plan_name, COUNT(plan_name)
FROM subscriptions 
LEFT JOIN plans
USING (plan_id)
WHERE start_date >= '2021-01-01' 
GROUP BY plan_name;

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
-- Steps:
-- Churned customer count, all customer count --> percentage 
-- Group by customer_id 
SELECT SUM(CASE WHEN plan_id=4 THEN 1 ELSE 0 END) AS churned_customer_count,
ROUND(SUM(CASE WHEN plan_id=4 THEN 1
ELSE 0 END)*100/COUNT(DISTINCT customer_id),1)
FROM subscriptions; 

-- 5. How many customers have churned straight after their initial free trial 
-- - what percentage is this rounded to the nearest whole number?
-- Steps:
-- Use LEAD to calculate next plan
-- Want to get the ones where plan_id = 0 and next_plan = 4 
-- Get the count of these distinct customer ids and get the percentage 
SELECT COUNT(DISTINCT customer_id) AS churned_imm, 
ROUND(100* COUNT(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions),1) AS percentage
FROM (SELECT *, LEAD(plan_id) OVER(ORDER BY customer_id) AS next_plan
FROM subscriptions) AS lead_table
WHERE plan_id = 0 and next_plan = 4;

-- 6. What is the number and percentage of customer plans after their initial free trial?
SELECT next_plan, COUNT(customer_id) AS converted_customers,
ROUND(100 * COUNT(customer_id)
    / (SELECT COUNT(DISTINCT customer_id) 
      FROM subscriptions) ,1) AS conversion_percentage
FROM (SELECT *, LEAD(plan_id) OVER(PARTITION BY customer_id ORDER BY plan_id) AS next_plan
FROM subscriptions) AS lead_table
WHERE plan_id = 0 AND next_plan IS NOT NULL
GROUP BY next_plan;

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
-- Steps:
-- Lead function again to determine end_date of plan 
-- Use - interval 1 'day' to calculate 

-- Since there are null values, we want to make sure the null values indicate up to today
WITH cte_filtered AS
(SELECT customer_id, plan_id, start_date, 
CASE WHEN end_date IS NULL THEN '2023-12-31'
ELSE end_date END AS end_date_new
FROM 
	(SELECT *, LEAD(start_date - INTERVAL '1' DAY) OVER(PARTITION BY customer_id ORDER BY start_date) AS end_date
	FROM subscriptions) 
	cte_end_date
HAVING '2020-12-31' BETWEEN start_date AND end_date_new
)

SELECT plan_name, COUNT(plan_name), 
ROUND(100*COUNT(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions),1)
FROM cte_filtered 
LEFT JOIN plans
USING (plan_id)
GROUP BY plan_name;

-- 8. How many customers have upgraded to an annual plan in 2020?
-- Steps:
-- Get the count for where it is annual plan and start_date is 2020 
SELECT COUNT(DISTINCT customer_id) AS count_id
FROM subscriptions
LEFT JOIN plans
USING (plan_id)
WHERE plan_name = 'pro annual' AND start_date BETWEEN '2020-01-01' AND '2020-12-31';

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
-- Steps:
-- Get the customers for when plan_id is 0 and is 3 --> subquery in FROM 
-- To do that we can first filter the customers where both plans occur
-- Then we use the lead function to calculate the days in between
-- Take the average as a whole 
WITH cte_days_between AS 
(SELECT *, LEAD(start_date) OVER(PARTITION BY customer_id) AS annual_start_date
FROM 
(SELECT customer_id
FROM subscriptions
WHERE plan_id = 3) annual_plan 
LEFT JOIN subscriptions
USING (customer_id) 
WHERE plan_id = 0 OR plan_id = 3 )

SELECT AVG(DATEDIFF(annual_start_date,start_date))
FROM cte_days_between;

-- Can also use two CTE tables and join
WITH trial_plan AS (
  SELECT 
    customer_id, 
    start_date AS trial_date
  FROM subscriptions
  WHERE plan_id = 0
), annual_plan AS (
  SELECT 
    customer_id, 
    start_date AS annual_date
  FROM subscriptions
  WHERE plan_id = 3
)
SELECT 
  ROUND(
    AVG(
      annual.annual_date - trial.trial_date)
  ,0) AS avg_days_to_upgrade
FROM trial_plan AS trial
JOIN annual_plan AS annual
  ON trial.customer_id = annual.customer_id;
