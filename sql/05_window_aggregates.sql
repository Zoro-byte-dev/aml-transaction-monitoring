-- =====================================================================
-- 05_window_aggregates.sql
-- Raw, historical window aggregates for each transaction's SENDER.
--
-- Global rules (apply to every subquery):
--   1. External only: self-transfers (from_account = to_account) are
--      excluded from every window.
--   2. Strictly historical: windows cover [t - window, t). The current
--      transaction and anything later are never counted.
--   3. Windows are anchored on the sender (t.from_account).
--
-- Derived features (ratios, guards, pass-through) are built in 06.
-- Expect this script to take a while: it runs several index lookups
-- for each of the 5,078,345 rows.
-- =====================================================================

DROP TABLE IF EXISTS feat_window_aggregates;

CREATE TABLE feat_window_aggregates AS
SELECT
    t.transaction_id,

    -- 60m external outflow
    o.out_cnt_60m,
    o.out_vol_60m,
    o.out_cp_60m,

    -- 60m external inflow
    i.in_cnt_60m,
    i.in_vol_60m,
    i.in_cp_60m,

    -- 5m external outflow
    b.out_cnt_5m,
    b.out_vol_5m,

    -- other external payments sent in the same minute
    s.same_minute_out_cnt,

    -- latest external inflow inside the 60m window
    li.last_in_time_60m,

    -- per-recipient outflow volumes, for concentration features
    cp.dominant_cp_vol_60m,
    cp.top3_cp_vol_60m,
    cp.sum_sq_cp_vol_60m

FROM transaction_usd t

CROSS JOIN LATERAL (
    SELECT count(*)                            AS out_cnt_60m,
           COALESCE(sum(u.amount_paid_usd), 0) AS out_vol_60m,
           count(DISTINCT u.to_account)        AS out_cp_60m
    FROM transaction_usd u
    WHERE u.from_account = t.from_account
      AND u.from_account <> u.to_account
      AND u.transaction_time >= t.transaction_time - INTERVAL '60 minutes'
      AND u.transaction_time <  t.transaction_time
) o

CROSS JOIN LATERAL (
    SELECT count(*)                                AS in_cnt_60m,
           COALESCE(sum(u.amount_received_usd), 0) AS in_vol_60m,
           count(DISTINCT u.from_account)          AS in_cp_60m
    FROM transaction_usd u
    WHERE u.to_account = t.from_account
      AND u.from_account <> u.to_account
      AND u.transaction_time >= t.transaction_time - INTERVAL '60 minutes'
      AND u.transaction_time <  t.transaction_time
) i

CROSS JOIN LATERAL (
    SELECT count(*)                            AS out_cnt_5m,
           COALESCE(sum(u.amount_paid_usd), 0) AS out_vol_5m
    FROM transaction_usd u
    WHERE u.from_account = t.from_account
      AND u.from_account <> u.to_account
      AND u.transaction_time >= t.transaction_time - INTERVAL '5 minutes'
      AND u.transaction_time <  t.transaction_time
) b

CROSS JOIN LATERAL (
    -- order within a minute is unknown, so this is reported separately
    SELECT count(*) AS same_minute_out_cnt
    FROM transaction_usd u
    WHERE u.from_account = t.from_account
      AND u.from_account <> u.to_account
      AND u.transaction_time = t.transaction_time
      AND u.transaction_id  <> t.transaction_id
) s

LEFT JOIN LATERAL (
    SELECT u.transaction_time AS last_in_time_60m
    FROM transaction_usd u
    WHERE u.to_account = t.from_account
      AND u.from_account <> u.to_account
      AND u.transaction_time >= t.transaction_time - INTERVAL '60 minutes'
      AND u.transaction_time <  t.transaction_time
    ORDER BY u.transaction_time DESC
    LIMIT 1
) li ON true

CROSS JOIN LATERAL (
    SELECT max(v)                         AS dominant_cp_vol_60m,
           sum(v) FILTER (WHERE rn <= 3)  AS top3_cp_vol_60m,
           sum(v * v)                     AS sum_sq_cp_vol_60m
    FROM (
        SELECT sum(u.amount_paid_usd) AS v,
               row_number() OVER (ORDER BY sum(u.amount_paid_usd) DESC) AS rn
        FROM transaction_usd u
        WHERE u.from_account = t.from_account
          AND u.from_account <> u.to_account
          AND u.transaction_time >= t.transaction_time - INTERVAL '60 minutes'
          AND u.transaction_time <  t.transaction_time
        GROUP BY u.to_account
    ) per_cp
) cp;

ALTER TABLE feat_window_aggregates ADD PRIMARY KEY (transaction_id);
ANALYZE feat_window_aggregates;

-- Check: one row per transaction (expect 5,078,345)
SELECT count(*) FROM feat_window_aggregates;
