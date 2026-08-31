-- fact_transaction: Kimball fact derived from Raw Vault via Bridge table

CREATE OR REPLACE TABLE consumption.fact_transaction AS

WITH latest_sat AS (
  SELECT
    transaction_hk,
    load_dts, 
    record_source,
    transaction_amount,
    transaction_currency,
    transaction_type,
    transaction_date,
    channel, is_flagged_fraud,
    ROW_NUMBER() OVER (PARTITION BY transaction_hk ORDER BY load_dts DESC) AS rn
  FROM raw_vault.sat_transaction              
)

SELECT
  dc.customer_sk,
  da.account_sk,
  dd.date_sk,

  ht.transaction_bk                  AS transaction_id,
  ls.record_source,
  ls.transaction_amount,
  ls.transaction_currency,
  ls.transaction_type,
  ls.channel,
  ls.is_flagged_fraud,

  -- Late-arriving data: vault absorbed it; fact table surfaces it for analysts
  CASE
    WHEN ls.load_dts > DATEADD(HOUR, 2, ls.transaction_date)
    THEN TRUE ELSE FALSE
  END                                AS is_late_arriving,

  ls.load_dts                       AS vault_load_timestamp

FROM raw_vault.hub_transaction ht             
JOIN latest_sat ls
  ON  ht.transaction_hk = ls.transaction_hk AND ls.rn = 1
JOIN raw_vault.link_account_transaction lat    
  ON  ht.transaction_hk = lat.transaction_hk
JOIN business_vault.bridge_customer_account bca 
  ON  lat.account_hk = bca.account_hk
JOIN consumption.dim_customer dc
  ON  bca.customer_hk = dc.customer_sk
JOIN consumption.dim_account da
  ON  bca.account_hk  = da.account_sk
JOIN consumption.dim_date dd
  ON  CAST(ls.transaction_date AS DATE) = dd.full_date