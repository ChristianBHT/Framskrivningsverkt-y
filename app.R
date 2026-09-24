## Kommuneframsyn - resultatvisning og verktøy
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
## Kommunens egne tall: brukeren kan skrive inn egen verdi for 2025 for
## Y_1, Y_2* og Y_5 (sidepanelet). Den erstatter SSBs 2025-tall som ANKER i den
## glidende overgangen - se juster_anker() og beslutningslogg pkt. 21.
##
## Planlagt videre arbeid (se også "Om"-fanen i appen):
##   - Bootstrap-usikkerhet for trend-varianten.
##   - Flere Y-variabler.
##   - Valg av befolkningsscenario: LLML/HHMH (SSB) og Telemarksforskning,
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
library(commonmark)

utmappe <- file.path("data", "ssb")

## ---- Profil: logo, lenke og bunntekst -------------------------------------
## Logoen ligger i resources/ (ikke www/) og serveres derfra via
## addResourcePath. Husk at resources/telemarks-logo.png må med i
## opplastingslisten i skript/deploy_shinyapps.R.
addResourcePath("resources", "resources")
TF_URL <- "https://telemarksforsking.no/"
TF_LOGO <- "resources/telemarks-logo.png"

## ---- Fargepalett (avledet av Telemarksforsknings logo) ----------------------
## Logoen har nøyaktig to farger (målt i pikslene): petrolblå #004C66 og
## rav/oransje #D17E12. Resten av paletten er avledet av dem. Alle farger i appen
## (tema, plott, CSS) skal hentes herfra, ikke skrives inn på nytt.
## Kontrast mot hvit (WCAG): petrol 9,4:1 (AAA), mørk oransje 5,4:1 og grå
## 5,3:1 (AA for tekst); rå oransje bare 3,1:1, så den brukes til grafikk og
## aksenter, ikke til liten tekst eller som bakgrunn for hvit tekst.
## Petrol og oransje skilles tydelig også ved fargesvakhet (avstand i Lab 80-97
## for alle simulerte typer); tredjeserien (skifergrå) er valgt for å være
## trygg og nøytral ("alternativ").
PALETT <- list(
  petrol        = "#004C66",  # logo, hovedfarge (knapper, lenker, topplinje, observert)
  petrol_mork   = "#00374A",  # hover/aktiv
  oransje       = "#D17E12",  # logo, aksent (framskrevet, markeringer)
  oransje_tekst = "#9C5A00",  # oransje som tekstfarge (kontrast 5,4:1)
  tekst         = "#1E2A30",  # brødtekst
  graa          = "#5C6F78",  # dempet tekst, sekundærfarge
  alternativ    = "#6B7F88",  # tredje dataserie (f.eks. stordriftsanalysen)
  flate         = "#F2F6F7",  # svak petrol-tone til bakgrunnsflater
  flate_mork    = "#E4ECEF",  # tabellhoder, rammer
  suksess       = "#2F7D5B",
  info          = "#2B7A99",
  feil          = "#B3261E"
)
hex_rgba <- function(hex, alpha) {
  v <- col2rgb(hex)
  sprintf("rgba(%d,%d,%d,%s)", v[1], v[2], v[3], alpha)
}

## Navn. APP_NAVN er navnet på HELE verktøyet/plattformen (vises i topplinjen
## og på startsiden) - foreløpig arbeidstittel, endres her ett sted.
## MODELL_NAVN er navnet på framskrivningsmodellen, og brukes BARE som navn på
## fanen med framskrivningene.
APP_NAVN <- "Kommuneframsyn"
APP_UNDERTITTEL <- "Nøkkeltall, framskrivninger og analyser for kommunenes helse- og omsorgstjenester"
MODELL_NAVN <- "Framskrivningsmodellen Fram"

## Bunntekst som legges nederst på HVER fane (via panel_fot() under).
## Årstallet beregnes ved oppstart, slik at det alltid er inneværende år.
## Kreditering og lisens (SSBs krav, https://www.ssb.no/diverse/lisens): navngi
## SSB (helst med lenke til ssb.no), lenke til lisensen (CC BY 4.0), og opplys
## om at tallene er endret/bearbeidet. Kommersiell bruk er tillatt.
SSB_URL <- "https://www.ssb.no/"
SSB_LISENS_SIDE <- "https://www.ssb.no/diverse/lisens"
CC_BY_URL <- "https://creativecommons.org/licenses/by/4.0/"
ekstern_lenke <- function(href, ...) {
  tags$a(href = href, target = "_blank", rel = "noopener noreferrer", ...)
}
## Samme lenke som ren HTML-tekst: brukes der lenken står midt i en setning, fordi
## tag-renderingen ellers legger et mellomrom før påfølgende komma/punktum.
html_lenke <- function(href, tekst) {
  sprintf('<a href="%s" target="_blank" rel="noopener noreferrer">%s</a>', href, tekst)
}

bunntekst <- div(
  class = "app-footer",
  div(class = "kilde-linje",
      HTML(paste0("Kilde: ", html_lenke(SSB_URL, "Statistisk sentralbyrå (SSB)"),
                  ", lisens ", html_lenke(CC_BY_URL, "CC BY 4.0"),
                  ". Tallene er bearbeidet av Telemarksforskning."))),
  div("© ", format(Sys.Date(), "%Y"), " Copyright Telemarksforskning"),
  div("Utviklet av ",
      tags$a(href = "mailto:christian.b.thorjussen@tmforsk.no",
             title = "Send e-post til christian.b.thorjussen@tmforsk.no",
             "Christian Thorjussen"))
)
panel_fot <- function(title, ...) nav_panel(title, ..., bunntekst)

## BRYTER: TRUE = fanene Teknisk dokumentasjon / Beslutningslogg / Videre
## arbeid vises (beta-versjonen til gjennomgang). Sett til FALSE i den
## ENDELIGE appen, der metodikk bare skal forklares overfladisk (kort
## beskrivelse i "Om"-fanen). Husk da også å fjerne dokumentasjon/*.md fra
## skript/deploy_shinyapps.R hvis de ikke skal lastes opp.
VIS_FULL_DOKUMENTASJON <- TRUE

