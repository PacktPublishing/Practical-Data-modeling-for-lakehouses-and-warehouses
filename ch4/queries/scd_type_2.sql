WITH latest_correction AS (
  SELECT * FROM omnifin.raw_vault.sat_customer_fintech
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY customer_hk, applied_dts ORDER BY load_dts DESC) = 1
)
SELECT customer_hk,
       applied_dts AS effective_from,
       coalesce(lead(applied_dts) OVER w, TIMESTAMP '9999-12-31 23:59:59') AS effective_to,
       lead(applied_dts) OVER w IS NULL AS is_current,
       customer_tier, kyc_status, risk_score, preferred_channel
FROM latest_correction
WINDOW w AS (PARTITION BY customer_hk ORDER BY applied_dts);