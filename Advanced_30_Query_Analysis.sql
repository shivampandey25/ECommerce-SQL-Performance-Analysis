-- ==========================================
-- E-Commerce Database: Advanced Performance Analysis
-- Total Queries: 25
-- RDBMS: SQL Server (T-SQL)
-- ==========================================

-- ==========================================
-- CATEGORY A: SALES & REVENUE PERFORMANCE
-- ==========================================

-- 1. Total revenue and order count by product category
SELECT TOP 10 pct.product_category_name_english AS Category, SUM(oi.price) AS Total_Revenue, COUNT(oi.order_item_id) AS Total_Items_Sold
FROM Order_Items oi
JOIN Products p ON oi.product_id = p.product_id
JOIN Product_Category_Translation pct ON p.product_category_name = pct.product_category_name
GROUP BY pct.product_category_name_english
ORDER BY Total_Revenue DESC;

-- 2. Top 10 highest-grossing individual products
SELECT TOP 10 product_id, SUM(price) AS Total_Revenue, COUNT(order_id) AS Times_Sold
FROM Order_Items
GROUP BY product_id
ORDER BY Total_Revenue DESC;

-- 3. Monthly revenue trends
SELECT YEAR(o.order_purchase_timestamp) AS Order_Year, MONTH(o.order_purchase_timestamp) AS Order_Month, SUM(op.payment_value) AS Monthly_Revenue
FROM Orders o
JOIN Order_Payments op ON o.order_id = op.order_id
WHERE o.order_status = 'delivered'
GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
ORDER BY Order_Year, Order_Month;

-- 4. Day of the week with the most sales volume
SELECT DATENAME(weekday, order_purchase_timestamp) AS Day_Of_Week, COUNT(order_id) AS Total_Orders, SUM(payment_value) AS Total_Revenue
FROM Orders o JOIN Order_Payments op ON o.order_id = op.order_id
GROUP BY DATENAME(weekday, order_purchase_timestamp)
ORDER BY Total_Revenue DESC;

-- 5. Peak ordering hours of the day
SELECT DATEPART(hour, order_purchase_timestamp) AS Hour_Of_Day, COUNT(order_id) AS Total_Orders
FROM Orders
GROUP BY DATEPART(hour, order_purchase_timestamp)
ORDER BY Total_Orders DESC;

-- 6. Average Order Value (AOV) by Category
SELECT pct.product_category_name_english, AVG(op.payment_value) AS Average_Order_Value
FROM Orders o
JOIN Order_Items oi ON o.order_id = oi.order_id
JOIN Order_Payments op ON o.order_id = op.order_id
JOIN Products p ON oi.product_id = p.product_id
JOIN Product_Category_Translation pct ON p.product_category_name = pct.product_category_name
GROUP BY pct.product_category_name_english
ORDER BY Average_Order_Value DESC;

-- 7. Cumulative running total of revenue over time
WITH DailyRevenue AS (
    SELECT CAST(o.order_purchase_timestamp AS DATE) AS Order_Date, SUM(op.payment_value) AS Daily_Total
    FROM Orders o JOIN Order_Payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY CAST(o.order_purchase_timestamp AS DATE)
)
SELECT Order_Date, Daily_Total, SUM(Daily_Total) OVER (ORDER BY Order_Date) AS Cumulative_Revenue
FROM DailyRevenue;

-- ==========================================
-- CATEGORY B: CUSTOMER BEHAVIOR & SEGMENTATION
-- ==========================================

-- 8. High-value customers (Most money spent)
SELECT TOP 10 c.customer_unique_id, SUM(op.payment_value) AS Total_Spent
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id
JOIN Order_Payments op ON o.order_id = op.order_id
GROUP BY c.customer_unique_id
ORDER BY Total_Spent DESC;

-- 9. Repeat customers (More than 1 order)
SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS Total_Orders
FROM Customers c JOIN Orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER BY Total_Orders DESC;

-- 10. Customer geographic distribution by state
SELECT customer_state, COUNT(DISTINCT customer_unique_id) AS Total_Customers
FROM Customers
GROUP BY customer_state
ORDER BY Total_Customers DESC;

-- 11. Customer geographic distribution by city (Top 10)
SELECT TOP 10 customer_city, customer_state, COUNT(DISTINCT customer_unique_id) AS Total_Customers
FROM Customers
GROUP BY customer_city, customer_state
ORDER BY Total_Customers DESC;

-- 12. Average items per order by customer state
SELECT c.customer_state, AVG(CAST(ItemCount.Total_Items AS FLOAT)) AS Avg_Items_Per_Order
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id
JOIN (SELECT order_id, COUNT(order_item_id) AS Total_Items FROM Order_Items GROUP BY order_id) ItemCount ON o.order_id = ItemCount.order_id
GROUP BY c.customer_state
ORDER BY Avg_Items_Per_Order DESC;

