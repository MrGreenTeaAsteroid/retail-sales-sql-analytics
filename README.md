# Retail Sales SQL Analytics

A PostgreSQL analytics project built on a retail sales data warehouse
(customers, products, and sales facts in a `gold` star schema). Covers
exploratory SQL, magnitude and ranking analysis, time-series and cumulative
analysis, YoY performance, customer/product segmentation, and two reporting
views — all in a single, runnable `.sql` file.

**Key findings and charts: see [INSIGHTS.md](INSIGHTS.md).**

## Dataset

| Table | Rows | Description |
|---|---|---|
| `gold.dim_customers` | 18,484 | Customer demographics (country, gender, birthdate, etc.) |
| `gold.dim_products` | 295 | Product catalog (category, subcategory, cost) |
| `gold.fact_sales` | 60,398 | Order line items (Dec 2010 – Jan 2014) |

CSVs are in [`datasets/`](datasets/).

## What's covered

The script is organized into numbered sections:

| # | Section | Answers questions like... |
|---|---|---|
| 0 | Schema, tables, helper functions, data load | — |
| 1 | Database exploration | What tables/columns exist? |
| 2 | Dimensions exploration | What countries/categories/products exist? |
| 3 | Date range exploration | What's the data's time span? Customer age range? |
| 4 | Measures exploration | Total sales, orders, customers, products |
| 5 | Magnitude analysis | Revenue/customers by country, category, gender |
| 6 | Ranking analysis | Top/bottom products and customers |
| 7 | Change over time | Monthly/yearly sales trend |
| 8 | Cumulative analysis | Running total sales, moving average price |
| 9 | Performance analysis | YoY growth, product sales vs. its own average |
| 10 | Data segmentation | Cost tiers, customer segments (VIP/Regular/New) |
| 11 | Part-to-whole analysis | % of revenue by category |
| 12 | `gold.report_customers` (view) | Consolidated customer KPIs |
| 13 | `gold.report_products` (view) | Consolidated product KPIs |

## Setup

Requires PostgreSQL (tested on 16).

```bash
createdb retail_sales
psql -d retail_sales -f retail_sales_sql_analytics.sql
```

Run this from the repo root — the script loads `datasets/*.csv` using
relative `\copy` paths, so the `datasets/` folder needs to sit next to the
`.sql` file.

## Notes

- All T-SQL constructs from the original design (`TOP`, `GETDATE()`,
  `DATEDIFF`, `DATETRUNC`, `FORMAT`) were ported to PostgreSQL equivalents
  (`LIMIT`, `CURRENT_DATE`, `EXTRACT`/`age()`, `date_trunc`, `to_char`).
  Two small helper functions, `gold.months_between()` and
  `gold.years_between()`, stand in for `DATEDIFF(month/year, ...)`.
- Segment thresholds (VIP/Regular/New, High/Mid/Low-Performer) are
  illustrative business rules defined in the script, not universal
  definitions.

## License

MIT
