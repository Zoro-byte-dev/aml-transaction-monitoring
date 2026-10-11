-- =====================================================================
-- 04_transaction_usd.sql
-- Every transaction with both amounts converted to USD.
--
-- * amount_paid_usd     -> used for the sender's OUTGOING features
-- * amount_received_usd -> used for the receiver's INCOMING features
-- Inner joins are deliberate: an unmapped currency would drop rows,
-- and the row-count check below would catch it.
-- =====================================================================

DROP TABLE IF EXISTS transaction_usd;

CREATE TABLE transaction_usd AS
SELECT
    t.transaction_id,
    t.transaction_time,
    t.from_account,
    t.to_account,
    t.amount_paid,
    t.payment_currency,
    t.amount_received,
    t.receiving_currency,
    t.amount_paid     * p.usd_per_unit AS amount_paid_usd,
    t.amount_received * r.usd_per_unit AS amount_received_usd
FROM transaction_base t
JOIN currency_map cp ON cp.currency_name = t.payment_currency
JOIN currency_map cr ON cr.currency_name = t.receiving_currency
JOIN fx_rates p ON p.currency_code = cp.currency_code
               AND p.rate_date     = t.transaction_time::date
JOIN fx_rates r ON r.currency_code = cr.currency_code
               AND r.rate_date     = t.transaction_time::date;

ALTER TABLE transaction_usd ADD PRIMARY KEY (transaction_id);

-- Covering indexes: every window lookup in 05 is answered from these
CREATE INDEX ix_transaction_usd_from_time
    ON transaction_usd (from_account, transaction_time)
    INCLUDE (amount_paid_usd, to_account);
CREATE INDEX ix_transaction_usd_to_time
    ON transaction_usd (to_account, transaction_time)
    INCLUDE (amount_received_usd, from_account);

ANALYZE transaction_usd;

-- Check 1: no rows lost, no NULL conversions
SELECT (SELECT count(*) FROM transaction_base) AS base_rows,
       count(*)                                AS usd_rows,
       count(*) FILTER (WHERE amount_paid_usd IS NULL
                           OR amount_received_usd IS NULL) AS null_rows
FROM transaction_usd;

-- Check 2: paid and received agree after conversion (ignore sub-$1 dust,
-- where 2-decimal / 6-decimal rounding dominates). mean_rel_diff ~0.
SELECT payment_currency,
       receiving_currency,
       count(*) AS n,
       avg(abs(amount_paid_usd - amount_received_usd) / amount_paid_usd) AS mean_rel_diff
FROM transaction_usd
WHERE payment_currency <> receiving_currency
  AND amount_paid_usd >= 1
GROUP BY 1, 2
ORDER BY mean_rel_diff DESC
LIMIT 20;
