-- Staging table

CREATE OR REPLACE TABLE stg.customer (
    customer_id          VARCHAR(20),       -- Natural key from core banking system
    full_name            VARCHAR(100),
    date_of_birth        DATE,
    home_city            VARCHAR(50),
    home_postal_code     VARCHAR(10),
    email_address        VARCHAR(100),
    phone_number         VARCHAR(20),
    income_band          VARCHAR(20),       -- e.g. '<30K','30K-60K','60K-100K','>100K'
    employment_status    VARCHAR(30),       -- 'Employed','Self-Employed','Retired','Unemployed'
    credit_risk_rating   VARCHAR(10),       -- 'Low','Medium','High' — re-assessed quarterly
    customer_segment     VARCHAR(20),       -- 'Retail','Premium','Private Banking'
    kyc_status           VARCHAR(20),       -- 'Verified','Pending','Expired' — for compliance
    last_updated_at      TIMESTAMP_NTZ      -- Watermark from the source system
);

-- Dim table

CREATE OR REPLACE TABLE edw.dim_customer (
    -- Surrogate key: Kimball-mandated, Snowflake auto-generates this
    customer_sk          NUMBER AUTOINCREMENT PRIMARY KEY,

    -- Natural key: ties back to the source system
    customer_id          VARCHAR(20),

    -- Customer attributes
    full_name            VARCHAR(100),
    date_of_birth        DATE,
    home_city            VARCHAR(50),
    home_postal_code     VARCHAR(10),
    email_address        VARCHAR(100),
    phone_number         VARCHAR(20),
    income_band          VARCHAR(20),
    employment_status    VARCHAR(30),
    credit_risk_rating   VARCHAR(10),
    customer_segment     VARCHAR(20),
    kyc_status           VARCHAR(20),

    -- SCD Type 2 tracking columns (Kimball naming conventions)
    effective_date       TIMESTAMP_NTZ,     -- When this version became active
    expiry_date          TIMESTAMP_NTZ,     -- When this version expired (9999-12-31 = still active)
    is_current           BOOLEAN,           -- TRUE = active record, FALSE = historical

    -- Audit
    row_created_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Stream table

CREATE OR REPLACE STREAM stg.customer_changes ON TABLE stg.customer;

-- Change data view

CREATE OR REPLACE VIEW stg.customer_change_data AS

-- New customers loaded for the first time
SELECT customer_id, full_name, date_of_birth, home_city, home_postal_code,
       email_address, phone_number, income_band, employment_status,
       credit_risk_rating, customer_segment, kyc_status,
       start_time, end_time, is_current, 'I' AS dml_type
FROM (
    SELECT customer_id, full_name, date_of_birth, home_city, home_postal_code,
           email_address, phone_number, income_band, employment_status,
           credit_risk_rating, customer_segment, kyc_status,
           last_updated_at AS start_time,
           LAG(last_updated_at) OVER (PARTITION BY customer_id ORDER BY last_updated_at DESC) AS end_time_raw,
           CASE WHEN end_time_raw IS NULL THEN '9999-12-31'::TIMESTAMP_NTZ ELSE end_time_raw END AS end_time,
           CASE WHEN end_time_raw IS NULL THEN TRUE ELSE FALSE END AS is_current
    FROM stg.customer_changes
    WHERE METADATA$ACTION = 'INSERT' AND METADATA$ISUPDATE = 'FALSE'
)

UNION

-- Updated customers: expire old row (U) + insert new version (I)
SELECT customer_id, full_name, date_of_birth, home_city, home_postal_code,
       email_address, phone_number, income_band, employment_status,
       credit_risk_rating, customer_segment, kyc_status,
       start_time, end_time, is_current, dml_type
FROM (
    SELECT customer_id, full_name, date_of_birth, home_city, home_postal_code,
           email_address, phone_number, income_band, employment_status,
           credit_risk_rating, customer_segment, kyc_status,
           last_updated_at AS start_time,
           LAG(last_updated_at) OVER (PARTITION BY customer_id ORDER BY last_updated_at DESC) AS end_time_raw,
           CASE WHEN end_time_raw IS NULL THEN '9999-12-31'::TIMESTAMP_NTZ ELSE end_time_raw END AS end_time,
           CASE WHEN end_time_raw IS NULL THEN TRUE ELSE FALSE END AS is_current,
           dml_type
    FROM (
        SELECT customer_id, full_name, date_of_birth, home_city, home_postal_code,
               email_address, phone_number, income_band, employment_status,
               credit_risk_rating, customer_segment, kyc_status,
               last_updated_at, 'I' AS dml_type
        FROM stg.customer_changes
        WHERE METADATA$ACTION = 'INSERT' AND METADATA$ISUPDATE = 'TRUE'

        UNION

        SELECT customer_id, NULL, NULL, NULL, NULL, NULL, NULL,
               NULL, NULL, NULL, NULL, NULL,
               effective_date, 'U' AS dml_type
        FROM edw.dim_customer
        WHERE customer_id IN (
            SELECT DISTINCT customer_id FROM stg.customer_changes
            WHERE METADATA$ACTION = 'INSERT' AND METADATA$ISUPDATE = 'TRUE'
        )
        AND is_current = TRUE
    )
)

UNION

-- Closed/offboarded customers: logically expire their current row
SELECT dc.customer_id, NULL, NULL, NULL, NULL, NULL, NULL,
       NULL, NULL, NULL, NULL, NULL,
       dc.effective_date, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, FALSE, 'D'
FROM edw.dim_customer dc
INNER JOIN stg.customer_changes sc ON dc.customer_id = sc.customer_id
WHERE sc.METADATA$ACTION = 'DELETE'
  AND sc.METADATA$ISUPDATE = 'FALSE'
  AND dc.is_current = TRUE;


-- Stream task edw.load_dim_customer

CREATE OR REPLACE TASK edw.load_dim_customer
    WAREHOUSE = transform_wh
    SCHEDULE  = '1 minute'
    WHEN system$stream_has_data('stg.customer_changes')
AS

MERGE INTO edw.dim_customer dc
USING stg.customer_change_data cd
    ON dc.customer_id  = cd.customer_id
   AND dc.effective_date = cd.start_time

-- Expire the old version of a changed customer
WHEN MATCHED AND cd.dml_type = 'U' THEN UPDATE
    SET dc.expiry_date = cd.end_time,
        dc.is_current  = FALSE

-- Logically close a customer who has left the bank
WHEN MATCHED AND cd.dml_type = 'D' THEN UPDATE
    SET dc.expiry_date = cd.end_time,
        dc.is_current  = FALSE

-- Insert a new customer or a new version of an existing customer
-- customer_sk is intentionally omitted — AUTOINCREMENT generates it
WHEN NOT MATCHED AND cd.dml_type = 'I' THEN INSERT
    (customer_id, full_name, date_of_birth, home_city, home_postal_code,
     email_address, phone_number, income_band, employment_status,
     credit_risk_rating, customer_segment, kyc_status,
     effective_date, expiry_date, is_current)
VALUES
    (cd.customer_id, cd.full_name, cd.date_of_birth, cd.home_city, cd.home_postal_code,
     cd.email_address, cd.phone_number, cd.income_band, cd.employment_status,
     cd.credit_risk_rating, cd.customer_segment, cd.kyc_status,
     cd.start_time, cd.end_time, cd.is_current);