-- 13. State-wise Total Revenue Generation
SELECT c.customer_state, SUM(op.payment_value) AS Total_State_Revenue
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id
JOIN Order_Payments op ON o.order_id = op.order_id
GROUP BY c.customer_state
ORDER BY Total_State_Revenue DESC;

-- ==========================================
-- CATEGORY C: LOGISTICS & DELIVERY EFFICIENCY
-- ==========================================

-- 14. Order status distribution
SELECT order_status, COUNT(order_id) AS Total_Orders
FROM Orders
GROUP BY order_status
ORDER BY Total_Orders DESC;

-- 15. Average delivery time in days
SELECT AVG(DATEDIFF(day, order_purchase_timestamp, order_delivered_customer_date)) AS Avg_Delivery_Days
FROM Orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL;

-- 16. On-time vs Late delivery count
SELECT 
    CASE 
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On Time'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        ELSE 'Unknown'
    END AS Delivery_Performance,
    COUNT(order_id) AS Total_Orders
FROM Orders
WHERE order_status = 'delivered'
GROUP BY 
    CASE 
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On Time'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        ELSE 'Unknown'
    END;

-- 17. States with the highest average delivery delays
SELECT c.customer_state, AVG(DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date)) AS Avg_Delay_Days
FROM Orders o JOIN Customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
GROUP BY c.customer_state
ORDER BY Avg_Delay_Days DESC;

-- 18. Seller fulfillment performance (Days to hand over to carrier)
SELECT s.seller_id, AVG(DATEDIFF(day, o.order_approved_at, o.order_delivered_carrier_date)) AS Avg_Processing_Days
FROM Orders o 
JOIN Order_Items oi ON o.order_id = oi.order_id
JOIN Sellers s ON oi.seller_id = s.seller_id
WHERE o.order_delivered_carrier_date IS NOT NULL
GROUP BY s.seller_id
ORDER BY Avg_Processing_Days DESC;

-- 19. Freight value as a percentage of total order value
SELECT TOP 10 order_id, SUM(freight_value) AS Total_Freight, SUM(price) AS Total_Price, 
      (SUM(freight_value) / (SUM(price) + SUM(freight_value))) * 100 AS Freight_Percentage
FROM Order_Items
GROUP BY order_id
ORDER BY Freight_Percentage DESC;

-- ==========================================
-- CATEGORY D: FINANCIALS, PAYMENTS & REVIEWS
-- ==========================================

-- 20. Payment method breakdown
SELECT payment_type, COUNT(order_id) AS Transactions, SUM(payment_value) AS Total_Processed
FROM Order_Payments
GROUP BY payment_type
ORDER BY Total_Processed DESC;

-- 21. Average credit card installments by state
SELECT c.customer_state, AVG(CAST(op.payment_installments AS FLOAT)) AS Avg_Installments
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id
JOIN Order_Payments op ON o.order_id = op.order_id
WHERE op.payment_type = 'credit_card'
GROUP BY c.customer_state
ORDER BY Avg_Installments DESC;

-- 22. Voucher usage total volume
SELECT COUNT(order_id) AS Voucher_Transactions, SUM(payment_value) AS Total_Voucher_Value
FROM Order_Payments
WHERE payment_type = 'voucher';

-- 23. Average Review Score by Category
SELECT pct.product_category_name_english, AVG(CAST(orv.review_score AS FLOAT)) AS Avg_Review_Score
FROM Order_Reviews orv
JOIN Order_Items oi ON orv.order_id = oi.order_id
JOIN Products p ON oi.product_id = p.product_id
JOIN Product_Category_Translation pct ON p.product_category_name = pct.product_category_name
GROUP BY pct.product_category_name_english
ORDER BY Avg_Review_Score DESC;

-- 24. Impact of late delivery on review scores
SELECT 
    CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late' ELSE 'On Time' END AS Delivery_Status,
    AVG(CAST(orv.review_score AS FLOAT)) AS Avg_Review_Score
FROM Orders o JOIN Order_Reviews orv ON o.order_id = orv.order_id
WHERE o.order_status = 'delivered'
GROUP BY CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late' ELSE 'On Time' END;

-- 25. High-revenue, low-rating products (Quality control candidates)
SELECT TOP 10 p.product_id, pct.product_category_name_english, SUM(oi.price) AS Total_Revenue, AVG(CAST(orv.review_score AS FLOAT)) AS Avg_Score
FROM Products p
JOIN Order_Items oi ON p.product_id = oi.product_id
JOIN Order_Reviews orv ON oi.order_id = orv.order_id
JOIN Product_Category_Translation pct ON p.product_category_name = pct.product_category_name
GROUP BY p.product_id, pct.product_category_name_english
HAVING SUM(oi.price) > 1000 AND AVG(CAST(orv.review_score AS FLOAT)) <= 2.5
ORDER BY Total_Revenue DESC;
