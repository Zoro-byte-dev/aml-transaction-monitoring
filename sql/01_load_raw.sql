-- =====================================================================
-- 01_load_raw.sql
-- Load the original Kaggle file (HI-Small_Trans.csv) into a staging table.
--
-- * Every column is loaded as text so nothing fails on parsing.
-- * row_id numbers rows in file order and becomes transaction_id.
-- * \copy maps columns BY POSITION, so the duplicate "Account" header
--   in the CSV cannot overwrite the receiver account (the bug that
--   corrupted the first version of this project).
--
-- BEFORE RUNNING: edit the file path on the \copy line.
-- The \copy command must stay on ONE line.
-- =====================================================================

DROP TABLE IF EXISTS raw_transactions;

CREATE TABLE raw_transactions (
    row_id             bigint GENERATED ALWAYS AS IDENTITY,
    ts                 text,
    from_bank          text,
    from_account       text,
    to_bank            text,
    to_account         text,
    amount_received    text,
    receiving_currency text,
    amount_paid        text,
    payment_currency   text,
    payment_format     text,
    is_laundering      text
);

\copy raw_transactions (ts, from_bank, from_account, to_bank, to_account, amount_received, receiving_currency, amount_paid, payment_currency, payment_format, is_laundering) FROM '/path/to/HI-Small_Trans.csv' WITH (FORMAT csv, HEADER true)

-- Load check: expect 5,078,345 rows, ~0.1% laundering, 2022/09/01 to 2022/09/18
SELECT count(*)                                    AS n_rows,
       count(*) FILTER (WHERE is_laundering = '1') AS n_laundering,
       min(ts) AS first_ts,
       max(ts) AS last_ts
FROM raw_transactions;

-- Corruption check: real transfers must be the large majority
SELECT count(*) FILTER (WHERE from_account <> to_account) AS real_transfers,
       count(*) FILTER (WHERE from_account =  to_account) AS self_transfers
FROM raw_transactions;
