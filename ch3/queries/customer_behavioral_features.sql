CREATE TABLE project.ml_features.customer_behavioral_features
(
  customer_id             INT64      NOT NULL,
  snapshot_date           DATE       NOT NULL,
  features ARRAY<STRUCT<
	  feature_name          STRING     NOT NULL,
	  feature_value         FLOAT64,
	  computed_at           TIMESTAMP NOT NULL
	>>
)
PARTITION BY snapshot_date
CLUSTER BY customer_id;

WITH reference_date AS (
  SELECT DATE '2024-01-31' AS as_of_date
)
SELECT
  bf.customer_id,
  bf.snapshot_date                                    AS feature_snapshot_date,
  DATE_DIFF(r.as_of_date, bf.snapshot_date, DAY)     AS feature_lag_days,
  bf.features
FROM reference_date r
CROSS JOIN project.ml_features.customer_behavioral_features bf
WHERE bf.snapshot_date <= r.as_of_date
  AND bf.snapshot_date >= DATE_SUB(r.as_of_date, INTERVAL 95 DAY)
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY bf.customer_id
  ORDER BY bf.snapshot_date DESC
) = 1
SELECT
	ls.customer_id,
	ls.feature_snapshot_date,
	ls.feature_lag_days,
	MAX(IF(f.feature_name = 'txn_vol_30d',            f.feature_value, NULL)) AS txn_vol_30d,
  MAX(IF(f.feature_name = 'txn_count_90d',          f.feature_value, NULL)) AS txn_count_90d,
  MAX(IF(f.feature_name = 'avg_txn_amount_7d',      f.feature_value, NULL)) AS avg_txn_amount_7d,
  MAX(IF(f.feature_name = 'declined_txn_ratio_14d', f.feature_value, NULL)) AS declined_txn_ratio_14d
FROM latest_snapshot ls,
UNNEST(ls.features) AS f
GROUP BY
  ls.customer_id,
  ls.feature_snapshot_date,
  ls.feature_lag_days;


SELECT
  ca.customer_id,
  ca.snapshot_date,
  ca.customer_segment,
  ca.risk_tier,
  ca.credit_limit_usd
FROM reference_date r
CROSS JOIN project.replicated.customer_attribute_snapshots ca
WHERE ca.snapshot_date <= r.as_of_date
  AND ca.snapshot_date >= DATE_SUB(r.as_of_date, INTERVAL 95 DAY)
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY ca.customer_id
  ORDER BY ca.snapshot_date DESC
) = 1;