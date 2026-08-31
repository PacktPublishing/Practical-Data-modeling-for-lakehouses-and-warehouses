-- SAT_CUSTOMER_FINTECH: Satellite load from Kafka events

MERGE INTO raw_vault.sat_customer_fintech AS target
USING (
  SELECT
    SHA2(UPPER(TRIM(user_uuid)), 256)      AS customer_hk,
    event_timestamp                         AS load_dts,
    'KAFKA:CUSTOMER.PROFILE.CHANGED'        AS record_source,
    SHA2(
      CONCAT_WS('||',
        COALESCE(UPPER(TRIM(full_name)),       'UNKNOWN'),
        COALESCE(UPPER(TRIM(email_address)),   'UNKNOWN'),
        COALESCE(UPPER(TRIM(customer_tier)),   'UNKNOWN'),
        COALESCE(UPPER(TRIM(kyc_status)),      'UNKNOWN'),
        COALESCE(CAST(risk_score AS STRING),   '0')
      ), 256
    )                                       AS hash_diff,
    full_name,
    email_address,
    mobile_number,
    customer_tier,
    kyc_status,
    risk_score,
    preferred_channel
  FROM staging.stg_kafka_customer_profile_changed
  WHERE user_uuid IS NOT NULL
) AS source
ON  target.customer_hk = source.customer_hk
AND target.hash_diff   = source.hash_diff
WHEN NOT MATCHED THEN
  INSERT (customer_hk, load_dts, record_source, hash_diff,
          full_name, email_address, mobile_number, customer_tier,
          kyc_status, risk_score, preferred_channel)
  VALUES (source.customer_hk, source.load_dts, source.record_source, source.hash_diff,
          source.full_name, source.email_address, source.mobile_number, source.customer_tier,
          source.kyc_status, source.risk_score, source.preferred_channel)