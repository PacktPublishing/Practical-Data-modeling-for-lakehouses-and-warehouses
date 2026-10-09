> SHOW CREATE TABLE omnifin.raw_vault.sat_customer_fintech;

> CREATE TABLE omnifin.raw_vault.sat_customer_fintech (
		customer_hk       BINARY       NOT NULL,
		load_dts          TIMESTAMP    NOT NULL,
		applied_dts       TIMESTAMP    NOT NULL,
		record_source     STRING       NOT NULL,
		hash_diff         BINARY       NOT NULL,
		customer_tier     STRING,
		kyc_status        STRING,
		risk_score        DECIMAL(5,2),
		preferred_channel STRING)
USING DELTA
CLUSTER BY (load_dts)
TBLPROPERTIES (
	'delta.appendOnly' = 'true',
	'delta.constraints.kafka_source_only' = 'record_source LIKE \'KAFKA:%\'',
);