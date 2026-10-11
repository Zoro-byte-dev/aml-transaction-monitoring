# Illustrative investigations

Three alert reviews written the way a transaction-monitoring analyst would
write them, using accounts from the synthetic IBM AML dataset.

**These are illustrative.** The data is simulated: account IDs are synthetic,
no real person or business is involved, and findings describe simulated
behaviour, not confirmed financial crime.

| Case | Typology | Main indicators |
|---|---|---|
| [01](01_gather_and_forward.md) | Gather-and-forward (layering, mule behaviour) | `flow_through_ratio_60m`, `minutes_since_last_external_incoming_60m` |
| [02](02_counterparty_concentration.md) | Counterparty concentration | `dominant_outgoing_counterparty_share_60m`, `outgoing_counterparty_hhi_60m` |
| [03](03_activity_burst.md) | Unusual activity burst | `external_outgoing_tx_5m_concentration`, `external_same_minute_outgoing_count` |

## Method

1. Candidates were selected from features only (`sql/10_case_candidates.sql`),
   excluding self-transfers, the first hour of data and hub accounts.
2. Each account's activity was reviewed two hours either side of the alert.
3. The assessment and decision were written **before** checking the label.
4. The label was checked last and recorded as the outcome.
