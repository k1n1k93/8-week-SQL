-- 1. What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM (price) AS sum_sales FROM dannys_diner.sales
JOIN dannys_diner.menu
ON dannys_diner.sales.product_id = dannys_diner.menu.product_id
GROUP BY customer_id 
ORDER BY sum_sales DESC;

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT (DISTINCT order_date) AS count_days FROM dannys_diner.sales 
JOIN dannys_diner.menu 
ON dannys_diner.sales.product_id = dannys_diner.menu.product_id
GROUP BY customer_id
ORDER BY count_days DESC;

-- 3. What was the first item from the menu purchased by each customer?

SELECT DISTINCT ON (customer_id)
		   customer_id, product_name, order_date
FROM dannys_diner.sales, dannys_diner.menu
WHERE dannys_diner.sales.product_id = dannys_diner.menu.product_id
ORDER BY customer_id, order_date;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT product_name, COUNT (product_name)
FROM dannys_diner.sales, dannys_diner.menu
WHERE dannys_diner.sales.product_id = dannys_diner.menu.product_id
GROUP BY product_name
ORDER BY count DESC
FETCH FIRST 1 ROWS ONLY;

-- 5. Which item was the most popular for each customer?

WITH pop_item AS 
(SELECT customer_id, product_name, COUNT (product_name),
rank() OVER (PARTITION BY customer_id ORDER BY COUNT (product_name) DESC) AS ranking
FROM dannys_diner.sales 
JOIN dannys_diner.menu 
ON dannys_diner.sales.product_id = dannys_diner.menu.product_id
GROUP BY customer_id, product_name)
SELECT customer_id, product_name, count FROM pop_item WHERE ranking = 1

-- 6. Which item was purchased first by the customer after they became a member?

SELECT DISTINCT ON (sales.customer_id)
			sales.customer_id, menu.product_name, members.join_date, sales.order_date
FROM dannys_diner.sales
JOIN dannys_diner.menu
ON dannys_diner.menu.product_id = dannys_diner.sales.product_id
JOIN dannys_diner.members
ON dannys_diner.sales.customer_id = dannys_diner.members.customer_id
WHERE sales.order_date > members.join_date
ORDER BY sales.customer_id, sales.order_date;

-- 7. Which item was purchased just before the customer became a member?

SELECT DISTINCT ON (sales.customer_id) 
			sales.customer_id, menu.product_name, members.join_date, sales.order_date
FROM dannys_diner.sales
JOIN dannys_diner.menu
ON dannys_diner.menu.product_id = dannys_diner.sales.product_id
JOIN dannys_diner.members
ON dannys_diner.sales.customer_id = dannys_diner.members.customer_id
WHERE members.join_date - sales.order_date  > 0
ORDER BY sales.customer_id, sales.order_date DESC;

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT sales.customer_id, COUNT (sales.product_id), SUM (menu.price) AS total_sum_paid
FROM dannys_diner.sales
JOIN dannys_diner.menu
ON dannys_diner.menu.product_id = dannys_diner.sales.product_id
JOIN dannys_diner.members
ON dannys_diner.sales.customer_id = dannys_diner.members.customer_id
WHERE sales.order_date < members.join_date
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH points AS
(SELECT *, 
CASE 
WHEN product_name = ???sushi??? THEN menu.price*20
ELSE menu.price*10
	END AS points
FROM dannys_diner.menu)
SELECT sales.customer_id, SUM(points) AS points
FROM dannys_diner.sales
JOIN points
ON points.product_id = sales.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH dates AS
(SELECT *, 
  join_date + interval '6 day' AS bonus_till, 
  date_trunc ('day', timestamp '2021-01-31') AS end_jan
 FROM dannys_diner.members)
SELECT sales.customer_id,
		SUM (CASE 
	  WHEN menu.product_id = 1 
		THEN menu.price*20
	  WHEN sales.order_date BETWEEN dates.join_date AND dates.bonus_till 
		THEN menu.price*20
	  ELSE menu.price*10
	  END)
FROM dates
JOIN dannys_diner.sales
ON dates.customer_id = sales.customer_id
JOIN dannys_diner.menu
ON menu.product_id = sales.product_id
WHERE sales.order_date < dates.end_jan
GROUP BY sales.customer_id;

-- Join All the Things

SELECT sales.customer_id, sales.order_date, menu.product_name, menu.price,
		CASE
		WHEN members.join_date > sales.order_date THEN 'N'
		WHEN members.join_date <= sales.order_date THEN 'Y'
		ELSE 'N'
		END AS member
FROM dannys_diner.sales
FULL JOIN dannys_diner.members
ON sales.customer_id = members.customer_id
FULL JOIN dannys_diner.menu
ON sales.product_id = menu.product_id
ORDER BY customer_id, order_date;

-- Rank All the Things

WITH ranking AS
	(SELECT sales.customer_id, sales.order_date, menu.product_name, menu.price,
		CASE
		WHEN members.join_date > sales.order_date THEN 'N'
		WHEN members.join_date <= sales.order_date THEN 'Y'
		ELSE 'N'
		END AS member
	FROM dannys_diner.sales
	FULL JOIN dannys_diner.members
	ON sales.customer_id = members.customer_id
	FULL JOIN dannys_diner.menu
	ON sales.product_id = menu.product_id)
SELECT *,
	CASE
	WHEN member = 'N'
	THEN NULL
	ELSE rank() OVER (PARTITION BY customer_id, member ORDER BY order_date)
	END AS purchase_date_ranking
FROM ranking;
