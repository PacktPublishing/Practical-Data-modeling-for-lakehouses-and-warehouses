-- HUB_CUSTOMER: Idempotent hub load using Delta Lake MERGE

MERGE INTO raw_vault.hub_customer AS target
USING (
  SELECT DISTINCT
    SHA2(UPPER(TRIM(customer_id)), 256)  AS customer_hk,
    customer_id                          AS customer_bk,
    current_timestamp()                  AS load_dts,
    'CORE_BANKING_SYSTEM'                AS record_source
  FROM staging.stg_customer_omnifin
  WHERE customer_id IS NOT NULL
) AS source
ON target.customer_hk = source.customer_hk
WHEN NOT MATCHED THEN
  INSERT (customer_hk, customer_bk, load_dts, record_source)
  VALUES (source.customer_hk, source.customer_bk, source.load_dts, source.record_source)