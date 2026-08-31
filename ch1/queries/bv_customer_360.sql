-- Business Vault view: BV_CUSTOMER_360
-- Joins HUB_CUSTOMER to its three current satellite records
-- and applies two business rules to derive composite attributes.
-- This is pure SQL logic — no physical storage, no pre-computation.

CREATE OR REPLACE VIEW business_vault.bv_customer_360 AS

WITH profile_current AS (
    -- Current record from SAT_CUSTOMER_PROFILE
    -- QUALIFY LEAD() IS NULL means: keep only the row
    -- that has no subsequent row for the same customer_hk.
    -- That row is by definition the most recent one.
    SELECT
        customer_hk,
        first_name,
        last_name,
        email_address,
        phone_number,
        date_of_birth,
        nationality,
        load_dts       AS profile_load_dts,
        hashdiff       AS profile_hashdiff
    FROM raw_vault.sat_customer_profile
    QUALIFY LEAD(load_dts) OVER (
        PARTITION BY customer_hk
        ORDER BY load_dts ASC
    ) IS NULL
),

kyc_current AS (
    -- Current record from SAT_CUSTOMER_KYC
    SELECT
        customer_hk,
        kyc_status,
        kyc_tier,
        document_type,
        document_expiry,
        verified_by,
        approval_ts,
        load_dts       AS kyc_load_dts,
        hashdiff       AS kyc_hashdiff
    FROM raw_vault.sat_customer_kyc
    QUALIFY LEAD(load_dts) OVER (
        PARTITION BY customer_hk
        ORDER BY load_dts ASC
    ) IS NULL
),

risk_current AS (
    -- Current record from SAT_CUSTOMER_RISK
    SELECT
        customer_hk,
        risk_score,
        risk_tier,
        model_version,
        scoring_ts,
        load_dts       AS risk_load_dts,
        hashdiff       AS risk_hashdiff
    FROM raw_vault.sat_customer_risk
    QUALIFY LEAD(load_dts) OVER (
        PARTITION BY customer_hk
        ORDER BY load_dts ASC
    ) IS NULL
)

SELECT
    -- Hub identity columns
    h.customer_hk,
    h.customer_id,
    h.load_dts                          AS hub_load_dts,
    h.record_source                     AS hub_record_source,

    -- Profile attributes (from SAT_CUSTOMER_PROFILE)
    p.first_name,
    p.last_name,
    p.email_address,
    p.phone_number,
    p.date_of_birth,
    p.nationality,
    p.profile_load_dts,

    -- KYC attributes (from SAT_CUSTOMER_KYC)
    k.kyc_status,
    k.kyc_tier,
    k.document_type,
    k.document_expiry,
    k.verified_by,
    k.approval_ts,
    k.kyc_load_dts,

    -- Risk attributes (from SAT_CUSTOMER_RISK)
    r.risk_score,
    r.risk_tier,
    r.model_version,
    r.scoring_ts,
    r.risk_load_dts,

    -- BUSINESS RULE 1: Composite customer status
    -- This is the first business rule applied in the Business Vault layer.
    -- It combines KYC status and risk tier into a single operational status.
    -- Raw Vault knows nothing of this logic — it only stores what arrived.
    CASE
        WHEN k.kyc_status = 'APPROVED' AND r.risk_tier = 'LOW'
            THEN 'ACTIVE_LOW_RISK'
        WHEN k.kyc_status = 'APPROVED' AND r.risk_tier = 'MEDIUM'
            THEN 'ACTIVE_MEDIUM_RISK'
        WHEN k.kyc_status = 'APPROVED' AND r.risk_tier = 'HIGH'
            THEN 'ACTIVE_HIGH_RISK'
        WHEN k.kyc_status = 'IN_REVIEW'
            THEN 'PENDING_KYC'
        WHEN k.kyc_status = 'REJECTED'
            THEN 'KYC_REJECTED'
        WHEN k.kyc_status IS NULL
            THEN 'AWAITING_KYC'
        ELSE 'UNKNOWN'
    END                                 AS customer_status,

    -- BUSINESS RULE 2: Product eligibility flag
    -- Derived from the combination of KYC approval and acceptable risk tier.
    -- Downstream marts consume this flag directly rather than replicating
    -- the CASE logic in every mart model.
    CASE
        WHEN k.kyc_status = 'APPROVED'
         AND r.risk_tier IN ('LOW', 'MEDIUM')
        THEN TRUE
        ELSE FALSE
    END                                 AS is_product_eligible

FROM raw_vault.hub_customer          h
LEFT JOIN profile_current            p ON h.customer_hk = p.customer_hk
LEFT JOIN kyc_current                k ON h.customer_hk = k.customer_hk
LEFT JOIN risk_current               r ON h.customer_hk = r.customer_hk;