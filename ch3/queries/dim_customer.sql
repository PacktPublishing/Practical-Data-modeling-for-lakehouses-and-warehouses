CREATE OR REPLACE TABLE DIM_CUSTOMER
(
    CUSTOMER_ID             BIGINT          NOT NULL,
    CUSTOMER_FULL_NAME      VARCHAR(100)    NOT NULL,
    CUSTOMER_SEGMENT        VARCHAR(20)     NOT NULL    COMMENT 'RETAIL, PRIVATE, BUSINESS, CORPORATE',
    CUSTOMER_RISK_TIER      CHAR(3)         NOT NULL    COMMENT 'LOW, MED, HIG',
    CUSTOMER_TYPE        CHAR(4)         NOT NULL    COMMENT 'INDV, CORP, SMME, GOVT',
    CUSTOMER_STATUS      CHAR(2)         NOT NULL    COMMENT 'AC=Active, SU=Suspended, CL=Closed',
    COUNTRY              CHAR(3)         NOT NULL    COMMENT 'ISO 3166-1 alpha-3',
    PREFERRED_CHANNEL    CHAR(4)                     COMMENT 'MOBI, BRNC, ONLN, ATM',
    ONBOARDING_DATE_ID      INTEGER                     COMMENT 'FK to DIM_DATE',
    IS_CURRENT              NUMBER(1,0)     NOT NULL    DEFAULT 1,
    ETL_INSERT_TS           TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP()
)


INSERT INTO DIM_CUSTOMER
WITH distinct_customers AS (
    SELECT DISTINCT customer_id FROM fact_transaction_clustered
)
SELECT
    customer_id,
    'CUST-' || LPAD(customer_id::VARCHAR, 7, '0')
    || '-' || LEFT(MD5(customer_id::VARCHAR), 8)        AS CUSTOMER_FULL_NAME,
    CASE (customer_id % 10)
        WHEN 0 THEN 'RETAIL'    WHEN 1 THEN 'RETAIL'
        WHEN 2 THEN 'RETAIL'    WHEN 3 THEN 'RETAIL'
        WHEN 4 THEN 'BUSINESS'  WHEN 5 THEN 'BUSINESS'
        WHEN 6 THEN 'BUSINESS'
        WHEN 7 THEN 'PRIVATE'   WHEN 8 THEN 'PRIVATE'
        ELSE        'CORPORATE'
    END                                                 AS CUSTOMER_SEGMENT,
    CASE (customer_id % 3)
        WHEN 0 THEN 'LOW'
        WHEN 1 THEN 'MED'
        ELSE        'HIG'
    END                                                 AS CUSTOMER_RISK_TIER,
    CASE (customer_id % 4)
        WHEN 0 THEN 'INDV'
        WHEN 1 THEN 'CORP'
        WHEN 2 THEN 'SMME'
        ELSE        'GOVT'
    END                                                 AS CUSTOMER_TYPE,
    CASE (customer_id % 10)
        WHEN 8 THEN 'SU'
        WHEN 9 THEN 'CL'
        ELSE        'AC'
    END                                                 AS CUSTOMER_STATUS,
    CASE
        WHEN (customer_id % 20) BETWEEN 0  AND 11 THEN 'ZAF'   -- 60%
        WHEN (customer_id % 20) BETWEEN 12 AND 15 THEN 'GBR'   -- 20%
        WHEN (customer_id % 20) BETWEEN 16 AND 17 THEN 'USA'   -- 10%
        WHEN  customer_id % 20  = 18               THEN 'NAM'   --  5%
        ELSE                                             'ZWE'  --  5%
    END                                                 AS COUNTRY,
    CASE (customer_id % 4)
        WHEN 0 THEN 'MOBI'
        WHEN 1 THEN 'ONLN'
        WHEN 2 THEN 'BRNC'
        ELSE        'ATM'
    END                                                 AS PREFERRED_CHANNEL,
    TO_NUMBER(TO_CHAR(
        DATEADD('day', customer_id % 5113, '2010-01-01'::DATE),
    'YYYYMMDD'))                                        AS ONBOARDING_DATE_ID,
    1                                                   AS IS_CURRENT,
    CURRENT_TIMESTAMP()                                 AS ETL_INSERT_TS
FROM distinct_customers