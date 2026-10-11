# AML Feature Dictionary

Oct 11, 2026

## Overview

`aml_features_60m` holds 22 validated point-in-time behavioural features, plus a self-transfer flag, for all 5,078,345 transactions in the IBM AML synthetic dataset (HI-Small, 1–18 September 2022). It is the single feature table for transaction-monitoring rules and machine-learning models.

- **Pipeline:** `transaction_base` → `transaction_usd` (via `fx_rates`, `currency_map`) → `aml_features_60m`
- **Key:** `transaction_id` (primary key, one row per transaction)
- **Currency:** all amounts in USD, using simulator-implied rates for 15 currencies including Bitcoin
- **Label:** `Is Laundering` is deliberately not stored here. It is joined only when building the modelling dataset.

## Global rules

Every feature follows four rules, so features from different families can be compared directly.

1. **External only.** Every window aggregate excludes self-transfers (`from_account = to_account`), so internal reinvestments are never counted as money moving between parties.
2. **Strictly historical windows.** Windows cover `[t − window, t)`. The current transaction and any later ones are excluded, so nothing leaks from the future. Timestamps are at minute resolution, so same-minute activity is captured separately.
3. **The current payment counts only in pass-through features.** Historical features exclude it. Pass-through features add it, because they describe this payment against recent inflow. It counts as $0 when the current row is a self-transfer.
4. **Guards return NULL, not zero.** A ratio is NULL when its denominator lacks evidence: under $1 of volume, fewer than 3 transactions, or too few counterparties. NULL means "not enough evidence", never "zero activity".

Accounts are identified by account ID. Windows are anchored on the **sender** (`from_account`) of each transaction.

## Identifiers and helper columns

Five columns support joins and calculations but are not model features.

| Column | Type | Meaning |
| --- | --- | --- |
| `transaction_id` | bigint | Row position in the original Kaggle CSV. Stable join key, but not chronological |
| `transaction_time` | timestamp | Transaction time, minute resolution |
| `from_account` | text | Sending account; all windows are anchored here |
| `to_account` | text | Receiving account |
| `current_external_payment_usd` | numeric | This payment in USD if external, else 0. Makes the self-transfer rule visible |

`is_self_transfer` (boolean, `from_account = to_account`) is a model feature. It tells the model when payment-level features describe account context rather than this payment.

## Feature definitions

The 22 features fall into six families, plus the self-transfer flag. "Populated" is the number of non-NULL rows out of 5,078,345.

### 1. External activity (60 minutes)

How much the sender sent and received in the previous hour. Never NULL; 0 means no activity.

| Feature | Definition | Guard | Populated |
| --- | --- | --- | --- |
| `external_outgoing_tx_count_60m` | External payments sent | None | 5,078,345 |
| `external_outgoing_volume_60m_usd` | USD sent externally | None | 5,078,345 |
| `external_unique_outgoing_counterparties_60m` | Distinct accounts paid | None | 5,078,345 |
| `external_incoming_tx_count_60m` | External payments received | None | 5,078,345 |
| `external_incoming_volume_60m_usd` | USD received externally | None | 5,078,345 |
| `external_unique_incoming_counterparties_60m` | Distinct accounts received from | None | 5,078,345 |

### 2. Burst activity (5 minutes and same minute)

Short-horizon activity that the hourly window smooths over.

| Feature | Definition | Guard | Populated |
| --- | --- | --- | --- |
| `external_outgoing_tx_count_5m` | External payments sent in `[t − 5m, t)` | None | 5,078,345 |
| `external_outgoing_volume_5m_usd` | USD sent in `[t − 5m, t)` | None | 5,078,345 |
| `external_same_minute_outgoing_count` | Other external payments sent in the same minute | None | 5,078,345 |

### 3. Direction (60 minutes)

Whether the account is mostly sending or mostly receiving: 0 = only receiving, 1 = only sending.

| Feature | Definition | Guard | Populated |
| --- | --- | --- | --- |
| `external_outgoing_volume_share_60m` | out volume ÷ (out + in volume) | Total volume ≥ $1 | 2,631,300 |
| `external_outgoing_tx_share_60m` | out count ÷ (out + in count) | Total count ≥ 3 | 823,489 |

### 4. Timing concentration (5 of 60 minutes)

How much of the hour's outflow happened in the last 5 minutes. About 0.083 = evenly spread; near 1 = a burst.

| Feature | Definition | Guard | Populated |
| --- | --- | --- | --- |
| `external_outgoing_tx_5m_concentration` | 5m out count ÷ 60m out count | 60m out count ≥ 3 | 744,052 |
| `external_outgoing_volume_5m_concentration` | 5m out volume ÷ 60m out volume | 60m out count ≥ 3 and volume ≥ $1 | 743,768 |

