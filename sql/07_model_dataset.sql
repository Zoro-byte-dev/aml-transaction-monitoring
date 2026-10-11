-- =====================================================================
-- 07_model_dataset.sql
-- Modelling view: features + current-transaction fields + time split
-- + label. A view, so it never goes stale and duplicates no data.
--
-- Split: chronological, by time quantiles (60 / 20 / 20 of rows),
-- not calendar days, because activity is uneven across the 18 days.
--
-- Never use as model inputs: transaction_id, transaction_time,
-- from_account, to_account, split, is_laundering,
-- current_external_payment_usd (redundant helper).
-- =====================================================================

CREATE OR REPLACE VIEW aml_model_dataset AS
WITH cutoffs AS (
    SELECT percentile_disc(0.6) WITHIN GROUP (ORDER BY transaction_time) AS train_end,
           percentile_disc(0.8) WITHIN GROUP (ORDER BY transaction_time) AS val_end
    FROM transaction_base
)
SELECT
    f.*,
    b.payment_format,
    b.payment_currency,
    b.receiving_currency,
    u.amount_paid_usd,
    (b.payment_currency <> b.receiving_currency) AS is_cross_currency,
    (b.from_bank <> b.to_bank)                   AS is_cross_bank,
    CASE WHEN f.transaction_time <  c.train_end THEN 'train'
         WHEN f.transaction_time <  c.val_end   THEN 'validation'
         ELSE 'test' END                         AS split,
    l.is_laundering
FROM aml_features_60m   f
JOIN transaction_base   b USING (transaction_id)
JOIN transaction_usd    u USING (transaction_id)
JOIN transaction_labels l USING (transaction_id)
CROSS JOIN cutoffs c;

-- Check: rows ~60/20/20, enough positives in every split
-- Observed: train 3,046,861 / 2,297 positives (0.075%)
--           validation 1,015,602 / 1,082 (0.107%)
--           test 1,015,882 / 1,798 (0.177%)
SELECT split,
       count(*)                                  AS rows,
       count(*) FILTER (WHERE is_laundering)     AS positives,
       round(100.0 * avg(is_laundering::int), 3) AS pct_laundering,
       min(transaction_time) AS first_tx,
       max(transaction_time) AS last_tx
FROM aml_model_dataset
GROUP BY split
ORDER BY min(transaction_time);
