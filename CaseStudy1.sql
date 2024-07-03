/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- Steps:
-- Join sales table with menu table 
-- Group by customer and calculate the sum of the price
SELECT s.customer_id, sum(price) AS customer_spent
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.menu m 
USING (product_id)
GROUP BY customer_id
ORDER BY customer_id;

-- 2. How many days has each customer visited the restaurant?
-- Steps:
-- Get the count of distinct order_date for each customer
SELECT customer_id, COUNT(DISTINCT(order_date))
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
-- Steps:
-- Sort order_date by ascending order
-- Use window function to get a rank of purchased products for each customer 
-- Join menus table to get specific item purchased by customer
-- Use that as a CTE table so we can get records where rank is 1
-- To insure no duplicates, group by all variables
WITH ranked AS
(
SELECT customer_id, 
		order_date,
        s.product_id,
 		product_name,
        RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS ranking
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.menu m
USING (product_id)
)

SELECT customer_id, product_name
FROM ranked
WHERE ranking=1
GROUP BY customer_id, product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- Steps:
-- Calculate the counts of the products by grouping them together
-- To eliminate the case where there's a tie, rank the counts and output rank=1
WITH ranked AS
(
SELECT product_id, COUNT(product_id) AS count_product, 
  RANK() OVER(ORDER BY COUNT(product_id) DESC) AS ranking
FROM dannys_diner.sales
GROUP BY product_id
ORDER BY count_product DESC
)

SELECT r.product_id, product_name, count_product
FROM ranked r
LEFT JOIN dannys_diner.menu m
USING (product_id)
WHERE ranking=1;

-- 5. Which item was the most popular for each customer?
-- Steps:
-- Get the number of counts for each product for each customer
-- Get the rank that is partitioned by customer
-- Use that as a CTE and then get rank=1
WITH ranked AS 
(
SELECT customer_id, product_id, COUNT(product_id) as count_product, 
  RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(product_id)) AS ranking
FROM dannys_diner.sales
GROUP BY customer_id, product_id
ORDER BY customer_id ASC, count_product DESC
)

SELECT customer_id, product_name
FROM ranked r
LEFT JOIN dannys_diner.menu m 
USING (product_id)
WHERE ranking=1
ORDER BY customer_id;

-- 6. Which item was purchased first by the customer after they became a member?
-- Steps:
-- Join the members table and get records where the order_date >= member date
-- Sort by order_date, group by customer and get a rank 
WITH ranked AS
(SELECT s.customer_id, order_date, product_id, join_date,
RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS ranking
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.members mm
USING (customer_id)
WHERE join_date <= order_date)

SELECT customer_id, product_name
FROM ranked r
LEFT JOIN dannys_diner.menu m 
USING (product_id)
WHERE ranking=1
ORDER BY customer_id;

-- 7. Which item was purchased just before the customer became a member?
-- The same as last question but order_date < join_date and descending the order_date
WITH ranked AS
(SELECT s.customer_id, order_date, product_id, join_date,
RANK() OVER(PARTITION BY customer_id ORDER BY order_date DESC) AS ranking
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.members mm
USING (customer_id)
WHERE join_date > order_date)

SELECT customer_id, product_name
FROM ranked r
LEFT JOIN dannys_diner.menu m 
USING (product_id)
WHERE ranking=1
ORDER BY customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
-- Steps:
-- Join all tables together to get price and member info
-- Calculate count of items and sum or prices for customers before they became a member
SELECT customer_id, COUNT(product_id), SUM(price)
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.members mm
USING (customer_id)
LEFT JOIN dannys_diner.menu m
USING (product_id)
WHERE join_date > order_date
GROUP BY customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- Steps:
-- Join price table
-- Use case when for the points calculation
-- Use that as a CTE to get the sum of the points for each customer
WITH points AS (SELECT customer_id, 
	CASE WHEN product_name='sushi' THEN price*20
    ELSE price*10
    END AS points
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.menu m
USING (product_id)
ORDER BY customer_id)

SELECT customer_id, SUM(points)
FROM points
GROUP BY customer_id
ORDER BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
-- Steps:
-- Get a column that calculates a week after the join date using interval
-- Add another case when for when order_date is between the join_date and new date 
-- Inner join members since we only want to know customer A and B
WITH week AS
(
SELECT s.customer_id, s.product_id, product_name, price, order_date, join_date, 
join_date + INTERVAL '6' DAY AS week_later
FROM dannys_diner.sales s
INNER JOIN dannys_diner.members mm
USING (customer_id)
LEFT JOIN dannys_diner.menu m
USING (product_id)
WHERE order_date < '2021-02-01'
)

SELECT 	customer_id,
	SUM(CASE WHEN product_name='sushi' THEN price*20
    WHEN order_date BETWEEN join_date AND week_later THEN price*20
    ELSE price*10
    END) AS total_points
FROM week
GROUP BY customer_id;

-- BONUS1
SELECT s.customer_id, order_date, product_name, price, 
	CASE WHEN join_date IS NULL THEN 'N'
    WHEN join_date > order_date THEN 'N'
	ELSE 'Y' END AS member
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.members mm
USING (customer_id)
LEFT JOIN dannys_diner.menu m
USING (product_id)
ORDER BY s.customer_id, order_date;

-- BONUS2
WITH member_cte AS 
(
SELECT s.customer_id, order_date, product_name, price, 
	CASE WHEN join_date IS NULL THEN 'N'
    WHEN join_date > order_date THEN 'N'
	ELSE 'Y' END AS member
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.members mm
USING (customer_id)
LEFT JOIN dannys_diner.menu m
USING (product_id)
ORDER BY s.customer_id, order_date
)

SELECT customer_id, order_date, product_name, price, member,
	CASE WHEN member='Y' THEN
		RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date) 
    ELSE NULL 
    END AS ranking
FROM member_cte