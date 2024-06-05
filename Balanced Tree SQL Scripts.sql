-- HIGH LEVEL SALES ANALYSIS:

#1. What was the total quantity sold for all products?


SELECT SUM(qty) AS total_quantity
FROM balanced_tree.sales;


#2. Total quantity sold for each product category:

SELECT 
    details.product_name,
    SUM(sales.qty) AS sale_counts
FROM balanced_tree.sales AS sales
INNER JOIN balanced_tree.product_details AS details
    ON sales.prod_id = details.product_id
GROUP BY details.product_name
ORDER BY sale_counts DESC;


#3. What is the total generated revenue for all products before discounts?


SELECT SUM(qty * price) AS total_revenue 
FROM balanced_tree.sales;


#4. What was the total discount amount for all products?


SELECT ROUND(SUM(qty * price * discount / 100), 2) AS total_discount
FROM balanced_tree.sales;


-- TRANSACTION ANALYSIS:

#1. How many unique transactions were there?


SELECT COUNT(DISTINCT txn_id) AS unique_transaction
FROM balanced_tree.sales;


#2. What is the average unique products purchased in each transaction?


WITH cte AS (
    SELECT txn_id, COUNT(DISTINCT prod_id) AS unique_products
    FROM balanced_tree.sales
    GROUP BY txn_id
)
SELECT ROUND(AVG(unique_products), 1) AS avg_unique_products
FROM cte;


#3. What are the 25th, 50th, and 75th percentile values for the revenue per transaction?


with cte_1 as (
	  select txn_id, qty , price,
	   row_number() over(partition by txn_id order by price) as row_num,
	   count(*) over(partition by txn_id) as product_count
	   from sales ) ,

cte_2 as (
       select * ,
       floor(product_count *0.25) as 25th_percentile_index, 
       floor(product_count *0.5) as 50th_percentile_index,
       floor(product_count *0.275) as 75th_percentile_index
	   from cte_1 ),

cte_3 as (
         select txn_id , (qty*price) as 25th_percentile_revenue
         from cte_2
		 where row_num = 25th_percentile_index ),
         
cte_4 as (
         select txn_id , (qty*price) as 50th_percentile_revenue
         from cte_2
		 where row_num = 50th_percentile_index ), 
         
cte_5 as (
         select txn_id , (qty*price) as 75th_percentile_revenue
         from cte_2
		 where row_num = 75th_percentile_index )

select c3.txn_id , 25th_percentile_revenue , 50th_percentile_revenue , 75th_percentile_revenue
from cte_3 AS c3
inner join cte_4 AS c4 using(txn_id)
inner join cte_5 As c5 using(txn_id) ;      
      


#4. What is the average discount value per transaction?


WITH cte AS (
    SELECT txn_id, ROUND(SUM(qty * price * discount / 100), 2) AS discount_value
    FROM balanced_tree.sales
    GROUP BY txn_id
)
SELECT ROUND(AVG(discount_value), 2) AS avg_discount_value
FROM cte;


#5. What is the percentage split of all transactions for members vs non-members?


WITH SalesSummary AS (
    SELECT
        member_m,
        COUNT(*) AS member_count
    FROM
        sales
    GROUP BY
        member_m
)

SELECT
    IF(member_m = "t", "Members", "Non-members") AS type_of_members,
    ROUND(member_count * 100 / (SELECT COUNT(*) FROM sales), 1) AS prcnt
FROM
    SalesSummary;


#6. What is the average revenue for member transactions and non-member transactions?


WITH cte_member_revenue AS (
    SELECT
        member,
        txn_id,
        SUM(price * qty) AS revenue
    FROM balanced_tree.sales
    GROUP BY 
        member, 
        txn_id
)
SELECT
    member,
    ROUND(AVG(revenue), 2) AS avg_revenue
FROM cte_member_revenue
GROUP BY member;


-- PRODUCT ANALYSIS:

#1. What are the top 3 products by total revenue before discount?


SELECT s.prod_id, d.product_name, SUM(s.qty * s.price) AS total_revenue
FROM balanced_tree.sales AS s
JOIN balanced_tree.product_details AS d ON d.product_id = s.prod_id
GROUP BY s.prod_id, d.product_name
ORDER BY total_revenue DESC
LIMIT 3;


#2. What is the total quantity, revenue, and discount for each segment?


WITH qty_details AS (
    SELECT segment_name, SUM(s.qty) AS total_qty 
    FROM balanced_tree.sales AS s
    JOIN balanced_tree.product_details p ON p.product_id = s.prod_id
    GROUP BY segment_name
),
revenue_details AS (
    SELECT segment_name, SUM(s.qty * s.price) AS total_revenue
    FROM balanced_tree.sales AS s
    JOIN balanced_tree.product_details p ON p.product_id = s.prod_id
    GROUP BY segment_name
),
discount_details AS (
    SELECT segment_name, ROUND(SUM(s.qty * s.price * s.discount / 100), 2) AS total_discount
    FROM balanced_tree.sales AS s
    JOIN balanced_tree.product_details p ON p.product_id = s.prod_id
    GROUP BY segment_name
)
SELECT q.segment_name, q.total_qty, r.total_revenue, d.total_discount
FROM qty_details AS q
JOIN revenue_details AS r USING (segment_name)
JOIN discount_details AS d USING (segment_name);


#3. What is the top selling product for each segment?


WITH cte1 AS (
    SELECT p.product_name, p.segment_name, SUM(s.qty) AS sold_quantity
    FROM balanced_tree.product_details AS p 
    JOIN balanced_tree.sales AS s ON s.prod_id = p.product_id
    GROUP BY p.product_name, p.segment_name
),
cte2 AS (
    SELECT *,
           DENSE_RANK() OVER(PARTITION BY segment_name ORDER BY sold_quantity DESC) AS rnk
    FROM cte1
)
SELECT segment_name, product_name, sold_quantity
FROM cte2
WHERE rnk = 1;