### 5. Pass-through (60 minutes, includes the current payment)

Whether this payment forwards money that recently came in, the signature of layering and mule accounts. `out_incl` = external outgoing volume + `current_external_payment_usd`; `in` = external incoming volume.

| Feature | Definition | Guard | Populated |
| --- | --- | --- | --- |
| `external_outgoing_incl_current_60m_usd` | `out_incl` | None | 5,078,345 |
| `flow_through_volume_60m_usd` | min(`in`, `out_incl`) | None | 5,078,345 |
| `excess_outgoing_volume_60m_usd` | max(`out_incl` − `in`, 0) | None | 5,078,345 |
| `flow_through_ratio_60m` | flow-through ÷ `in` | `in` ≥ $1 | 332,427 |
| `log_out_in_ratio_60m` | ln((`out_incl` + 1) ÷ (`in` + 1)) | None (smoothed) | 5,078,345 |
| `minutes_since_last_external_incoming_60m` | Minutes since the latest external inflow in the window (1–60) | An inflow in the window | 345,567 |

With no recent inflow, `log_out_in_ratio_60m` reduces to the log of the payment size. Analyse it split by whether inflow exists.

### 6. Counterparty concentration (60 minutes)

How concentrated the account's outflow is among recipients, by USD volume per recipient. Historical only.

| Feature | Definition | Guard | Populated |
| --- | --- | --- | --- |
| `dominant_outgoing_counterparty_share_60m` | Largest recipient's volume ÷ total out volume | ≥ 2 counterparties and ≥ $1 | 618,592 |
| `top3_outgoing_counterparty_share_60m` | Top 3 recipients' volume ÷ total out volume | ≥ 4 counterparties and ≥ $1 | 450,561 |
| `outgoing_counterparty_hhi_60m` | Σ (recipient volume share)² | ≥ 2 counterparties and ≥ $1 | 618,592 |

The minimum possible dominant share is 1/n for n counterparties (3/n for the top-3 share). HHI correlates 0.98 with the dominant share at this window, so it is a candidate to drop for linear models.

### 7. Transaction flag

| Feature | Definition | Guard | Populated |
| --- | --- | --- | --- |
| `is_self_transfer` | `from_account = to_account` | None | 5,078,345 |

## Validation

Every check passed on the final table (11 October 2026): all populations match their guards exactly, and every invariant returns 0 violations.

| Check | Rule tested | Result |
| --- | --- | --- |
| Row count and key | 5,078,345 rows; `transaction_id` primary key | Pass |
| Guard populations | Each ratio's non-NULL count equals the rows meeting its guard | Pass (all 10 match) |
| Bounds | Shares, concentrations and ratios within \[0, 1\]; gap within 1–60 | 0 violations |
| Non-negativity | No negative counts, volumes or gaps | 0 violations |
| Pass-through identity | flow-through + excess = `out_incl` (±$0.01) | 0 failures |
| Self-transfer rule | `current_external_payment_usd` = 0 on every self-transfer | 0 violations |
| Window nesting | 5-minute count ≤ 60-minute count | 0 violations |
| Gap consistency | Gap present exactly when external inflow exists | 0 mismatches |
| Concentration floors | Dominant ≥ 1/n; top-3 ≥ 3/n; HHI ≥ 1/n | 0 violations |
| Cross-family | top-3 ≥ dominant; dominant² ≤ HHI ≤ dominant | 0 violations |
| Carry-over | Burst features and flag identical to their source table | 0 mismatches |

Currency rates were validated separately: implied rates are constant across all 18 days, and rates predicted for non-USD pairs match observed ratios.

## Limitations and next steps

The 60-minute window sees little of most accounts' activity, so longer windows are the likely next build.

- **Coverage:** only 6.8% of transactions have any external inflow in the prior hour, and 48% have no external activity at all.
- **Hub accounts:** 15 high-frequency accounts produce about 55% of rows with a transaction share. Evaluate hub and non-hub accounts separately.
- **Same-minute order is unknown.** Inflow and outflow in the same minute are invisible to pass-through features.
- **Dataset start:** windows are truncated before 01:00 on 1 September, inflating shares and concentrations.
- **Synthetic rates:** currency rates are the simulator's, not real September 2022 market rates.

Next steps:

- [x] Save every build and validation query as numbered `.sql` files
- [ ] Join the label and locate laundering cases by activity segment
- [ ] Build the 24-hour layer if most laundering falls outside 60-minute activity
- [ ] Time-based split, rules baseline, then a gradient-boosted model (PR-AUC, recall at fixed precision)
