INSERT INTO omnifin.business_vault.pit_customer_daily
REPLACE WHERE snapshot_date = current_date()
WITH latest_match AS (
  SELECT l.master_customer_hk, l.duplicate_customer_hk, s.match_status
  FROM omnifin.business_vault.sal_customer l
  JOIN omnifin.business_vault.sat_sal_customer_match s
    ON l.sal_customer_hk = s.sal_customer_hk
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY s.sal_customer_hk ORDER BY s.load_dts DESC) = 1
),
master AS (
  SELECT h.customer_hk,
         coalesce(m.master_customer_hk, h.customer_hk) AS master_customer_hk
  FROM omnifin.raw_vault.hub_customer h
  LEFT JOIN latest_match m
    ON h.customer_hk = m.duplicate_customer_hk AND m.match_status = 'MATCHED'
),
omnifin AS (SELECT customer_hk, max(load_dts) AS ldts
            FROM omnifin.raw_vault.sat_customer_omnifin GROUP BY customer_hk),
fintech AS (SELECT customer_hk, max(load_dts) AS ldts
            FROM omnifin.raw_vault.sat_customer_fintech GROUP BY customer_hk)
SELECT m.master_customer_hk,
       current_date()                                AS snapshot_date,
       max_by(o.customer_hk, o.ldts)                 AS sat_customer_omnifin_hk,
       coalesce(max(o.ldts), TIMESTAMP '1900-01-01') AS sat_customer_omnifin_ldts,
       max_by(f.customer_hk, f.ldts)                 AS sat_customer_fintech_hk,
       coalesce(max(f.ldts), TIMESTAMP '1900-01-01') AS sat_customer_fintech_ldts
FROM master m
LEFT JOIN omnifin o ON m.customer_hk = o.customer_hk
LEFT JOIN fintech f ON m.customer_hk = f.customer_hk
GROUP BY m.master_customer_hk;

INSERT INTO omnifin.business_vault.pit_customer_monthly
REPLACE WHERE snapshot_date = last_day(add_months(current_date(), -1))
SELECT * FROM omnifin.business_vault.pit_customer_daily
WHERE snapshot_date = last_day(add_months(current_date(), -1));

DELETE FROM omnifin.business_vault.pit_customer_daily
WHERE snapshot_date < date_sub(current_date(), 95);