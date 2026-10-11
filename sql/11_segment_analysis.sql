-- =====================================================================
-- 11_segment_analysis.sql
-- Where does laundering sit relative to what the 60-minute features
-- can see? (Analysis only: uses the label, writes nothing.)
--
-- Observed result (external transactions only):
--   no activity in 60m : 1,926,689 tx | 4,164 laundering | 0.216%
--   light (1-2 tx)     : 1,750,435 tx |   333 laundering | 0.019%
--   busy (3+ tx)       :   360,150 tx |    36 laundering | 0.010%
--   hub accounts       :   449,859 tx |   633 laundering | 0.141%
--
-- => 81% of laundering occurs with an empty 60-minute window.
--    Longer windows (24h / 7d) and account-history features are the
--    next lever. The ID prefix below is used for analysis only.
-- =====================================================================

SELECT CASE
         WHEN from_account LIKE '100428%'         THEN '4 hub'
         WHEN external_outgoing_tx_count_60m
            + external_incoming_tx_count_60m = 0  THEN '1 no activity in 60m'
         WHEN external_outgoing_tx_count_60m
            + external_incoming_tx_count_60m < 3  THEN '2 light (1-2 tx)'
         ELSE                                          '3 busy (3+ tx)'
       END AS segment,
       count(*)                                  AS n,
       count(*) FILTER (WHERE is_laundering)     AS n_laundering,
       round(100.0 * avg(is_laundering::int), 3) AS pct
FROM aml_model_dataset
WHERE NOT is_self_transfer
GROUP BY 1
ORDER BY 1;
