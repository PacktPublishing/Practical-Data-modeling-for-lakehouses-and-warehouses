-- The staging table loaded by Snowpipe from the Kafka account.status.changed topic.
-- Hash keys and HashDiff are computed here before the vault load.

CREATE OR REPLACE TABLE staging.account_balance_staging (
    account_id          VARCHAR(36)    NOT NULL,
    account_hk          BINARY(20)     NOT NULL,  -- SHA1_BINARY(UPPER(TRIM(account_id)))
    balance_hashdiff    BINARY(20)     NOT NULL,  -- SHA1_BINARY of all balance attribute columns
    balance_amount      NUMBER(18,2)   NOT NULL,
    available_balance   NUMBER(18,2)   NOT NULL,
    reserved_balance    NUMBER(18,2)   NOT NULL,
    balance_currency    VARCHAR(3)     NOT NULL,
    balance_timestamp   TIMESTAMP_NTZ  NOT NULL,
    load_dts            TIMESTAMP_NTZ  NOT NULL,
    record_source       VARCHAR(100)   NOT NULL
);

-- Append-only stream because SAT_ACCOUNT_BALANCE is insert-only.
-- APPEND_ONLY = TRUE means the stream only tracks INSERT operations,
-- not UPDATEs or DELETEs on the staging table.
-- This is correct for a raw vault satellite source.

CREATE OR REPLACE STREAM staging.account_balance_stream
    ON TABLE staging.account_balance_staging
    APPEND_ONLY = TRUE;

-- The Task that polls the stream every minute
-- and loads new rows into SAT_ACCOUNT_BALANCE.

CREATE OR REPLACE TASK raw_vault.load_sat_account_balance
    WAREHOUSE = FINTECH_DV_MEDIUM        -- upgraded from XS three months ago
    SCHEDULE  = '1 MINUTE'
WHEN
    SYSTEM$STREAM_HAS_DATA('staging.account_balance_stream')
AS
INSERT INTO raw_vault.sat_account_balance (
    account_hk,
    load_dts,
    record_source,
    hashdiff,
    balance_amount,
    available_balance,
    reserved_balance,
    balance_currency,
    balance_timestamp
)
SELECT
    src.account_hk,
    src.load_dts,
    src.record_source,
    src.balance_hashdiff,
    src.balance_amount,
    src.available_balance,
    src.reserved_balance,
    src.balance_currency,
    src.balance_timestamp
FROM staging.account_balance_stream src
LEFT JOIN (
    SELECT
        account_hk,
        hashdiff
    FROM raw_vault.sat_account_balance
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY account_hk
        ORDER BY load_dts DESC
    ) = 1
) latest
ON  src.account_hk = latest.account_hk
WHERE latest.hashdiff IS NULL              -- new account never seen before
   OR src.balance_hashdiff != latest.hashdiff;  -- balance genuinely changed