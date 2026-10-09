CREATE TABLE IF NOT EXISTS omnifin.raw_vault.sat_transaction_fintech (
    transaction_hk        BINARY         NOT NULL,
    load_dts              TIMESTAMP      NOT NULL,
    applied_dts           TIMESTAMP      NOT NULL,
    record_source         STRING         NOT NULL,
    hash_diff             BINARY         NOT NULL,
    transaction_status    STRING,
    value_date            DATE,
    transaction_amount    DECIMAL(18,4),
    transaction_currency  STRING,
    transaction_type      STRING,
    channel               STRING,
    payload               VARIANT        NOT NULL
)
CLUSTER BY (load_dts)
TBLPROPERTIES (
    'delta.appendOnly'                    = 'true',
    'delta.enableVariantShredding'        = 'true',
    'delta.constraints.kafka_source_only' = 'record_source LIKE \'KAFKA:%\''
); 