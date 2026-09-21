## Omsorg 2050 - Resultatvisning
##
## Viser historisk (observert) og framskrevet verdi per kommune for én valgt
## Y-variabel, basert på:
##   - Historikk: data/ssb/paneldata_2007_2025_2024struktur_med_demens.rds
##     (hent_paneldata_2007_2025.R + legg_til_demens.R)
##   - Framskrivning: data/ssb/framskrevet_<variabel>.rds
##     (modell_<variabel>.R + framskriv_<variabel>.R), kun hovedalternativet
##     MMMM, 2026-2050, basert på hovedmodell_slope (tilfeldig intercept OG
##     helning på demensandel per kommune), ANKRET ved kommunens siste
##     observerte (2025) demensandel - se framskriv_y1.R for full
##     begrunnelse. Dette er en rettet policy: det ble tidligere brukt en
##     SEPARAT intercept-only-modell for punktestimatet, som ga et synlig
##     sprang mot trend-varianten under selv når trend-effekten var 0 % -
##     de to var rett og slett ulike modeller. Nå brukes ALLTID
##     hovedmodell_slope, med T (trend-utfasing) implisitt = 0 for
##     standardvisningen.
##
## Nye Y-variabler legges til i Y_VARIABLER-listen under - resten av appen
## (kommuneutvalg, plott, tabell, nedlasting) er felles og variabel-agnostisk.
##
## Alle variabler har i tillegg en egen, reaktiv framskrivningsvariant
## (framskriv_trend()) basert på den respektive hovedmodell_slope (tilfeldig
## helning på demensandel per kommune, tolket som en kommunespesifikk
## trend/politikk), med en brukerstyrt utfasing av denne trenden over T år -
## se egen kommentarblokk ved framskriv_trend() under. Skrus på med en
## avkryssingsboks i appen (av som standard). IKKE bootstrap-testet ennå
## (usikkerhetsbånd vises derfor ikke når denne varianten er valgt).
##
## Glidende overgang (observert siste år -> modell) strekkes nå over HELE
## framskrivningsperioden (2026-2050), ikke bare de første 10 årene - se
## framskriv_y1.R for begrunnelse (unngår et kink i grafen ved gammelt
## brytpunkt i 2036).
##
## Planlagt videre arbeid (se også "Om"-fanen i appen):
##   - Bootstrap-usikkerhet for trend-varianten.
##   - Flere Y-variabler.
##   - Valg av befolkningsscenario: LLML/HHMH (SSB) og Telemarksforsking,
##     i tillegg til hovedalternativet MMMM.
##   - Estimere TILBUD (ikke bare etterspørsel) av sykepleiere, med
##     metodikk fra SSB-rapporten RAPP 2026/18 (se lenke i "Om"-fanen).

