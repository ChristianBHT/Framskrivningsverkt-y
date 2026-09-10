## Framskrevet behov for helse- og omsorgstjenester, etter kommune
##
## Combines SSB's municipal population projections (table 12882) with SSB's
## KOSTRA coverage-rate figures for health/care services (table 12209) to
## project how many people in a chosen municipality are likely to need
## home care, institutional care (nursing home) or day activities for the
## elderly, over a chosen set of years and population-projection alternative.
##
## Data is queried live from SSB's StatBank API on every request - see the
## "Om" tab in the app for sources, method and known limitations.

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(plotly)
library(DT)

source("R/ssb_api.R")

## ---- static reference data (stable SSB dimension codes, not worth a live call) ----

PROJECTION_ALTERNATIVES <- c(
  "Hovedalternativet (MMMM)"      = "Personer",
  "Lav nasjonal vekst (LLML)"     = "Personer1",
  "Hoy nasjonal vekst (HHMH)"     = "Personer2",
  "Lav nettoinnvandring (MMML)"   = "Personer3",
  "Hoy nettoinnvandring (MMMH)"   = "Personer4",
  "Sterk aldring (LHML)"          = "Personer5",
  "Svak aldring (HLMH)"           = "Personer6",
  "Ingen nettoinnvandring (MMM0)" = "Personer7",
  "Ingen flytting (MM00)"         = "Personer8"
)

INDICATORS <- list(
  KOShjtj80aarover0001 = list(
    label = "Hjemmetjenester, 80 ar og over",
    band  = "80+",
    unit  = "personer"
  ),
  KOSsykhjand80aar0000 = list(
    label = "Institusjonsopphold (sykehjem m.m.), 80 ar og over",
    band  = "80+",
    unit  = "personer"
  ),
  KOSandeldagakt670000 = list(
    label = "Dagaktivitetstilbud, 67-79 ar",
    band  = "67-79",
    unit  = "personer"
  )
)

AGE_BANDS <- list(`0-66` = c(0, 66), `67-79` = c(67, 79), `80+` = c(80, 150))

POP_YEAR_MIN <- 2020
POP_YEAR_MAX <- 2050
KOSTRA_LOOKUP_YEARS <- 2025:2015

## ---- data fetched once at app startup (small, stable lookup tables) ----

startup_error <- NULL
municipalities <- tryCatch(get_population_region_list(), error = function(e) {
  startup_error <<- conditionMessage(e)
  data.frame(code = character(), name = character(), is_legacy_code = logical())
})

mun_choices <- setNames(municipalities$code, municipalities$name)
default_region <- if ("5001" %in% municipalities$code) "5001" else municipalities$code[1]

## ---- "Om" tab content (plain tags, no extra markdown dependency) -----------

about_panel <- div(
  h4("Om denne appen"),
  p("Appen kombinerer to tabeller fra SSBs statistikkbank, hentet direkte via SSBs API ved hver forsporring:"),
  tags$ul(
    tags$li(
      tags$a(href = "https://www.ssb.no/statbank/table/12882", target = "_blank", "Tabell 12882"),
      " - Framskrevet folkemengde etter region, kjonn, alder, framskrivingsalternativ og ar. ",
      "Brukes til a beregne befolkning i aldersgruppene 67-79 ar og 80 ar og over, for valgt framskrivingsalternativ."
    ),
    tags$li(
      tags$a(href = "https://www.ssb.no/statbank/table/12209", target = "_blank", "Tabell 12209"),
      " - Utvalgte nokkeltall for helse og omsorg (KOSTRA), etter region og ar. ",
      "Brukes til a hente kommunens siste registrerte dekningsgrad for hjemmetjenester, institusjonsopphold og dagaktivitetstilbud."
    )
  ),
  h5("Metode"),
  p("Projisert behov = befolkning i aldersgruppen (tabell 12882) x andel av aldersgruppen som bruker tjenesten (tabell 12209, evt. justert manuelt i sidepanelet). ",
    "Dekningsgraden holdes konstant gjennom hele perioden med mindre du selv endrer den - appen framskriver altsa ikke endringer i dekningsgrad over tid, kun demografiendringen."),
  h5("Kjente begrensninger"),
  tags$ul(
    tags$li("Framskrivingstabellen (12882) oppdateres sjeldnere enn KOSTRA-tabellen. For kommuner pavirket av kommune-/fylkessammenslaingene rundt 2020 og delingene i 2024, kan tabellen fortsatt bruke eldre regionnummer. Appen varsler om dette i sidepanelet, og bruker da landsmedian som standard dekningsgrad siden kommunens KOSTRA-tall ikke kan slas opp pa det gamle nummeret."),
    tags$li("Dekningsgrad er en forenkling: fremtidig dekningsgrad pavirkes ogsa av kommunens kapasitet, prioriteringer og nasjonale reformer, ikke bare demografi."),
    tags$li("Tall kan vaere sensurert/mangle for sma kommuner enkelte ar; appen faller da tilbake pa landsmedian.")
  ),
  p(tags$small(class = "text-muted", "Kildekode: app.R og R/ssb_api.R i dette prosjektet."))
)

