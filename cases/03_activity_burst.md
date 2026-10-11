# Case 03: Unusual activity burst

*Illustrative review on synthetic data. Not a finding of financial crime.*

| Field | Value |
|---|---|
| Account | `<synthetic account ID>` |
| Alert transaction | `<transaction_id>` at `<YYYY-MM-DD HH:MM>` |
| Typology | <e.g. gather-and-forward / layering> |
| Review window | Alert time ± 2 hours |

## 1. Alert trigger

Which rule fired, with the feature values that triggered it.

- `<feature>` = <value> (threshold: <threshold>)
- `<feature>` = <value>

## 2. Activity reviewed

A short timeline of the account's transactions (from `sql/10_case_candidates.sql`, step 4).

| Time | Direction | Counterparty | Format | Amount (USD) |
|---|---|---|---|---|
| | | | | |

## 3. Observations

What is unusual, stated as facts.

- <e.g. Received $48,200 from 4 senders between 14:05 and 14:22.>
- <e.g. Sent $47,900 to one new counterparty at 14:31, 9 minutes later.>

## 4. Possible legitimate explanations

- <e.g. Payment processor or payroll account forwarding collected funds.>
- <e.g. Business settling a supplier invoice after receiving customer payments.>

## 5. Evidence for and against suspicion

| Supports suspicion | Weakens suspicion |
|---|---|
| | |

## 6. Limitations and information needed

A real review would also use data this dataset does not contain:

- Customer profile: occupation or business type, expected activity, account age
- KYC / CDD records, previous alerts, adverse media
- Counterparty information and the stated purpose of the payments

## 7. Assessment and recommended action

<Close / monitor / escalate for further review>, with a one-paragraph rationale
that separates facts from assumptions.

## 8. Outcome (checked after the assessment)

- Laundering label in the review window: <n of N transactions>
- Did the assessment match? What would I do differently?