#4. What is the total quantity, revenue, and discount for each category?


SELECT 
    details.category_id,
    details.category_name,
    SUM(sales.qty) AS total_quantity,
    SUM(sales.qty * sales.price) AS total_revenue,
    ROUND(SUM(sales.qty * sales.price * sales.discount) / 100, 2) AS total_discount
FROM balanced_tree.sales AS sales
INNER JOIN balanced_tree.product_details AS details
    ON sales.prod_id = details.product_id
GROUP BY details.category_id, details.category_name
ORDER BY total_revenue DESC;


#5. What is the top selling product for each category?


WITH cte1 AS (
    SELECT p.product_name, p.category_name, SUM(s.qty) AS sold_quantity
    FROM balanced_tree.product_details AS p 
    JOIN balanced_tree.sales AS s ON s.prod_id = p.product_id
    GROUP BY p.product_name, p.category_name
),
cte2 AS (
    SELECT *,
           DENSE_RANK() OVER(PARTITION BY category_name ORDER BY sold_quantity DESC) AS rnk
    FROM cte1
)
SELECT category_name, product_name, sold_quantity
FROM cte2
WHERE rnk = 1;


#6. What is the percentage split of revenue by product for each segment?


WITH cte1 AS (
    SELECT segment_name, product_name, SUM(s.qty * s.price) AS total_revenue
    FROM balanced_tree.sales AS s 
    JOIN balanced_tree.product_details AS p ON p.product_id = s.prod_id
    GROUP BY segment_name, product_name
    ORDER BY segment_name
),
cte2 AS (
    SELECT *,
           SUM(total_revenue) OVER(PARTITION BY segment_name) AS segment_rev
    FROM cte1
)
SELECT segment_name, product_name, ROUND(total_revenue * 100 / segment_rev, 1) AS prcnt        
FROM cte2;


#7. What is the percentage split of revenue by segment for each category?


WITH cte1 AS (
    SELECT category_name, segment_name, SUM(s.qty * s.price) AS total_revenue
    FROM balanced_tree.sales AS s 
    JOIN balanced_tree.product_details AS p ON p.product_id = s.prod_id
    GROUP BY category_name, segment_name
    ORDER BY category_name
),
cte2 AS (
    SELECT *,
           SUM(total_revenue) OVER(PARTITION BY category_name) AS category_rev
    FROM cte1
)
SELECT category_name, segment_name, ROUND(total_revenue * 100 / category_rev, 1) AS prcnt        
FROM cte2;


#8. What is the percentage split of total revenue by category?


WITH cte1 AS (
    SELECT category_name, SUM(s.qty * s.price) AS total_revenue
    FROM balanced_tree.sales AS s
    JOIN balanced_tree.product_details AS p ON p.product_id = s.prod_id
    GROUP BY category_name
),
cte2 AS (
    SELECT SUM(total_revenue) AS total
    FROM cte1
)
SELECT category_name, ROUND(total_revenue * 100 / (SELECT total FROM cte2), 1) AS prcnt
FROM cte1;


#9. What is the total transaction “penetration” for each product? 
-- (hint: penetration = number of transactions where 
-- at least 1 quantity of a product was purchased 
-- divided by total number of transactions)


WITH cte AS (
    SELECT COUNT(DISTINCT txn_id) AS total_txn
    FROM balanced_tree.sales
)
SELECT p.product_name, 
       ROUND(COUNT(DISTINCT s.txn_id) * 100 / (SELECT total_txn FROM cte), 1) AS penetration
FROM balanced_tree.sales AS s
RIGHT JOIN balanced_tree.product_details AS p ON p.product_id = s.prod_id
WHERE s.qty >= 1
GROUP BY p.product_name;


#10. What is the most common combination of at least 1 quantity of any 3 products in a single transaction?


WITH cte AS (
    SELECT s.prod_id, p.product_name, s.qty, s.price, s.discount, s.member, txn_id, s.start_txn_time
    FROM balanced_tree.sales AS s
    INNER JOIN balanced_tree.product_details p ON p.product_id = s.prod_id
)
SELECT c1.product_name AS first_product, c2.product_name AS second_product, 
       c3.product_name AS third_product, COUNT(*) AS combination_count    
FROM cte AS c1
INNER JOIN cte AS c2 ON c2.txn_id = c1.txn_id AND c1.prod_id < c2.prod_id
INNER JOIN cte AS c3 ON c3.txn_id = c1.txn_id AND c2.prod_id < c3.prod_id
GROUP BY first_product, second_product, third_product
ORDER BY combination_count DESC
LIMIT 1;


-- Bonus question: What is the most common combination of at least 1 quantity of any 3 products in a single transaction?


WITH t AS (
    SELECT h.id AS style_id,
           h.level_text AS style_name,
           t1.id AS segment_id,
           t1.level_text AS segment_name,
           t1.parent_id AS category_id,
           t2.level_text AS category_name
    FROM balanced_tree.product_hierarchy h
    LEFT JOIN balanced_tree.product_hierarchy t1 ON h.parent_id = t1.id
    LEFT JOIN balanced_tree.product_hierarchy t2 ON t1.parent_id = t2.id
    WHERE h.id BETWEEN 7 AND 18
)
SELECT p.product_id,
       p.price,
       CONCAT(t.style_name, ' ', t.segment_name, ' - ', t.category_name) AS product_name,
       t.category_id,
       t.segment_id,
       t.style_id,
       t.category_name,
       t.segment_name,
       t.style_name
FROM balanced_tree.product_prices p
LEFT JOIN t ON p.id = t.style_id;
