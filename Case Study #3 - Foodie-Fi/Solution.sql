-- A. Customer Journey
-- This code picks 8 customer_ids at random and shows when each of the picked customers subscribed to the corresponding plan as well as how many days their subscription lasted. Null values mean the corresponding plan has never been cancelled.

SELECT customer_id, p.plan_name, start_date, 
LEAD (start_date) OVER (
	PARTITION BY customer_id ORDER BY customer_id, start_date) - start_date AS time_on_plan
FROM foodie_fi.plans p
JOIN foodie_fi.subscriptions s
ON p.plan_id = s.plan_id
WHERE customer_id IN (SELECT customer_id FROM foodie_fi.subscriptions
					  ORDER BY RANDOM() 
					  LIMIT 8);

-- How many customers has Foodie-Fi ever had?

SELECT COUNT (DISTINCT customer_id) FROM foodie_fi.subscriptions;

-- What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value

WITH cte AS
(SELECT customer_id, p.plan_id, 
 TO_CHAR (start_date,'Month') AS month_name,
 EXTRACT (Month FROM start_date) AS month_num
FROM foodie_fi.subscriptions s
JOIN foodie_fi.plans p
ON s.plan_id = p.plan_id)
SELECT month_name, COUNT (customer_id)
FROM cte
WHERE plan_id = 0
GROUP BY month_name, month_num
ORDER BY month_num;

-- What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

SELECT COUNT (customer_id), plan_name FROM foodie_fi.plans p
JOIN foodie_fi.subscriptions s
ON p.plan_id = s.plan_id
WHERE EXTRACT (year from start_date) > 2020
GROUP BY plan_name
ORDER BY count;

-- What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

WITH cte AS
(SELECT plan_id, customer_id AS churned FROM foodie_fi.subscriptions
WHERE plan_id = 4
GROUP BY plan_id, customer_id)
SELECT COUNT (DISTINCT churned), 
ROUND (COUNT (DISTINCT churned)/CAST (
	COUNT (DISTINCT s.customer_id) AS decimal)*100, 1) 
FROM cte
RIGHT JOIN foodie_fi.subscriptions s
ON cte.plan_id = s.plan_id;

-- How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?

WITH cte AS
(SELECT customer_id, plan_id, 
RANK () OVER (PARTITION BY customer_id ORDER BY plan_id) ranking
FROM foodie_fi.subscriptions)
SELECT COUNT (customer_id), 
ROUND (COUNT (DISTINCT customer_id)/CAST (
	(SELECT COUNT (DISTINCT customer_id) 
FROM foodie_fi.subscriptions) AS decimal)*100, 0) percentage
FROM cte
WHERE plan_id = 4 AND ranking = 2;

-- What is the number and percentage of customer plans after their initial free trial?

WITH cte AS
(SELECT customer_id, plan_id, 
RANK () OVER (PARTITION BY customer_id ORDER BY plan_id) ranking
FROM foodie_fi.subscriptions)
SELECT plan_name, COUNT (customer_id), 
ROUND (COUNT (DISTINCT customer_id)/CAST (
	(SELECT COUNT (DISTINCT customer_id) 
	 FROM foodie_fi.subscriptions) AS decimal)*100, 0) percentage 
FROM cte
JOIN foodie_fi.plans p
ON cte.plan_id = p.plan_id
WHERE ranking = 2
GROUP BY plan_name
ORDER BY count DESC;

-- What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

WITH cte AS
(SELECT DISTINCT ON (customer_id) customer_id, plan_id, RANK () OVER (
	PARTITION BY customer_id ORDER BY start_date DESC)
FROM foodie_fi.subscriptions
WHERE start_date <= to_timestamp ('31-12-2020', 'DD-MM-YYYY'))
SELECT plan_name, COUNT (customer_id) FROM cte
JOIN foodie_fi.plans p
ON cte.plan_id = p.plan_id
WHERE rank = 1
GROUP BY plan_name, rank, cte.plan_id
ORDER BY cte.plan_id;

-- How many customers have upgraded to an annual plan in 2020?

SELECT COUNT (*) FROM foodie_fi.plans p
JOIN foodie_fi.subscriptions s
ON p.plan_id = s.plan_id
WHERE s.plan_id = 3 AND EXTRACT (year FROM s.start_date) = 2020;

-- How many days on average does it take for a customer to upgrade to an annual plan from the day they join Foodie-Fi?

WITH cte AS
(SELECT 
LEAD (start_date) OVER (
	PARTITION BY customer_id ORDER BY customer_id, start_date) - start_date AS time_on_plan
FROM foodie_fi.plans p
JOIN foodie_fi.subscriptions s
ON p.plan_id = s.plan_id
WHERE p.plan_id = 0 OR p.plan_id = 3)
SELECT ROUND (AVG (time_on_plan)) FROM cte;

 -- How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

WITH cte AS
(SELECT customer_id, plan_id, start_date,
RANK () OVER (PARTITION BY customer_id ORDER BY plan_id) ranking
FROM foodie_fi.subscriptions)
SELECT COUNT (customer_id)
FROM cte
WHERE EXTRACT (year FROM start_date) = 2020 AND
((plan_id = 1 AND ranking = 3) OR (plan_id = 1 AND ranking = 4));
