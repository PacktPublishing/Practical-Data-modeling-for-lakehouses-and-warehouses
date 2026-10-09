CREATE TABLE IF NOT EXISTS omnifin.business_vault.sal_customer (
  sal_customer_hk       BINARY    NOT NULL,
  master_customer_hk    BINARY    NOT NULL,
  duplicate_customer_hk BINARY    NOT NULL,
  load_dts              TIMESTAMP NOT NULL,
  record_source         STRING    NOT NULL
)
CLUSTER BY (load_dts)
TBLPROPERTIES ('delta.appendOnly' = 'true');

CREATE TABLE IF NOT EXISTS omnifin.business_vault.sat_sal_customer_match (
  sal_customer_hk BINARY       NOT NULL,
  load_dts        TIMESTAMP    NOT NULL,
  applied_dts     TIMESTAMP    NOT NULL,
  record_source   STRING       NOT NULL,
  match_score     DECIMAL(4,3) NOT NULL,
  match_status    STRING       NOT NULL
)
CLUSTER BY (load_dts)
TBLPROPERTIES ('delta.appendOnly' = 'true');