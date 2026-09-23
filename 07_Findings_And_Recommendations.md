# 7. Findings and Recommendations

Every figure below comes from the notebooks in this repository and can be reproduced by running them.

## Findings

### Sales

1. Revenue in the period is 49.72 lakh rupees from 5,000 orders, at an average order value of 994 rupees.
2. Monthly revenue is flat across the 21 months. No seasonal pattern appears in the data.
3. 139 of 268 product codes produce 80% of revenue. The weakest 25% of codes produce 5.8%.
4. The 80-20 rule does not hold exactly here: the real split is closer to 80-52.

### Margin

5. Dairy and Breakfast is first by revenue but fifth by margin earned. Pet Care is fourth by revenue and first by margin.
6. Margin percentage is fixed within each category, so the difference comes from the category mix and not from pricing.

### Customers

7. 2,172 of 2,500 registered customers have ordered. 328 never ordered at all.
8. Repeat customers produce 86.7% of revenue.
9. The median gap between the first and second order is 135 days, which is very long for quick commerce.
10. 600 customers carry the label Inactive in the source, yet they placed 1,190 orders.

### Activation funnel

11. 13.1% of registered customers are lost before the first order, 31.3% of buyers stop after one order, and only 806 customers reach a third order.

### Delivery

12. The on-time rate is 69.4% by the status column, but by the actual minutes 62% of orders arrive after the promised time and 20.1% are more than 10 minutes late.
13. When an order is late, the average delay is 8.7 minutes.
14. The on-time rate ranges from 61.9% to 72.1% across states, so one national promise does not fit every region.
15. Average rating is 3.33, 3.39 and 3.33 across the three delivery statuses. An ANOVA gives a p-value of 0.34, so the difference is not real. Ratings cannot be used to detect delivery problems here.

### Stock and spoilage

16. 180 of 268 products hold a minimum stock level that cannot sell within their shelf life. These products carry 60.8% of revenue.
17. The correlation between shelf life and minimum stock is 0.04 with a p-value of 0.50, so shelf life was never considered when the stock levels were set.
18. Wastage exposure is 11.12 lakh rupees, and 72 products carry 80% of it.
19. The recommended stock levels release 2,495 units, a cut of 46%, worth 12.40 lakh rupees.

### Payments

20. Cash, UPI, Card and Wallet are close to an even split, with similar average order values. Payment method does not separate high and low spenders.

### Order arrival

21. Time slots in the source have unequal lengths: Night covers 8 hours, Afternoon 5. Per hour, demand is almost flat at 205 to 221 orders, so the apparent night peak is an artefact of slot length.

### Regions

22. South zone produces 28% of revenue and has the highest repeat rate at 72.2%, against 62.5% in West.
23. Uttar Pradesh alone produces 12.6% of revenue.

### High-value orders

24. Orders of 1,000 rupees and above are 35.9% of orders but 67.6% of revenue, and their on-time rate is the same as that of small orders.

### Forecasting

25. Category forecasts beat a naive benchmark, with an average error of about 11%, which is good enough to drive a monthly stock plan at category level.

## Recommendations

| # | Recommendation | What the data shows | What to do |
|---|---|---|---|
| 1 | Reset minimum stock for short shelf-life products | 180 products cannot sell their minimum stock before expiry, carrying 60.8% of revenue and 11.12 lakh rupees of exposure | Apply the recommended level per product. This releases 2,495 units worth 12.40 lakh rupees and still keeps 80% of the shelf life as buffer |
| 2 | Set the delivery promise per region | 62% of orders arrive after the promise, and the on-time rate ranges from 61.9% to 72.1% by state | Set each zone's promise at the 90th percentile of its actual delivery time, so the promise is one the operation can keep |
| 3 | Give large orders delivery priority | Large orders carry 67.6% of revenue but get the same on-time rate as small ones | Route orders of 1,000 rupees and above first during peak hours |
| 4 | Send a reminder within 30 days of the first order | 31.3% of buyers never place a second order, and returners take a median 135 days | Target the first 30 days, well before customers normally drift away |
| 5 | Rank categories by margin, not by sales | Dairy and Breakfast leads revenue but is fifth on margin; Pet Care is first on margin | Move promotional spend and dark-store space towards the categories that earn, with wastage risk in the same view |
| 6 | Merge duplicate product codes | 268 codes exist for only 51 names, and one name has 12 codes | Merge codes holding under 8% of their name group, which shortens the catalogue without a measurable revenue loss |
| 7 | Rebuild the customer segments | 600 customers labelled Inactive placed 1,190 orders | Build segments from recency, frequency and spend, so campaigns reach the right group |
| 8 | Plan riders by hour, not by slot | Slot lengths are unequal and demand per hour is flat at 205 to 221 orders | Use the hour and weekday demand map for rosters and stop treating Night as the peak |
| 9 | Prioritise regions with a combined score | South leads on both revenue share and repeat rate, while some high-revenue states have weak delivery | Use the priority score: 40% revenue share, 30% repeat rate, 30% on-time rate |
| 10 | Drive replenishment from the forecast | Forecasts beat the naive benchmark with an average error near 11% | Order next month's stock from the forecast plus safety stock, and review the error every month |

## What this data cannot answer

1. Every order holds exactly one item, so there is no basket analysis of products bought together.
2. Margin is fixed per category, so product-level pricing effects cannot be measured.
3. There is no stock movement history, so stock risk is modelled from stock levels, demand and shelf life.
4. Location is at city level only, and the pincode column does not agree with the city.
5. The first and last months are partial, so they are marked on every monthly chart.
