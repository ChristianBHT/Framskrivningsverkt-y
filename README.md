# Framskrevet behov for helse- og omsorgstjenester

R Shiny app that projects municipal demand for elderly health/care services
in Norway, by combining two live SSB StatBank tables:

- **12882** - population projections by municipality, age and projection
  alternative (MMMM etc.)
- **12209** - KOSTRA health/care key figures (coverage rates for home care,
  institutional care, day activities) by municipality

Projected demand = projected population in an age band x coverage rate for
that service (defaulted from the municipality's latest KOSTRA figure, or a
national median when that's unavailable, and always adjustable in the app).

## Run it

```r
install.packages(c("shiny", "bslib", "httr2", "dplyr", "tidyr", "plotly", "DT"))
shiny::runApp("municipal-health-demand")
```

Requires an internet connection - all data is fetched live from
`data.ssb.no` on each request, nothing is bundled.

## Files

- `app.R` - UI and server logic
- `R/ssb_api.R` - SSB PxWebApi / Klass client functions (query building,
  JSON parsing, municipality lists, rate lookups with fallbacks)

## Known limitation

Table 12882 (population projections) is refreshed less often than the
KOSTRA table, so for the ~115 municipalities affected by the 2020 and 2024
Norwegian municipality/county boundary changes it may still expose an older
region code. The app detects this (banner in the sidebar) and falls back to
a national median coverage rate for those cases. See the "Om" tab in the
app for the full explanation.