library(shiny)
library(bslib)
library(httr2)
library(dplyr)
library(plotly)
library(DT)
library(lme4)

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
## `modell_slope_fil` peker til den tilfeldig-helning-varianten av modellen
## (se modell_<variabel>.R) - brukes av framskriv_trend() til den
## kommunespesifikke trend-varianten (se lenger ned).
Y_VARIABLER <- list(
  Y_1 = list(
    navn = "Etterspørsel etter hjemmetjenester (brukere)",
    historisk_kolonne = "Y_1_a_ialt",
    framskrevet_fil = "framskrevet_y1.rds",
    framskrevet_kolonne = "y1_predikert",
    usikkerhet_fil = "framskrevet_y1_usikkerhet.rds",
    nedre_kolonne = "y1_nedre",
    ovre_kolonne = "y1_ovre",
    modell_slope_fil = "modell_y1_hovedmodell_slope.rds",
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
    modell_slope_fil = "modell_y2s_hovedmodell_slope.rds",
    flagg_2010 = FALSE
  ),
  Y_5 = list(
    navn = "Etterspørsel etter sykepleier (avtalte årsverk)",
    historisk_kolonne = "Y_5_ialt",
    framskrevet_fil = "framskrevet_y5.rds",
    framskrevet_kolonne = "y5_predikert",
    usikkerhet_fil = "framskrevet_y5_usikkerhet.rds",
    nedre_kolonne = "y5_nedre",
    ovre_kolonne = "y5_ovre",
    modell_slope_fil = "modell_y5_hovedmodell_slope.rds",
    ## Alternativ estimering vist i SAMME plott (uten usikkerhetsbånd) - se
    ## modell_y5_poisson.R / framskriv_y5_poisson.R.
    alternativ = list(
      framskrevet_fil = "framskrevet_y5_poisson.rds",
      framskrevet_kolonne = "y5p_predikert",
      modell_slope_fil = "modell_y5p_hovedmodell_slope.rds"
    ),
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

## ============================================================================
## Kommunespesifikk trend (tilfeldig helning på demensandel) - alle variabler
## ============================================================================
## `hovedmodell_slope` (se modell_<variabel>.R) har - i tillegg til det
## tilfeldige kommuneintercepet som brukes i hovedmodellen - en TILFELDIG
## HELNING per kommune på demensandel. Denne tolkes her som en
## kommunespesifikk TREND (f.eks. lokal politikk) i hvor sterkt
## etterspørselen utvikler seg med demensandelen, utover det nasjonale
## gjennomsnittet.
##
## Denne trenden er IKKE nødvendigvis noe man vil anta varer resten av
## framskrivningsperioden (25 år) - den fases derfor lineært UT over T år,
## valgt av brukeren i appen (T = 0-10): 100 % effekt i 2026, avtagende til
## 0 % ved år (2026 + T). T = 0 gir ingen trendeffekt i det hele tatt.
## Dette er en ANNEN, uavhengig utfasing enn glidende-overgang-mekanismen
## under (som blander inn observert siste år) - begge virker samtidig.
##
## ANKRING VED SISTE OBSERVERTE (2025) NIVÅ, IKKE VED ABSOLUTT NULL:
## intercept og helning er sterkt korrelerte i disse modellene (estimert
## SOM ET PAR). Å bare nulle ut helningens bidrag ved absolutt
## demensandel = 0, mens kommunens fulle tilfeldige intercept beholdes
## uendret, gir et inkonsistent "halvt par" og eksploderende verdier
## (testet og bekreftet). Løsningen er å ankre utfasingen ved kommunens
## SISTE OBSERVERTE (2025) demensandel: `intercept_prime` bygger inn hele
## kommunens nivå VED ANKERET - denne delen fases ALDRI ut. Det som fases
## ut over T år er BARE den tilfeldige helningens bidrag til ENDRINGEN i
## demensandel UTOVER ankeret (dvs. framtidig vekst), som i seg selv er en
## liten størrelse - dette unngår eksplosjonen og gir en glatt overgang.
##
## NB: bootstrap-usikkerhet er IKKE beregnet for denne varianten ennå -
## ingen usikkerhetsbånd vises når trend-effekt er valgt.
modell_slope_liste <- lapply(Y_VARIABLER, function(v) {
  readRDS(file.path(utmappe, v$modell_slope_fil))
})

demensandel_anker <- historisk |>
  filter(år == 2025) |>
  transmute(kommunenr_2024, demensandel_anker = demensandel)

siste_observert_liste <- lapply(Y_VARIABLER, function(v) {
  historisk |>
    filter(år == 2025) |>
    transmute(kommunenr_2024, observert = .data[[v$historisk_kolonne]])
})

## Befolkning/demensandel for framskrivingsårene er uavhengig av hvilken
## modellvariant som brukes - gjenbruk derfor det som allerede er beregnet
## for hovedmodellen (framskrevet_liste), i stedet for å hente på nytt.
framtidsdata_liste <- list()
for (id in names(Y_VARIABLER)) {
  framtidsdata_liste[[id]] <- framskrevet_liste[[id]] |>
    select(kommunenr_2024, år, folk_ialt, demensandel) |>
    distinct() |>
    left_join(demensandel_anker, by = "kommunenr_2024")
}

## ---- Alternative estimeringer (kun vist i plottet, uten usikkerhetsbånd) ----
## Samme oppsett som over: populasjon/demensandel/anker og siste observerte
## verdi er felles med hovedvarianten av samme variabel.
alternativ_id <- Filter(function(id) !is.null(Y_VARIABLER[[id]]$alternativ), names(Y_VARIABLER))
alternativ_framskrevet_liste <- list()
alternativ_modell_liste <- list()
for (id in alternativ_id) {
  alt <- Y_VARIABLER[[id]]$alternativ
  alternativ_framskrevet_liste[[id]] <- readRDS(file.path(utmappe, alt$framskrevet_fil))
  alternativ_modell_liste[[id]] <- readRDS(file.path(utmappe, alt$modell_slope_fil))
}

framskriv_trend <- function(variabel_id, T, alternativ = FALSE) {
  v <- Y_VARIABLER[[variabel_id]]
  modell_slope <- if (alternativ) alternativ_modell_liste[[variabel_id]] else modell_slope_liste[[variabel_id]]
  verdi_kolonne <- if (alternativ) v$alternativ$framskrevet_kolonne else v$framskrevet_kolonne
  d0 <- framtidsdata_liste[[variabel_id]]
  siste_observert <- siste_observert_liste[[variabel_id]]

  faste <- fixef(modell_slope)
  intercept <- faste[["(Intercept)"]]
  demens_koef <- faste[["demensandel"]]
  aar_koef <- faste[grepl("^år_f", names(faste))]
  aar_effekt_framskrevet <- mean(aar_koef)

  re <- ranef(modell_slope)$kommunenr_2024
  d <- d0[as.character(d0$kommunenr_2024) %in% rownames(re), ]

  u_intercept <- re[as.character(d$kommunenr_2024), "(Intercept)"]
  u_slope <- re[as.character(d$kommunenr_2024), "demensandel"]

  startaar <- min(d$år)
  sluttaar <- max(d$år)

  # Lineær utfasing av trenden: 100 % i startåret -> 0 % ved (startår + T).
  aar_siden_start <- d$år - startaar
  vekt_trend <- if (T <= 0) rep(0, nrow(d)) else pmax(0, (T - aar_siden_start) / T)

  intercept_prime <- intercept + u_intercept + (demens_koef + u_slope) * d$demensandel_anker
  delta_demensandel <- d$demensandel - d$demensandel_anker

  lin_pred <- intercept_prime + aar_effekt_framskrevet +
    (demens_koef + vekt_trend * u_slope) * delta_demensandel +
    log(d$folk_ialt)

  d[[verdi_kolonne]] <- as.numeric(exp(lin_pred))

  # Glidende overgang (observert siste år -> modell), strukket over HELE
  # framskrivningsperioden - samme prinsipp/begrunnelse som framskriv_y1.R.
  m <- merge(d, siste_observert, by = "kommunenr_2024", all.x = TRUE)
  vekt_obs <- pmax(0, 0.9 * (sluttaar - m$år) / (sluttaar - startaar))
  modell_kolonne <- paste0(verdi_kolonne, "_modell")
  m[[modell_kolonne]] <- m[[verdi_kolonne]]
  m[[verdi_kolonne]] <- ifelse(is.na(m$observert), m[[modell_kolonne]],
                                vekt_obs * m$observert + (1 - vekt_obs) * m[[modell_kolonne]])
  m$observert <- NULL
  m
}

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
## `framskrevet_override`: brukes for Y_1 sin trend-variant (se over) - en
## allerede beregnet data.frame for ALLE kommuner, med samme kolonner som
## framskrevet_liste sine oppføringer. Når denne er satt, finnes det ikke
## noe usikkerhetsbånd (bootstrap er ikke kjørt for denne varianten).
## `alternativ_override`: tilsvarende trend-variant av den alternative
## estimeringen (kun for variabler med `alternativ` i Y_VARIABLER); hvis NULL
## brukes den ferdigberegnede alternative framskrivningen (T = 0).
lag_tidsserie <- function(kommune, variabel_id, framskrevet_override = NULL,
                          alternativ_override = NULL) {
  v <- Y_VARIABLER[[variabel_id]]
  framskrevet <- if (!is.null(framskrevet_override)) framskrevet_override else framskrevet_liste[[variabel_id]]
  usikkerhet <- if (!is.null(framskrevet_override)) NULL else usikkerhet_liste[[variabel_id]]

  obs <- historisk |>
    filter(kommunenr_2024 == kommune) |>
    transmute(år, kilde = "Observert", verdi = .data[[v$historisk_kolonne]],
              folk_ialt, demensandel, nedre = NA_real_, ovre = NA_real_)
  proj <- framskrevet |>
    filter(kommunenr_2024 == kommune) |>
    transmute(år, kilde = "Framskrevet (MMMM)", verdi = .data[[v$framskrevet_kolonne]],
              folk_ialt, demensandel)
  proj <- if (!is.null(usikkerhet)) {
    proj |> left_join(
      usikkerhet |>
        filter(kommunenr_2024 == kommune) |>
        transmute(år, nedre = .data[[v$nedre_kolonne]], ovre = .data[[v$ovre_kolonne]]),
      by = "år"
    )
  } else {
    proj |> mutate(nedre = NA_real_, ovre = NA_real_)
  }

  alt <- NULL
  if (!is.null(v$alternativ)) {
    alt_data <- if (!is.null(alternativ_override)) alternativ_override else alternativ_framskrevet_liste[[variabel_id]]
    alt <- alt_data |>
      filter(kommunenr_2024 == kommune) |>
      transmute(år, kilde = "Alternativ modell (MMMM)",
                verdi = .data[[v$alternativ$framskrevet_kolonne]],
                folk_ialt, demensandel, nedre = NA_real_, ovre = NA_real_)
  }
  bind_rows(obs, proj, alt) |> arrange(år)
}

## ============================================================================
## UI
## ============================================================================
ui <- page_sidebar(
  title = "Framskrivningsmodellen Fram - Resultater",
  theme = bs_theme(version = 5, bootswatch = "flatly"),

  sidebar = sidebar(
    width = 340,
    selectInput("variabel", "Variabel",
                choices = setNames(names(Y_VARIABLER), vapply(Y_VARIABLER, `[[`, "", "navn"))),
    selectizeInput("kommune", "Kommune", choices = kommune_valg, selected = KOMMUNE_STANDARD),
    checkboxInput("bruk_trend", "Bruk kommunens egen trend", value = FALSE),
    conditionalPanel(
      condition = "input.bruk_trend == true",
      sliderInput("trend_T", "Trenden fases ut over (år)",
                  min = 0, max = 10, value = 5, step = 1),
      tags$small(class = "text-muted",
                  "Styrer hvor lenge kommunens egen historiske utvikling ",
                  "påvirker framskrivningen, før den går over til det ",
                  "nasjonale gjennomsnittet. 0 år = ingen effekt. Vises uten ",
                  "usikkerhetsintervall.")
    ),
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
        p("Viser observerte tall 2007-2025 og en framskrivning 2026-2050 for valgt variabel og kommune, basert på SSBs offisielle statistikk og befolkningsframskrivninger. Det skraverte feltet rundt framskrivningen viser et 95 % usikkerhetsintervall, der det er beregnet."),
        p("Du kan også slå på \"Bruk kommunens egen trend\" for å justere hvor lenge kommunens egen historiske utvikling skal påvirke framskrivningen, før den går over til det nasjonale gjennomsnittet."),
        h5("Kjente begrensninger"),
        tags$ul(
          tags$li("For enkelte variabler er ett eller flere år utelatt fra beregningsgrunnlaget pga. datakvalitet - merkes i plottet der det er relevant."),
          tags$li("For enkelte variabler finnes historiske tall bare for en del av perioden 2007-2025 - vises som et hull i den historiske linjen."),
          tags$li("Kun ett befolkningsscenario er beregnet så langt."),
          tags$li("Usikkerhetsintervallet fanger opp estimeringsusikkerhet i modellen, ikke usikkerhet i selve befolkningsframskrivningen eller i valg av modelltype."),
          tags$li("Usikkerhetsintervall er ikke beregnet når kommunens egen trend er slått på.")
        ),
        h5("Planlagt videre arbeid"),
        tags$ol(
          tags$li("Eventuelt flere variabler."),
          tags$li("Valg av flere befolkningsscenarioer."),
          tags$li("Nøyere gjennomgang av datagrunnlag for å luke ut feilregistreringer"), 
          tags$li("Estimere tilbud (ikke bare etterspørsel) av sykepleiere, med metodikk fra ",
            tags$a(
              href = "https://www.ssb.no/helse/helsetjenester/artikler/behov-for-og-tilgang-pa-arbeidskraft-i-offentlig-helse-og-omsorg-fremover/_/attachment/inline/e35491e6-e7b1-43f0-82f9-726b8b21574e:2475fafc0fdb77314f7751654ffea53725e30f2e/RAPP2026-18.pdf",
              target = "_blank", rel = "noopener noreferrer",
              "SSBs rapport RAPP 2026/18"
            ),
            ". Inkludere LLML- og HHMH-befolkningsframskrivninger fra SSB, samt befolkningsframskrivninger fra Telemarksforsking, som alternativ til hovedalternativet MMMM."
          )
        ),
        h5("Datakilder"),
        p("All historikk og framskrivning bygger på offentlig tilgjengelig statistikk fra SSBs statistikkbank (data.ssb.no):"),
        tags$ul(
          tags$li(tags$b("04686, 12292"), " - kommunale omsorgstjenester (mottakere av hjemmetjenester, heldøgnsbolig, tildelte timer/uke)"),
          tags$li(tags$b("11645"), " - mottakere av institusjonstjenester (langtidsopphold)"),
          tags$li(tags$b("11924, 14534"), " - sykepleiere, avtalte årsverk"),
          tags$li(tags$b("07459"), " - befolkning etter kommune, alder og kjønn"),
          tags$li(tags$b("12882"), " - SSBs befolkningsframskrivninger")
        )
      )
    )
  )
)

