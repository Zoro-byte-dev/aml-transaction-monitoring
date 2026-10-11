-- =====================================================================
-- 06_aml_features_60m.sql
-- Final feature table: 22 features + is_self_transfer.
-- Definitions, guards and expected populations are documented in
-- docs/FEATURES.md (the AML Feature Dictionary).
--
-- Guards return NULL (not 0) when a ratio's denominator lacks evidence:
--   volume < $1, fewer than 3 transactions, or too few counterparties.
--
-- Pass-through features INCLUDE the current payment; it counts as $0
-- when the current row is a self-transfer. All other features are
-- strictly historical.
-- =====================================================================

DROP TABLE IF EXISTS aml_features_60m;

CREATE TABLE aml_features_60m AS
SELECT
    -- identifiers
    t.transaction_id,
    t.transaction_time,
    t.from_account,
    t.to_account,

    -- 1. External activity (60m)
    w.out_cnt_60m AS external_outgoing_tx_count_60m,
    w.out_vol_60m AS external_outgoing_volume_60m_usd,
    w.out_cp_60m  AS external_unique_outgoing_counterparties_60m,
    w.in_cnt_60m  AS external_incoming_tx_count_60m,
    w.in_vol_60m  AS external_incoming_volume_60m_usd,
    w.in_cp_60m   AS external_unique_incoming_counterparties_60m,

    -- 3. Direction (60m)
    CASE WHEN w.out_vol_60m + w.in_vol_60m >= 1
         THEN w.out_vol_60m / (w.out_vol_60m + w.in_vol_60m)
    END AS external_outgoing_volume_share_60m,

    CASE WHEN w.out_cnt_60m + w.in_cnt_60m >= 3
         THEN w.out_cnt_60m::numeric / (w.out_cnt_60m + w.in_cnt_60m)
    END AS external_outgoing_tx_share_60m,

    -- 4. Timing concentration (5 of 60 minutes)
    CASE WHEN w.out_cnt_60m >= 3
         THEN w.out_cnt_5m::numeric / w.out_cnt_60m
    END AS external_outgoing_tx_5m_concentration,

    CASE WHEN w.out_cnt_60m >= 3 AND w.out_vol_60m >= 1
         THEN w.out_vol_5m / w.out_vol_60m
    END AS external_outgoing_volume_5m_concentration,

    -- helper: the current payment, counted only if external
    c.current_external_payment_usd,

    -- 5. Pass-through (60m, includes current payment)
    p.out_incl                                     AS external_outgoing_incl_current_60m_usd,
    LEAST(w.in_vol_60m, p.out_incl)                AS flow_through_volume_60m_usd,
    GREATEST(p.out_incl - w.in_vol_60m, 0)         AS excess_outgoing_volume_60m_usd,
    CASE WHEN w.in_vol_60m >= 1
         THEN LEAST(w.in_vol_60m, p.out_incl) / w.in_vol_60m
    END                                            AS flow_through_ratio_60m,
    ln((p.out_incl + 1) / (w.in_vol_60m + 1))      AS log_out_in_ratio_60m,
    EXTRACT(EPOCH FROM t.transaction_time - w.last_in_time_60m) / 60.0
                                                   AS minutes_since_last_external_incoming_60m,

    -- 6. Counterparty concentration (60m)
    CASE WHEN w.out_cp_60m >= 2 AND w.out_vol_60m >= 1
         THEN w.dominant_cp_vol_60m / w.out_vol_60m
    END AS dominant_outgoing_counterparty_share_60m,

    CASE WHEN w.out_cp_60m >= 4 AND w.out_vol_60m >= 1
         THEN w.top3_cp_vol_60m / w.out_vol_60m
    END AS top3_outgoing_counterparty_share_60m,

    CASE WHEN w.out_cp_60m >= 2 AND w.out_vol_60m >= 1
         THEN w.sum_sq_cp_vol_60m / (w.out_vol_60m * w.out_vol_60m)
    END AS outgoing_counterparty_hhi_60m,

    -- 7. Transaction flag
    (t.from_account = t.to_account) AS is_self_transfer,

    -- 2. Burst activity (5m, same minute)
    w.out_cnt_5m          AS external_outgoing_tx_count_5m,
    w.out_vol_5m          AS external_outgoing_volume_5m_usd,
    w.same_minute_out_cnt AS external_same_minute_outgoing_count

FROM transaction_usd t
JOIN feat_window_aggregates w USING (transaction_id)

CROSS JOIN LATERAL (
    SELECT CASE WHEN t.from_account <> t.to_account
                THEN t.amount_paid_usd ELSE 0
           END AS current_external_payment_usd
) c

CROSS JOIN LATERAL (
    SELECT w.out_vol_60m + c.current_external_payment_usd AS out_incl
) p;

ALTER TABLE aml_features_60m ADD PRIMARY KEY (transaction_id);
ANALYZE aml_features_60m;
