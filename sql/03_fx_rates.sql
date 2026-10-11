-- =====================================================================
-- 03_fx_rates.sql
-- Currency map and USD conversion rates.
--
-- The IBM data is synthetic: the simulator used its own fixed rates,
-- which do NOT match real September 2022 market rates. Rates are
-- therefore derived from the data itself, using amount-weighted sums
-- over every transaction between USD and each currency (both directions).
-- Weighted sums make 2-decimal (and 6-decimal BTC) rounding negligible.
--
-- Convention: usd_per_unit = USD value of 1 unit of the currency.
-- =====================================================================

DROP TABLE IF EXISTS currency_map;

CREATE TABLE currency_map (
    currency_name text PRIMARY KEY,
    currency_code text NOT NULL UNIQUE
);

INSERT INTO currency_map (currency_name, currency_code) VALUES
    ('US Dollar',         'USD'),
    ('Euro',              'EUR'),
    ('Swiss Franc',       'CHF'),
    ('Yuan',              'CNY'),
    ('Shekel',            'ILS'),
    ('Rupee',             'INR'),
    ('UK Pound',          'GBP'),
    ('Yen',               'JPY'),
    ('Ruble',             'RUB'),
    ('Bitcoin',           'BTC'),
    ('Canadian Dollar',   'CAD'),
    ('Australian Dollar', 'AUD'),
    ('Mexican Peso',      'MXN'),
    ('Saudi Riyal',       'SAR'),
    ('Brazil Real',       'BRL');

DROP TABLE IF EXISTS fx_rates;

CREATE TABLE fx_rates (
    currency_code text    NOT NULL,
    rate_date     date    NOT NULL,
    usd_per_unit  numeric NOT NULL,
    source        text    NOT NULL,
    PRIMARY KEY (currency_code, rate_date)
);

INSERT INTO fx_rates (currency_code, rate_date, usd_per_unit, source)
WITH usd_pairs AS (
    -- local currency -> USD
    SELECT payment_currency AS currency_name,
           amount_paid      AS local_amt,
           amount_received  AS usd_amt
    FROM transaction_base
    WHERE receiving_currency = 'US Dollar'
      AND payment_currency  <> 'US Dollar'
    UNION ALL
    -- USD -> local currency
    SELECT receiving_currency,
           amount_received,
           amount_paid
    FROM transaction_base
    WHERE payment_currency    = 'US Dollar'
      AND receiving_currency <> 'US Dollar'
),
rates AS (
    SELECT currency_name,
           sum(usd_amt) / NULLIF(sum(local_amt), 0) AS usd_per_unit
    FROM usd_pairs
    GROUP BY currency_name
    UNION ALL
    SELECT 'US Dollar', 1.0::numeric
)
SELECT cm.currency_code,
       d.rate_date,
       r.usd_per_unit,
       'simulator_implied_v1'
FROM rates r
JOIN currency_map cm ON cm.currency_name = r.currency_name
CROSS JOIN (SELECT DISTINCT transaction_time::date AS rate_date
            FROM transaction_base) d;

-- Check 1: expect 270 rows (15 currencies x 18 days)
SELECT count(*) AS fx_rows FROM fx_rates;

-- Check 2: rates are constant over time in the raw data (flat per currency)
SELECT transaction_time::date AS day,
       payment_currency,
       sum(amount_received) / sum(amount_paid) AS usd_per_unit
FROM transaction_base
WHERE receiving_currency = 'US Dollar'
  AND payment_currency IN ('Euro', 'Yuan', 'UK Pound', 'Rupee')
GROUP BY 1, 2
ORDER BY 2, 1;

-- Check 3: independent validation on non-USD pairs
-- observed / predicted - 1 should be ~0 for every pair with real volume
SELECT t.payment_currency,
       t.receiving_currency,
       count(*) AS n,
       (sum(t.amount_received) / sum(t.amount_paid))
         / (p.usd_per_unit / r.usd_per_unit) - 1 AS rel_error
FROM transaction_base t
JOIN currency_map cp ON cp.currency_name = t.payment_currency
JOIN currency_map cr ON cr.currency_name = t.receiving_currency
JOIN fx_rates p ON p.currency_code = cp.currency_code AND p.rate_date = '2022-09-01'
JOIN fx_rates r ON r.currency_code = cr.currency_code AND r.rate_date = '2022-09-01'
WHERE t.payment_currency <> t.receiving_currency
  AND 'US Dollar' NOT IN (t.payment_currency, t.receiving_currency)
GROUP BY 1, 2, p.usd_per_unit, r.usd_per_unit
ORDER BY abs((sum(t.amount_received) / sum(t.amount_paid))
             / (p.usd_per_unit / r.usd_per_unit) - 1) DESC
LIMIT 20;
