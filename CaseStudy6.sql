-- 1. How many users are there?
SELECT COUNT(DISTINCT user_id)
FROM clique_bait.users;
-- 2. How many cookies does each user have on average?
-- Steps:
-- Get the count of cookies for each user
-- Get the average of the count 
SELECT AVG(count_cookies)
FROM 
(SELECT COUNT(DISTINCT cookie_id) AS count_cookies
FROM clique_bait.users
GROUP BY user_id) sub_count;

-- 3. What is the unique number of visits by all users per month?
-- Steps:
-- Count the unique number visit_id 
-- Group it by month 
SELECT EXTRACT(MONTH FROM event_time) AS month_event, COUNT(DISTINCT visit_id)
FROM clique_bait.events
GROUP BY EXTRACT(MONTH FROM event_time);

-- 4. What is the number of events for each event type?
SELECT event_type, COUNT(visit_id)
FROM clique_bait.events
GROUP BY event_type;

-- 5. What is the percentage of visits which have a purchase event?
-- Steps:
-- Number of unique visits where purchase event is 3 / Total number of unique visits 
-- Nominator we can use SUM(CASE WHEN) --> actually no
-- Using sum(case when) in this case will not regard a unique purchase event
SELECT 
100*COUNT(DISTINCT visit_id)/(SELECT COUNT(DISTINCT visit_id) FROM clique_bait.events) AS percentage_purchase_event
FROM clique_bait.events
WHERE event_type = 3;

-- 6. What is the percentage of visits which view the checkout page but do not have a purchase event?
-- Steps:
-- Nominator: Number of unique visits that viewed the checkout page without purchase event 
-- Denominator: Number of unique visits that viewed the checkout page
WITH checkout_purchase AS (
SELECT 
  visit_id,
  MAX(CASE WHEN event_type = 1 AND page_id = 12 THEN 1 ELSE 0 END) AS checkout,
  MAX(CASE WHEN event_type = 3 THEN 1 ELSE 0 END) AS purchase
FROM clique_bait.events
GROUP BY visit_id)

SELECT 
  ROUND(100 * (1-(SUM(purchase)::numeric/SUM(checkout))),2) AS percentage_checkout_view_with_no_purchase
FROM checkout_purchase;

-- 7. What are the top 3 pages by number of views?
-- Steps:
-- Count the number of event_type = 1 for each page_id 
SELECT page_id, COUNT(visit_id)
FROM clique_bait.events
WHERE event_type = 1
GROUP BY page_id
ORDER BY COUNT(visit_id) DESC
LIMIT 3;

-- 8. What is the number of views and cart adds for each product category?
SELECT product_category,
SUM(CASE WHEN event_type = 1 THEN 1 ELSE 0 END) AS count_views,
SUM(CASE WHEN event_type = 2 THEN 1 ELSE 0 END) AS count_card_adds
FROM clique_bait.events
LEFT JOIN clique_bait.page_hierarchy 
USING (page_id)
WHERE product_category IS NOT NULL
GROUP BY product_category;

-- 9. What are the top 3 products by purchases?
SELECT page_name, COUNT(DISTINCT visit_id) as purchase_count
FROM clique_bait.events
LEFT JOIN clique_bait.page_hierarchy 
USING (page_id)
WHERE visit_id IN 
(
SELECT visit_id
FROM clique_bait.events
LEFT JOIN clique_bait.page_hierarchy 
USING (page_id)
WHERE event_type = 3
) AND product_category IS NOT NULL
GROUP BY page_name;

-- 3. Product Funnel Analysis
-- Using a single SQL query - create a new output table which has the following details:
-- How many times was each product viewed?
-- How many times was each product added to cart?
-- How many times was each product added to a cart but not purchased (abandoned)?
-- How many times was each product purchased?

