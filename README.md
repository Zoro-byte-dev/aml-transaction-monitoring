# AML Transaction Analytics Pipeline

A PostgreSQL pipeline that turns 5.08 million synthetic bank transactions
(IBM AML dataset, HI-Small) into 22 validated, point-in-time behavioural
features for anti-money-laundering transaction monitoring.

**Status:** feature pipeline complete and validated. Baseline models
(rules and LightGBM) in progress.

## Highlights

- **5,078,345 transactions**, 15 currencies including Bitcoin, 5,177 labelled
  laundering cases (0.10%).
- **22 behavioural features** across six families: activity, burst,
  direction, timing concentration, pass-through and counterparty concentration.
- **Fully reproducible:** one command rebuilds everything from the raw CSV in
  about 3 minutes.
- **Validated:** every feature's population matches its guard exactly, and
  every bound and invariant check returns 0 violations (`sql/99_validation.sql`).

## Pipeline

```
HI-Small_Trans.csv
  -> raw_transactions          01  load (positional, all text)
  -> transaction_base          02  typed transactions
     transaction_labels        02  label, kept separate from features
  -> currency_map, fx_rates    03  USD rates derived from the data
  -> transaction_usd           04  amounts in USD
  -> feat_window_aggregates    05  raw historical window aggregates
  -> aml_features_60m          06  final 22 features + is_self_transfer
  -> aml_model_dataset (view)  07  features + transaction fields + split + label
                               99  validation checks
```

Analysis: `10_case_candidates.sql` (investigation cases),
`11_segment_analysis.sql` (where laundering sits).

## How to run

1. Download `HI-Small_Trans.csv` from Kaggle:
   https://www.kaggle.com/datasets/ealtman2019/ibm-transactions-for-anti-money-laundering-aml
2. Edit the file path on the `\copy` line in `sql/01_load_raw.sql`.
3. From this folder, in an empty database:

   ```
   psql -d <your_database> -f sql/00_run_all.sql
   psql -d <your_database> -f sql/07_model_dataset.sql
   ```

## Design rules

- **External only:** self-transfers are excluded from every window aggregate.
- **Strictly historical:** windows cover `[t - window, t)`; nothing from the
  current or future transactions leaks into history.
- **Current payment:** included only in pass-through features, and counted
  as $0 when the current row is a self-transfer.
- **Guards:** ratios return NULL (not 0) when the denominator lacks evidence.
- **No label leakage:** the label lives only in `transaction_labels` and is
  joined only in the modelling view.
- **Chronological split:** 60 / 20 / 20 by time quantile, never random.

Full definitions, guards and populations: [`docs/FEATURES.md`](docs/FEATURES.md).

## Findings so far

- **Corrupted source data caught and fixed.** The first copy of the data had
  every receiver account overwritten by the sender's (a duplicate `Account`
  header handled by name). The pipeline now loads columns by position.
- **Synthetic exchange rates.** The simulator's rates differ from real
  September 2022 rates, so rates are derived from the data and validated on
  non-USD currency pairs.
- **Most laundering is invisible to 60-minute windows.** 81% of laundering
  cases occur when the sender had no external activity in the previous hour,
  where those accounts launder at 11x the rate of lightly active accounts.
  Longer windows and account-history features are the next step.
- **Hub accounts.** 15 high-frequency accounts dominate busy-window rows and
  carry 12% of laundering cases, so results are reported separately for them.
- **Prevalence drift.** The laundering rate rises from 0.075% (train) to
  0.177% (test), so PR-AUC is always read against each split's base rate.

## Illustrative investigations

[`cases/`](cases/) contains alert reviews written as a transaction-monitoring
analyst would, using synthetic accounts. They are illustrative, not findings
of real financial crime.

## Roadmap

- [x] Currency normalisation and validated feature pipeline
- [x] Chronological modelling dataset
- [ ] Rules-based baseline and risk score
- [ ] LightGBM baseline (PR-AUC, recall at fixed alert volume, hub vs non-hub)
- [ ] 24-hour / 7-day and account-history features, measured against the baseline
