## Omsorg 2050 - Resultatvisning
##
## Viser historisk (observert) og framskrevet verdi per kommune for én valgt
## Y-variabel, basert på:
##   - Historikk: data/ssb/paneldata_2007_2025_2024struktur_med_demens.rds
##     (hent_paneldata_2007_2025.R + legg_til_demens.R)
##   - Framskrivning: data/ssb/framskrevet_<variabel>.rds
##     (modell_<variabel>.R + framskriv_<variabel>.R), kun hovedalternativet
##     MMMM, 2026-2050, basert på hovedmodell (kun tilfeldig kommuneintercept
##     - se framskriv_y1.R for hvorfor helningsmodellen ble forkastet, samme
##     begrunnelse gjelder øvrige variabler).
##
## Nye Y-variabler legges til i Y_VARIABLER-listen under - resten av appen
## (kommuneutvalg, plott, tabell, nedlasting) er felles og variabel-agnostisk.
##
## Planlagt videre arbeid:
##   - Flere Y-variabler (Y_3/Y_4/Y_5 separat, hvis ønskelig utover Y_2*).
##   - Konfidens-/prediksjonsintervall på framskrivningen.
##   - Valg av befolkningsscenario (i dag kun hovedalternativet MMMM).

library(shiny)
library(bslib)
library(httr2)
library(dplyr)
library(plotly)
library(DT)

utmappe <- file.path("data", "ssb")

## ============================================================================
## Konfigurasjon: én oppføring per Y-variabel som kan velges i appen
## ============================================================================
## `historisk_kolonne` må finnes (evt. beregnes, se under) på `historisk`.
## `framskrevet_fil`/`framskrevet_kolonne` peker til output fra det
## tilhørende framskriv_*.R-scriptet. `flagg_2010` = TRUE markerer 2010 i
## plottet som "utelatt fra modell" - kun sant for Y_1, se
## modell_y2_stjerne.R for hvorfor dette IKKE gjelder Y_2*.
## `usikkerhet_fil`/`nedre_kolonne`/`ovre_kolonne` peker til output fra det
## tilhørende usikkerhet_*.R-scriptet (95 % bootstrap-konfidensintervall for
## framskrivningen).
Y_VARIABLER <- list(
  Y_1 = list(
    navn = "Etterspørsel etter hjemmetjenester (brukere)",
    historisk_kolonne = "Y_1_a_ialt",
    framskrevet_fil = "framskrevet_y1.rds",
    framskrevet_kolonne = "y1_predikert",
    usikkerhet_fil = "framskrevet_y1_usikkerhet.rds",
    nedre_kolonne = "y1_nedre",
    ovre_kolonne = "y1_ovre",
    flagg_2010 = TRUE
  ),
  Y_2_stjerne = list(
    navn = "Etterspørsel etter bolig (brukere)",
    historisk_kolonne = "Y_2_stjerne_ialt",
    framskrevet_fil = "framskrevet_y2_stjerne.rds",
    framskrevet_kolonne = "y2s_predikert",
    usikkerhet_fil = "framskrevet_y2_stjerne_usikkerhet.rds",
    nedre_kolonne = "y2s_nedre",
    ovre_kolonne = "y2s_ovre",
    flagg_2010 = FALSE
  ),
  Y_5 = list(
    navn = "Etterspørsel etter sykepleiere (årsverk)",
    historisk_kolonne = "Y_5_ialt",
    framskrevet_fil = "framskrevet_y5.rds",
    framskrevet_kolonne = "y5_predikert",
    usikkerhet_fil = "framskrevet_y5_usikkerhet.rds",
    nedre_kolonne = "y5_nedre",
    ovre_kolonne = "y5_ovre",
    flagg_2010 = FALSE
  )
)

## ---- Data lastet én gang ved oppstart --------------------------------------

## Kommunenavn (kun for et brukervennlig utvalg - selve dataene bruker bare
## kommunenummer). Samme kilde (Klass-klassifikasjon 131) som er brukt
## tidligere i prosjektet for å knytte navn til gjeldende (2024) kommunenummer.
hent_kommunenavn <- function() {
  url <- sprintf("https://data.ssb.no/api/klass/v1/classifications/131/codesAt?date=%s",
                 format(Sys.Date(), "%Y-%m-%d"))
  parsed <- request(url) |> req_perform() |> resp_body_json(simplifyVector = TRUE)
  koder <- parsed$codes
  koder[koder$code != "9999", c("code", "name")]
}

