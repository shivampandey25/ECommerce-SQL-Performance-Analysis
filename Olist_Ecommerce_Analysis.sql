-- ==========================================
-- E-Commerce Database Performance Analysis
-- ==========================================

-- 1. Database Creation
CREATE DATABASE OlistECommerce;
USE OlistECommerce;

-- 2. Table Creation (Schema)
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

-- 3. Data Cleansing & Alterations
ALTER TABLE Customers ALTER COLUMN customer_zip_code_prefix VARCHAR(50);
ALTER TABLE Sellers ALTER COLUMN seller_zip_code_prefix VARCHAR(50);
ALTER TABLE Geolocation ALTER COLUMN geolocation_zip_code_prefix VARCHAR(50);
ALTER TABLE Sellers ALTER COLUMN seller_state VARCHAR(50);
ALTER TABLE Geolocation ALTER COLUMN geolocation_state VARCHAR(50);

-- ==========================================
-- Business Queries & Insights
-- ==========================================

-- Query 1: Top Revenue Generating Categories
SELECT TOP 5 
    pct.product_category_name_english AS Category, 
    SUM(oi.price) AS Total_Revenue, 
    COUNT(oi.order_item_id) AS Items_Sold
FROM Order_Items oi
JOIN Products p ON oi.product_id = p.product_id
JOIN Product_Category_Translation pct ON p.product_category_name = pct.product_category_name
GROUP BY pct.product_category_name_english
ORDER BY Total_Revenue DESC;

-- Query 2: High-Value Customer Identification
WITH CustomerSpend AS (
    SELECT 
        c.customer_unique_id, 
        COUNT(DISTINCT o.order_id) AS Total_Orders, 
        SUM(op.payment_value) AS Total_Spent
    FROM Customers c 
    JOIN Orders o ON c.customer_id = o.customer_id
    JOIN Order_Payments op ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id
)
SELECT TOP 5 customer_unique_id, Total_Orders, Total_Spent 
FROM CustomerSpend 
ORDER BY Total_Spent DESC;

-- Query 3: Delivery Performance Tracking
SELECT TOP 5
    order_id, 
    order_estimated_delivery_date, 
    order_delivered_customer_date,
    CASE 
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On Time'
        ELSE 'Pending/Unknown'
    END AS Delivery_Status
FROM Orders 
WHERE order_status = 'delivered' 
ORDER BY order_delivered_customer_date DESC;

-- Query 4: Month-Over-Month Sales Growth
WITH MonthlySales AS (
    SELECT 
        YEAR(o.order_purchase_timestamp) AS Order_Year, 
        MONTH(o.order_purchase_timestamp) AS Order_Month, 
        SUM(op.payment_value) AS Total_Sales
    FROM Orders o JOIN Order_Payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
),
SalesGrowth AS (
    SELECT Order_Year, Order_Month, Total_Sales, 
        LAG(Total_Sales) OVER (ORDER BY Order_Year, Order_Month) AS Previous_Month_Sales
    FROM MonthlySales
)
SELECT TOP 5 Order_Year, Order_Month, Total_Sales, Previous_Month_Sales,
    CASE WHEN Previous_Month_Sales IS NULL THEN 0 
    ELSE ROUND(((Total_Sales - Previous_Month_Sales) / Previous_Month_Sales) * 100, 2) END AS MoM_Growth_Pct
FROM SalesGrowth 
ORDER BY Order_Year, Order_Month;

-- Query 5: Payment Method Popularity
SELECT 
    payment_type, 
    COUNT(order_id) AS Total_Transactions, 
    SUM(payment_value) AS Total_Processed_Value,
    ROUND((COUNT(order_id) * 100.0) / (SELECT COUNT(*) FROM Order_Payments), 2) AS Percentage_of_Total_Transactions
FROM Order_Payments 
GROUP BY payment_type 
ORDER BY Total_Transactions DESC;
