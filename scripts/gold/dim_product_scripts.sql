CREATE VIEW gold.dim_product AS 
SELECT 
	ROW_NUMBER() OVER (ORDER BY Pn.prd_start_dt, Pn.prd_key) AS product_key,
	Pn.prd_id AS product_id,
	Pn.prd_key AS product_number,
	Pn.prd_nm product_name,
	Pn.cat_key AS category_id,
	Px.cat AS category,
	Px.subcat AS sub_category,
	Px.maintenance,
	Pn.prd_cost AS cost,
	Pn.prd_line AS product_line,
	Pn.prd_start_dt AS start_date
FROM silver.crm_prd_info AS Pn
LEFT JOIN silver.erp_px_cat_g1v2 AS Px
ON		  Pn.cat_key = Px.id
WHERE Pn.prd_end_dt IS NULL -- Filtered all the historical records