-- Note 1 - In product_page_events CTE, find page views and cart adds for individual visit ids by wrapping SUM around CASE statements so that we do not have to group the results by event_type as well.
-- Note 2 - In purchase_events CTE, get only visit ids that have made purchases.
-- Note 3 - In combined_table CTE, merge product_page_events and purchase_events using LEFT JOIN. Take note of the table sequence. In order to filter for visit ids with purchases, we use a CASE statement and where visit id is not null, it means the visit id is a purchase.
WITH product_page_events AS ( -- Note 1
  SELECT 
    e.visit_id,
    ph.product_id,
    ph.page_name AS product_name,
    ph.product_category,
    SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS page_view, -- 1 for Page View
    SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_add -- 2 for Add Cart
  FROM clique_bait.events AS e
  JOIN clique_bait.page_hierarchy AS ph
    ON e.page_id = ph.page_id
  WHERE product_id IS NOT NULL
  GROUP BY e.visit_id, ph.product_id, ph.page_name, ph.product_category
),
purchase_events AS ( -- Note 2
  SELECT 
    DISTINCT visit_id
  FROM clique_bait.events
  WHERE event_type = 3 -- 3 for Purchase
),
combined_table AS ( -- Note 3
  SELECT 
    ppe.visit_id, 
    ppe.product_id, 
    ppe.product_name, 
    ppe.product_category, 
    ppe.page_view, 
    ppe.cart_add,
    CASE WHEN pe.visit_id IS NOT NULL THEN 1 ELSE 0 END AS purchase
  FROM product_page_events AS ppe
  LEFT JOIN purchase_events AS pe
    ON ppe.visit_id = pe.visit_id
),
product_info AS (
  SELECT 
    product_name, 
    product_category, 
    SUM(page_view) AS views,
    SUM(cart_add) AS cart_adds, 
    SUM(CASE WHEN cart_add = 1 AND purchase = 0 THEN 1 ELSE 0 END) AS abandoned,
    SUM(CASE WHEN cart_add = 1 AND purchase = 1 THEN 1 ELSE 0 END) AS purchases
  FROM combined_table
  GROUP BY product_id, product_name, product_category)

SELECT *
FROM product_info
ORDER BY product_id;

-- Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.
WITH product_page_events AS ( -- Note 1
  SELECT 
    e.visit_id,
    ph.product_id,
    ph.page_name AS product_name,
    ph.product_category,
    SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS page_view, -- 1 for Page View
    SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_add -- 2 for Add Cart
  FROM clique_bait.events AS e
  JOIN clique_bait.page_hierarchy AS ph
    ON e.page_id = ph.page_id
  WHERE product_id IS NOT NULL
  GROUP BY e.visit_id, ph.product_id, ph.page_name, ph.product_category
),
purchase_events AS ( -- Note 2
  SELECT 
    DISTINCT visit_id
  FROM clique_bait.events
  WHERE event_type = 3 -- 3 for Purchase
),
combined_table AS ( -- Note 3
  SELECT 
    ppe.visit_id, 
    ppe.product_id, 
    ppe.product_name, 
    ppe.product_category, 
    ppe.page_view, 
    ppe.cart_add,
    CASE WHEN pe.visit_id IS NOT NULL THEN 1 ELSE 0 END AS purchase
  FROM product_page_events AS ppe
  LEFT JOIN purchase_events AS pe
    ON ppe.visit_id = pe.visit_id
),
product_category AS (
  SELECT 
    product_category, 
    SUM(page_view) AS views,
    SUM(cart_add) AS cart_adds, 
    SUM(CASE WHEN cart_add = 1 AND purchase = 0 THEN 1 ELSE 0 END) AS abandoned,
    SUM(CASE WHEN cart_add = 1 AND purchase = 1 THEN 1 ELSE 0 END) AS purchases
  FROM combined_table
  GROUP BY product_category)

SELECT *
FROM product_category
-- Use your 2 new output tables - answer the following questions:
-- 1. Which product had the most views, cart adds and purchases?
-- 2. Which product was most likely to be abandoned?
-- 3. Which product had the highest view to purchase percentage?
-- 4. What is the average conversion rate from view to cart add?
-- 5. What is the average conversion rate from cart add to purchase?
