# 5. Analysis Guide

The analysis runs inside Jupyter. DuckDB does the querying, Python does the statistics, modelling
and charts. There are 120 steps in the master notebook and 92 SQL queries in total.

## Notebooks

| Notebook | What it covers | Code steps |
|---|---|---|
| `00_Master_Analysis.ipynb` | Everything in one run, ending with the exported result workbook | 120 |
| `01_Data_Validation.ipynb` | Keys, missing values, referential integrity, business rules, label check | 14 |
| `02_Sales_Performance.ipynb` | Monthly trend and growth, category and product ranking, concentration, order value bands, daily outliers | 20 |
| `03_Customer_Analysis.ipynb` | Repeat behaviour, order gaps, cohort retention, revenue deciles, RFM base table | 16 |
| `04_Activation_Funnel.ipynb` | Registration to first, second and third order, activation speed, repeat purchase curve | 10 |
| `05_Product_And_Margin.ipynb` | Revenue rank against margin rank, top products per category, ABC and XYZ classes, price bands | 14 |
| `06_SKU_Rationalisation.ipynb` | Weakest product codes, merge and review candidates with revenue impact | 8 |
| `07_Delivery_Analysis.ipynb` | Promise accuracy, delay distribution, state and month patterns, distance effect, model of late delivery | 20 |
| `08_Stock_And_Spoilage.ipynb` | Stock cover against shelf life, risk by category, exposure value, safety stock, recommended levels | 17 |
| `09_Payment_Analysis.ipynb` | Method performance, mix by label and zone, independence test, trend | 10 |
| `10_Feedback_Analysis.ipynb` | Ratings, sentiment by topic, rating against delivery status and delay band | 12 |
| `11_Order_Arrival.ipynb` | Hourly demand, slot length correction, weekday against weekend, demand map | 13 |
| `12_Regional_Market.ipynb` | Zone and state metrics, composite priority score, revenue against delivery quadrants | 11 |
| `13_High_Value_Orders.ipynb` | Revenue concentration in large orders, revenue at risk, stability of top customers | 8 |
| `14_Segmentation_And_Forecasting.ipynb` | K-Means groups with silhouette check, category forecast with backtesting, replenishment plan, outliers | 18 |

Every notebook starts with the same setup: it loads the workbook, builds the DuckDB tables and
creates the analysis views. That means any notebook can be run on its own.

## How the database is built

```
data/Blinkit_analysis_new.xlsx
        ↓  pandas read_excel
7 DuckDB tables (orders_src, items_src, delivery_src, feedback_src, customers_src, products_src, inventory_src)
        ↓  typed views
orders, items, feedback
        ↓  one joined view
f_sales   — 5,000 rows, order level, with product, geography, delivery and feedback attached
```

Almost every query runs against `f_sales`, so filters and joins stay consistent across topics.

## SQL techniques used

| Technique | Where it is used |
|---|---|
| Window functions: `LAG`, `RANK`, `DENSE_RANK`, `ROW_NUMBER`, `NTILE` | Month-over-month growth, product and category ranking, deciles, top products inside a category |
| Running totals and moving averages | Cumulative revenue, three-month average, Pareto curve |
| Common table expressions | Almost every multi-step query |
| Conditional aggregation with `FILTER` | On-time share, sentiment counts, payment mix, new against repeat revenue |
| Correlated subqueries | Repeat rate per state |
| `quantile_cont` | Delivery promise at the 80th, 90th and 95th percentile |
| Date functions: `date_trunc`, `date_diff`, `strptime`, `strftime` | Month grouping, gaps between orders, cohort index |
| Cohort matrix in pure SQL | Monthly retention table |

## Python techniques used

| Technique | Library | Where |
|---|---|---|
| K-Means clustering with silhouette score | scikit-learn | Customer segmentation |
| Holt-Winters exponential smoothing with backtesting and MAPE | statsmodels | Category demand forecast |
| Logistic regression | statsmodels | What drives a late delivery |
| Kaplan-Meier estimate | numpy, written out step by step | Repeat purchase curve |
| ANOVA, Kruskal-Wallis, chi-square, Spearman, Pearson, Mann-Whitney, Welch t-test, Shapiro | scipy | Testing whether differences are real |
| ABC and XYZ classification | pandas | Product classification by value and by variability |
| Safety stock and reorder point | numpy | Stock plan per product |
| Outlier detection with IQR and z-score | pandas, scipy | Order value distribution |

## Running it

```bash
pip install -r requirements.txt
jupyter notebook
```

Place `Blinkit_analysis_new.xlsx` in `data/` first. Run the cells in order. The notebook writes
`blinkit.duckdb` on the first run and `outputs/Blinkit_Analysis_Outputs.xlsx` at the end.

## Result workbook

`outputs/Blinkit_Analysis_Outputs.xlsx` holds 13 sheets: key findings, monthly sales, category
performance, state performance, state priority score, stock plan, ABC-XYZ, RFM segments, segment
profile, category forecast, SKU recommendations, repeat curve and the hour by day demand map.