historisk <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
# Lagret som demens_estimert (antall), ikke andel - beregn andelen her, samme
# som i modell_y1.R/framskriv_y1.R.
historisk$demensandel <- historisk$demens_estimert / historisk$folk_ialt
# Avledede historiske kolonner for variabler som er en sum av andre - må
# holdes i sync med tilsvarende beregning i modell_y2_stjerne.R.
historisk$Y_2_stjerne_ialt <- historisk$Y_2_ialt + historisk$Y_3_a_ialt

# Last inn framskrivning for hver konfigurerte variabel (små filer, greit å
# holde alle i minnet samtidig).
framskrevet_liste <- lapply(Y_VARIABLER, function(v) {
  readRDS(file.path(utmappe, v$framskrevet_fil))
})

# Usikkerhet (95 % bootstrap-konfidensintervall, se usikkerhet_*.R) - lastes
# på samme måte, og slås sammen med framskrevet_liste i lag_tidsserie().
usikkerhet_liste <- lapply(Y_VARIABLER, function(v) {
  readRDS(file.path(utmappe, v$usikkerhet_fil))
})

kommunenavn <- tryCatch(hent_kommunenavn(), error = function(e) NULL)

kommuner_tilgjengelig <- sort(unique(historisk$kommunenr_2024))
if (!is.null(kommunenavn)) {
  navnetabell <- kommunenavn[kommunenavn$code %in% kommuner_tilgjengelig, ]
  navnetabell <- navnetabell[order(navnetabell$name), ]
  kommune_valg <- setNames(navnetabell$code, paste0(navnetabell$name, " (", navnetabell$code, ")"))
} else {
  # Reserveløsning uten navn, i tilfelle Klass-API ikke er tilgjengelig.
  kommune_valg <- setNames(kommuner_tilgjengelig, kommuner_tilgjengelig)
}
KOMMUNE_STANDARD <- if ("3101" %in% kommuner_tilgjengelig) "3101" else kommuner_tilgjengelig[1]

## ---- Slå sammen historikk + framskrivning til én tidsserie per kommune ----
## Variabel-agnostisk: leser kolonnenavn fra Y_VARIABLER-oppføringen for
## valgt variabel, og returnerer alltid en `verdi`-kolonne uansett hvilken
## variabel som er valgt.
lag_tidsserie <- function(kommune, variabel_id) {
  v <- Y_VARIABLER[[variabel_id]]
  framskrevet <- framskrevet_liste[[variabel_id]]
  usikkerhet <- usikkerhet_liste[[variabel_id]]

  obs <- historisk |>
    filter(kommunenr_2024 == kommune) |>
    transmute(år, kilde = "Observert", verdi = .data[[v$historisk_kolonne]],
              folk_ialt, demensandel, nedre = NA_real_, ovre = NA_real_)
  proj <- framskrevet |>
    filter(kommunenr_2024 == kommune) |>
    transmute(år, kilde = "Framskrevet (MMMM)", verdi = .data[[v$framskrevet_kolonne]],
              folk_ialt, demensandel) |>
    left_join(
      usikkerhet |>
        filter(kommunenr_2024 == kommune) |>
        transmute(år, nedre = .data[[v$nedre_kolonne]], ovre = .data[[v$ovre_kolonne]]),
      by = "år"
    )
  bind_rows(obs, proj) |> arrange(år)
}

