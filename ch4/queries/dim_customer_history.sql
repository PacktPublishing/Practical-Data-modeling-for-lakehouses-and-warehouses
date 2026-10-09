CREATE OR REPLACE TABLE omnifin.information_mart.dim_customer_history AS
WITH versions AS (
  SELECT master_customer_hk,
         sat_customer_omnifin_hk, sat_customer_omnifin_ldts,
         sat_customer_fintech_hk, sat_customer_fintech_ldts,
         min(snapshot_date) AS effective_from
  FROM omnifin.business_vault.pit_customer_daily
  GROUP BY ALL
)
SELECT
  sha2(concat(hex(v.master_customer_hk), '|', cast(v.effective_from AS STRING)), 256)
                                                    AS customer_version_sk,
  hex(v.master_customer_hk)                         AS customer_sk,
  h.customer_bk                                     AS customer_id,
  v.effective_from,
  coalesce(lead(v.effective_from) OVER w, DATE '9999-12-31') AS effective_to,
  lead(v.effective_from) OVER w IS NULL             AS is_current,
  coalesce(so.customer_segment, sf.customer_tier)   AS customer_segment,
  so.credit_limit                                   AS credit_limit,
  so.risk_rating                                    AS regulatory_risk_rating,
  sf.kyc_status                                     AS kyc_status,
  sf.risk_score                                     AS ml_risk_score,
  sf.preferred_channel                              AS preferred_channel,
  so.customer_hk IS NOT NULL                        AS has_omnifin_record,
  sf.customer_hk IS NOT NULL                        AS has_fintech_record,
  current_timestamp()                               AS dw_insert_timestamp,
  'HYBRID_VAULT_TO_MART'                            AS dw_record_source
FROM versions v
JOIN omnifin.raw_vault.hub_customer h
  ON v.master_customer_hk = h.customer_hk
LEFT JOIN omnifin.raw_vault.sat_customer_omnifin so
  ON v.sat_customer_omnifin_hk = so.customer_hk
 AND v.sat_customer_omnifin_ldts = so.load_dts
LEFT JOIN omnifin.raw_vault.sat_customer_fintech sf
  ON v.sat_customer_fintech_hk = sf.customer_hk
 AND v.sat_customer_fintech_ldts = sf.load_dts
WINDOW w AS (PARTITION BY v.master_customer_hk ORDER BY v.effective_from);