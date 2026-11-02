# E-Commerce Database & Business Performance Analysis

## 1. Project Overview & Purpose
**Need of this project:** The project analyzes an e-commerce platform using the Brazilian E-Commerce Dataset by Olist (approx. 100,000 orders). 

**Purpose it solves:** It enables a business to understand its sales performance, customer behaviors, product popularity, seller reliability, and delivery efficiency. By building a normalized relational database and writing targeted SQL queries, it provides actionable insights (like top revenue categories, high-value customers, and payment trends) that drive strategic business decisions.

## 2. Environment Setup & Data Import
* **Environment:** SQL Server Management Studio (SSMS) 22 
* **Dataset:** Olist Brazilian E-Commerce Dataset from Kaggle.
* **Methodology:**
  * Created a dedicated database (`OlistECommerce`).
  * Established normalized tables using T-SQL.
  * Attempted to use SSMS Import Wizard but shifted to `BULK INSERT` for massive files to improve speed (taking seconds instead of minutes).

## 3. Errors Encountered & Solutions
1. **SSMS Wizard Freezing:** The built-in wizard was too slow for 100,000+ rows. 
   * *Solution:* Switched to `BULK INSERT` for direct, high-speed file loading.
2. **Type Mismatch on Zip Codes:** `BULK INSERT` failed due to hidden characters or formatting in the Kaggle CSV for zip codes originally set as `INT`.
   * *Solution:* Used `ALTER TABLE Customers ALTER COLUMN customer_zip_code_prefix VARCHAR(50);` to store zip codes as text, which is the standard database best practice.
3. **Data Truncation Error:** Some state names exceeded the default `VARCHAR(10)` limit.
   * *Solution:* Increased the column size to `VARCHAR(50)` for `seller_state` and `geolocation_state`, then re-imported.
4. **Line Breaks in Reviews:** Customers hitting "Enter" in text reviews broke the `BULK INSERT` parser.
   * *Solution:* Used the SSMS Import Flat File Wizard *specifically* for the `Order_Reviews` file because its parser handles multi-line text qualifiers properly.

## 4. Database Schema (DDL)
*Reasoning: Tables were created strictly based on the ER Diagram to ensure entity relationships and data integrity using Primary and Foreign Keys.*

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


---

---
## 5. Business Queries & Insights

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


