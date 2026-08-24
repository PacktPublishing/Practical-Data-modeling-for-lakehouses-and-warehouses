-- dim_customer: Kimball dimension derived from the Business Vault PIT table

CREATE OR REPLACE TABLE consumption.dim_customer AS

WITH today_snapshot AS (
  SELECT
    customer_hk,
    sat_customer_omnifin_ldts,
    sat_customer_fintech_ldts
  FROM business_vault.pit_customer        
  WHERE snapshot_date = CURRENT_DATE()
)

SELECT
  ts.customer_hk::VARCHAR            AS customer_sk,
  hc.customer_bk                     AS customer_id,

  -- OmniFin is the system of record for all regulated attributes
  COALESCE(so.full_name,            sf.full_name)        AS customer_name,
  COALESCE(so.email,                sf.email_address)    AS email,
  COALESCE(so.customer_segment,     sf.customer_tier)    AS customer_segment,
  so.credit_limit                                        AS credit_limit,
  so.date_of_birth                                       AS date_of_birth,
  so.risk_rating                                         AS regulatory_risk_rating,

  -- Fintech enriches what OmniFin does not capture
  sf.mobile_number                                       AS mobile_number,
  sf.kyc_status                                          AS kyc_status,
  sf.risk_score                                          AS ml_risk_score,
  sf.preferred_channel                                   AS preferred_channel,

  -- Source lineage flags: vault traceability preserved inside the mart
  CASE WHEN so.customer_hk IS NOT NULL THEN TRUE ELSE FALSE END AS has_omnifin_record,
  CASE WHEN sf.customer_hk IS NOT NULL THEN TRUE ELSE FALSE END AS has_fintech_record,

  CURRENT_TIMESTAMP()                AS dw_insert_timestamp,
  'HYBRID_VAULT_TO_MART'             AS dw_record_source

FROM today_snapshot ts
JOIN raw_vault.hub_customer hc                  
  ON  ts.customer_hk = hc.customer_hk
LEFT JOIN raw_vault.sat_customer_omnifin so     
  ON  ts.customer_hk = so.customer_hk
  AND so.load_dts   = ts.sat_customer_omnifin_ldts
LEFT JOIN raw_vault.sat_customer_fintech sf     
  ON  ts.customer_hk = sf.customer_hk
  AND sf.load_dts   = ts.sat_customer_fintech_ldts