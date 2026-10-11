-- =====================================================================
-- 99_validation.sql
-- Data-quality checks on aml_features_60m.
-- Every check has a known expected result; any difference is a bug.
-- =====================================================================

-- 1. Row count and populations
--    Expected: 5,078,345 | 2,631,300 | 823,489 | 744,052 | 743,768
--              332,427 | 345,567 | 618,592 | 450,561 | 618,592
SELECT
  count(*)                                          AS n,
  count(external_outgoing_volume_share_60m)         AS vol_share,
  count(external_outgoing_tx_share_60m)             AS tx_share,
  count(external_outgoing_tx_5m_concentration)      AS tx_conc,
  count(external_outgoing_volume_5m_concentration)  AS vol_conc,
  count(flow_through_ratio_60m)                     AS ft_ratio,
  count(minutes_since_last_external_incoming_60m)   AS gap,
  count(dominant_outgoing_counterparty_share_60m)   AS dominant,
  count(top3_outgoing_counterparty_share_60m)       AS top3,
  count(outgoing_counterparty_hhi_60m)              AS hhi
FROM aml_features_60m;

-- 2. Bounds and non-negativity: expect 0 for every column
SELECT
  count(*) FILTER (WHERE external_outgoing_volume_share_60m        NOT BETWEEN 0 AND 1) AS vol_share_bounds,
  count(*) FILTER (WHERE external_outgoing_tx_share_60m            NOT BETWEEN 0 AND 1) AS tx_share_bounds,
  count(*) FILTER (WHERE external_outgoing_tx_5m_concentration     NOT BETWEEN 0 AND 1) AS tx_conc_bounds,
  count(*) FILTER (WHERE external_outgoing_volume_5m_concentration NOT BETWEEN 0 AND 1) AS vol_conc_bounds,
  count(*) FILTER (WHERE flow_through_ratio_60m                    NOT BETWEEN 0 AND 1) AS ft_ratio_bounds,
  count(*) FILTER (WHERE minutes_since_last_external_incoming_60m  NOT BETWEEN 1 AND 60) AS gap_bounds,
  count(*) FILTER (WHERE external_outgoing_volume_60m_usd < 0
                      OR external_incoming_volume_60m_usd < 0
                      OR flow_through_volume_60m_usd      < 0
                      OR excess_outgoing_volume_60m_usd   < 0)                      AS negatives
FROM aml_features_60m;

-- 3. Invariants: expect 0 for every column
SELECT
  count(*) FILTER (WHERE abs(flow_through_volume_60m_usd + excess_outgoing_volume_60m_usd
                             - external_outgoing_incl_current_60m_usd) > 0.01)          AS identity,
  count(*) FILTER (WHERE is_self_transfer AND current_external_payment_usd <> 0)       AS self_rule,
  count(*) FILTER (WHERE external_outgoing_tx_count_5m > external_outgoing_tx_count_60m) AS nesting,
  count(*) FILTER (WHERE (external_incoming_tx_count_60m > 0)
                      <> (minutes_since_last_external_incoming_60m IS NOT NULL))       AS gap_mismatch,
  count(*) FILTER (WHERE dominant_outgoing_counterparty_share_60m
                         < 1.0 / NULLIF(external_unique_outgoing_counterparties_60m, 0) - 1e-9) AS dominant_floor,
  count(*) FILTER (WHERE top3_outgoing_counterparty_share_60m
                         < dominant_outgoing_counterparty_share_60m - 1e-9)            AS top3_lt_dom,
  count(*) FILTER (WHERE outgoing_counterparty_hhi_60m
                         > dominant_outgoing_counterparty_share_60m + 1e-9)            AS hhi_gt_dom,
  count(*) FILTER (WHERE outgoing_counterparty_hhi_60m
                         < power(dominant_outgoing_counterparty_share_60m, 2) - 1e-9)  AS hhi_lt_dom_sq
FROM aml_features_60m;

-- 4. Leakage guard: the label must not be in the feature table
--    Expect 0 rows.
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'aml_features_60m'
  AND column_name ILIKE '%launder%';
