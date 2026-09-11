CREATE TABLE fact_transaction
(
	transaction_id BIGINT NOT NULL,
	account_id INTEGER NOT NULL,
	customer_id INTEGER NOT NULL,
	date_id INTEGER NOT NULL,
	channel_id BYTEINT NOT NULL,
	product_id SMALLINT NOT NULL,
	currency_id BYTEINT NOT NULL,
	country_id SMALLINT,
	branch_id SMALLINT,
	transaction_ref VARCHAR(50) NOT NULL,
	transaction_type CHAR(3),
	transaction_status CHAR(3),
	payment_method CHAR(4),
	transaction_amount NUMERIC(18,4) NOT NULL,
	transaction_amount_local NUMERIC(18,4),
	authorized_amount NUMERIC(18,4),
	fee_amount NUMERIC(18,4),
	vat_amount NUMERIC(12,4),
	running_balance_amount NUMERIC(18,4),
	foreign_exchange_rate NUMERIC(10,6),
	etl_batch_id INTEGER NOT NULL,
	etl_insert_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	etl_update_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	etl_source_system CHAR(6) NOT NULL,
	record_valid_flag BYTEINT NOT NULL DEFAULT 1
)


INSERT INTO fact_transaction
WITH base AS (
    SELECT
        -- Sequential row number → becomes the surrogate PK
        SEQ8() + 1                                          AS rn,
 
        -- ── Date randomisation (THE KEY: fully random, no temporal order) ──
        UNIFORM(0, 1094, RANDOM())::INTEGER                 AS date_offset,     -- days from 2022-01-01
        UNIFORM(0, 2,    RANDOM())::INTEGER                 AS booking_lag,     -- 0-2 day settlement lag
        UNIFORM(0, 86399,RANDOM())::INTEGER                 AS time_of_day_s,   -- seconds since midnight
 
        -- ── Dimension foreign keys ──
        UNIFORM(1, 1000000, RANDOM())::INTEGER              AS acct_sk,
        UNIFORM(1, 800000,  RANDOM())::INTEGER              AS cust_sk,
        UNIFORM(1, 1000000, RANDOM())::INTEGER              AS counterparty_sk,
        UNIFORM(1, 5,       RANDOM())::SMALLINT             AS channel_sk,
        UNIFORM(1, 20,      RANDOM())::SMALLINT             AS product_sk,
        1             AS currency_sk,     
        UNIFORM(1, 30,      RANDOM())::SMALLINT             AS country_sk,
        UNIFORM(1, 200,     RANDOM())::SMALLINT             AS branch_sk,
 
        -- ── Categorical dice rolls (single roll per column, used in CASE below) ──
        UNIFORM(1, 100, RANDOM())::INTEGER                  AS type_roll,
        UNIFORM(1, 100, RANDOM())::INTEGER                  AS status_roll,
        UNIFORM(1, 4,   RANDOM())::INTEGER                  AS method_roll,
        UNIFORM(1, 3,   RANDOM())::INTEGER                  AS src_roll,
 
        -- ── Measures ──
        UNIFORM(1, 500, RANDOM())::INTEGER                  AS batch_id,
 
        -- Transaction amount: EXP(uniform 2.3–12.0) → range 10–163K ZAR
        -- Log-scale gives realistic heavy-tailed retail banking distribution
        ROUND(EXP(
            2.3 + UNIFORM(0, 970, RANDOM())::FLOAT / 100.0
        ), 2)                                               AS raw_amt,
 
        -- FX rate (1 for USD)
        1.0 AS fx_rate,
 
        -- Auth percentage (95–100% of transaction amount)
        UNIFORM(95, 100, RANDOM())::INTEGER                 AS auth_pct,
 
        -- Running balance multiplier (balance = raw_amt × 1–50)
        UNIFORM(1, 50, RANDOM())::INTEGER                   AS balance_mult
 
    FROM TABLE(GENERATOR(ROWCOUNT => 500000000))   -- ← adjust for your scale
),
derived AS (
    SELECT
        rn,
        -- Materialise the transaction date and booking date
        DATEADD('day', date_offset,              '2022-01-01'::DATE) AS txn_date,
        DATEADD('day', date_offset + booking_lag,'2022-01-01'::DATE) AS booking_date,
        time_of_day_s,
        acct_sk, cust_sk, counterparty_sk,
        channel_sk, product_sk, currency_sk, country_sk, branch_sk,
        batch_id, raw_amt, fx_rate, auth_pct, balance_mult,
 
        -- Weighted transaction type from a single roll
        -- TRF 35% | PMT 30% | ATM 15% | POS 15% | FEE 5%
        CASE
            WHEN type_roll <=  35 THEN 'TRF'
            WHEN type_roll <=  65 THEN 'PMT'
            WHEN type_roll <=  80 THEN 'ATM'
            WHEN type_roll <=  95 THEN 'POS'
            ELSE                       'FEE'
        END AS txn_type,
 
        -- Weighted status from a single roll
        -- AP 80% | PE 10% | RE 7% | CA 3%
        CASE
            WHEN status_roll <=  80 THEN 'AP'
            WHEN status_roll <=  90 THEN 'PE'
            WHEN status_roll <=  97 THEN 'RE'
            ELSE                         'CA'
        END AS txn_status,
 
        -- Payment method
        CASE method_roll
            WHEN 1 THEN 'CARD'
            WHEN 2 THEN 'SWFT'
            WHEN 3 THEN 'SEPA'
            ELSE        'RTGS'
        END AS pay_method,
 
        -- Source system
        CASE src_roll
            WHEN 1 THEN 'COREBN'
            WHEN 2 THEN 'CARDS_'
            ELSE        'SWIFT_'
        END AS src_sys
 
    FROM base
)
SELECT
    -- Surrogate key
    rn                                                      AS TRANSACTION_ID,
 
    -- Dimension FKs
    acct_sk                                                 AS ACCOUNT_ID,
    cust_sk                                                 AS CUSTOMER_ID,
    TO_NUMBER(TO_CHAR(txn_date,     'YYYYMMDD'))            AS DATE_ID,
    channel_sk                                              AS CHANNEL_ID,
    product_sk                                              AS PRODUCT_ID,
    currency_sk                                             AS CURRENCY_ID,
    country_sk                                              AS COUNTRY_ID,
    branch_sk                                               AS BRANCH_ID,
 
    -- Degenerate dimensions
    'TXN' || LPAD(rn::VARCHAR, 12, '0')                     AS TRANSACTION_REF,
    txn_type                                                AS TRANSACTION_TYPE,
    txn_status                                              AS TRANSACTION_STATUS,
    pay_method                                              AS PAYMENT_METHOD,
 
    -- Measures
    raw_amt                                                 AS TRANSACTION_AMOUNT,
    ROUND(raw_amt * fx_rate, 4)                             AS TRANSACTION_AMOUNT_LOCAL,
    ROUND(raw_amt * auth_pct / 100.0, 4)                   AS AUTHORIZED_AMOUNT,
    ROUND(raw_amt * 0.0085, 4)                             AS FEE_AMOUNT,        -- 0.85% service fee
    ROUND(raw_amt * 0.0085 * 0.15, 4)                      AS VAT_AMOUNT,        -- 15% VAT on fee
    ROUND(raw_amt * balance_mult, 4)                        AS RUNNING_BALANCE_AMOUNT,
    fx_rate                                                 AS FOREIGN_EXCHANGE_RATE,
 
    -- ETL audit
    batch_id                                                AS ETL_BATCH_ID,
    CURRENT_TIMESTAMP()                                     AS ETL_INSERT_TIMESTAMP,
    CURRENT_TIMESTAMP()                                     AS ETL_UPDATE_TIMETSTAMP,
    src_sys                                                 AS ETL_SOURCE_SYSTEM,
    1                                                       AS RECORD_VALID_FLAG
 
FROM derived;