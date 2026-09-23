# 6. Web Dashboard: Blinkit Nexus

A single-page analytics console built on 5,000 Blinkit orders (March 2023 to November 2024).
Everything runs in the browser: no server, no database, no build step.

## Files

| File | What it is |
|---|---|
| `dashboard/Blinkit_Nexus.html` | The finished dashboard. One file, about 490 KB, opens by double click. Rename to `index.html` to host it. |
| `dashboard/src/app.html` | Page template, styles and application code, with a `/*DATA*/` placeholder |
| `dashboard/src/style.css` | Design tokens and all styling (kept separate for editing, inlined at build time) |
| `dashboard/src/icons.js` | Line icon set and the rules that pick an icon for each card |
| `dashboard/src/art.js` | Page artwork, one SVG illustration per page |
| `dashboard/src/prep.py` | Reads the cleaned Excel workbook and writes `data.js` |
| `dashboard/src/data.js` | Order-level data used by the page, about 390 KB |
| `dashboard/src/geo_map.py` | City to state to zone mapping used by `prep.py` |

## How the data gets in

```
Blinkit_analysis_new.xlsx  ->  prep.py  ->  data.js  ->  app.html  ->  Blinkit_Nexus.html
```

`prep.py` flattens orders, order items, delivery, feedback and customers into one array of 5,000 rows,
replaces repeated text with index numbers to keep the file small, and writes it as `data.js`.

Rebuild after changing the data or the code:

```bash
python3 dashboard/src/prep.py                      # writes src/data.js
python3 - <<'PY'
s = open('dashboard/src/app.html').read()
d = open('dashboard/src/data.js').read()
open('dashboard/Blinkit_Nexus.html','w').write(s.replace('/*DATA*/', d))
PY
```

## Pages

| Page | What it answers |
|---|---|
| Overview | Headline figures, monthly revenue, notable signals, category split, state map, hourly demand |
| Sales & Margin | Monthly revenue and growth, category rank by sales against rank by margin, concentration curve, top products, order value bands |
| Customer Analysis | Activation funnel, return speed, segment label against actual buying, order frequency, top customers |
| Delivery Analysis | Promise gap in minutes, status mix, on-time gauge, state ranking, monthly trend, rating by status |
| Stock & Spoilage | Stock cover against shelf life, risk by category, recommended minimum stock for every product |
| Regional Market | Tile map of India, zone comparison, state priority score |
| Order Arrival | Day and hour demand map, slot length correction, weekday against weekend |
| Payment Analysis | Method performance, average order value by method, payment mix by month and by zone |
| Feedback Analysis | Rating distribution, rating by delivery status, sentiment by topic, rating by delay band and by category |
| Order Log | Every order in the current filter, searchable |

## Interaction

- Filters for period, region and category change every figure on every page.
- Keyboard: `1` to `9` switch pages, `T` toggles the theme, `R` resets the filters.
- Light and dark themes, both defined as CSS variables; the page follows the system setting until the theme button is used.
- Every chart has hover tooltips. Tables with a sort arrow can be sorted by clicking a column.
- The tile map, heat map and status bars have their own hover readouts.

## Design

- Type: Bricolage Grotesque for headings, Instrument Sans for text, IBM Plex Mono for labels and figures.
- Colour: one accent (green) with a gold second accent; green, amber and red are reserved for good, warning and critical states.
- Icons: a single line icon set at 24 by 24, drawn in the surrounding text colour so both themes work.
- Artwork: one SVG illustration per page, built from the same icon language.
- Charts: Chart.js 4.4.1 from a CDN, with gradients, rounded bar ends and theme-aware grid colours.

## Hosting

The file is self-contained, so any static host works. Rename it to `index.html` and upload it.
The only external requests are Google Fonts and the Chart.js script; the page still renders without them.

