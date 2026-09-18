# framskriv_y5.R
#
# Framskriver Y_5 (alle sykepleiere, årsverk) per kommune (2024-struktur) og
# år, ved å bruke den estimerte HOVEDMODELLEN (tilfeldig intercept, se
# modell_y5.R) på SSBs BEFOLKNINGSFRAMSKRIVNINGER (tabell 12882).
#
# Parallell til framskriv_y1.R/framskriv_y2_stjerne.R (samme fremgangsmåte,
# samme forbehold om årseffekt/regionkoder/glidende overgang) - se
# framskriv_y1.R for mer utfyllende forklaring av hvorfor hvert steg gjøres
# som det gjøres. Duplisert i stedet for delt via en felles hjelpefil, i
# tråd med resten av prosjektets stil.
#
# MODELLFORM: modell_y5.R bruker log(Y_5) ~ ... + offset(log(folk_ialt)),
# altså samme log-lineære populasjonsskalering som Poisson-modellene for
# Y_1/Y_2* - prediksjonen her er derfor strukturelt identisk med
# framskriv_y2_stjerne.R (lineær prediktor + eksponensiering), selv om
# modell_y5.R er en lmer (normalfordelte feil på logskala), ikke en glmer.
#
# NB: bruker bevisst `hovedmodell` (kun tilfeldig intercept), IKKE en av
# helningsvariantene - samme begrunnelse som for Y_1/Y_2*/Y_4: den
# korrelerte helningsvarianten ga en implausibel NEGATIV effektiv helning
# på demensandel for 103 av 357 kommuner. Se modell_y5.R.
#
# DATADEKNING: Y_5 mangler helt for 2007-2014 (se modell_y5.R), så siste
# observerte år for den glidende overgangen er likevel 2025, som for de
# andre variablene - dette påvirker bare hvor mye historikk modellen ble
# trent på, ikke framskrivningsoppsettet.
#
# Forutsetning: kjør modell_y5.R først, slik at
# data/ssb/modell_y5_hovedmodell.rds finnes.
#
# Installer én gang: install.packages(c("httr2", "lme4", "dplyr", "tidyr"))

library(httr2)
library(lme4)
library(dplyr)
library(tidyr)

utmappe <- file.path("data", "ssb")

## ============================================================================
## 1. Prevalensrater (samme som i legg_til_demens.R)
## ============================================================================
dementia_dic <- data.frame(
  aldersgrup = rep(c("0-29", "30-64", "65-69", "70-74", "75-79",
                     "80-84", "85-89", "90+"), 2),
  kjonn = rep(c("Menn", "Kvinner"), each = 8),
  demensprevalens = c(
    0, 0.000838, 0.005717, 0.063894, 0.100285, 0.177985, 0.304476, 0.414735,
    0, 0.000873, 0.008860, 0.048112, 0.089572, 0.180180, 0.345687, 0.509160
  ),
  stringsAsFactors = FALSE
)

