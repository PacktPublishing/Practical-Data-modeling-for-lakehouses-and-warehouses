-- PIT_CUSTOMER: Point-In-Time table for the customer entity

CREATE OR REPLACE TABLE business_vault.pit_customer
USING DELTA AS

WITH snapshot_calendar AS (
  SELECT CAST(exploded AS DATE) AS snapshot_date
  FROM (
    SELECT EXPLODE(
      SEQUENCE(DATE('2020-01-01'), CURRENT_DATE(), INTERVAL 1 DAY)
    ) AS exploded
  )
),

hub_x_calendar AS (
  SELECT h.customer_hk, s.snapshot_date
  FROM   raw_vault.hub_customer h
  CROSS  JOIN snapshot_calendar s
  WHERE  s.snapshot_date >= CAST(h.load_dts AS DATE)
),

omnifin_with_end AS (
  SELECT
    customer_hk,
    load_dts AS sat_ldts,
    COALESCE(
      LEAD(load_dts) OVER (PARTITION BY customer_hk ORDER BY load_dts),
      TIMESTAMP('9999-12-31 23:59:59')
    ) AS sat_end_ldts
  FROM raw_vault.sat_customer_omnifin
),

fintech_with_end AS (
  SELECT
    customer_hk,
    load_dts AS sat_ldts,
    COALESCE(
      LEAD(load_dts) OVER (PARTITION BY customer_hk ORDER BY load_dts),
      TIMESTAMP('9999-12-31 23:59:59')
    ) AS sat_end_ldts
  FROM raw_vault.sat_customer_fintech
)

SELECT
  hxc.customer_hk,
  hxc.snapshot_date,
  COALESCE(o.sat_ldts, TIMESTAMP('1900-01-01')) AS sat_customer_omnifin_ldts,
  COALESCE(f.sat_ldts, TIMESTAMP('1900-01-01')) AS sat_customer_fintech_ldts
FROM hub_x_calendar hxc
LEFT JOIN omnifin_with_end o
  ON  hxc.customer_hk  = o.customer_hk
  AND hxc.snapshot_date >= CAST(o.sat_ldts AS DATE)
  AND hxc.snapshot_date <  CAST(o.sat_end_ldts AS DATE)
LEFT JOIN fintech_with_end f
  ON  hxc.customer_hk  = f.customer_hk
  AND hxc.snapshot_date >= CAST(f.sat_ldts AS DATE)
  AND hxc.snapshot_date <  CAST(f.sat_end_ldts AS DATE)