## ---- Dokumentasjon vist som faner (åpen, ingen innlogging) -----------------
## Teknisk dokumentasjon, beslutningslogg og videre arbeid leses fra
## dokumentasjon/*.md ved oppstart og vises som HTML. Lenker til lokale
## .md-filer (som ikke finnes som sider i appen) fjernes til ren tekst;
## eksterne lenker åpnes i ny fane.
les_dokument <- function(filnavn) {
  sti <- file.path("dokumentasjon", filnavn)
  if (!file.exists(sti)) return(tags$p("Dokumentet er ikke tilgjengelig."))
  tekst <- readLines(sti, warn = FALSE, encoding = "UTF-8")
  Encoding(tekst) <- "UTF-8"
  html <- commonmark::markdown_html(paste(tekst, collapse = "\n"), extensions = TRUE)
  html <- gsub('<a href="[^"]*\\.md[^"]*">(.*?)</a>', "\\1", html, perl = TRUE)
  html <- gsub('<a href="(https?://)', '<a target="_blank" rel="noopener noreferrer" href="\\1',
               html, perl = TRUE)
  div(class = "dokument", HTML(html))
}
dokument_faner <- if (VIS_FULL_DOKUMENTASJON) {
  list(
    panel_fot("Teknisk dokumentasjon", br(), les_dokument("teknisk_dokumentasjon.md")),
    panel_fot("Beslutningslogg", br(), les_dokument("beslutningslogg.md")),
    panel_fot("Videre arbeid", br(), les_dokument("videre_arbeid.md"))
  )
} else list()

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
    navn = "Brukere av hjemmesykepleie",
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
    navn = "Brukere av boliger",
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
    navn = "Sykepleiere (avtalte årsverk)",
    historisk_kolonne = "Y_5_ialt",
    framskrevet_fil = "framskrevet_y5.rds",
    framskrevet_kolonne = "y5_predikert",
    usikkerhet_fil = "framskrevet_y5_usikkerhet.rds",
    nedre_kolonne = "y5_nedre",
    ovre_kolonne = "y5_ovre",
    modell_slope_fil = "modell_y5_hovedmodell_slope.rds",
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

## ---- Analyse stordriftsfordeler (resultater fra skript/modellsjekk_kvantil.R) ----
## Kompakte sammendragsfiler, én per variabel. Mangler en fil, utelates
## variabelen (og fanen viser en melding hvis ingen finnes).
stordrift <- bind_rows(lapply(names(Y_VARIABLER), function(id) {
  fil <- file.path(utmappe, paste0("modellsjekk_kvantil_", tolower(id), "_sammendrag.rds"))
  if (!file.exists(fil)) return(NULL)
  x <- readRDS(fil)
  x$sammendrag |>
    transmute(variabel = id,
              navn = { n <- sub("^Etterspørsel etter ", "", Y_VARIABLER[[id]]$navn); paste0(toupper(substr(n, 1, 1)), substring(n, 2)) },
              tau, beta = beta_pop_estimat, nedre = beta_pop_nedre95,
              ovre = beta_pop_ovre95, andel_under_1 = p_under_0, n = x$n)
}))

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

framskriv_trend <- function(variabel_id, T) {
  v <- Y_VARIABLER[[variabel_id]]
  modell_slope <- modell_slope_liste[[variabel_id]]
  verdi_kolonne <- v$framskrevet_kolonne
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

## ---- Befolkningspyramider (forhåndsberegnet av skript/lag_pyramidedata.R) ----
## SSBs tall (observert 2007-2025, framskrevet 2026-2050, hovedalternativet
## MMMM), 5-årige aldersgrupper. Ingenting regnes ut i appen ut over
## prosentandeler og summer for valgt kommune og år. Delt opp per kommune én
## gang her, slik at hvert oppslag er en enkel listeindeksering.
PYRAMIDE_NAVN <- "Befolkningspyramider"
PYRAMIDE_HIST_AR <- c(2010, 2015, 2020, 2025)
pyramide_data <- readRDS(file.path(utmappe, "befolkning_pyramide.rds"))
pyramide_liste <- split(pyramide_data, pyramide_data$kommunenr)
rm(pyramide_data)
PYRAMIDE_FRAM_AR <- sort(unique(pyramide_liste[[1]]$år[pyramide_liste[[1]]$type == "Framskrevet"]))
PYRAMIDE_REFERANSEAR <- max(PYRAMIDE_HIST_AR)
pyramide_valg <- c("Hele landet" = "0000", kommune_valg[kommune_valg %in% names(pyramide_liste)])

#' Tegner én befolkningspyramide (menn til venstre, kvinner til høyre).
#' `d`: rader for én kommune; `aar`: året som vises; `xmaks`: felles halv
#' akselengde (samme for alle pyramidene til kommunen, slik at de kan
#' sammenlignes); `prosent`: andel av kommunens befolkning i stedet for antall;
#' `referanse`: valgfritt år som tegnes som omriss bak.
pyramide_plot <- function(d, aar, xmaks, prosent = FALSE, referanse = NULL,
                          tittel = as.character(aar), liten = FALSE) {
  grupper <- levels(d$aldersgruppe)
  hent <- function(a) {
    x <- d[d$år == a, ]
    tot <- sum(x$antall)
    lag <- function(k) {
      v <- x$antall[x$kjonn == k][match(grupper, x$aldersgruppe[x$kjonn == k])]
      if (prosent) v / tot * 100 else v
    }
    list(menn = lag("Menn"), kvinner = lag("Kvinner"))
  }
  visning <- function(v) if (prosent) sprintf("%.1f %%", v) else format(round(v), big.mark = " ")
  n <- hent(aar)

  p <- plot_ly() |>
    add_bars(x = -n$menn, y = grupper, orientation = "h", name = "Menn",
             marker = list(color = PALETT$petrol),
             text = sprintf("Menn %s år: %s", grupper, visning(n$menn)), hoverinfo = "text", textposition = "none") |>
    add_bars(x = n$kvinner, y = grupper, orientation = "h", name = "Kvinner",
             marker = list(color = PALETT$oransje),
             text = sprintf("Kvinner %s år: %s", grupper, visning(n$kvinner)), hoverinfo = "text", textposition = "none")

  if (!is.null(referanse) && referanse != aar) {
    r <- hent(referanse)
    omriss <- list(color = "rgba(0,0,0,0)", line = list(color = PALETT$tekst, width = 1.5))
    p <- p |>
      add_bars(x = -r$menn, y = grupper, orientation = "h", name = paste(referanse, "(omriss)"),
               marker = omriss, hoverinfo = "skip", legendgroup = "omriss") |>
      add_bars(x = r$kvinner, y = grupper, orientation = "h", name = paste(referanse, "(omriss)"),
               marker = omriss, hoverinfo = "skip", legendgroup = "omriss", showlegend = FALSE)
  }

  # Samme akseutstrekning for små og store pyramider (aksemaks fra samme pretty()).
  tikk <- pretty(c(0, xmaks), n = 4)
  tikk <- tikk[tikk > 0]
  aksemaks <- max(tikk)
  if (liten) tikk <- aksemaks   # små pyramider: bare ytterpunktet, ellers overlapper etikettene
  tikkverdier <- c(-rev(tikk), 0, tikk)
  tikktekst <- if (prosent) paste0(abs(tikkverdier), " %") else format(abs(tikkverdier), big.mark = " ", trim = TRUE)
  skrift <- if (liten) 10 else 12

  p |> layout(
    title = list(text = tittel, font = list(size = if (liten) 14 else 16), x = 0.5),
    barmode = "overlay", bargap = 0.06,
    xaxis = list(range = c(-aksemaks, aksemaks), tickvals = tikkverdier, ticktext = tikktekst,
                 tickfont = list(size = skrift - 1), tickangle = 0, zeroline = TRUE, zerolinecolor = PALETT$graa),
    yaxis = list(categoryorder = "array", categoryarray = grupper, tickfont = list(size = skrift),
                 title = if (liten) "" else "Alder (år)"),
    showlegend = !liten,
    legend = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.12),
    margin = list(l = if (liten) 42 else 60, r = 10, t = 40, b = if (liten) 30 else 50)
  ) |> config(displayModeBar = FALSE)
}