## ============================================================================
## UI
## ============================================================================
ui <- page_sidebar(
  title = "Omsorg 2050 - Resultater",
  theme = bs_theme(version = 5, bootswatch = "flatly"),

  sidebar = sidebar(
    width = 340,
    selectInput("variabel", "Variabel",
                choices = setNames(names(Y_VARIABLER), vapply(Y_VARIABLER, `[[`, "", "navn"))),
    selectizeInput("kommune", "Kommune", choices = kommune_valg, selected = KOMMUNE_STANDARD),
    tags$hr(),
    tags$small(
      class = "text-muted",
      "Historikk: observerte SSB-tall 2007-2025. Framskrivning: modellbasert ",
      "2026-2050 (SSBs hovedalternativ MMMM).)."
    )
  ),

  navset_tab(
    nav_panel("Framskrivning",
      br(),
      plotlyOutput("plot_verdi", height = "480px")
    ),
    nav_panel("Datatabell",
      br(),
      downloadButton("last_ned", "Last ned CSV"),
      br(), br(),
      DTOutput("tabell")
    ),
    nav_panel("Om",
      br(),
      div(
        h4("Om denne visningen"),
        p("Viser observerte tall 2007-2025 og en framskrivning 2026-2050 for valgt variabel og kommune, basert på SSBs offisielle statistikk og befolkningsframskrivninger. Det skraverte feltet rundt framskrivningen viser et 95 % usikkerhetsintervall."),
        h5("Kjente begrensninger"),
        tags$ul(
          tags$li("For enkelte variabler er ett eller flere år utelatt fra beregningsgrunnlaget pga. datakvalitet - merkes i plottet der det er relevant."),
          tags$li("For enkelte variabler finnes historiske tall bare for en del av perioden 2007-2025 - vises som et hull i den historiske linjen."),
          tags$li("Kun ett befolkningsscenario er beregnet så langt."),
          tags$li("Usikkerhetsintervallet fanger opp estimeringsusikkerhet i modellen, ikke usikkerhet i selve befolkningsframskrivningen eller i valg av modelltype.")
        ),
        h5("Planlagt videre arbeid"),
        tags$ul(
          tags$li("Eventuelt flere variabler."),
          tags$li("Valg av flere befolkningsscenarioer.")
        )
      )
    )
  )
)

## ============================================================================
## Server
## ============================================================================
server <- function(input, output, session) {

  tidsserie <- reactive({
    req(input$kommune, input$variabel)
    lag_tidsserie(input$kommune, input$variabel)
  })

  output$plot_verdi <- renderPlotly({
    d <- tidsserie()
    validate(need(nrow(d) > 0, "Ingen data for valgt kommune."))
    v <- Y_VARIABLER[[input$variabel]]

    # Marker 2010 med egen farge/form KUN for variabler der dette faktisk er
    # utelatt fra modellestimeringen (se v$flagg_2010).
    d$gruppe <- if (v$flagg_2010) {
      ifelse(d$år == 2010, "2010 (utelatt fra modell)", d$kilde)
    } else {
      d$kilde
    }

    farger <- c(
      "Observert" = "#0072B2",
      "Framskrevet (MMMM)" = "#D55E00",
      "2010 (utelatt fra modell)" = "grey50"
    )

    p <- plot_ly()

    # Usikkerhetsbånd (95 % bootstrap-konfidensintervall) - kun for de
    # framskrevne årene, tegnes FØR linjene slik at linjene vises over båndet.
    ki <- d[d$kilde == "Framskrevet (MMMM)" & !is.na(d$nedre) & !is.na(d$ovre), ]
    if (nrow(ki) > 0) {
      p <- p |> add_ribbons(
        data = ki, x = ~år, ymin = ~nedre, ymax = ~ovre,
        name = "95 % konfidensintervall",
        line = list(width = 0), fillcolor = "rgba(213,94,0,0.2)",
        hoverinfo = "skip"
      )
    }

    for (g in unique(d$gruppe)) {
      sub <- d[d$gruppe == g, ]
      p <- p |> add_trace(
        data = sub, x = ~år, y = ~verdi, type = "scatter", mode = "lines+markers",
        name = g,
        line = list(color = farger[[g]], dash = if (sub$kilde[1] == "Framskrevet (MMMM)") "dash" else "solid"),
        marker = list(color = farger[[g]])
      )
    }

    p |> layout(title = v$navn,
                xaxis = list(title = "År"),
                yaxis = list(title = "Antall"),
                legend = list(title = list(text = "")))
  })

  output$tabell <- renderDT({
    d <- tidsserie()
    validate(need(nrow(d) > 0, "Ingen data for valgt kommune."))
    datatable(d, rownames = FALSE, options = list(pageLength = 15)) |>
      formatRound(columns = c("verdi", "folk_ialt", "nedre", "ovre"), digits = 0) |>
      formatPercentage(columns = "demensandel", digits = 2)
  })

  output$last_ned <- downloadHandler(
    filename = function() sprintf("%s_%s.csv", input$variabel, input$kommune),
    content = function(file) {
      write.csv(tidsserie(), file, row.names = FALSE, na = "", fileEncoding = "UTF-8")
    }
  )
}

shinyApp(ui, server)
