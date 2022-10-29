-- Cleaning the data

UPDATE pizza_runner.customer_orders
SET exclusions = CASE
WHEN exclusions = '' THEN NULL 
 	WHEN exclusions = 'null' THEN NULL 
  	ELSE exclusions
	END,
extras = CASE
	WHEN extras = '' THEN NULL 
 	WHEN extras = 'null' THEN NULL 
  	ELSE extras
	END;

UPDATE pizza_runner.runner_orders
SET pickup_time = CASE
	WHEN pickup_time = '' THEN NULL 
 	WHEN pickup_time = 'null' THEN NULL
	ELSE pickup_time
	END,
distance = CASE
	WHEN distance = '' THEN NULL 
 	WHEN distance = 'null' THEN NULL
	ELSE distance
	END,
duration = CASE
	WHEN duration = '' THEN NULL 
 	WHEN duration = 'null' THEN NULL
	ELSE duration
	END,
cancellation = CASE
	WHEN cancellation = '' THEN NULL 
 	WHEN cancellation = 'null' THEN NULL
	ELSE cancellation
	END;

UPDATE pizza_runner.runner_orders
SET distance = CASE
	WHEN distance LIKE '%km' THEN TRIM ('km' FROM distance)
	ELSE distance
	END;

UPDATE pizza_runner.runner_orders
SET duration = CASE
	WHEN duration LIKE '%minutes' 
THEN TRIM ('minutes' FROM duration)
	WHEN duration LIKE '%mins' 
THEN TRIM ('mins' FROM duration)
	WHEN duration LIKE '%minute' 
THEN TRIM ('minute' FROM duration)
	ELSE duration
	END;

ALTER TABLE pizza_runner.runner_orders
	ALTER COLUMN pickup_time TYPE timestamp USING pickup_time::timestamp without time zone,
	ALTER COLUMN distance TYPE numeric USING distance::numeric(4,1),
	ALTER COLUMN duration TYPE int USING duration::integer;
-- A. Pizza Metrics
-- 1. How many pizzas were ordered?
SELECT COUNT (*) FROM pizza_runner.customer_orders;
-- How many unique customer orders were made?
SELECT COUNT (DISTINCT order_id) FROM pizza_runner.customer_orders;
-- How many successful orders were delivered by each runner?
SELECT COUNT (DISTINCT order_id) FROM pizza_runner.runner_orders
WHERE pickup_time IS NOT NULL
GROUP BY runner_id;
-- How many of each type of pizza was delivered?
SELECT COUNT (pizza_name) FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders
ON customer_orders.order_id = runner_orders.order_id
JOIN pizza_runner.pizza_names
ON customer_orders.pizza_id = pizza_names.pizza_id
WHERE pickup_time IS NOT NULL
GROUP BY pizza_name;
-- How many Vegetarian and Meatlovers were ordered by each customer?
SELECT customer_id, pizza_name, COUNT (pizza_name) FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders
ON customer_orders.order_id = runner_orders.order_id
JOIN pizza_runner.pizza_names
ON customer_orders.pizza_id = pizza_names.pizza_id
WHERE pickup_time IS NOT NULL
GROUP BY customer_id, pizza_name
ORDER BY customer_id;
-- 2-й вариант
SELECT
  customer_id,
  SUM (CASE 
	  WHEN pizza_name = 'Meatlovers' 
	  THEN 1 
	  ELSE 0 
	  END
	 ) AS "Meatlovers",
  SUM (CASE 
	  WHEN pizza_name = 'Vegetarian' 
	  THEN 1 
	  ELSE 0 
	  END
	 ) AS "Vegetarian"
FROM pizza_runner.customer_orders
JOIN pizza_runner.pizza_names
ON customer_orders.pizza_id = pizza_names.pizza_id
GROUP BY customer_id
ORDER BY customer_id;
-- What was the maximum number of pizzas delivered in a single order?
SELECT customer_orders.order_id, COUNT (customer_orders.order_id) FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders
ON customer_orders.order_id = runner_orders.order_id
WHERE cancellation IS NULL
GROUP BY customer_orders.order_id
ORDER BY count DESC;
-- For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT customer_id,
SUM (CASE 
	 WHEN exclusions IS NOT NULL OR extras IS NOT NULL
	 THEN 1
	ELSE 0
	END) AS Change,
SUM (CASE
	 WHEN exclusions IS NULL AND extras IS NULL
	 THEN 1
	 ELSE 0
	END) as No_change
FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders
ON customer_orders.order_id = runner_orders.order_id
WHERE runner_orders.cancellation IS NULL
GROUP BY customer_id;
-- How many pizzas were delivered that had both exclusions and extras?
SELECT customer_id,
SUM (CASE 
	 WHEN exclusions IS NOT NULL AND extras IS NOT NULL
	 THEN 1
	ELSE 0
	END) AS Change
FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders
ON customer_orders.order_id = runner_orders.order_id
WHERE runner_orders.cancellation IS NULL
GROUP BY customer_id;
-- What was the total volume of pizzas ordered for each hour of the day?
SELECT EXTRACT (hour FROM order_time) AS Hour,
COUNT (order_id) 
FROM pizza_runner.customer_orders
GROUP BY Hour
ORDER BY Hour;
-- What was the volume of orders for each day of the week?
SELECT to_char (order_time, 'Day') AS day_of_week, 
EXTRACT (DOW FROM order_time) AS day_order,
COUNT (order_id) 
FROM pizza_runner.customer_orders
GROUP BY day_of_week, day_order
ORDER BY day_order;
-- How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT to_char (registration_date, 'W') AS week, COUNT (runner_id)
FROM pizza_runner.runners
GROUP BY week
ORDER BY week;
 -- What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pick up the order?
