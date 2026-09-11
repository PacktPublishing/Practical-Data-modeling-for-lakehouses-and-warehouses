CREATE TABLE project.information_mart.micromart_customer_behavior
(
  customer_id                  INT64      NOT NULL,
  snapshot_date                DATE       NOT NULL,
  -- Identity and segment attributes, sourced from Business Vault
  customer_segment             STRING     NOT NULL,
  risk_tier                    STRING     NOT NULL,
  credit_limit_usd             NUMERIC,
  -- Behavioral features, owned and computed by Customer Behavior team
  txn_vol_7d                   NUMERIC,
  txn_vol_30d                  NUMERIC,
  txn_vol_90d                  NUMERIC,
  txn_count_30d                INT64,
  txn_count_90d                INT64,
  avg_txn_amount_7d            NUMERIC,
  declined_txn_ratio_14d       NUMERIC,
  cross_border_count_30d       INT64,
  -- Audit columns, mandatory under OmniFin data contract standard
  _insert_timestamp          TIMESTAMP  NOT NULL,
  _source_pipeline           STRING     NOT NULL,
  _business_vault_version    STRING     NOT NULL
)
PARTITION BY snapshot_date
CLUSTER BY customer_id, risk_tier
OPTIONS (
  require_partition_filter = TRUE,
  partition_expiration_days = 550
);