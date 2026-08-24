-- SAT_CUSTOMER_OMNIFIN: Idempotent satellite load

MERGE INTO raw_vault.sat_customer_omnifin AS target
USING (
  SELECT
    SHA2(UPPER(TRIM(customer_id)), 256)    AS customer_hk,
    current_timestamp()                     AS load_dts,
    'CORE_BANKING_SYSTEM'                   AS record_source,
    SHA2(
      CONCAT_WS('||',
        COALESCE(UPPER(TRIM(full_name)),         'UNKNOWN'),
        COALESCE(UPPER(TRIM(email)),              'UNKNOWN'),
        COALESCE(UPPER(TRIM(customer_segment)),  'UNKNOWN'),
        COALESCE(CAST(credit_limit AS STRING),   '0'),
        COALESCE(UPPER(TRIM(risk_rating)),       'UNKNOWN'),
        COALESCE(CAST(date_of_birth AS STRING),  'UNKNOWN')
      ), 256
    )                                       AS hash_diff,
    full_name,
    email,
    customer_segment,
    credit_limit,
    date_of_birth,
    risk_rating
  FROM staging.stg_customer_omnifin
  WHERE customer_id IS NOT NULL
) AS source
ON  target.customer_hk = source.customer_hk
AND target.hash_diff   = source.hash_diff
WHEN NOT MATCHED THEN
  INSERT (customer_hk, load_dts, record_source, hash_diff,
          full_name, email, customer_segment, credit_limit,
          date_of_birth, risk_rating)
  VALUES (source.customer_hk, source.load_dts, source.record_source, source.hash_diff,
          source.full_name, source.email, source.customer_segment, source.credit_limit,
          source.date_of_birth, source.risk_rating)