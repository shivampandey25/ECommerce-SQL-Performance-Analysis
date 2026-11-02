E-Commerce Database & Business Performance Analysis
1. Project Overview & Purpose
Need of this project: The project analyzes an e-commerce platform using the Brazilian E-Commerce Dataset by Olist (approx. 100,000 orders). Purpose it solves: It enables a business to understand its sales performance, customer behaviors, product popularity, seller reliability, and delivery efficiency. By building a normalized relational database and writing targeted SQL queries, it provides actionable insights (like top revenue categories, high-value customers, and payment trends) that drive strategic business decisions.
2. Environment Setup & Data Import
Environment: SQL Server Management Studio (SSMS) 22 Dataset: Olist Brazilian E-Commerce Dataset from Kaggle. Methodology:

Created a dedicated database (OlistECommerce).
Established normalized tables using T-SQL.
Attempted to use SSMS Import Wizard but shifted to BULK INSERT for massive files to improve speed (taking seconds instead of minutes).
3. Errors Encountered & Solutions
SSMS Wizard Freezing: The built-in wizard was too slow for 100,000+ rows.
Solution: Switched to BULK INSERT for direct, high-speed file loading.
Type Mismatch on Zip Codes: BULK INSERT failed due to hidden characters or formatting in the Kaggle CSV for zip codes originally set as INT.
Solution: Used ALTER TABLE Customers ALTER COLUMN customer_zip_code_prefix VARCHAR(50); to store zip codes as text, which is the standard database best practice.
Data Truncation Error: Some state names exceeded the default VARCHAR(10) limit.
Solution: Increased the column size to VARCHAR(50) for seller_state and geolocation_state, then re-imported.
Line Breaks in Reviews: Customers hitting "Enter" in text reviews broke the BULK INSERT parser.
Solution: Used the SSMS Import Flat File Wizard specifically for the Order_Reviews file because its parser handles multi-line text qualifiers properly.
4. Database Schema (DDL)
Reasoning: Tables were created strictly based on the ER Diagram to ensure entity relationships and data integrity using Primary and Foreign Keys.

CREATE DATABASE OlistECommerce;
USE OlistECommerce;

CREATE TABLE Customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(50),
    customer_city VARCHAR(100),
    customer_state VARCHAR(50)
);

CREATE TABLE Products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

CREATE TABLE Orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) FOREIGN KEY REFERENCES Customers(customer_id),
    order_status VARCHAR(50),
    order_purchase_timestamp DATETIME2,
    order_approved_at DATETIME2,
    order_delivered_carrier_date DATETIME2,
    order_delivered_customer_date DATETIME2,
    order_estimated_delivery_date DATETIME2
);
-- (Included other tables: Sellers, Order_Items, Order_Payments, Order_Reviews, Geolocation, Product_Category_Translation)
5. Business Queries & Outputs
Query 1: Top Revenue Categories
Reasoning: Uses JOINs to connect items, products, and English translations, and GROUP BY with SUM to aggregate revenue.

SELECT TOP 10 pct.product_category_name_english AS Category, SUM(oi.price) AS Total_Revenue, COUNT(oi.order_item_id) AS Items_Sold
FROM Order_Items oi
JOIN Products p ON oi.product_id = p.product_id
JOIN Product_Category_Translation pct ON p.product_category_name = pct.product_category_name
GROUP BY pct.product_category_name_english
ORDER BY Total_Revenue DESC;

Output Insight: health_beauty and watches_gifts generate the highest revenue.
Query 2: Identify High-Value Customers
Reasoning: Uses a Common Table Expression (CTE) to track individual people across multiple distinct orders based on their unique ID.

WITH CustomerSpend AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS Total_Orders, SUM(op.payment_value) AS Total_Spent
    FROM Customers c JOIN Orders o ON c.customer_id = o.customer_id
    JOIN Order_Payments op ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id
)
SELECT TOP 10 customer_unique_id, Total_Orders, Total_Spent FROM CustomerSpend ORDER BY Total_Spent DESC;

Output Insight: Top individual spent over $13,664.
Query 3: Rank Top-Selling Products by Category
Reasoning: Uses Window Function DENSE_RANK() OVER (PARTITION BY...) to find the exact top 2 products within each specific category.

WITH ProductSales AS (
    SELECT pct.product_category_name_english AS Category, p.product_id, COUNT(oi.order_item_id) AS Items_Sold
    FROM Order_Items oi
    JOIN Products p ON oi.product_id = p.product_id
    JOIN Product_Category_Translation pct ON p.product_category_name = pct.product_category_name
    GROUP BY pct.product_category_name_english, p.product_id
),
RankedProducts AS (
    SELECT Category, product_id, Items_Sold, DENSE_RANK() OVER (PARTITION BY Category ORDER BY Items_Sold DESC) AS Sales_Rank
    FROM ProductSales
)
SELECT * FROM RankedProducts WHERE Sales_Rank <= 2 ORDER BY Category, Sales_Rank;

Output Insight: Accurate ranking of exact product IDs by sales volume within their respective categories.
Query 4: Delivery Performance
Reasoning: Uses CASE WHEN to dynamically compare actual vs. estimated delivery dates.

SELECT order_id, order_estimated_delivery_date, order_delivered_customer_date,
    CASE 
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On Time'
        ELSE 'Pending/Unknown'
    END AS Delivery_Status
FROM Orders WHERE order_status = 'delivered' ORDER BY order_delivered_customer_date DESC;

Output Insight: Successfully flagged delayed orders for logistics review.
Query 5: Monthly Growth Percentage
Reasoning: Uses the LAG() window function to pull the previous month's sales onto the same row for calculating MoM growth.

WITH MonthlySales AS (
    SELECT YEAR(o.order_purchase_timestamp) AS Order_Year, MONTH(o.order_purchase_timestamp) AS Order_Month, SUM(op.payment_value) AS Total_Sales
    FROM Orders o JOIN Order_Payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
),
SalesGrowth AS (
    SELECT Order_Year, Order_Month, Total_Sales, LAG(Total_Sales) OVER (ORDER BY Order_Year, Order_Month) AS Previous_Month_Sales
    FROM MonthlySales
)
SELECT Order_Year, Order_Month, Total_Sales, Previous_Month_Sales,
    CASE WHEN Previous_Month_Sales IS NULL THEN 0 ELSE ROUND(((Total_Sales - Previous_Month_Sales) / Previous_Month_Sales) * 100, 2) END AS Month_Over_Month_Growth_Pct
FROM SalesGrowth ORDER BY Order_Year, Order_Month;

Output Insight: Significant spike in sales growth observed entering January 2017.
Query 6: Popular Payment Methods
Reasoning: Uses basic grouping and a subquery to calculate the percentage of total transactions.

SELECT payment_type, COUNT(order_id) AS Total_Transactions, SUM(payment_value) AS Total_Processed_Value,
ROUND((COUNT(order_id) * 100.0) / (SELECT COUNT(*) FROM Order_Payments), 2) AS Percentage_of_Total_Transactions
FROM Order_Payments GROUP BY payment_type ORDER BY Total_Transactions DESC;

Output Insight: Credit cards dominate the platform, processing nearly 74% of all transactions.
