CREATE OR REPLACE VIEW omnifin.staging.stg_transaction_fintech AS
SELECT
    unhex(sha2(upper(trim(payload:transaction_ref::STRING)), 256)) AS transaction_hk,
    trim(payload:transaction_ref::STRING)                          AS transaction_bk,
    payload:status_timestamp::TIMESTAMP                            AS applied_dts,
    'KAFKA:PAYMENTS.TRANSACTION.POSTED'                            AS record_source,
    unhex(sha2(concat_ws('||',
        coalesce(to_json(payload:transaction_status),     '^^'),
        coalesce(to_json(payload:value_date),             '^^'),
        coalesce(to_json(payload:amount),                 '^^'),
        coalesce(to_json(payload:currency),               '^^'),
        coalesce(to_json(payload:transaction_type),       '^^'),
        coalesce(to_json(payload:channel),                '^^'),
        coalesce(to_json(payload:merchant_category_code), '^^')), 256)) AS hash_diff,
    try_variant_get(payload, '$.transaction_status', 'STRING')     AS transaction_status,
    try_variant_get(payload, '$.value_date',         'DATE')       AS value_date,
    try_variant_get(payload, '$.amount',             'DECIMAL(18,4)') AS transaction_amount,
    try_variant_get(payload, '$.currency',           'STRING')     AS transaction_currency,
    try_variant_get(payload, '$.transaction_type',   'STRING')     AS transaction_type,
    try_variant_get(payload, '$.channel',            'STRING')     AS channel,
    payload
FROM omnifin.landing.kafka_transaction
WHERE payload:transaction_ref::STRING IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY upper(trim(payload:transaction_ref::STRING)),
                 payload:status_timestamp::TIMESTAMP
    ORDER BY _landing_ts DESC) = 1;