## ============================================================================
## 2. Kommunehistorikk (samme sammenslåtte kodeliste som resten av prosjektet)
## ============================================================================
hent_kommunehistorikk <- function() {
  url <- "https://data.ssb.no/api/pxwebapi/v2/codeLists/agg_KommSummer?lang=no"
  resp <- request(url) |> req_timeout(60) |> req_perform() |>
    resp_body_json(simplifyVector = FALSE)
  rader <- lapply(resp$values, function(v) {
    data.frame(kommunenr_2024 = sub("^K-", "", v$code),
               kommunenr_hist = unlist(v$valueMap),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rader)
}

## ============================================================================
## 3. Hent framskrevet befolkning (alder x kjønn) fra tabell 12882
## ============================================================================
hent_gyldige_koder <- function(table_id, dim_code) {
  resp <- request(paste0("https://data.ssb.no/api/v0/no/table/", table_id, "/")) |>
    req_timeout(60) |> req_perform()
  meta <- resp_body_json(resp, simplifyVector = TRUE)
  meta$variables$values[[which(meta$variables$code == dim_code)]]
}

hent_framskrevet_befolkning_ett_aar <- function(koder_hist, year, alternativ) {
  alder_koder <- c(sprintf("%03d", 0:104), "105+")
  body <- list(
    query = list(
      list(code = "Region", selection = list(filter = "item", values = as.list(koder_hist))),
      list(code = "Kjonn", selection = list(filter = "item", values = list("1", "2"))),
      list(code = "Alder", selection = list(filter = "item", values = as.list(alder_koder))),
      list(code = "ContentsCode", selection = list(filter = "item", values = list(alternativ))),
      list(code = "Tid", selection = list(filter = "item", values = list(as.character(year))))
    ),
    response = list(format = "json")
  )
  resp <- request("https://data.ssb.no/api/v0/no/table/12882/") |>
    req_body_json(body) |> req_timeout(120) |> req_retry(max_tries = 4) |>
    req_error(is_error = function(resp) FALSE) |> req_perform()
  if (resp_status(resp) >= 400) {
    stop(sprintf("SSB API-feil (HTTP %s) mot tabell 12882 for år %s: %s",
                  resp_status(resp), year, resp_body_string(resp)))
  }
  parsed <- resp_body_json(resp, simplifyVector = FALSE)
  cols <- parsed$columns
  col_codes <- vapply(cols, function(c) c$code, character(1))
  dim_idx <- which(vapply(cols, function(c) c$type, character(1)) %in% c("d", "t"))
  if (length(parsed$data) == 0) return(data.frame())
  rader <- lapply(parsed$data, function(row) {
    vals <- as.list(unlist(row$key))
    names(vals) <- col_codes[dim_idx]
    vals$verdi <- suppressWarnings(as.numeric(row$values[[1]]))
    as.data.frame(vals, stringsAsFactors = FALSE)
  })
  do.call(rbind, rader)
}

hent_framskrevet_befolkning <- function(kommuner_2024, years, alternativ = "Personer",
                                        kommunehistorikk) {
  gyldige <- hent_gyldige_koder("12882", "Region")
  kh <- kommunehistorikk[kommunehistorikk$kommunenr_2024 %in% kommuner_2024, ]
  koder_hist <- intersect(unique(kh$kommunenr_hist), gyldige)

  d <- bind_rows(lapply(years, function(year) {
    message("  henter befolkningsframskrivning for ", year, " (", alternativ, ")...")
    hent_framskrevet_befolkning_ett_aar(koder_hist, year, alternativ)
  }))
  d <- merge(d, kh, by.x = "Region", by.y = "kommunenr_hist")
  names(d)[names(d) == "Region"] <- "kommunenr_hist"
  d$Tid <- as.integer(d$Tid)
  d
}

## ============================================================================
## 4. Beregn framskrevet demensandel og folk_ialt per kommune x år
## ============================================================================
beregn_demens_framskrevet <- function(befolkning_fremtid, rater = dementia_dic) {
  d <- befolkning_fremtid
  alder <- as.integer(sub("+", "", as.character(d$Alder), fixed = TRUE))
  d$aldersgrup <- as.character(cut(alder,
                                   breaks = c(0, 30, 65, 70, 75, 80, 85, 90, Inf), right = FALSE,
                                   labels = c("0-29", "30-64", "65-69", "70-74", "75-79", "80-84", "85-89", "90+")))
  d$kjonn <- ifelse(d$Kjonn == "1", "Menn", "Kvinner")
  rate_nokkel <- paste(rater$aldersgrup, rater$kjonn, sep = "|")
  indeks <- match(paste(d$aldersgrup, d$kjonn, sep = "|"), rate_nokkel)
  if (anyNA(indeks)) stop("Mangler prevalens for minst én alders-/kjønnsgruppe.")
  d$demens_estimert <- d$verdi * rater$demensprevalens[indeks]

  d |>
    group_by(kommunenr_2024, år = Tid) |>
    summarise(folk_ialt = sum(verdi), demens_estimert = sum(demens_estimert),
              .groups = "drop") |>
    mutate(demensandel = demens_estimert / folk_ialt)
}

## ============================================================================
## 5. Predikér Y_5 med hovedmodell_slope, ANKRET ved 2025-nivået
## ============================================================================
## Se framskriv_y1.R for full begrunnelse: bruker BEVISST hovedmodell_slope
## (ikke en separat intercept-only-modell), ankret ved kommunens siste
## observerte (2025) demensandel, slik at "trend-effekt = 0 %" i appen gir
## nøyaktig samme tall som når trend-bryteren er av. Kommunens egen
## tilfeldige helning brukes ALDRI på framtidig vekst her - bare på det
## faste ankerpunktet.
framskriv_y5 <- function(modell, framtidsdata) {
  faste <- fixef(modell)
  intercept <- faste[["(Intercept)"]]
  demens_koef <- faste[["demensandel"]]
  aar_koef <- faste[grepl("^år_f", names(faste))]
  aar_effekt_framskrevet <- mean(aar_koef)

  re <- ranef(modell)$kommunenr_2024
  kjente_kommuner <- rownames(re)
  kjent <- as.character(framtidsdata$kommunenr_2024) %in% kjente_kommuner
  if (!all(kjent)) {
    warning(sum(!kjent), " kommune(r) fantes ikke i modellens treningsdata ",
            "og er utelatt fra framskrivningen.")
    framtidsdata <- framtidsdata[kjent, ]
  }

  u_intercept <- re[as.character(framtidsdata$kommunenr_2024), "(Intercept)"]
  u_slope <- re[as.character(framtidsdata$kommunenr_2024), "demensandel"]

  ## Samme log-lineær-med-offset-form som modellestimeringen (se modell_y5.R):
  ## lin_pred er log(Y_5), så prediksjonen eksponensieres tilbake til
  ## opprinnelig skala (årsverk).
  intercept_prime <- intercept + u_intercept +
    (demens_koef + u_slope) * framtidsdata$demensandel_anker
  delta_demensandel <- framtidsdata$demensandel - framtidsdata$demensandel_anker

  lin_pred <- intercept_prime + aar_effekt_framskrevet +
    demens_koef * delta_demensandel +
    log(framtidsdata$folk_ialt)

  framtidsdata$y5_predikert <- as.numeric(exp(lin_pred))
  framtidsdata
}

## ============================================================================
## 6. Glidende overgang fra observert 2025-nivå til modellframskrivning
## ============================================================================
## Samme skjema som framskriv_y1.R/framskriv_y2_stjerne.R: 90 % vekt på
## observert 2025 i 2026, lineært ned til 0 % i 2036.
## SLUTTAAR_OVERGANG settes til siste framskrevne år lenger ned (etter at
## AR_FRAMOVER er definert) - overgangen strekkes over HELE
## framskrivningsperioden, ikke bare 2026-2036, for å unngå et kink i grafen
## (se framskriv_y1.R for full begrunnelse).
STARTAAR_OVERGANG <- 2026
START_ANDEL_OBSERVERT <- 0.9

glatt_overgang <- function(framskrevet_raa, siste_observert) {
  d <- merge(framskrevet_raa, siste_observert, by = "kommunenr_2024", all.x = TRUE)
  vekt <- pmax(0, START_ANDEL_OBSERVERT *
                 (SLUTTAAR_OVERGANG - d$år) / (SLUTTAAR_OVERGANG - STARTAAR_OVERGANG))

  d$y5_predikert_modell <- d$y5_predikert
  d$y5_predikert <- ifelse(
    is.na(d$y5_observert),
    d$y5_predikert_modell,
    vekt * d$y5_observert + (1 - vekt) * d$y5_predikert_modell
  )
  d$vekt_observert_2025 <- ifelse(is.na(d$y5_observert), 0, vekt)
  d$y5_observert <- NULL
  d
}

## ============================================================================
## 7. Kjør: hent framskrivning, beregn demens, predikér, glatt overgangen
## ============================================================================
for (pakke in c("httr2", "lme4", "dplyr", "tidyr")) {
  if (!requireNamespace(pakke, quietly = TRUE)) {
    stop("Mangler ", pakke, ". Kjør install.packages(c('httr2','lme4','dplyr','tidyr')) først.")
  }
}

message("Leser hovedmodell_slope...")
hovedmodell_slope <- readRDS(file.path(utmappe, "modell_y5_hovedmodell_slope.rds"))
kommuner_2024 <- rownames(ranef(hovedmodell_slope)$kommunenr_2024)

ALTERNATIV <- "Personer"      # "Personer"=MMMM (hoved), "Personer1"=LLML, "Personer2"=HHMH
AR_FRAMOVER <- 2026:2050
SLUTTAAR_OVERGANG <- max(AR_FRAMOVER)
SISTE_OBSERVERTE_AR <- 2025

message("Leser historikk (for anker og glidende overgang)...")
historisk <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
historisk$demensandel <- historisk$demens_estimert / historisk$folk_ialt
demensandel_anker <- historisk |>
  filter(år == SISTE_OBSERVERTE_AR) |>
  transmute(kommunenr_2024, demensandel_anker = demensandel)
siste_observert <- historisk |>
  filter(år == SISTE_OBSERVERTE_AR) |>
  transmute(kommunenr_2024, y5_observert = Y_5_ialt)

message("Bygger kommunehistorikk...")
kommunehistorikk <- hent_kommunehistorikk()

message("Henter befolkningsframskrivning (", ALTERNATIV, "), ",
        min(AR_FRAMOVER), "-", max(AR_FRAMOVER), "...")
befolkning_fremtid <- hent_framskrevet_befolkning(
  kommuner_2024, AR_FRAMOVER, alternativ = ALTERNATIV, kommunehistorikk = kommunehistorikk)

message("Beregner framskrevet demensandel...")
framtidsdata <- beregn_demens_framskrevet(befolkning_fremtid) |>
  left_join(demensandel_anker, by = "kommunenr_2024")

message("Predikerer Y_5 (rå modellframskrivning)...")
framskrevet_y5_raa <- framskriv_y5(hovedmodell_slope, framtidsdata)

message("Glatter overgangen fra observert ", SISTE_OBSERVERTE_AR, " til modell (",
        STARTAAR_OVERGANG, "-", SLUTTAAR_OVERGANG, ")...")
framskrevet_y5 <- glatt_overgang(framskrevet_y5_raa, siste_observert)

## ---- Lagre -------------------------------------------------------------
saveRDS(framskrevet_y5, file.path(utmappe, "framskrevet_y5.rds"))
write.csv(framskrevet_y5, file.path(utmappe, "framskrevet_y5.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message("Lagret framskrivning for ", length(unique(framskrevet_y5$kommunenr_2024)),
        " kommuner, ", length(unique(framskrevet_y5$år)), " år, i ",
        normalizePath(utmappe))
