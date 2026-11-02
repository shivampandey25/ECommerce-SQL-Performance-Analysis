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
-- Additional tables created: Products, Sellers, Order_Items, Order_Payments, Order_Reviews, Geolocation, Product_Category_Translation