## ============================================================================
## Server
## ============================================================================
server <- function(input, output, session) {

  # Rå trend-framskrivning for ALLE kommuner (billig å regne om - ingen
  # modell-refit, bare lineær algebra på en allerede estimert modell) for
  # valgt variabel. Filtreres til valgt kommune inne i lag_tidsserie().
  framskrevet_trend_reaktiv <- reactive({
    req(input$variabel, input$trend_T)
    framskriv_trend(input$variabel, input$trend_T)
  })

  tidsserie <- reactive({
    req(input$kommune, input$variabel)
    override <- if (isTRUE(input$bruk_trend)) framskrevet_trend_reaktiv() else NULL
    alt_override <- if (isTRUE(input$bruk_trend) && !is.null(Y_VARIABLER[[input$variabel]]$alternativ)) {
      framskriv_trend(input$variabel, input$trend_T, alternativ = TRUE)
    } else NULL
    lag_tidsserie(input$kommune, input$variabel, framskrevet_override = override,
                  alternativ_override = alt_override)
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
      "Alternativ modell (MMMM)" = "#009E73",
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
        line = list(color = farger[[g]], dash = if (sub$kilde[1] == "Framskrevet (MMMM)") "dash" else if (sub$kilde[1] == "Alternativ modell (MMMM)") "dot" else "solid"),
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
