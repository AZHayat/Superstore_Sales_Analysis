-- Create the superstore database
CREATE DATABASE superstore;

-- Describe the structure of the orders table
DESCRIBE orders;

-- 1. Sales per Product
-- Display top 10 products with the highest sales based on quantity
SELECT product_name, category, SUM(quantity) AS total_quantity
FROM orders
GROUP BY product_name, category
ORDER BY total_quantity DESC
LIMIT 10;

/*
From the query result, staples have the highest sales.
However, it is recommended to focus promotion efforts on products ranked 2-10,
since staples are already very popular and additional promotions may not yield significant returns.
*/

-- 2. Profit by Category
-- Display total sales and profit by category
SELECT category, SUM(sales) AS total_sale, SUM(ABS(profit)) AS total_profit
FROM orders
GROUP BY category
ORDER BY total_profit DESC, total_sale DESC;

-- Display total sales and profit by sub-category
SELECT category, sub_category, SUM(sales) AS total_sale, SUM(ABS(profit)) AS total_profit
FROM orders
GROUP BY category, sub_category
ORDER BY total_profit DESC, total_sale DESC;

/*
Office supplies show the highest sales. 
To improve performance, focus on promoting furniture, which shows lower sales. 
In the sub-category, storage is performing well, while labels need a push. 
Suggested strategies include discount offers, bundling with high-performing products, or targeted marketing campaigns.
*/

-- 3. Churn Analysis
-- Here, churn is defined as customers who did not make a purchase
SELECT product_name,
	COUNT(product_name) AS total_order,
	COUNT((Returned="Yes")) AS total_returns,
    ROUND((COUNT((Returned="Yes"))/COUNT(*))*100) AS return_rate
FROM orders
LEFT JOIN returns ON OrderID = order_id
GROUP BY product_name
ORDER BY return_rate DESC;

-- Identify products with 100% return rates
WITH return_rates AS (
	SELECT product_name,
		COUNT(product_name) AS total_order,
		COUNT((Returned="Yes")) AS total_returns,
		ROUND((COUNT((Returned="Yes"))/COUNT(*))*100) AS return_rate
	FROM orders
	LEFT JOIN returns ON OrderID = order_id
	GROUP BY product_name
	HAVING return_rate = 100)
SELECT COUNT(product_name) AS total_return_all_product
FROM return_rates;

-- 4. Geographic Sales Analysis
-- Analyze sales and profit across different regions
SELECT region, COUNT(customer_name) AS total_customer, SUM(sales) AS total_sale, ROUND(SUM(abs(profit))) AS total_profit
FROM orders
GROUP BY region
ORDER BY total_profit, total_sale;

/*
Canada shows the lowest total profit, sales, and customer count compared to other regions.
This indicates untapped potential in the Canadian market. 
Focus on improving performance in this area with promotions, marketing campaigns, and improved customer service.
*/

-- 5. Sales Trends Over Time
-- Analyze monthly sales trends over time
WITH month_ly AS (
	SELECT year(str_to_date(order_date, '%m/%d/%Y')) AS year_date,
		MONTH(str_to_date(order_date, '%m/%d/%Y')) AS month_date,
        sales
	FROM orders)
SELECT year_date, month_date, SUM(sales) AS total_sale
FROM month_ly
GROUP BY year_date, month_date;

-- Show sales trends by month across all years
SELECT MONTH(str_to_date(order_date, '%m/%d/%Y')) AS month_date,
        SUM(sales) AS total_sale
FROM orders
GROUP BY month_date;

/*
The sales trend shows a consistent dip in January-February and peaks in November-December.
This could be due to customers making larger purchases during the holiday season.
Promotional strategies should focus on:
1. Maximizing peak sales during November-December.
2. Increasing sales during the slower months (January-February) to balance sales throughout the year.
*/

-- 6. Customer Lifetime Value (CLTV) Analysis
-- Calculate Average Purchase Value
SELECT customer_name, ROUND(AVG(sales),1) AS avg_sales
FROM orders
GROUP BY customer_name;

-- Calculate Purchase Frequency
SELECT customer_name, COUNT(*) AS freq_order
FROM orders
GROUP BY customer_name;

-- Calculate Customer Lifetime (time between first and last purchase)
SELECT customer_name, 
	MIN(str_to_date(order_date, '%m/%d/%Y')) AS first_order,
    MAX(str_to_date(order_date, '%m/%d/%Y')) AS last_order,
    DATEDIFF(MAX(str_to_date(order_date, '%m/%d/%Y')), MIN(str_to_date(order_date, '%m/%d/%Y'))) AS life_time
