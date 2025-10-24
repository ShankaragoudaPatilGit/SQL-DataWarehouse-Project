CREATE VIEW gold.fact_sales AS 
SELECT
	SD.sls_ord_num AS order_number,
	P.product_key,
	C.customer_key,
	SD.sls_order_dt AS order_date,
	SD.sls_ship_dt AS shipping_date,
	SD.sls_due_dt AS due_date,
	SD.sls_sales AS sales_amount,
	SD.sls_quantity AS quantity,
	SD.sls_price AS price
FROM silver.crm_sales_details SD
LEFT JOIN gold.dim_customers C 
ON		  SD.sls_cust_id = C.customer_id
LEFT JOIN gold.dim_product P
ON		  SD.sls_prd_key = P.product_number
