# 2. The Cleaned Excel Workbook

The workbook `Blinkit_analysis_new.xlsx` is the single input for everything else in this project.
It holds 19 sheets: the cleaned tables, the reference tables and a set of pivot summaries.

## Cleaned tables

| Sheet | Rows | Contents |
|---|---|---|
| `Orders_Raw_Archive` | 5,000 | Full order record: customer, timestamps, delivery fields, area, segment label, derived date parts |
| `Orders_Customer_Info` | 5,000 | Order header with the customer fields used for reporting |
| `Order_Line_Items` | 5,000 | One line per order: product, quantity, unit price, line total, plus the product attributes |
| `Products` | 268 | Product master: category, brand, price, MRP, margin, shelf life, stock levels |
| `Customers` | 2,500 | Customer master: contact fields, area, pincode, registration date, segment label |
| `Delivery_Performance` | 5,000 | Promised time, actual time, minutes against promise, distance, delay reason, status |
| `Customer_Feedback` | 5,000 | Rating, feedback text, topic, sentiment, feedback date |
| `Inventory_Analysis` | 268 | Derived per product: units sold, times ordered, monthly demand, stock cover, movement class, wastage risk |

## Reference sheets

| Sheet | Contents |
|---|---|
| `Data_Quality_Report` | What was checked, what was found, what was done |
| `Data_Dictionary` | 44 entries covering every column used |
| `Reference_Parameters` | Primary keys, foreign keys and what each relationship means |
| `Relational_Diagram` | Table relationships drawn out |

## Pivot summaries

| Sheet | Question it answers |
|---|---|
| `Pivot_Monthly_Trend` | How do orders and revenue move month to month |
| `Pivot_Category_Sales` | Which categories sell the most |
| `Pivot_Payment_Method` | How do customers pay |
| `Pivot_Customer_Segment` | How do the segment labels compare on order value |
| `Pivot_Area_Delivery` | Which 20 areas have the weakest delivery |
| `Pivot_Inventory_Movement` | Which products move fast and which sit still |
| `Pivot_Category_Stock` | Which categories carry the most stock risk |

## How the workbook was produced

1. The raw Kaggle files were opened and copied into a working file. The raw copy was left untouched.
2. Text fields were trimmed and standardised: city names, category names, payment methods.
3. Dates and times were converted from text into date values so month, hour and delay could be derived.
4. Derived columns were added: month, day of week, weekend flag, time slot, order value band.
5. Keys were checked for duplicates and for broken links between tables.
6. Business rules were checked: quantity, price against MRP, delivery after order, rating range.
7. `Inventory_Analysis` was built from the order data: units sold, monthly demand, stock cover and risk.
8. A city to state to zone table was added, because the pincode column does not agree with the city.

The full record of what changed and why is in `04_Data_Cleaning.md`.
