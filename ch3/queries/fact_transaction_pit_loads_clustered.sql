CREATE OR REPLACE TABLE fact_transaction_pit_loads_clustered
(
    date_id                 INTEGER         NOT NULL COMMENT 'Value date YYYYMMDD',
    snapshot_date           DATE            NOT NULL COMMENT 'PIT snapshot date',
    date_diff               INTEGER         NOT NULL COMMENT 'DATE_SK minus SNAPSHOT_DATE',
    transaction_type        CHAR(3)         NOT NULL,
    transaction_status      CHAR(2)         NOT NULL,
    account_id              INTEGER         NOT NULL,
    transaction_amount      NUMBER(18,4)    NOT NULL
)
CLUSTER BY (date_id, transaction_type);

CREATE OR REPLACE TABLE fact_transaction_pit_loads_degraded
(
    date_id                 INTEGER         NOT NULL COMMENT 'Value date YYYYMMDD — the cluster key',
    snapshot_date           DATE            NOT NULL COMMENT 'PIT snapshot date — NOT the cluster key',
    DATE_DIVERGENCE_DAYS    INTEGER         NOT NULL COMMENT 'DATE_SK minus SNAPSHOT_DATE. Non-zero = the problem.',
    TRANSACTION_HASH_KEY    VARCHAR(32)     NOT NULL,
    TRANSACTION_TYPE     CHAR(3)         NOT NULL,
    TRANSACTION_STATUS   CHAR(2)         NOT NULL,
    ACCOUNT_ID              INTEGER         NOT NULL,
    TRANSACTION_AMT         NUMBER(18,4)    NOT NULL
)
CLUSTER BY (date_id, TRANSACTION_TYPE);

INSERT INTO fact_transaction_pit_loads_clustered
WITH pit_output AS (
    SELECT
        -- SNAPSHOT_DATE: the PIT driving date, spread across 90 days
        DATEADD('day', UNIFORM(0, 89, RANDOM())::INT, '2024-01-01'::DATE) AS snap_date,
        -- Date divergence weight (single roll per row — correct weighting)
        UNIFORM(1, 11, RANDOM())::INT                                      AS date_weight,
        UNIFORM(1, 5,  RANDOM())::INT                                      AS type_roll,
        UNIFORM(1, 4,  RANDOM())::INT                                      AS status_roll,
        UNIFORM(1, 1000000, RANDOM())::INT                                 AS acct_sk,
        ROUND(EXP(2.3 + UNIFORM(0, 970, RANDOM())::FLOAT / 100), 2)       AS txn_amt,
        SEQ8() + 1                                                         AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 30000000))   -- 30M rows → enough partitions to show the gap
),
with_value_date AS (
    SELECT
        snap_date,
        -- VALUE_DATE diverges from SNAPSHOT_DATE in 30% of rows
        DATEADD('day',
            CASE date_weight
                WHEN 8  THEN -1    -- yesterday backdated
                WHEN 9  THEN -2    -- SWIFT T+2
                WHEN 10 THEN -3    -- SWIFT T+3 / correction
                WHEN 11 THEN  1    -- pre-value-dated FX
                ELSE         0     -- clean transaction (70%)
            END,
        snap_date)                                                         AS value_date,
        date_weight,
        type_roll, status_roll, acct_sk, txn_amt, rn
    FROM pit_output
)
SELECT
    TO_NUMBER(TO_CHAR(value_date, 'YYYYMMDD'))                            AS date_id,
    snap_date                                                             AS SNAPSHOT_DATE,
    DATEDIFF('day', snap_date, value_date)                                AS DATE_DIVERGENCE_DAYS,
    MD5(LPAD(rn::VARCHAR, 12, '0'))                                       AS TRANSACTION_HASH_KEY,
    CASE type_roll WHEN 1 THEN 'ATM' WHEN 2 THEN 'FEE'
                   WHEN 3 THEN 'POS' WHEN 4 THEN 'PMT' ELSE 'TRF' END    AS TRANSACTION_TYPE,
    CASE status_roll WHEN 1 THEN 'PE' WHEN 2 THEN 'RE'
                     WHEN 3 THEN 'CA' ELSE 'AP' END                       AS TRANSACTION_STATUS,
    acct_sk                                                               AS ACCOUNT_ID,
    txn_amt                                                               AS TRANSACTION_AMT
FROM with_value_date
ORDER BY DATE_ID, TRANSACTION_TYPE;


INSERT INTO fact_transaction_pit_loads_degraded
SELECT * FROM fact_transaction_pit_loads_clustered;

SELECT
    'SORTED'   AS scenario,
    info:total_partition_count::INT AS total_partitions,
    ROUND(info:average_overlaps::FLOAT, 1) AS avg_overlaps,
    ROUND(info:average_depth::FLOAT,   1) AS avg_depth,
    '← close to 1.0 = healthy'     AS interpretation
FROM (SELECT PARSE_JSON(SYSTEM$CLUSTERING_INFORMATION(
    'fact_transaction_pit_loads_clustered', '(DATE_id, TRANSACTION_TYPE)')) AS info)
 
UNION ALL
 
SELECT
    'DEGRADED',
    info:total_partition_count::INT,
    ROUND(info:average_overlaps::FLOAT, 1),
    ROUND(info:average_depth::FLOAT,   1),
    '← high value = every query scans everything'
FROM (SELECT PARSE_JSON(SYSTEM$CLUSTERING_INFORMATION(
    'fact_transaction_pit_loads_degraded', '(DATE_id, TRANSACTION_TYPE)')) AS info);

