INSERT INTO omnifin.business_vault.merchant_transaction
WITH extracted AS (
  SELECT transaction_hk, load_dts, applied_dts,
         CASE
           WHEN payload:merchant_category_code IS NULL
             OR is_variant_null(payload:merchant_category_code)          THEN 'MISSING'
           WHEN schema_of_variant(payload:merchant_category_code)
                IN ('STRING', 'BIGINT')                                  THEN 'FLAT'
           WHEN schema_of_variant(payload:merchant_category_code)
                LIKE 'OBJECT<%'                                          THEN 'ENRICHED'
           ELSE 'UNEXPECTED'
         END AS mcc_shape,
         coalesce(try_variant_get(payload, '$.merchant_category_code.code', 'STRING'),
                  try_variant_get(payload, '$.merchant_category_code', 'STRING')) AS mcc_raw,
         try_variant_get(payload, '$.merchant_category_code.confidence', 'DECIMAL(3,2)')
                                                                         AS mcc_confidence,
         try_variant_get(payload, '$.merchant_category_code.source', 'STRING') AS mcc_source
  FROM omnifin.raw_vault.sat_transaction_fintech
)
SELECT e.transaction_hk, e.load_dts, e.applied_dts,
       'BV:MERCHANT_CATEGORY_V2'                                         AS record_source,
       e.mcc_shape,
       CASE WHEN e.mcc_raw RLIKE '^[0-9]{1,4}$' THEN lpad(e.mcc_raw, 4, '0') END
                                                                         AS merchant_category_code,
       e.mcc_confidence,
       e.mcc_source
FROM extracted e
WHERE NOT EXISTS (
  SELECT 1
  FROM omnifin.business_vault.sat_transaction_merchant t
  WHERE t.transaction_hk = e.transaction_hk
    AND t.applied_dts    = e.applied_dts
    AND t.load_dts       = e.load_dts
    AND t.record_source  = 'BV:MERCHANT_CATEGORY_V2'
);