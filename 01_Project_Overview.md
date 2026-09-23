# 1. Project Overview

## Objective

Analyse the order history of a quick-commerce grocery business and answer four questions:

1. Where does the revenue come from, and how concentrated is it?
2. Which customers come back, and where are they lost?
3. How reliable is the delivery promise, and where does it break?
4. How much stock is held that cannot sell before it expires?

## Scope of the data

| Item | Value |
|---|---|
| Orders | 5,000 |
| Customers | 2,500 registered, 2,172 have ordered |
| Products | 268 product codes across 51 product names |
| Cities | 316, mapped to 28 states and 5 zones |
| Period | 16 March 2023 to 4 November 2024 (21 months) |
| Revenue | 49.72 lakh rupees |

## Workflow

```
Raw Excel workbook
      ↓  cleaning in Excel
Cleaned workbook (19 sheets)
      ↓  validation in Excel and Python
DuckDB database built inside Jupyter
      ↓  SQL analysis, 92 queries
Python: statistics, clustering, forecasting
      ↓
Findings and recommendations
      ↓
Web dashboard, Power BI model, documentation
```

## Tools

| Stage | Tool |
|---|---|
| Source data | Excel workbook from Kaggle |
| Cleaning and first checks | Excel |
| Database | DuckDB |
| Analysis environment | Jupyter Notebook |
| SQL | DuckDB SQL: window functions, CTEs, conditional aggregation, quantiles |
| Python | pandas, numpy, scipy, scikit-learn, statsmodels |
| Charts | matplotlib and seaborn in the notebooks, Chart.js in the dashboard |
| Reporting | Web dashboard and Power BI |

## Deliverables

| Deliverable | Where |
|---|---|
| Cleaned workbook | `data/Blinkit_analysis_new.xlsx` |
| Master notebook, 120 steps with outputs | `notebooks/00_Master_Analysis.ipynb` |
| 14 topic notebooks | `notebooks/01_…` to `notebooks/14_…` |
| SQL query file | `sql/blinkit_analysis_queries.sql` |
| Result workbook, 13 sheets | `outputs/Blinkit_Analysis_Outputs.xlsx` |
| Product stock plan | `outputs/Blinkit_Stock_Recommendation.xlsx` |
| Web dashboard | `dashboard/Blinkit_Nexus.html` |
| Power BI model input | `powerbi/Blinkit_PowerBI_Ready.xlsx` |
| Documentation | `docs/` |

## Rules followed during the project

1. The raw file was never edited. All work happened on a separate cleaned copy.
2. No record was deleted because it looked odd. Suspicious records were flagged and reported.
3. Every change to the data is recorded in `04_Data_Cleaning.md` with its reason.
4. Figures that the source had already calculated were recomputed from the order data before being used.
5. Where the source contradicted itself, the source was rejected and the reason written down.