## ---- UI --------------------------------------------------------------------

ui <- page_sidebar(
  title = "Framskrevet behov for helse- og omsorgstjenester",
  theme = bs_theme(version = 5, bootswatch = "flatly"),

  sidebar = sidebar(
    width = 340,
    selectizeInput("region", "Kommune",
                    choices = mun_choices, selected = default_region),
    uiOutput("legacy_warning"),
    selectInput("alternative", "Framskrivingsalternativ (SSB)",
                choices = PROJECTION_ALTERNATIVES, selected = "Personer"),
    sliderInput("years", "Ar",
                min = POP_YEAR_MIN, max = POP_YEAR_MAX,
                value = c(2026, 2040), step = 1, sep = ""),
    checkboxGroupInput("indicators", "Tjenester som skal framskrives",
                        choices = setNames(names(INDICATORS), vapply(INDICATORS, `[[`, "", "label")),
                        selected = names(INDICATORS)),
    actionButton("go", "Hent / oppdater data", class = "btn-primary w-100"),
    tags$hr(),
    uiOutput("rate_sliders"),
    tags$hr(),
    tags$small(
      class = "text-muted",
      "Dekningsgrader er forhandsutfylt med kommunens siste tilgjengelige KOSTRA-tall ",
      "(eller landsmedian der kommunetall mangler) og kan justeres manuelt over."
    )
  ),

  navset_tab(
    nav_panel("Befolkning",
      br(),
      plotlyOutput("pop_plot", height = "480px")
    ),
    nav_panel("Behovsframskrivning",
      br(),
      plotlyOutput("demand_plot", height = "480px")
    ),
    nav_panel("Datatabell",
      br(),
      downloadButton("download_csv", "Last ned CSV"),
      br(), br(),
      DTOutput("data_table")
    ),
    nav_panel("Om",
      br(),
      about_panel
    )
  )
)

## ---- server ------------------------------------------------------------------

