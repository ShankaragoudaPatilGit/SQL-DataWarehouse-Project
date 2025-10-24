/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'Silver' schema from external CSV files. 
    It performs the following actions:
    - Truncates the Silver tables before loading data.
    - Uses the `BULK INSERT` command to load data from bronze tables to silver table.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS 
BEGIN
	BEGIN TRY
		DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
		SET @batch_start_time = GETDATE();

		PRINT('=========================================================================');
		PRINT('Loading Silver Layer');
		PRINT('=========================================================================');

		PRINT('-------------------------------------------------------------------------');
		PRINT('Loading CRM Tables');
		PRINT('-------------------------------------------------------------------------');
		-- Loading silver.crm_cust_info
		SET @start_time =  GETDATE() ;
		PRINT('>> Truncating silver.crm_cust_info');
		IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
			TRUNCATE TABLE silver.crm_cust_info;

		PRINT('>> Inserting silver.crm_cust_info');
		INSERT INTO silver.crm_cust_info
			(
				cst_id,
				cst_key,
				cst_firstname,
				cst_lastname,
				cst_marital_status,
				cst_gndr,
				cst_create_date
			)
		SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_last_name,
			CASE 
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				ELSE 'Unknown'
			END AS cst_marital_status, -- Normalize the marital status for readable format
			CASE 
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'Unknow'
			END cst_gndr, -- Normalize the gender values for readable format
			cst_create_date
		FROM (
			SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_val
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
			) t
		WHERE flag_val = 1 ;-- Select the most recent record per customer
		SET @end_time = GETDATE() ;
		PRINT('>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('------------------------------------')

		-- Loading silver.crm_prd_info
		SET @start_time =  GETDATE() ;
		PRINT('>> Truncating silver.crm_prd_info');
		IF OBJECT_ID('silver.crm_prd_info', 'U') IS NULL 
			TRUNCATE TABLE silver.crm_prd_info;

		PRINT('>> Inserting silver.crm_prd_info');
		INSERT INTO silver.crm_prd_info
		(
			prd_id,
			cat_key,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_key, -- Extract Category Key
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key, -- Extract Product Key 
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost,
			CASE UPPER(TRIM(prd_line))
				WHEN 'M' THEN 'Mountain'
				WHEN 'R' THEN 'Road'
				WHEN 'S' THEN 'Other Sales'
				WHEN 'T' THEN 'Touring'
				ELSE 'Unknown'
			END as prd_line, -- Mapped column for better readable format
			prd_start_dt,
			DATEADD( DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt ASC)) AS prd_end_dt -- Enriched column for prd_end_date
		FROM bronze.crm_prd_info ;
		SET @end_time = GETDATE() ;
		PRINT('>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('------------------------------------')

		--Loading silver.crm_sales_details
		SET @start_time =  GETDATE() ;
		PRINT('>> Truncating silver.crm_sales_details');
		IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
			TRUNCATE TABLE silver.crm_sales_details;

		PRINT('>> Inserting silver.crm_sales_details');
		INSERT INTO silver.crm_sales_details
		(
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE 
				WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) <> 8 THEN NULL 
				ELSE CAST(CAST(sls_order_dt AS NVARCHAR) AS DATE)
			END AS sls_order_dt,
			CASE 
				WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) <> 8 THEN NULL 
				ELSE CAST(CAST(sls_ship_dt AS NVARCHAR) AS DATE)
			END AS sls_ship_dt,
			CASE 
				WHEN sls_due_dt <= 0 OR LEN(sls_due_dt) <> 8 THEN NULL 
				ELSE CAST(CAST(sls_due_dt AS NVARCHAR) AS DATE)
			END AS sls_due_dt,
			CASE 
				WHEN sls_sales <= 0 OR sls_sales IS NULL OR sls_sales <> (sls_quantity * ABS(sls_price)) 
					THEN sls_quantity * ABS(sls_price)
				ELSE sls_sales
			END AS sls_sales,
			sls_quantity,
			CASE 
				WHEN sls_price <= 0 OR sls_price IS NULL 
					THEN sls_sales / NULLIF(sls_quantity, 0)
				ELSE sls_price
			END AS sls_price
		FROM bronze.crm_sales_details ;
		SET @end_time = GETDATE() ;
		PRINT('>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('------------------------------------')

		PRINT('-------------------------------------------------------------------------');
		PRINT('Loading ERP Tables');
		PRINT('-------------------------------------------------------------------------');

		-- Loading silver.erp_cust_az12
		SET @start_time =  GETDATE() ;
		PRINT('>> Truncating silver.erp_cust_az12');
		IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
			TRUNCATE TABLE silver.erp_cust_az12 ;

		PRINT('>> Inserting silver.erp_cust_az12');
		INSERT INTO silver.erp_cust_az12
		(
			cid,
			bdate,
			gen
		)
		SELECT 
			CASE 
				WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
				ELSE cid
			END AS cid, -- Replacing the prefic NAS from the cid
			CASE 
				WHEN bdate > GETDATE() THEN NULL 
				ELSE bdate
			END AS bdate, -- Updated the Future bdate to NULL
			CASE 
				WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
				WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
				ELSE 'Unknown'
			END AS gen -- Normalize the gender values and updated null or empty string value to unknown
		FROM bronze.erp_cust_az12 ;
		SET @end_time = GETDATE() ;
		PRINT('>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('------------------------------------')

		-- Loading silver.erp_loc_a101
		SET @start_time =  GETDATE() ;
		PRINT('>> Truncating silver.erp_loc_a101');
		IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
			TRUNCATE TABLE silver.erp_loc_a101;

		PRINT('>> Inserting silver.erp_loc_a101');
		INSERT INTO silver.erp_loc_a101
		(
			cid,
			cntry
		)
		SELECT
			REPLACE(cid, '-', '') AS cid, -- Replaced unwanted '-' values to ''
			CASE 
				WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
				WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
				WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'Unknown'
				ELSE cntry
			END AS cntry -- Normalized the cntry names
		FROM bronze.erp_loc_a101 ;
		SET @end_time = GETDATE() ;
		PRINT('>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('------------------------------------')

		-- Loading silver.erp_px_cat_g1v2
		SET @start_time =  GETDATE() ;
		PRINT('>> Truncating silver.erp_px_cat_g1v2');
		if OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
			TRUNCATE TABLE silver.erp_px_cat_g1v2 ;

		PRINT('>> Inserting silver.erp_px_cat_g1v2');
		INSERT INTO silver.erp_px_cat_g1v2
		(
			id,
			cat,
			subcat,
			maintenance
		)
		SELECT 
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2 ;
		SET @end_time = GETDATE() ;
		PRINT('>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds') ;
		PRINT('------------------------------------') ;
		SET @batch_end_time = GETDATE() ;
		PRINT('>> Batch Load Duration : ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds') ;
	END TRY
	BEGIN CATCH
	PRINT('=========================================================================');
	PRINT('ERROR OCCURED DURING SILVER BATCH LOADING')
	PRINT('ERROR MESSAGE : ' + ERROR_MESSAGE());
	PRINT('ERORR NUMBER  : ' + CAST(ERROR_NUMBER() AS NVARCHAR));
	PRINT('ERROR STATE   : ' + CAST(ERROR_STATE() AS NVARCHAR));
	PRINT('=========================================================================');
	END CATCH
END