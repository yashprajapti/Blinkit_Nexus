# 8. Power BI Model

`powerbi/Blinkit_PowerBI_Ready.xlsx` is the input file for the Power BI report. It holds the data
as a star schema, plus the relationship list and the DAX measures to paste in.

## Tables in the file

| Table | Rows | Role |
|---|---|---|
| `DIM_Date` | 600 | Date table, marked as the date table in Power BI |
| `DIM_Customer` | 2,500 | Customer master |
| `DIM_Product` | 268 | Product master with shelf life and stock levels |
| `DIM_Geography` | 316 | City to state, zone and city tier |
| `FACT_Orders` | 5,000 | Order header |
| `FACT_Order_Items` | 5,000 | Order lines, the revenue grain |
| `FACT_Delivery` | 5,000 | Promise, actual time and delay |
| `FACT_Feedback` | 5,000 | Rating and sentiment |
| `Relationships` | 7 | The relationships to create |
| `DAX_Measures` | 32 | Measure name, DAX code and the page it belongs to |
| `Setup_Guide` | 48 | Step-by-step build notes |

## Relationships

| From (one side) | To (many side) | Cardinality | Cross filter |
|---|---|---|---|
| `DIM_Date[Date]` | `FACT_Orders[order_date]` | One to many | Single |
| `DIM_Customer[customer_id]` | `FACT_Orders[customer_id]` | One to many | Single |
| `DIM_Geography[area]` | `FACT_Orders[area]` | One to many | Single |
| `DIM_Product[product_id]` | `FACT_Order_Items[product_id]` | One to many | Single |
| `FACT_Orders[order_id]` | `FACT_Order_Items[order_id]` | One to many | Single |
| `FACT_Orders[order_id]` | `FACT_Delivery[order_id]` | One to one | Both |
| `FACT_Orders[order_id]` | `FACT_Feedback[order_id]` | One to one | Both |

## Measures

The 32 measures cover the same figures the notebooks produce, for example:

| Group | Measures |
|---|---|
| Headline | Total Revenue, Item Revenue, Total Orders, Total Units, Avg Order Value, Avg Items per Order |
| Customers | Active Customers, Registered Customers, Never Ordered, Repeat Customer Revenue, Silent Churn % |
| Delivery | On-Time Orders, On-Time %, Delayed Orders, Revenue Through Delayed Orders, High Value Revenue at Risk |
| Stock | Total Products, Products at Risk, Wastage Risk %, Total Reduction Units, Margin Weighted Revenue |
| Trend | Revenue PM, MoM Growth %, Running Revenue, Cumulative Revenue %, Revenue Rank, Revenue Share % |
| Feedback and region | Avg Rating, Negative Feedback %, Cities Served, States Served, Zone Revenue Share % |

Revenue uses the order-item grain:

```dax
Item Revenue = SUM ( FACT_Order_Items[line_total] )
```

## Build order

1. Get data, Excel workbook, select the four `DIM_` and four `FACT_` sheets.
2. In Model view, create the seven relationships listed above.
3. Select `DIM_Date`, then Table tools, Mark as date table, pick `Date`.
4. Create the measures from the `DAX_Measures` sheet, one at a time.
5. Build the report pages, matching the pages of the web dashboard in this repository.

Status: the model file and measures are ready. The report pages are still to be built.