## ---- Kommunens egne tall som anker ------------------------------------------
## Brukeren kan skrive inn kommunens egen verdi for ANKERAAR (2025) for en
## variabel. Den erstatter SSBs observerte 2025-tall som anker i den glidende
## overgangen. Overgangen er (se framskriv_*.R og usikkerhet_*.R):
##   verdi(t) = vekt(t) * anker + (1 - vekt(t)) * modell(t),
##   vekt(t)  = 0,9 * (sluttår - t) / (sluttår - startår)
## Byttes ankeret fra SSBs tall (obs) til egen verdi (egen), endres verdien
## derfor med vekt(t) * (egen - obs), og det gjelder likt for HVER bootstrap-
## trekning. Det ferdige 95 %-båndet (persentiler av glattede verdier) flyttes
## dermed nøyaktig med samme beløp, uten ny bootstrap. Båndet uttrykker
## fortsatt bare modellusikkerheten; det sier ingenting om usikkerhet i selve
## egen verdi. Mangler SSB-tall for 2025 (NA), er dagens verdi ren modell, og
## vekten brukes på (egen - modell).
ANKERAAR <- 2025
ANKER_START_ANDEL <- 0.9   # samme som START_ANDEL_OBSERVERT i skriptene
EGEN_KILDE <- paste0("Egen verdi (", ANKERAAR, ")")

juster_anker <- function(proj, obs_anker, egen) {
  startaar <- min(proj$år)
  sluttaar <- max(proj$år)
  vekt <- pmax(0, ANKER_START_ANDEL * (sluttaar - proj$år) / (sluttaar - startaar))
  referanse <- if (is.na(obs_anker)) proj$verdi else obs_anker
  skift <- vekt * (egen - referanse)
  proj$verdi <- pmax(0, proj$verdi + skift)
  proj$nedre <- pmax(0, proj$nedre + skift)
  proj$ovre <- pmax(0, proj$ovre + skift)
  proj
}

## ---- Slå sammen historikk + framskrivning til én tidsserie per kommune ----
## Variabel-agnostisk: leser kolonnenavn fra Y_VARIABLER-oppføringen for
## valgt variabel, og returnerer alltid en `verdi`-kolonne uansett hvilken
## variabel som er valgt.
## `framskrevet_override`: brukes for trend-varianten (se over) - en
## allerede beregnet data.frame for ALLE kommuner, med samme kolonner som
## framskrevet_liste sine oppføringer. Når denne er satt, finnes det ikke
## noe usikkerhetsbånd (bootstrap er ikke kjørt for denne varianten).
## `egen_verdi`: kommunens egen verdi for ANKERAAR (tall) eller NULL/NA.
lag_tidsserie <- function(kommune, variabel_id, framskrevet_override = NULL,
                          egen_verdi = NULL) {
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

  egen <- NULL
  if (!is.null(egen_verdi) && length(egen_verdi) == 1 && !is.na(egen_verdi) && nrow(proj) > 0) {
    anker_rad <- obs[obs$år == ANKERAAR, ]
    proj <- juster_anker(proj, if (nrow(anker_rad) > 0) anker_rad$verdi[1] else NA_real_, egen_verdi)
    egen <- anker_rad |> mutate(kilde = EGEN_KILDE, verdi = egen_verdi)
  }
  bind_rows(obs, proj, egen) |> arrange(år)
}

