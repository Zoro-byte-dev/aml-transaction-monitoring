-- =====================================================================
-- 10_case_candidates.sql
-- Find candidate accounts for the three illustrative investigations
-- in cases/. Candidates are chosen from FEATURES ONLY. Check the label
-- (step 5) only after writing your assessment.
--
-- Common exclusions, applied to every candidate list:
--   * self-transfers (internal movements, not flows between parties)
--   * the truncated first hour (windows incomplete before 01:00 on 1 Sep)
--   * the 15 high-frequency hub accounts (IDs starting 100428...).
--     The ID prefix is used here for ANALYSIS ONLY, never as a feature.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Gather-and-forward
--    Most of the recent inflow goes back out within minutes.
-- ---------------------------------------------------------------------
SELECT transaction_id, transaction_time, from_account,
       external_incoming_tx_count_60m             AS in_cnt,
       external_unique_incoming_counterparties_60m AS in_cp,
       round(external_incoming_volume_60m_usd, 2)       AS in_usd,
       round(external_outgoing_incl_current_60m_usd, 2) AS out_incl_usd,
       round(flow_through_ratio_60m, 3)           AS ft_ratio,
       minutes_since_last_external_incoming_60m   AS mins_since_in
FROM aml_features_60m
WHERE NOT is_self_transfer
  AND transaction_time >= '2022-09-01 01:00'
  AND from_account NOT LIKE '100428%'
  AND flow_through_ratio_60m >= 0.9
  AND minutes_since_last_external_incoming_60m <= 10
  AND external_incoming_volume_60m_usd >= 5000
ORDER BY external_incoming_volume_60m_usd DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- 2. Counterparty concentration
--    Several recipients, but one receives almost all the money.
-- ---------------------------------------------------------------------
SELECT transaction_id, transaction_time, from_account,
       external_unique_outgoing_counterparties_60m AS out_cp,
       round(external_outgoing_volume_60m_usd, 2)  AS out_usd,
       round(dominant_outgoing_counterparty_share_60m, 3) AS dominant_share,
       round(outgoing_counterparty_hhi_60m, 3)     AS hhi
FROM aml_features_60m
WHERE NOT is_self_transfer
  AND transaction_time >= '2022-09-01 01:00'
  AND from_account NOT LIKE '100428%'
  AND external_unique_outgoing_counterparties_60m >= 3
  AND dominant_outgoing_counterparty_share_60m >= 0.9
  AND external_outgoing_volume_60m_usd >= 10000
ORDER BY external_outgoing_volume_60m_usd DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- 3. Unusual activity burst
--    Most of the hour's payments were sent in the last 5 minutes.
-- ---------------------------------------------------------------------
SELECT transaction_id, transaction_time, from_account,
       external_outgoing_tx_count_60m          AS out_cnt_60m,
       external_outgoing_tx_count_5m           AS out_cnt_5m,
       external_same_minute_outgoing_count     AS same_minute,
       round(external_outgoing_tx_5m_concentration, 3) AS tx_conc,
       round(external_outgoing_volume_5m_usd, 2)       AS out_usd_5m
FROM aml_features_60m
WHERE NOT is_self_transfer
  AND transaction_time >= '2022-09-01 01:00'
  AND from_account NOT LIKE '100428%'
  AND external_outgoing_tx_5m_concentration >= 0.8
  AND external_outgoing_tx_count_60m >= 5
ORDER BY external_outgoing_volume_5m_usd DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- 4. Account timeline for a chosen candidate
--    Replace the account and alert time. Shows both directions,
--    two hours either side of the alert.
-- ---------------------------------------------------------------------
\set acct '''<account_id>'''
\set alert_time '''2022-09-05 14:37'''

SELECT b.transaction_time,
       CASE WHEN b.from_account = b.to_account THEN 'SELF'
            WHEN b.from_account = :acct       THEN 'OUT'
            ELSE 'IN' END                     AS direction,
       CASE WHEN b.from_account = :acct THEN b.to_account
            ELSE b.from_account END           AS counterparty,
       b.payment_format,
       b.amount_paid,
       b.payment_currency,
       b.receiving_currency,
       round(u.amount_paid_usd, 2)            AS amount_usd
FROM transaction_base b
JOIN transaction_usd  u USING (transaction_id)
WHERE (b.from_account = :acct OR b.to_account = :acct)
  AND b.transaction_time BETWEEN :alert_time::timestamp - INTERVAL '2 hours'
                             AND :alert_time::timestamp + INTERVAL '2 hours'
ORDER BY b.transaction_time;


-- ---------------------------------------------------------------------
-- 5. Outcome: run ONLY after writing your assessment.
--    Laundering label for the account's transactions in the same period.
-- ---------------------------------------------------------------------
SELECT count(*)                              AS n_tx,
       count(*) FILTER (WHERE l.is_laundering) AS n_laundering
FROM transaction_base b
JOIN transaction_labels l USING (transaction_id)
WHERE (b.from_account = :acct OR b.to_account = :acct)
  AND b.transaction_time BETWEEN :alert_time::timestamp - INTERVAL '2 hours'
                             AND :alert_time::timestamp + INTERVAL '2 hours';