WITH cte AS 
(SELECT runner_id,
date_trunc ('minute',pickup_time - order_time) AS diff
FROM pizza_runner.runner_orders
JOIN pizza_runner.customer_orders
ON runner_orders.order_id = customer_orders.order_id
WHERE pickup_time IS NOT NULL
GROUP BY runner_id, diff
ORDER BY runner_id)
SELECT runner_id, AVG (diff)
FROM cte
GROUP BY runner_id;
-- Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH cte AS
(SELECT customer_orders.order_id, COUNT (customer_orders.order_id) as pizza_count,
date_trunc ('minute', pickup_time - order_time) AS diff
FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders
ON customer_orders.order_id = runner_orders.order_id
GROUP BY customer_orders.order_id, diff)
SELECT pizza_count, AVG (diff) AS time_to_prepare
FROM cte
GROUP BY pizza_count
ORDER BY pizza_count;
-- What was the average distance travelled for each customer?
SELECT customer_id, ROUND (AVG (distance),1) FROM pizza_runner.runner_orders
JOIN pizza_runner.customer_orders
ON runner_orders.order_id = customer_orders.order_id
GROUP BY customer_id
ORDER BY customer_id;
-- What was the difference between the longest and shortest delivery times for all orders?
SELECT (MAX (duration) - MIN (duration)) AS diff
FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders
ON customer_orders.order_id = runner_orders.order_id;
-- What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT order_id, runner_id, 
ROUND (distance/(CAST (duration as decimal)/60*100)*100,1) AS speed
FROM pizza_runner.runner_orders
WHERE duration IS NOT NULL
ORDER BY runner_id, order_id;
-- What is the successful delivery percentage for each runner?
WITH cte AS
(SELECT runner_id,
 CAST (SUM (CASE WHEN distance != 0
	  THEN 1
	  ELSE 0
	  END) as decimal) AS success,
CAST (COUNT (order_id) AS decimal) AS total_orders
FROM pizza_runner.runner_orders
GROUP BY runner_id)
SELECT runner_id, ROUND (success/total_orders*100,1) AS success_del
FROM cte
ORDER BY runner_id;
-- What are the standard ingredients for each pizza?
WITH cte AS
(SELECT pizza_name, cast (string_to_table (toppings,',') AS integer) AS topping_id
FROM pizza_runner.pizza_recipes
JOIN pizza_runner.pizza_names
ON pizza_recipes.pizza_id = pizza_names.pizza_id)
SELECT pizza_name, string_agg (topping_name, ', ') AS com_ingr FROM cte
JOIN pizza_runner.pizza_toppings
ON pizza_toppings.topping_id = cte.topping_id
GROUP BY pizza_name;
-- What was the most commonly added extra?
WITH cte AS
(SELECT CAST (string_to_table (extras, ',') AS integer) AS extras_added 
FROM pizza_runner.customer_orders)
SELECT topping_name, COUNT (extras_added)
FROM cte
JOIN pizza_runner.pizza_toppings
ON extras_added = pizza_toppings.topping_id
GROUP BY topping_name
ORDER BY count DESC;
-- What was the most common exclusion?
WITH cte AS
(SELECT CAST (string_to_table (exclusions, ',') AS integer) AS exclusions_ordered 
FROM pizza_runner.customer_orders)
SELECT topping_name, COUNT (exclusions_ordered)
FROM cte
JOIN pizza_runner.pizza_toppings
ON exclusions_ordered = pizza_toppings.topping_id
GROUP BY topping_name
ORDER BY count DESC;
-- What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH cte AS
(SELECT *, CAST (string_to_table (toppings,',') AS integer) AS topping_id_toppings,
CAST (string_to_table (exclusions,',') AS integer) AS topping_id_exclusions,
CAST (string_to_table (extras,',') AS integer) AS topping_id_extras
FROM pizza_runner.pizza_recipes
JOIN pizza_runner.pizza_names
ON pizza_recipes.pizza_id = pizza_names.pizza_id
JOIN pizza_runner.customer_orders
ON pizza_recipes.pizza_id = customer_orders.pizza_id)
SELECT topping_name, COUNT (topping_id_toppings) - 
COUNT (topping_id_exclusions) + 
COUNT (topping_id_extras) AS num_toppings
FROM cte
JOIN pizza_runner.pizza_toppings
ON pizza_toppings.topping_id = cte.topping_id_toppings
GROUP BY topping_name
ORDER BY num_toppings DESC; 
-- If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
SELECT
SUM (CASE 
	  WHEN pizza_id = 1 
	  THEN 12
	  WHEN pizza_id = 2 
	  THEN 10 
	  END) AS "pizza_paid"
FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders
ON customer_orders.order_id = runner_orders.order_id
WHERE cancellation IS NULL;
-- What if there was an additional $1 charge for any pizza extras?
WITH cte AS
(SELECT order_id, rank() over(partition by order_id ORDER BY string_to_table (extras,',')) as extras_paid
FROM pizza_runner.customer_orders)
SELECT COUNT (extras_paid) +
SUM (CASE 
	  WHEN pizza_id = 1 
	  THEN 12
	  WHEN pizza_id = 2 
	  THEN 10 
	  END) AS "pizza_paid"
FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders
ON customer_orders.order_id = runner_orders.order_id
LEFT JOIN cte
ON customer_orders.order_id = cte.order_id
WHERE cancellation IS NULL
AND (extras_paid IS NULL OR extras_paid = 1);
