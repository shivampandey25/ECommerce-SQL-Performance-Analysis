# E-Commerce Database & Business Performance Analysis

## 📌 Project Overview
This project analyzes a Brazilian E-Commerce platform using the Olist dataset (comprising approximately 100,000 orders). The objective is to understand sales performance, customer behaviors, product popularity, and delivery efficiency. By building a normalized relational database and writing targeted SQL queries, this project extracts actionable insights to drive strategic business decisions.

**Tech Stack:** SQL Server Management Studio (SSMS) 22, T-SQL

## ⚙️ Environment Setup & Data Import Methodology
* **Database Creation:** Designed a dedicated, normalized relational database (`OlistECommerce`) using T-SQL.
* **Data Ingestion:** Initially utilized the SSMS Import Wizard, but transitioned to `BULK INSERT` scripts to efficiently load massive datasets (100,000+ rows) in seconds.
* **Data Cleansing:** 
  * Handled type mismatches by altering integer zip code columns to `VARCHAR(50)`, adhering to database best practices.
  * Resolved data truncation errors by expanding character limits for specific regional string columns.
  * Successfully parsed complex multi-line string data (customer reviews) containing hidden carriage returns.

## 🗄️ Database Schema
The database was structured to ensure entity relationships and data integrity using Primary and Foreign Keys.

```sql
CREATE DATABASE OlistECommerce;
USE OlistECommerce;

CREATE TABLE Customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(50),
    customer_city VARCHAR(100),
    customer_state VARCHAR(50)
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
```

---

## 📊 Business Queries & Insights

### 1. Top Revenue Generating Categories
**Business Question:** Which product categories generate the most revenue for the platform?
*Methodology: Uses `JOINs` to connect items, products, and English translations, and `GROUP BY` with `SUM` to aggregate revenue.*

```sql
SELECT TOP 5 
    pct.product_category_name_english AS Category, 
    SUM(oi.price) AS Total_Revenue, 
    COUNT(oi.order_item_id) AS Items_Sold
FROM Order_Items oi
JOIN Products p ON oi.product_id = p.product_id
JOIN Product_Category_Translation pct ON p.product_category_name = pct.product_category_name
GROUP BY pct.product_category_name_english
ORDER BY Total_Revenue DESC;
```
| Category | Total_Revenue | Items_Sold |
| :--- | :--- | :--- |
| health_beauty | 1258681.34 | 9670 |
| watches_gifts | 1205005.68 | 5991 |
| bed_bath_table | 1036988.68 | 11115 |
| sports_leisure | 988048.97 | 8641 |
| computers_accessories | 911954.32 | 7827 |

**Insight:** Health & Beauty and Watches & Gifts are the strongest revenue drivers, indicating a highly profitable lifestyle and gifting customer segment.

### 2. High-Value Customer Identification
**Business Question:** Which individual customers have spent the most money across all their orders?
*Methodology: Uses a Common Table Expression (CTE) to track individual people across multiple distinct orders based on their unique ID.*

```sql
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
```
| customer_unique_id | Total_Orders | Total_Spent |
| :--- | :--- | :--- |
| 0a0a92112bd4c708ca5fde585afaa872 | 1 | 13664.08 |
| 46450c74a0d8c5ca9395da1daac6c120 | 3 | 9553.02 |
| da122df9eeddfedc1dc1f5349a1a690c | 2 | 7571.63 |
| 763c8b1c9c68a0229c42c9fc6f662b93 | 1 | 7274.88 |
| dc4802a71eae9be1dd28f5d788ceb526 | 1 | 6929.31 |

**Insight:** The top customer generated over $13,600 in a single order, highlighting opportunities for VIP retention programs.

### 3. Delivery Performance Tracking
**Business Question:** Are sellers meeting their estimated delivery dates?
*Methodology: Uses `CASE WHEN` to dynamically compare actual vs. estimated delivery dates to flag logistics bottlenecks.*

```sql
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
```
| order_id | order_estimated_delivery_date | order_delivered_customer_date | Delivery_Status |
| :--- | :--- | :--- | :--- |
| 7e708aed151d6a8601ce8f2eaa712bf4 | 2018-07-13 | 2018-10-17 | Late |
| 450cb96c63e1e5b49d34f223f67976d2 | 2018-06-27 | 2018-10-11 | Late |
| b2997e1d7061605e9285496c581d1fbd | 2018-08-14 | 2018-10-02 | Late |

**Insight:** Surfacing delayed deliveries enables the business to penalize underperforming carriers and issue proactive customer refunds to protect brand reputation.

### 4. Month-Over-Month Sales Growth
**Business Question:** How is the platform's revenue trending month over month?
*Methodology: Uses the `LAG()` window function to pull the previous month's sales onto the current row for percentage growth calculation.*

```sql
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
```
| Order_Year | Order_Month | Total_Sales | Previous_Month_Sales | MoM_Growth_Pct |
| :--- | :--- | :--- | :--- | :--- |
| 2016 | 10 | 46566.71 | NULL | 0.00 |
| 2016 | 12 | 19.62 | 46566.71 | -99.96 |
| 2017 | 1 | 127545.67 | 19.62 | 649979.87 |
| 2017 | 2 | 271298.65 | 127545.67 | 112.71 |
| 2017 | 3 | 414369.39 | 271298.65 | 52.74 |

**Insight:** The platform experienced explosive scaling in Q1 2017, requiring rapid infrastructure and seller onboarding to meet demand.

### 5. Payment Method Popularity
**Business Question:** How are customers paying for their orders?
*Methodology: Uses basic grouping and a subquery to calculate the percentage of total transactions.*

```sql
SELECT 
    payment_type, 
    COUNT(order_id) AS Total_Transactions, 
    SUM(payment_value) AS Total_Processed_Value,
    ROUND((COUNT(order_id) * 100.0) / (SELECT COUNT(*) FROM Order_Payments), 2) AS Percentage_of_Total_Transactions
FROM Order_Payments 
GROUP BY payment_type 
ORDER BY Total_Transactions DESC;
```
| payment_type | Total_Transactions | Total_Processed_Value | Percentage_of_Total_Transactions |
| :--- | :--- | :--- | :--- |
| credit_card | 76795 | 12542084.19 | 73.92 |
| boleto | 19784 | 2869361.27 | 19.04 |
| voucher | 5775 | 379436.87 | 5.56 |
| debit_card | 1529 | 217989.79 | 1.47 |

**Insight:** Credit cards overwhelmingly dominate the platform at ~74% of volume. Optimizing the credit card checkout flow and minimizing processing fees should be top priorities.
