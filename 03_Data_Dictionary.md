# 3. Data Dictionary

Tables, keys and columns as used in the analysis. The cleaned workbook carries the same dictionary
as a sheet.

## Keys and relationships

| From (one) | To (many) | Relationship |
|---|---|---|
| `Customers.customer_id` | `Orders.customer_id` | One customer has many orders |
| `Orders.order_id` | `Order_Items.order_id` | One order has many items (one in this dataset) |
| `Products.product_id` | `Order_Items.product_id` | One product appears in many order lines |
| `Orders.order_id` | `Delivery_Performance.order_id` | One delivery record per order |
| `Orders.order_id` | `Customer_Feedback.order_id` | One review per order |
| `city_state_zone.area` | `Orders.area` | One city covers many orders |

## Orders

| Column | Type | Meaning |
|---|---|---|
| `order_id` | Text | Unique identifier of the order (primary key) |
| `customer_id` | Text | Links to the customer master |
| `order_date` | Date and time | When the order was placed |
| `promised_delivery_time` | Date and time | Time promised to the customer |
| `actual_delivery_time` | Date and time | Time the order arrived |
| `delivery_time_minutes` | Number | Actual minus promised, in minutes. Negative means early |
| `delivery_status` | Category | On Time, Slightly Delayed, Significantly Delayed |
| `order_total` | Currency | Order value as recorded in the order table |
| `payment_method` | Category | Cash, UPI, Card, Wallet |
| `distance_km` | Number | Distance covered for the delivery |
| `reasons_if_delayed` | Text | Reason recorded when the order was delayed |
| `area` | Text | City the order was delivered in |
| `pincode` | Text | Postal code as supplied. Not used, see cleaning notes |
| `customer_segment` | Category | Premium, Regular, New, Inactive label from the source |
| `registration_date` | Date | When the customer signed up |
| `order_day_of_week` | Text | Derived weekday name |
| `is_weekend` | Text | Derived Yes or No |
| `order_time_slot` | Category | Morning, Afternoon, Evening, Night. Slots are of unequal length |
| `order_value_segment` | Category | Low, Medium, High value band from the source |

## Order Items

| Column | Type | Meaning |
|---|---|---|
| `order_id` | Text | Links to the order |
| `product_id` | Text | Links to the product |
| `quantity` | Number | Units ordered |
| `unit_price` | Currency | Price per unit charged |
| `line_total` | Currency | Quantity times unit price. Used as revenue throughout this project |
| `margin_percentage` | Number | Margin on the product, fixed within each category |

## Products

| Column | Type | Meaning |
|---|---|---|
| `product_id` | Text | Unique identifier (primary key) |
| `product_name` | Text | Product name. 268 codes share 51 names |
| `category` | Category | One of 11 categories |
| `brand` | Text | Brand of the product |
| `price` | Currency | Selling price |
| `mrp` | Currency | Printed maximum price |
| `margin_percentage` | Number | Margin percentage, 15 to 40 |
| `shelf_life_days` | Number | Days the product stays sellable, 3 to 365 |
| `min_stock_level` | Number | Minimum stock the store should hold |
| `max_stock_level` | Number | Maximum stock the store should hold |

## Customers

| Column | Type | Meaning |
|---|---|---|
| `customer_id` | Text | Unique identifier (primary key) |
| `customer_name` | Text | Generated name, no real person |
| `email`, `phone`, `address` | Text | Contact fields, generated |
| `area`, `pincode` | Text | Location as supplied |
| `registration_date` | Date | Sign-up date |
| `customer_segment` | Category | Label from the source. Does not match behaviour, see findings |
| `total_orders`, `avg_order_value` | Number | Source summary fields |

## Customer Feedback

| Column | Type | Meaning |
|---|---|---|
| `feedback_id` | Text | Unique identifier (primary key) |
| `order_id` | Text | Links to the order |
| `rating` | Number | 1 to 5 stars |
| `feedback_text` | Text | Free text left by the customer |
| `feedback_category` | Category | Delivery, Product Quality, Customer Service, App Experience |
| `sentiment` | Category | Positive, Neutral, Negative |

## Inventory Analysis (derived)

| Column | Type | Meaning |
|---|---|---|
| `units_sold` | Number | Units sold in the 21-month period |
| `times_ordered` | Number | Distinct orders containing the product |
| `avg_monthly_demand` | Number | Units sold divided by 21 months |
| `stock_cover_months_at_min` | Number | Months the minimum stock lasts at that demand |
| `stock_cover_months_at_max` | Number | Months the maximum stock lasts at that demand |
| `movement_class` | Category | Fast, Medium or Slow moving by units-sold quartile |
| `stock_policy_status` | Category | Overstocked, Balanced or Reorder Risk |
| `wastage_risk` | Category | At risk when stock cover is longer than shelf life |

## City mapping (added in this project)

| Column | Type | Meaning |
|---|---|---|
| `area` | Text | City name as it appears in the orders |
| `state` | Text | State the city belongs to |
| `zone` | Text | North, South, East, West, Central or North East |
| `city_tier` | Text | Tier 1, 2 or 3 |

## Fields created during the analysis

| Field | Built from | Used for |
|---|---|---|
| `order_month` | `order_date` | Monthly trend, growth, cohorts |
| `order_hour` | `order_date` | Hourly demand, capacity planning |
| `is_late_minutes` | `delivery_time_minutes > 0` | Promise accuracy measured in minutes |
| `margin_value` | `line_total × margin_percentage / 100` | Margin ranking against revenue ranking |
| `shelf_life_months` | `shelf_life_days / 30.44` | Comparison against stock cover |
| `recency`, `frequency`, `monetary` | Order history per customer | Segmentation |
| `safety_stock`, `reorder_point` | Demand variation, one-week lead time | Stock plan |
