CREATE VIEW gold.dim_customers AS 
SELECT
	ROW_NUMBER() OVER (ORDER BY Ci.cst_id) AS customer_key,
	cst_id AS customer_id,
	cst_key AS customer_number,
	cst_firstname AS first_name,
	cst_lastname AS last_name,
	Ca.bdate AS birth_date,
	Cl.cntry AS country,
	CASE 
		WHEN Ci.cst_gndr <> 'Unknow' THEN Ci.cst_gndr -- CRM system is the master informatoin
		ELSE COALESCE(Ca.gen, 'Unknow')
	END AS gender,
	cst_marital_status AS marital_status,
	cst_create_date AS create_date
FROM silver.crm_cust_info Ci
LEFT JOIN silver.erp_cust_az12 Ca
ON		  Ci.cst_key = Ca.cid
LEFT JOIN silver.erp_loc_a101 Cl
ON		  Ci.cst_key = Cl.cid