## ============================================================================
## UI
## ============================================================================
## Kort på startsiden. `status = "tilgjengelig"` gir en "Åpne"-knapp
## (`knapp_id`, håndteres i server); `status = "kommer"` er et dempet kort
## uten knapp, for verktøy som er planlagt men ikke bygget.
verktoy_kort <- function(tittel, tekst, status = c("tilgjengelig", "kommer"), knapp_id = NULL) {
  status <- match.arg(status)
  kommer <- status == "kommer"
  card(
    class = paste("verktoy-kort", if (kommer) "kommer"),
    card_body(
      div(class = "d-flex justify-content-between align-items-start gap-2",
          h5(class = "mb-0", tittel),
          span(class = paste("badge", if (kommer) "bg-secondary" else "bg-success"),
               if (kommer) "Under utvikling" else "Tilgjengelig")),
      div(class = "kort-tekst", tekst),
      if (!kommer && !is.null(knapp_id))
        actionButton(knapp_id, "Åpne", class = "btn-outline-primary btn-sm align-self-start")
    )
  )
}

## CSS med paletten satt inn ({{navn}} byttes ut med PALETT$navn). Alle farger
## kommer fra PALETT; ikke skriv inn hex-verdier direkte her.
app_css <- local({
  mal <- "
    body { color: {{tekst}}; }
    a { color: {{petrol}}; }
    a:hover { color: {{petrol_mork}}; }
    /* Topplinje: petrol med hvit tekst; logoen ligger i en hvit boks */
    .bslib-page-title, .navbar { background-color: {{petrol}} !important; color: #fff !important; }
    .bslib-page-title a, .navbar a { color: #fff; }
    .header-logo { height: 46px; background: #fff; padding: 3px 6px; border-radius: 4px; }
    /* Faner: aktiv fane markeres med oransje strek (logofargen), tekst i petrol */
    .nav-tabs .nav-link { color: {{petrol}}; }
    .nav-tabs .nav-link:hover { color: {{petrol_mork}}; border-color: {{flate_mork}}; }
    .nav-tabs .nav-link.active { color: {{petrol_mork}}; font-weight: 600;
                                 border-top: 3px solid {{oransje}}; }
    .btn-outline-primary { color: {{petrol}}; border-color: {{petrol}}; }
    .btn-outline-primary:hover { background-color: {{petrol}}; border-color: {{petrol}}; color: #fff; }
    .text-muted { color: {{graa}} !important; }
    .dokument { max-width: 980px; line-height: 1.5; }
    .dokument table { border-collapse: collapse; margin: 0.8em 0; display: block; overflow-x: auto; }
    .dokument th, .dokument td { border: 1px solid {{flate_mork}}; padding: 4px 8px; vertical-align: top; }
    .dokument th { background: {{flate_mork}}; }
    .dokument pre { background: {{flate}}; padding: 8px 10px; overflow-x: auto; }
    .dokument code { font-size: 0.9em; color: {{oransje_tekst}}; }
    .dokument h1 { font-size: 1.6em; margin-top: 0; color: {{petrol}}; }
    .dokument h2 { font-size: 1.3em; margin-top: 1.6em; color: {{petrol}}; }
    .dokument h3 { font-size: 1.1em; color: {{petrol}}; }
    .app-footer { margin-top: 2.5rem; padding: 0.9rem 0; border-top: 1px solid {{flate_mork}};
                  font-size: 0.85rem; color: {{graa}}; text-align: center; }
    .app-footer a { color: inherit; text-decoration: underline; }
    .app-footer .kilde-linje { margin-bottom: 0.25rem; }
    .start { max-width: 1000px; margin: 0 auto; padding-top: 1rem; }
    .start-hero { text-align: center; margin-bottom: 1.5rem; }
    .start-logo { width: 170px; max-width: 50%; margin-bottom: 0.8rem; }
    .start-hero h2 { margin-bottom: 0.4rem; color: {{petrol}}; }
    .start-hero .undertittel { font-size: 1.15rem; color: {{tekst}}; max-width: 720px; margin: 0 auto 0.8rem; }
    .start h4.seksjon { margin: 1.8rem 0 0.8rem; color: {{petrol}};
                        border-bottom: 2px solid {{oransje}}; padding-bottom: 0.3rem; display: inline-block; }
    .verktoy-kort { height: 100%; border-color: {{flate_mork}}; }
    .verktoy-kort h5 { color: {{petrol}}; min-width: 0; }
    .verktoy-kort .badge { flex-shrink: 0; }
    .verktoy-kort .card-body { display: flex; flex-direction: column; gap: 0.5rem; }
    .verktoy-kort .kort-tekst { flex-grow: 1; color: {{tekst}}; font-size: 0.95rem; }
    .verktoy-kort.kommer { background: {{flate}}; border-style: dashed; }
    .verktoy-kort.kommer h5 { color: {{graa}}; }
    .start .tf-boks { background: {{flate}}; border-left: 4px solid {{oransje}};
                      padding: 1rem 1.25rem; margin: 2rem 0 0; }
  "
  for (n in names(PALETT)) mal <- gsub(paste0("{{", n, "}}"), PALETT[[n]], mal, fixed = TRUE)
  mal
})

ui <- page_sidebar(
  title = div(
    class = "d-flex align-items-center gap-3",
    tags$a(href = TF_URL, target = "_blank", rel = "noopener noreferrer",
           title = "Telemarksforskning",
           tags$img(src = TF_LOGO, alt = "Telemarksforskning", class = "header-logo")),
    APP_NAVN
  ),
  window_title = APP_NAVN,
  theme = bs_theme(
    version = 5, bootswatch = "flatly",
    primary = PALETT$petrol, secondary = PALETT$graa,
    success = PALETT$suksess, info = PALETT$info,
    warning = PALETT$oransje, danger = PALETT$feil,
    bg = "#FFFFFF", fg = PALETT$tekst,
    "link-color" = PALETT$petrol, "link-hover-color" = PALETT$petrol_mork
  ),

  sidebar = sidebar(
    id = "sidepanel",
    open = FALSE,   # Start-fanen er valgt først; åpnes på framskrivnings-/datatabellfanen
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
    div(class = "egne-tall",
      h6("Kommunens egne tall (valgfritt)"),
      tags$small(class = "text-muted d-block mb-2",
        sprintf("Skriv inn kommunens egen verdi for %d. Tallet brukes i stedet for SSBs tall som utgangspunkt for framskrivningen.", ANKERAAR)),
      numericInput("egen_Y_1", "Brukere av hjemmesykepleie", value = NA, min = 0, step = 1),
      numericInput("egen_Y_2_stjerne", "Brukere av boliger", value = NA, min = 0, step = 1),
      numericInput("egen_Y_5", "Sykepleiere (avtalte årsverk)", value = NA, min = 0, step = 0.1),
      uiOutput("egne_tall_hint"),
      actionButton("egne_nullstill", "Nullstill egne tall", class = "btn-outline-secondary btn-sm")
    ),
    tags$hr(),
    tags$small(
      class = "text-muted",
      "Historikk: observerte SSB-tall 2007-2025. Framskrivning: modellbasert ",
      "2026-2050 (SSBs hovedalternativ MMMM)."
    )
  ),

  tags$head(tags$style(HTML(app_css))),

  do.call(navset_tab, c(list(
    id = "hovedfaner",
    panel_fot("Start",
      div(class = "start",
        div(class = "start-hero",
          tags$img(src = TF_LOGO, alt = "Telemarksforskning", class = "start-logo"),
          h2(APP_NAVN),
          p(class = "undertittel", APP_UNDERTITTEL),
          p(class = "text-muted mb-0",
            "Et samlet verktøy som skal gi kommunene en ressurs i planleggingen: flere nøkkeltall, verktøy og modeller kommer fortløpende. Beta-versjon under utvikling.")
        ),

        h4(class = "seksjon", "Tilgjengelig nå"),
        layout_column_wrap(
          width = "280px",
          verktoy_kort(MODELL_NAVN,
                       "Framskriver antall brukere av hjemmesykepleie og boliger og etterspørselen etter sykepleiere (avtalte årsverk) per kommune fram til 2050, med usikkerhetsintervall.",
                       knapp_id = "gaa_til_framskriving"),
          verktoy_kort("Analyse stordriftsfordeler",
                       "Undersøker om større kommuner bruker mindre tjenester per innbygger enn små.",
                       knapp_id = "gaa_til_stordrift"),
          verktoy_kort(PYRAMIDE_NAVN,
                       "Hvordan alderssammensetningen i kommunen har endret seg siden 2010 og endrer seg fram mot 2050.",
                       knapp_id = "gaa_til_pyramider")
        ),

        h4(class = "seksjon", "Under utvikling"),
        layout_column_wrap(
          width = "280px",
          verktoy_kort("Nøkkeltall (KPI)",
                       "Sammendrag av nivå, vekst og bruk per innbygger for din kommune, sammenlignet med andre.",
                       status = "kommer"),
          verktoy_kort("Tilbud av helsepersonell",
                       "Framskriving av tilbudet av sykepleiere og gap mot etterspørselen.",
                       status = "kommer"),
          verktoy_kort("Flere modeller og verktøy",
                       "Flere tjenester, befolkningsscenarier og nøkkeltall som kan brukes i kommunenes planarbeid.",
                       status = "kommer")
        ),

        div(class = "tf-boks",
          p("Stiftelsen Telemarksforskning er et selvstendig samfunnsvitenskapelig forskingsinstitutt i Bø i Telemark. Vår visjon er å produsere «kunnskap som brukes i samfunnet»."),
          p(class = "mb-0",
            tags$a(href = TF_URL, target = "_blank", rel = "noopener noreferrer",
                   "telemarksforsking.no"))
        )
      )
    ),
    panel_fot(MODELL_NAVN,
      br(),
      h4(MODELL_NAVN),
      uiOutput("egen_merknad"),
      plotlyOutput("plot_verdi", height = "480px")
    ),
    panel_fot(PYRAMIDE_NAVN,
      br(),
      h4(PYRAMIDE_NAVN),
      layout_column_wrap(
        width = "230px",
        selectizeInput("pyr_kommune", "Kommune", choices = pyramide_valg,
                       selected = if (KOMMUNE_STANDARD %in% pyramide_valg) KOMMUNE_STANDARD else pyramide_valg[[1]]),
        sliderInput("pyr_aar", "Framskrevet år", min = min(PYRAMIDE_FRAM_AR), max = max(PYRAMIDE_FRAM_AR),
                    value = 2040, step = 1, sep = "", animate = TRUE),
        div(
          checkboxInput("pyr_prosent", "Vis som andel av befolkningen (%)", value = FALSE),
          checkboxInput("pyr_omriss", sprintf("Vis %d som omriss i framskrivningen", PYRAMIDE_REFERANSEAR), value = TRUE)
        )
      ),
      h5(class = "mt-3", "Historikk"),
      do.call(layout_column_wrap, c(
        list(width = "200px"),
        lapply(PYRAMIDE_HIST_AR, function(a) plotlyOutput(paste0("pyr_hist_", a), height = "340px"))
      )),
      h5(class = "mt-4", "Framskrivning"),
      uiOutput("pyr_nokkeltall"),
      plotlyOutput("pyr_fram", height = "560px"),
      tags$small(class = "text-muted",
        "Historiske pyramider viser SSBs befolkningstall (1. januar). Framskrivningen er SSBs befolkningsframskrivning, hovedalternativet (MMMM). Alle pyramidene til en kommune har samme akse, slik at de kan sammenlignes direkte. Haram er ikke med, fordi SSBs framskrivning mangler for kommunen.")
    ),
    panel_fot("Datatabell",
      br(),
      downloadButton("last_ned", "Last ned CSV"),
      br(), br(),
      DTOutput("tabell")
    ),
    panel_fot("Om",
      br(),
      div(
        h4("Om denne visningen"),
        p("Viser observerte tall 2007-2025 og en framskrivning 2026-2050 for valgt variabel og kommune, basert på SSBs offisielle statistikk og befolkningsframskrivninger. Det skraverte feltet rundt framskrivningen viser et 95 % usikkerhetsintervall, der det er beregnet."),
        p("Du kan også slå på \"Bruk kommunens egen trend\" for å justere hvor lenge kommunens egen historiske utvikling skal påvirke framskrivningen, før den går over til det nasjonale gjennomsnittet."),
        p("Under \"Kommunens egne tall\" i sidepanelet kan du skrive inn kommunens egen verdi for 2025 for brukere av hjemmesykepleie, brukere av boliger og sykepleiere. Tallet erstatter da SSBs tall som utgangspunkt for framskrivningen. Egne tall lagres ikke, og forsvinner når du laster siden på nytt."),
        h5("Kort om metoden"),
        p("Framskrivningen bygger på statistiske modeller som kobler kommunens historiske bruk av tjenestene til folketall og andelen eldre med økt behov, estimert på SSB-tall for 2007-2025. Modellene brukes sammen med SSBs befolkningsframskrivning til å beregne forventet etterspørsel fram til 2050, og det siste observerte året brukes som utgangspunkt slik at framskrivningen henger sammen med dagens nivå."),
        h5("Kjente begrensninger"),
        tags$ul(
          tags$li("For enkelte variabler er ett eller flere år utelatt fra beregningsgrunnlaget pga. datakvalitet - merkes i plottet der det er relevant."),
          tags$li("For enkelte variabler finnes historiske tall bare for en del av perioden 2007-2025 - vises som et hull i den historiske linjen."),
          tags$li("Kun ett befolkningsscenario er beregnet så langt."),
          tags$li("Usikkerhetsintervallet fanger opp estimeringsusikkerhet i modellen, ikke usikkerhet i selve befolkningsframskrivningen eller i valg av modelltype."),
          tags$li("Usikkerhetsintervall er ikke beregnet når kommunens egen trend er slått på."),
          tags$li("Når du har lagt inn egne tall, flyttes usikkerhetsintervallet med framskrivningen, men det sier ikke noe om usikkerhet i tallet du har lagt inn.")
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
            ". Inkludere LLML- og HHMH-befolkningsframskrivninger fra SSB, samt befolkningsframskrivninger fra Telemarksforskning, som alternativ til hovedalternativet MMMM."
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
        ),
        h5("Kreditering og lisens"),
        p(HTML(paste0("Statistikken er hentet fra ", html_lenke(SSB_URL, "Statistisk sentralbyrå (SSB)"),
          " og brukes under lisensen ", html_lenke(CC_BY_URL, "Creative Commons Attribution 4.0 International (CC BY 4.0)"),
          ", som også tillater kommersiell bruk. Se ", html_lenke(SSB_LISENS_SIDE, "SSBs lisensvilkår"), "."))),
        p(tags$b("Endringer: "), "SSBs tall er bearbeidet av Telemarksforskning. Historiske tall er samlet til dagens kommunestruktur, og andel eldre med økt behov, framskrivninger og usikkerhetsintervall er egne beregninger. Framskrivningene av etterspørselen er ikke SSBs tall, og SSB har ikke godkjent eller anbefalt dem. Befolkningsframskrivningen (tabell 12882) er SSBs og brukes som grunnlag."),
        if (VIS_FULL_DOKUMENTASJON) {
          p("Modellbeskrivelse, begrunnelser for valg som er tatt og arbeidsplan ligger i fanene ",
            tags$b("Teknisk dokumentasjon"), ", ", tags$b("Beslutningslogg"), " og ",
            tags$b("Videre arbeid"), ". Dette er et pågående arbeid (beta), og dokumentene beskriver også kjente feil.")
        }
      )
    ),
    panel_fot("Analyse stordriftsfordeler",
      br(),
      div(class = "dokument",
        h4("Analyse stordriftsfordeler"),
        p("Spørsmålet er om store kommuner bruker mindre tjenester per innbygger enn små, altså om det er stordriftsfordeler. Analysen ser på hvordan bruk per innbygger henger sammen med folketallet, for ulike deler av fordelingen av bruk per innbygger (kvantiler), etter at det er tatt hensyn til andelen eldre med økt behov og utviklingen over år."),
        p(tags$b("Hvordan lese figuren: "), "Tallet på den loddrette aksen (β) sier hvor mye bruken vokser når folketallet vokser. β = 1 betyr at bruken vokser like mye som folketallet (ingen stordriftsfordeler). β under 1 betyr at bruken vokser saktere enn folketallet, slik at større kommuner bruker mindre per innbygger (stordriftsfordeler); en kommune med 10 % flere innbyggere har da omtrent β × 10 % høyere bruk. Vertikale streker viser 95 % usikkerhetsintervall."),
        p(tags$b("Merk: "), "Kvantilene (0,1 til 0,9) rangerer kommunene etter bruk per innbygger, ikke etter størrelse. Høy kvantil (0,9) betyr kommuner med høy bruk per innbygger, uavhengig av hvor store de er."),
        plotlyOutput("plot_stordrift", height = "420px"),
        br(),
        DTOutput("tabell_stordrift"),
        br(),
        tags$small(class = "text-muted",
          "Analysen sammenligner kommuner med hverandre og sier lite om utvikling over tid i én og samme kommune. Andre forskjeller mellom kommuner er ikke kontrollert for, så resultatet viser en sammenheng, ikke nødvendigvis en årsak. Usikkerheten er beregnet ved gjentatt trekking av kommuner (100 trekk).")
      )
    )
  ), dokument_faner))
)

## ============================================================================
## Server
## ============================================================================
server <- function(input, output, session) {

  # Startsiden: knapp til framskrivningene.
  observeEvent(input$gaa_til_framskriving, {
    nav_select("hovedfaner", MODELL_NAVN)
  })
  observeEvent(input$gaa_til_stordrift, {
    nav_select("hovedfaner", "Analyse stordriftsfordeler")
  })

  observeEvent(input$gaa_til_pyramider, {
    nav_select("hovedfaner", PYRAMIDE_NAVN)
  })

  # Sidepanelet (variabel/kommune/trend) er bare relevant på fanene som viser
  # tidsserien; skjules ellers (Start, Om, analyse, dokumentasjon).
  observeEvent(input$hovedfaner, {
    sidebar_toggle("sidepanel", open = input$hovedfaner %in% c(MODELL_NAVN, "Datatabell"))
  })

  # Rå trend-framskrivning for ALLE kommuner (billig å regne om - ingen
  # modell-refit, bare lineær algebra på en allerede estimert modell) for
  # valgt variabel. Filtreres til valgt kommune inne i lag_tidsserie().
  framskrevet_trend_reaktiv <- reactive({
    req(input$variabel, input$trend_T)
    framskriv_trend(input$variabel, input$trend_T)
  })

  ## Kommunens egne tall (per kommune og variabel), kun i denne økten - ingenting
  ## lagres på serveren, og tallene deles ikke mellom brukere. Verdiene ligger i
  ## en liste med nøkkel "kommunenr|variabel"; inntastingsfeltene viser alltid
  ## verdiene for valgt kommune.
  egne_tall <- reactiveVal(list())
  egen_nokkel <- function(kommune, id) paste(kommune, id, sep = "|")

  for (id in names(Y_VARIABLER)) local({
    id_ <- id
    observeEvent(input[[paste0("egen_", id_)]], {
      req(input$kommune)
      x <- input[[paste0("egen_", id_)]]
      ny <- if (is.null(x) || is.na(x) || x < 0) NULL else x
      l <- egne_tall()
      nokkel <- egen_nokkel(input$kommune, id_)
      if (!identical(l[[nokkel]], ny)) {
        l[[nokkel]] <- ny
        egne_tall(l)
      }
    }, ignoreNULL = FALSE, ignoreInit = TRUE)
  })

  # Byttes kommune, vises den nye kommunens egne tall (tomme hvis ingen).
  observeEvent(input$kommune, {
    l <- egne_tall()
    for (id in names(Y_VARIABLER)) {
      v <- l[[egen_nokkel(input$kommune, id)]]
      updateNumericInput(session, paste0("egen_", id), value = if (is.null(v)) NA else v)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$egne_nullstill, {
    l <- egne_tall()
    for (id in names(Y_VARIABLER)) {
      l[[egen_nokkel(input$kommune, id)]] <- NULL
      updateNumericInput(session, paste0("egen_", id), value = NA)
    }
    egne_tall(l)
  })

  egen_verdi_valgt <- reactive({
    req(input$kommune, input$variabel)
    egne_tall()[[egen_nokkel(input$kommune, input$variabel)]]
  })

  # SSBs 2025-tall for valgt kommune, som veiledning ved siden av feltene.
  output$egne_tall_hint <- renderUI({
    req(input$kommune)
    d <- historisk[historisk$kommunenr_2024 == input$kommune & historisk$år == ANKERAAR, ]
    if (nrow(d) == 0) return(NULL)
    verdier <- vapply(names(Y_VARIABLER), function(id) {
      x <- d[[Y_VARIABLER[[id]]$historisk_kolonne]][1]
      if (is.na(x)) "mangler" else format(round(x, 1), big.mark = " ", decimal.mark = ",")
    }, character(1))
    tags$small(class = "text-muted d-block my-2",
      sprintf("SSB %d: hjemmesykepleie %s, boliger %s, sykepleiere %s.",
              ANKERAAR, verdier[["Y_1"]], verdier[["Y_2_stjerne"]], verdier[["Y_5"]]))
  })

  output$egen_merknad <- renderUI({
    egen <- egen_verdi_valgt()
    if (is.null(egen)) return(NULL)
    d <- historisk[historisk$kommunenr_2024 == input$kommune & historisk$år == ANKERAAR, ]
    ssb <- if (nrow(d) > 0) d[[Y_VARIABLER[[input$variabel]]$historisk_kolonne]][1] else NA_real_
    tal <- function(x) format(round(x, 1), big.mark = " ", decimal.mark = ",")
    div(class = "alert alert-info py-2", paste0(
      "Framskrivningen bruker kommunens egen verdi for ", ANKERAAR, " (", tal(egen), ") som utgangspunkt",
      if (!is.na(ssb)) paste0(" i stedet for SSBs tall (", tal(ssb), ")"), ". ",
      "Effekten trappes ned og er borte i 2050. Usikkerhetsintervallet er flyttet tilsvarende og ",
      "gjelder modellusikkerhet; det sier ikke noe om usikkerhet i selve tallet du har lagt inn."))
  })

  tidsserie <- reactive({
    req(input$kommune, input$variabel)
    override <- if (isTRUE(input$bruk_trend)) framskrevet_trend_reaktiv() else NULL
    lag_tidsserie(input$kommune, input$variabel, framskrevet_override = override,
                  egen_verdi = egen_verdi_valgt())
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
      "Observert" = PALETT$petrol,
      "Framskrevet (MMMM)" = PALETT$oransje,
      "2010 (utelatt fra modell)" = PALETT$tekst
    )
    farger[[EGEN_KILDE]] <- PALETT$tekst

    p <- plot_ly()

    # Usikkerhetsbånd (95 % bootstrap-konfidensintervall) - kun for de
    # framskrevne årene, tegnes FØR linjene slik at linjene vises over båndet.
    ki <- d[d$kilde == "Framskrevet (MMMM)" & !is.na(d$nedre) & !is.na(d$ovre), ]
    if (nrow(ki) > 0) {
      p <- p |> add_ribbons(
        data = ki, x = ~år, ymin = ~nedre, ymax = ~ovre,
        name = "95 % konfidensintervall",
        line = list(width = 0), fillcolor = hex_rgba(PALETT$oransje, 0.2),
        hoverinfo = "skip"
      )
    }

    for (g in unique(d$gruppe)) {
      sub <- d[d$gruppe == g, ]
      p <- if (g == EGEN_KILDE) {
        # Kommunens egen verdi: bare en markør (ruter), ikke en linje.
        p |> add_trace(
          data = sub, x = ~år, y = ~verdi, type = "scatter", mode = "markers",
          name = g, marker = list(color = farger[[g]], symbol = "diamond", size = 11)
        )
      } else {
        p |> add_trace(
          data = sub, x = ~år, y = ~verdi, type = "scatter", mode = "lines+markers",
          name = g,
          line = list(color = farger[[g]], dash = if (sub$kilde[1] == "Framskrevet (MMMM)") "dash" else "solid"),
          marker = list(color = farger[[g]])
        )
      }
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

  output$plot_stordrift <- renderPlotly({
    validate(need(nrow(stordrift) > 0, "Analysen er ikke tilgjengelig."))
    navn <- unique(stordrift$navn)
    farger_s <- setNames(c(PALETT$petrol, PALETT$oransje, PALETT$alternativ)[seq_along(navn)], navn)
    forskyvning <- setNames(c(-0.012, 0, 0.012)[seq_along(navn)], navn)
    p <- plot_ly()
    for (n in navn) {
      d <- stordrift[stordrift$navn == n, ]
      p <- p |> add_trace(
        x = d$tau + forskyvning[[n]], y = d$beta, type = "scatter", mode = "lines+markers",
        name = n, line = list(color = farger_s[[n]]), marker = list(color = farger_s[[n]]),
        error_y = list(type = "data", symmetric = FALSE, array = d$ovre - d$beta,
                       arrayminus = d$beta - d$nedre, color = farger_s[[n]]),
        text = sprintf("Kvantil %.2f: β = %.3f [%.3f, %.3f]", d$tau, d$beta, d$nedre, d$ovre),
        hoverinfo = "text"
      )
    }
    p |> layout(
      xaxis = list(title = "Kvantil av bruk per innbygger", tickvals = sort(unique(stordrift$tau))),
      yaxis = list(title = "β (bruk vs. folketall)"),
      shapes = list(list(type = "line", xref = "paper", x0 = 0, x1 = 1, y0 = 1, y1 = 1,
                         line = list(color = "grey40", dash = "dash", width = 1))),
      legend = list(orientation = "h", y = 1.12, x = 0)
    )
  })

  output$tabell_stordrift <- renderDT({
    validate(need(nrow(stordrift) > 0, "Analysen er ikke tilgjengelig."))
    tab <- stordrift |>
      transmute(Variabel = navn, Kvantil = tau, `β` = round(beta, 3),
                `95 % intervall` = sprintf("[%.3f, %.3f]", nedre, ovre),
                `Andel trekk med β under 1` = round(andel_under_1, 2),
                `Antall kommune-år` = n)
    datatable(tab, rownames = FALSE, options = list(dom = "t", pageLength = 20, ordering = FALSE))
  })

  ## ---- Befolkningspyramider ----
  pyr_data <- reactive({
    req(input$pyr_kommune)
    d <- pyramide_liste[[input$pyr_kommune]]
    validate(need(!is.null(d), "Ingen data for valgt kommune."))
    d
  })

  # Felles akse for alle pyramidene til kommunen (største verdi over alle år,
  # 2007-2050), slik at pyramidene kan sammenlignes og aksen ikke hopper når
  # brukeren endrer år.
  pyr_xmaks <- reactive({
    d <- pyr_data()
    tot <- tapply(d$antall, d$år, sum)
    v <- if (isTRUE(input$pyr_prosent)) d$antall / tot[as.character(d$år)] * 100 else d$antall
    max(v) * 1.05
  })

  for (a in PYRAMIDE_HIST_AR) local({
    aa <- a
    output[[paste0("pyr_hist_", aa)]] <- renderPlotly({
      pyramide_plot(pyr_data(), aa, pyr_xmaks(), prosent = isTRUE(input$pyr_prosent), liten = TRUE)
    })
  })

  output$pyr_fram <- renderPlotly({
    req(input$pyr_aar)
    pyramide_plot(pyr_data(), input$pyr_aar, pyr_xmaks(), prosent = isTRUE(input$pyr_prosent),
                  referanse = if (isTRUE(input$pyr_omriss)) PYRAMIDE_REFERANSEAR,
                  tittel = sprintf("%d (framskrevet)", input$pyr_aar))
  })

  output$pyr_nokkeltall <- renderUI({
    req(input$pyr_aar)
    d <- pyr_data()
    nokkel <- function(a) {
      x <- d[d$år == a, ]
      alder_start <- as.integer(sub("[-+].*", "", as.character(x$aldersgruppe)))
      tot <- sum(x$antall)
      c(tot = tot, andel_65 = sum(x$antall[alder_start >= 65]) / tot * 100,
        andel_80 = sum(x$antall[alder_start >= 80]) / tot * 100)
    }
    n <- nokkel(input$pyr_aar); r <- nokkel(PYRAMIDE_REFERANSEAR)
    tall <- function(v) format(round(v), big.mark = " ")
    prosent <- function(v) sub(".", ",", sprintf("%.1f %%", v), fixed = TRUE)
    endring <- (n[["tot"]] / r[["tot"]] - 1) * 100
    ref <- PYRAMIDE_REFERANSEAR
    tekst <- paste0(
      ": ", tall(n[["tot"]]), " innbyggere (", sub(".", ",", sprintf("%+.1f %%", endring), fixed = TRUE),
      " fra ", ref, "). ",
      "Andel 65 år og eldre: ", prosent(n[["andel_65"]]), " (", ref, ": ", prosent(r[["andel_65"]]), "). ",
      "Andel 80 år og eldre: ", prosent(n[["andel_80"]]), " (", ref, ": ", prosent(r[["andel_80"]]), ")."
    )
    p(class = "mb-2", HTML(paste0("<b>", input$pyr_aar, "</b>", tekst)))
  })

  output$last_ned <- downloadHandler(
    filename = function() sprintf("%s_%s.csv", input$variabel, input$kommune),
    content = function(file) {
      write.csv(tidsserie(), file, row.names = FALSE, na = "", fileEncoding = "UTF-8")
    }
  )
}

shinyApp(ui, server)
