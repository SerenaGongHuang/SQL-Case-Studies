-- A. PIZZA METRICS
-- 0. Clean data
CREATE TABLE customer_orders_temp AS
SELECT 
  order_id, 
  customer_id, 
  pizza_id, 
  CASE
	  WHEN exclusions ='' OR exclusions LIKE 'null' THEN NULL
	  ELSE exclusions
	  END AS exclusions,
  CASE
	  WHEN extras ='' or extras LIKE 'null' THEN NULL
	  ELSE extras
	  END AS extras,
	order_time
FROM pizza_runner.customer_orders;

CREATE TABLE runner_orders_temp AS
SELECT 
  order_id, 
  runner_id,  
  CASE
	  WHEN pickup_time LIKE 'null' THEN ' '
	  ELSE pickup_time
	  END AS pickup_time,
  CASE
	  WHEN distance LIKE 'null' THEN ' '
	  WHEN distance LIKE '%km' THEN TRIM('km' from distance)
	  ELSE distance 
    END AS distance,
  CASE
	  WHEN duration LIKE 'null' THEN ' '
	  WHEN duration LIKE '%mins' THEN TRIM('mins' from duration)
	  WHEN duration LIKE '%minute' THEN TRIM('minute' from duration)
	  WHEN duration LIKE '%minutes' THEN TRIM('minutes' from duration)
	  ELSE duration
	  END AS duration,
  CASE
	  WHEN cancellation NOT LIKE '%Cancellation' THEN NULL
	  ELSE cancellation 
	  END AS cancellation
FROM pizza_runner.runner_orders;

-- 1. How many pizzas were ordered?
SELECT COUNT(*)
FROM customer_orders_temp;

-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT(order_id))
FROM customer_orders_temp;

-- 3. How many successful orders were delivered by each runner?
SELECT 
  runner_id, 
  COUNT(order_id) AS successful_orders
FROM runner_orders_temp
WHERE cancellation IS NULL
GROUP BY runner_id;

-- 4. How many of each type of pizza was delivered?
SELECT 
  pizza_id, 
  COUNT(order_id) AS count_of_pizza
FROM customer_orders_temp c
LEFT JOIN runner_orders_temp r
USING (order_id)
WHERE cancellation IS NULL
GROUP BY pizza_id;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT 
  customer_id, pizza_name,
  COUNT(pizza_name) AS count_of_pizza
FROM customer_orders_temp c
LEFT JOIN pizza_runner.pizza_names n
USING (pizza_id)
GROUP BY customer_id, pizza_name
ORDER BY customer_id, pizza_name;

-- 6. What was the maximum number of pizzas delivered in a single order?
-- Steps:
-- Join runners_order to determine whether delivered or not
-- Count the number of pizzas delivered by each order_id

-- Method 1
WITH delivered AS (SELECT order_id, COUNT(order_id) AS count_pizzas
FROM customer_orders_temp c
LEFT JOIN runner_orders_temp r
USING (order_id)
WHERE cancellation IS NULL
GROUP BY order_id )

SELECT MAX(count_pizzas)
FROM delivered;

-- Method 2
WITH delivered AS 
(SELECT order_id, COUNT(order_id),
        RANK() OVER(ORDER BY COUNT(order_id) DESC) AS ranking
FROM customer_orders_temp c
LEFT JOIN runner_orders_temp r
USING (order_id)
WHERE cancellation IS NULL
GROUP BY order_id)

SELECT *
FROM delivered
WHERE ranking=1;
-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
-- Steps:
-- We can do two case when statements and sum each one
-- First case when: If exclusions is NULL AND extras is NULL then 1 -> no change
-- Second case when: If exclusions is not NULL AND extras is not NULL then 1 -> at least one change

SELECT customer_id, 
SUM(CASE WHEN exclusions IS NULL AND extras IS NULL THEN 1
ELSE 0
END) AS no_change,
SUM(CASE WHEN exclusions IS NOT NULL OR extras IS NOT NULL THEN 1
ELSE 0
END) AS one_plus_change
FROM customer_orders_temp
LEFT JOIN runner_orders_temp r
USING (order_id)
WHERE cancellation IS NULL
GROUP BY customer_id
ORDER BY customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT count(*)
FROM customer_orders_temp
LEFT JOIN runner_orders_temp r
USING (order_id)
WHERE cancellation IS NULL
AND  exclusions IS NOT NULL AND extras IS NOT NULL;

-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT HOUR(order_time) as hour_of_day, COUNT(order_id)
FROM customer_orders_temp
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 10. What was the volume of orders for each day of the week?
SELECT DAYNAME(order_time) as weekday, COUNT(order_id)
FROM customer_orders_temp
GROUP BY weekday
ORDER BY weekday;

-- B. Runner and Customer Experience
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT WEEK(registration_date) as week, COUNT(runner_id)
FROM pizza_runner.runners
GROUP BY week
ORDER BY week;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
-- Steps:
-- Join runner and customer table by order_id
-- Calculate the time
-- Then get average for each runner_id
SELECT runner_id, AVG(TIMESTAMPDIFF(MINUTE, order_time, pickup_time)) AS average_time
FROM customer_orders_temp c
LEFT JOIN runner_orders_temp r
USING (order_id)
WHERE cancellation IS NULL
GROUP BY runner_id;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
-- Steps:
-- For each order, count the number of pizzas, and the average time it takes to prepare
WITH cte_prep AS (SELECT COUNT(order_id) as count_order, TIMESTAMPDIFF(MINUTE, order_time, pickup_time) AS prep_time
FROM customer_orders_temp c
LEFT JOIN runner_orders_temp r
USING (order_id)
WHERE cancellation IS NULL
GROUP BY order_id, prep_time)

SELECT count_order, AVG(prep_time)
FROM cte_prep
GROUP BY count_order;
-- 4. What was the average distance travelled for each customer?
-- Steps:
-- Join customers and runners table together
-- Group by customer_id and avg the distance 
SELECT customer_id, AVG(distance)
FROM customer_orders_temp c
LEFT JOIN runner_orders_temp r
USING (order_id)
WHERE cancellation IS NULL
GROUP BY customer_id
ORDER BY customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
SELECT max(duration)-min(duration) AS difference
FROM runner_orders_temp
WHERE cancellation IS NULL;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
-- Distance/duration 
SELECT order_id, runner_id, AVG(distance/duration) AS avg_speed
FROM runner_orders_temp
WHERE cancellation IS NULL
GROUP BY runner_id, order_id
ORDER BY runner_id, order_id;

-- 7. What is the successful delivery percentage for each runner?
SELECT runner_id, SUM(CASE WHEN cancellation IS NULL THEN 1 ELSE 0 END)/COUNT(runner_id) AS percentage
FROM runner_orders_temp
GROUP BY runner_id;
