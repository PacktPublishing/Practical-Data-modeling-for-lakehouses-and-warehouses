-- BRIDGE_CUSTOMER_ACCOUNT: Pre-navigated relationship path

CREATE OR REPLACE TABLE business_vault.bridge_customer_account
USING DELTA AS

SELECT
  hc.customer_hk,
  hc.customer_bk      AS customer_id,
  ha.account_hk,
  ha.account_bk       AS account_id,
  lca.load_dts       AS relationship_load_date,
  lca.record_source   AS relationship_source,
  sa.account_type,
  sa.account_status,
  sa.account_currency,
  sa.account_open_date
FROM raw_vault.hub_customer hc
JOIN raw_vault.link_customer_account lca
  ON  hc.customer_hk = lca.customer_hk
JOIN raw_vault.hub_account ha
  ON  lca.account_hk = ha.account_hk
JOIN (
  SELECT
    account_hk, account_type, account_status,
    account_currency, account_open_date,
    ROW_NUMBER() OVER (PARTITION BY account_hk ORDER BY load_dts DESC) AS rn
  FROM raw_vault.sat_account_omnifin
) sa ON ha.account_hk = sa.account_hk AND sa.rn = 1