server <- function(input, output, session) {

  if (!is.null(startup_error)) {
    showNotification(
      paste("Klarte ikke a hente kommuneliste fra SSB ved oppstart:", startup_error),
      type = "error", duration = NULL
    )
  }

  is_legacy <- reactive({
    row <- municipalities[municipalities$code == input$region, ]
    isTRUE(nrow(row) > 0 && row$is_legacy_code[1])
  })

  output$legacy_warning <- renderUI({
    req(input$region)
    if (is_legacy()) {
      div(class = "alert alert-warning py-2 px-2 small mb-2",
          "Merk: befolkningsframskrivningen for denne kommunen bruker et eldre ",
          "regionnummer (fra 2020-2023-strukturen). KOSTRA-tall for dagens ",
          "kommunenummer slas normalt ikke opp automatisk - landsmedian brukes ",
          "som standard dekningsgrad. Se \"Om\"-fanen.")
    }
  })

  ## population, single-year age, fetched on demand
  pop_raw <- eventReactive(input$go, {
    req(input$region, input$alternative, input$years)
    years <- seq(input$years[1], input$years[2])
    withProgress(message = "Henter befolkningsframskrivning fra SSB...", {
      get_population_projection(input$region, years, input$alternative)
    })
  }, ignoreNULL = FALSE)

  pop_bands <- reactive({
    df <- pop_raw()
    req(nrow(df) > 0)
    summarise_age_bands(df, AGE_BANDS)
  })

  ## default coverage rates for the currently selected indicators, refreshed on "go"
  rate_defaults <- eventReactive(input$go, {
    req(input$region)
    codes <- names(INDICATORS)
    withProgress(message = "Henter KOSTRA-dekningsgrader...", {
      out <- lapply(codes, function(code) {
        own <- get_latest_kostra_rate(input$region, code, KOSTRA_LOOKUP_YEARS)
        if (!is.na(own$value)) {
          list(value = own$value, source = sprintf("kommunens tall, %d", own$year))
        } else {
          med_year <- KOSTRA_LOOKUP_YEARS[1]
          med <- get_kostra_national_median(code, med_year)
          list(value = if (is.na(med)) 10 else med,
               source = if (is.na(med)) "standardverdi (ingen data funnet)" else sprintf("landsmedian, %d", med_year))
        }
      })
      names(out) <- codes
      out
    })
  }, ignoreNULL = FALSE)

  output$rate_sliders <- renderUI({
    req(input$indicators)
    defaults <- rate_defaults()
    tagList(
      tags$strong("Antatt dekningsgrad (%)"),
      lapply(input$indicators, function(code) {
        d <- defaults[[code]]
        sliderInput(
          inputId = paste0("rate_", code),
          label = sprintf("%s  [%s]", INDICATORS[[code]]$label, d$source),
          min = 0, max = 100, step = 0.5,
          value = round(d$value, 1)
        )
      })
    )
  })

  demand_df <- reactive({
    req(input$indicators, length(input$indicators) > 0)
    bands <- pop_bands()
    req(nrow(bands) > 0)

    rows <- lapply(input$indicators, function(code) {
      rate_input <- input[[paste0("rate_", code)]]
      req(!is.null(rate_input))
      band_name <- INDICATORS[[code]]$band
      pop_band <- bands[bands$band == band_name, c("Tid", "personer")]
      pop_band$indicator <- INDICATORS[[code]]$label
      pop_band$rate <- rate_input
      pop_band$projected <- pop_band$personer * rate_input / 100
      pop_band
    })
    bind_rows(rows)
  })

  output$pop_plot <- renderPlotly({
    bands <- pop_bands()
    validate(need(nrow(bands) > 0, "Velg kommune og trykk \"Hent / oppdater data\"."))
    bands$band <- factor(bands$band, levels = names(AGE_BANDS))
    p <- plot_ly(bands, x = ~Tid, y = ~personer, color = ~band, colors = "Set2",
                 type = "scatter", mode = "lines+markers") |>
      layout(title = "Befolkning etter aldersgruppe",
             xaxis = list(title = "Ar"),
             yaxis = list(title = "Antall personer"),
             legend = list(title = list(text = "Aldersgruppe")))
    p
  })

  output$demand_plot <- renderPlotly({
    df <- demand_df()
    validate(need(nrow(df) > 0, "Velg minst en tjeneste og trykk \"Hent / oppdater data\"."))
    p <- plot_ly(df, x = ~Tid, y = ~projected, color = ~indicator, colors = "Set1",
                 type = "scatter", mode = "lines+markers") |>
      layout(title = "Projisert antall personer med behov for tjenesten",
             xaxis = list(title = "Ar"),
             yaxis = list(title = "Antall personer"),
             legend = list(title = list(text = "Tjeneste")))
    p
  })

  output$data_table <- renderDT({
    df <- demand_df()
    validate(need(nrow(df) > 0, "Ingen data a vise enna."))
    wide <- df |>
      select(Tid, indicator, projected) |>
      tidyr::pivot_wider(names_from = indicator, values_from = projected)
    bands <- pop_bands() |>
      tidyr::pivot_wider(names_from = band, values_from = personer)
    out <- dplyr::left_join(bands, wide, by = "Tid") |> dplyr::rename(Ar = Tid)
    datatable(out, rownames = FALSE, options = list(pageLength = 15)) |>
      formatRound(columns = setdiff(names(out), "Ar"), digits = 0)
  })

  output$download_csv <- downloadHandler(
    filename = function() sprintf("helse_omsorg_behov_%s.csv", input$region),
    content = function(file) {
      df <- demand_df()
      wide <- df |>
        select(Tid, indicator, projected) |>
        tidyr::pivot_wider(names_from = indicator, values_from = projected)
      bands <- pop_bands() |>
        tidyr::pivot_wider(names_from = band, values_from = personer)
      out <- dplyr::left_join(bands, wide, by = "Tid") |> dplyr::rename(Ar = Tid)
      write.csv(out, file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )
}

shinyApp(ui, server)
