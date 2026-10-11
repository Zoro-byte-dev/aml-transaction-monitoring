-- =====================================================================
-- 02_transaction_base.sql
-- Typed base table, plus a SEPARATE label table.
--
-- The label lives in transaction_labels, not in any feature table,
-- so it cannot leak into model inputs by accident. It is joined only
-- when the modelling dataset is built.
-- =====================================================================

DROP TABLE IF EXISTS transaction_base;

CREATE TABLE transaction_base AS
SELECT
    row_id                                            AS transaction_id,
    to_timestamp(ts, 'YYYY/MM/DD HH24:MI')::timestamp AS transaction_time,
    from_bank,
    from_account,
    to_bank,
    to_account,
    amount_paid::numeric                              AS amount_paid,
    payment_currency,
    amount_received::numeric                          AS amount_received,
    receiving_currency,
    payment_format
FROM raw_transactions;

ALTER TABLE transaction_base ADD PRIMARY KEY (transaction_id);
CREATE INDEX ON transaction_base (from_account, transaction_time);
CREATE INDEX ON transaction_base (to_account,   transaction_time);
CREATE INDEX ON transaction_base (transaction_time);

DROP TABLE IF EXISTS transaction_labels;

CREATE TABLE transaction_labels AS
SELECT row_id              AS transaction_id,
       (is_laundering = '1') AS is_laundering
FROM raw_transactions;

ALTER TABLE transaction_labels ADD PRIMARY KEY (transaction_id);

ANALYZE transaction_base;
ANALYZE transaction_labels;

-- Check: both tables have 5,078,345 rows
SELECT (SELECT count(*) FROM transaction_base)   AS base_rows,
       (SELECT count(*) FROM transaction_labels) AS label_rows;
