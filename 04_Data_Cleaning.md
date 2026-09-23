# 4. Data Cleaning and Validation

Nothing in the source was changed without a reason, and nothing was deleted for looking unusual.
Records that could not be explained were flagged and reported instead.

## What was changed

| Area | Issue found | Action taken | Reason |
|---|---|---|---|
| City names | Extra spaces and mixed capitalisation | Trimmed and standardised | The city has to match the state mapping exactly. One city, Khora, failed to match until it was trimmed |
| Dates and times | Order, promise and delivery times stored as text in day-month-year format | Converted to date and time values | Needed to derive month, hour and the minutes against promise |
| Registration date | Stored as text | Converted to date | Needed to measure days from sign-up to first order |
| Revenue field | Order total in the order table does not equal the item total | Item total used as revenue everywhere | The item total is built from quantity and unit price, so it can be checked. The order total cannot |
| Category names | Small spelling differences | Standardised to 11 names | Otherwise one category would be counted twice |
| Payment methods | Mixed capitalisation | Standardised to Cash, UPI, Card, Wallet | Needed for grouping |
| Derived columns | Month, weekday, weekend flag, time slot, value band | Added | Used across the analysis |
| Geography | Pincode does not agree with the city in many rows | Pincode dropped, city to state to zone table added | A wrong pincode would put orders in the wrong state |

## What was flagged but not changed

| Issue | Size | Why it was left alone |
|---|---|---|
| Delay reason blank | 1,902 orders | These orders were not delayed, so the blank is correct. Not treated as missing data |
| Customer segment label | 600 customers labelled Inactive placed 1,190 orders | Changing a label without evidence is not acceptable. The analysis uses behaviour instead, and the mismatch is reported as a finding |
| Registration date after first order | A number of customers | It cannot be known which of the two dates is wrong, so both are kept and the rows are flagged |
| Time slot lengths | Night covers 8 hours, Afternoon 5 | The slots come from the source. Instead of changing them, demand is reported per hour |

## What was rejected

| Source item | Test applied | Result |
|---|---|---|
| Stock file 1 and stock file 2 | Compared row by row | The two files disagree with each other |
| Damaged stock against stock received | Simple rule check | Damaged stock is higher than stock received in 29,255 rows, which is impossible |
| Marketing performance file | Joined to orders | Cannot be tied to the orders in this dataset |

Because of this, stock risk is not taken from the source stock files. It is built from three fields
that can be trusted: minimum stock level, observed demand and shelf life.

## Validation after cleaning

| Check | Result | Finding | Action |
|---|---|---|---|
| Duplicate keys | Pass | No duplicate order, customer, product or feedback identifiers | None needed |
| Missing values | Issue | Delay reason blank for 1,902 orders | Kept: blank means no delay |
| Referential integrity | Pass | Every order item, delivery record and review links to an existing order; every product and customer exists | None needed |
| Quantity and price rules | Pass | No zero or negative quantity, price never above MRP, line total equals quantity times price | None needed |
| Date rules | Issue | Registration after first order for some customers | Flagged |
| Order total | Issue | Order total does not match item total | Item total used as revenue |
| Rating range | Pass | All ratings between 1 and 5 | None needed |
| Stock levels | Pass | Minimum stock never above maximum stock | None needed |
| Segment labels | Issue | Inactive customers placed 1,190 orders | Reported, behaviour used instead |
| City mapping | Pass | All 316 cities map to a state and zone | None needed |

The same checks run as code in `notebooks/01_Data_Validation.ipynb`, so the result can be
reproduced at any time.

## Cross-checks built into the analysis

1. Demand figures in the source `Inventory_Analysis` sheet were recomputed from the order table and compared. Units matched for all 268 products.
2. Order totals were compared against item totals for all 5,000 orders before choosing which to use.
3. Delivery status was compared against the actual minutes, which is how the gap between the two was found.