FROM orders
GROUP BY customer_name;

-- Calculate CLTV
WITH afl AS (
	SELECT customer_name, 
		ROUND(AVG(sales),1) AS avg_sales,
		COUNT(*) AS freq_order,
		DATEDIFF(MAX(str_to_date(order_date, '%m/%d/%Y')), MIN(str_to_date(order_date, '%m/%d/%Y'))) AS life_time
	FROM orders
	GROUP BY customer_name)
SELECT *, (a.avg_sales * a.freq_order * a.life_time) AS CLTV
FROM afl a
ORDER BY CLTV DESC;

/* The CLTV analysis reveals that a select group of high-value customers significantly contributes 
to overall revenue through a combination of high average sales, frequent orders, and long customer lifetimes. 
Focusing on these top customers with targeted retention strategies, personalized offers, 
and exclusive promotions will be key to maintaining and enhancing their engagement. Additionally, 
re-engagement efforts for customers with long lifetimes but lower order frequencies can help increase purchase frequency, 
driving further revenue growth. This approach can ensure that the business maximizes the potential of its most valuable customers. */

-- 7. RFM Segmentation
-- Describe the orders table to understand its structure
DESCRIBE orders;

-- Perform RFM analysis (Recency, Frequency, Monetary) on customers
SELECT customer_name,
       MAX(str_to_date(order_date, '%m/%d/%Y')) AS recency,
       COUNT(*) AS frequency,
       SUM(sales) AS monetary
FROM orders
GROUP BY customer_name;

-- Get the latest order date
SELECT MAX(str_to_date(order_date, '%m/%d/%Y')) AS nowaday
FROM orders;

-- Calculate bins for recency, frequency, and monetary values
SELECT datediff(MAX(recency), MIN(recency)) AS bin_recency,
	(MAX(frequency) - MIN(frequency)) AS bin_frequency,
    (MAX(monetary) - MIN(monetary)) AS bin_monetary
FROM (SELECT customer_name,
       MAX(str_to_date(order_date, '%m/%d/%Y')) AS recency,
       COUNT(*) AS frequency,
       SUM(sales) AS monetary
	FROM orders
    GROUP BY customer_name) AS crfm;

-- Define recency bins based on the previous calculation
WITH nowaday AS (
SELECT MAX(str_to_date(order_date, '%m/%d/%Y')) AS now_date
FROM orders
),
crfm AS (
	SELECT customer_name,
       MAX(str_to_date(order_date, '%m/%d/%Y')) AS recency,
       COUNT(*) AS frequency,
       SUM(sales) AS monetary
	FROM orders
    GROUP BY customer_name),
scoring AS (
SELECT customer_name,
	CASE
		WHEN DATEDIFF(m.now_date, c.recency) <= 90 THEN 5
        WHEN DATEDIFF(m.now_date, c.recency) <= 180 THEN 4
        WHEN DATEDIFF(m.now_date, c.recency) <= 270 THEN 3
        WHEN DATEDIFF(m.now_date, c.recency) <= 360 THEN 2
        ELSE 1
	END AS recency_score,
    
    CASE 
		WHEN c.frequency >= 60 THEN 5
        WHEN c.frequency >= 45 THEN 4
        WHEN c.frequency >= 30 THEN 3
        WHEN c.frequency >= 15 THEN 2
        ELSE 1
	END AS frequency_score,
    
    CASE
		WHEN c.monetary >= 13000 THEN 5
        WHEN c.monetary >= 10000 THEN 4
        WHEN c.monetary >= 7000 THEN 3
        WHEN c.monetary >= 4000 THEN 2
        ELSE 1
	END AS monetary_score
FROM crfm c, nowaday m)
SELECT customer_name, s.recency_score, s.frequency_score, s.monetary_score,
	CASE
		WHEN s.recency_score = 5 AND s.frequency_score = 5 AND s.monetary_score = 5 THEN 'Champion'
		WHEN s.recency_score >= 4 AND s.frequency_score >= 4 THEN 'Loyal Customers'
		WHEN s.recency_score <= 2 AND s.frequency_score >= 4 THEN 'At Risk'
		WHEN s.recency_score = 1 THEN 'Lost Customers'
		ELSE 'Potential Customers'
	END AS segmentation
FROM scoring s
ORDER BY recency_score DESC, frequency_score DESC, monetary_score DESC;

/*
Champion & Loyal Customers: Retain these customers with loyalty programs and rewards.
At Risk: Focus efforts on re-engaging them before they churn.
Lost Customers: Consider offering deep discounts to win them back, but focus more on active customers.
Potential Customers: Nurture them with incentives to encourage loyalty.
*/
