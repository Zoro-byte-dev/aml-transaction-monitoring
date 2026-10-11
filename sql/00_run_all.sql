-- =====================================================================
-- 00_run_all.sql
-- Rebuild the whole pipeline from the raw CSV.
--
-- Run from the project's root folder:
--   psql -d practise -f sql/00_run_all.sql
--
-- Stops at the first error instead of carrying on with broken tables.
-- =====================================================================

\set ON_ERROR_STOP on
\timing on

\echo '01 load raw CSV'
\i sql/01_load_raw.sql

\echo '02 transaction_base + transaction_labels'
\i sql/02_transaction_base.sql

\echo '03 currency_map + fx_rates'
\i sql/03_fx_rates.sql

\echo '04 transaction_usd'
\i sql/04_transaction_usd.sql

\echo '05 window aggregates (slow)'
\i sql/05_window_aggregates.sql

\echo '06 aml_features_60m'
\i sql/06_aml_features_60m.sql

\echo '99 validation'
\i sql/99_validation.sql
