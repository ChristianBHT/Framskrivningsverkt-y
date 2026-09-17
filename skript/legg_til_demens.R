# legg_til_demens.R
#
# Beregner et demensprevalens-estimat per kommune (2024-struktur) og år, og
# legger det på som nye kolonner i paneldata_2024struktur.
#
# Prevalensratene er aldersgruppe- og kjønnsbetinget (dementia_dic), men
# paneldata_2024struktur har bare befolkning i tre grove aldersbånd (0-66,
# 67-79, 80+) med begge kjønn slått sammen - det er ikke detaljert nok til å
# bruke ratetabellen direkte. Vi henter derfor ETTÅRIG befolkning (alder x
# kjønn) fra SSB-tabell 07459 på nytt her, beregner demens på detaljnivå
# (samme fremgangsmåte som i det opprinnelige demensskriptet, gen_data.R),
# og summerer resultatet opp til én rad per kommune x år før vi kobler det på
# paneldata_2024struktur.
#
# Fordi 07459 hentes med SSBs egen sammenslåtte kodeliste (agg_KommSummer,
# samme som brukes i hent_paneldata_2007_2025.R), kommer befolkningen
# allerede ferdig summert til dagens (2024) kommunenummer - vi trenger altså
# IKKE kommunehistorikk/sammenslåingslogikk her, i motsetning til Y-variablene
# i hent_paneldata_2007_2025.R.
#
# Forutsetning: kjør hent_paneldata_2007_2025.R først, slik at
# data/ssb/paneldata_2007_2025_2024struktur.rds finnes.
#
# Installer én gang: install.packages(c("httr2", "rjstat", "dplyr"))

library(httr2)
library(dplyr)

utmappe <- file.path("data", "ssb")

## ============================================================================
## 1. Prevalensrater (aldersgruppe x kjønn)
## ============================================================================
dementia_dic <- data.frame(
  alder_grup = rep(0:7, 2),
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
## 2. Hent ettårig befolkning (alder x kjønn), allerede i 2024-kommunestruktur
## ============================================================================
## Samme batch-mønster som hent_befolkning() i hent_paneldata_2007_2025.R -
## én URL med alle kommuner samtidig blir for lang og avvist av webserveren
## (HTTP 404 FØR SSBs API i det hele tatt ser forespørselen), så vi deler opp
## i grupper av `batch_size` kommuner per kall.
hent_befolkning_detaljert_batch <- function(kommuner_2024, years) {
  url <- paste0(
    "https://data.ssb.no/api/pxwebapi/v2/tables/07459/data",
    "?lang=no&outputFormat=json-stat2",
    "&valuecodes%5BContentsCode%5D=Personer1",
    "&valuecodes%5BTid%5D=", paste(sort(unique(years)), collapse = ","),
    "&valuecodes%5BRegion%5D=", paste0("K-", kommuner_2024, collapse = ","),
    "&codelist%5BRegion%5D=agg_KommSummer",
    "&valuecodes%5BAlder%5D=*",
    "&codelist%5BAlder%5D=vs_AlleAldre00B",
    "&valuecodes%5BKjonn%5D=1,2",
    "&heading=ContentsCode,Tid&stub=Region,Kjonn,Alder"
  )
  resp <- request(url) |> req_timeout(120) |> req_retry(max_tries = 4) |> req_perform()
  rjstat::fromJSONstat(resp_body_string(resp), naming = "id")
}

hent_befolkning_detaljert <- function(kommuner_2024, years, batch_size = 100) {
  batcher <- split(kommuner_2024, ceiling(seq_along(kommuner_2024) / batch_size))
  d <- bind_rows(lapply(batcher, hent_befolkning_detaljert_batch, years = years))
  names(d)[names(d) == "value"] <- "verdi"
  # Fjern "K-"-prefikset fra den sammenslåtte kodelisten, slik at Region blir
  # et rent 2024-kommunenummer (samme format som kommunenr_2024 ellers).
  d$Region <- sub("^K-", "", d$Region)
  d
}

## ============================================================================
## 3. Demensberegning (uendret fra gen_data.R - se forklaring i kommentarer)
## ============================================================================
beregn_demens <- function(befolkning, rater = dementia_dic,
                          enhet = c("andel", "per_1000")) {
  enhet <- match.arg(enhet)
  krav <- c("Region", "Tid", "Kjonn", "Alder", "verdi")
  if (!all(krav %in% names(befolkning)) || !nrow(befolkning)) {
    stop("befolkning må ha rader og kolonnene: ", paste(krav, collapse = ", "))
  }
  if (!is.numeric(befolkning$verdi) ||
      any(!is.finite(befolkning$verdi[!is.na(befolkning$verdi)])) ||
      any(befolkning$verdi < 0, na.rm = TRUE)) stop("Ugyldig folkemengde.")
  nokler <- c("Region", "Tid", "Kjonn", "Alder")
  if (anyNA(befolkning[nokler]) || anyDuplicated(befolkning[nokler])) {
    stop("Manglende eller dupliserte nøkler for kommune, år, kjønn og alder.")
  }
  if ("ssb_tabell" %in% names(befolkning) &&
      any(is.na(befolkning$ssb_tabell) | befolkning$ssb_tabell != "07459")) {
    stop("Bruk historisk befolkning fra tabell 07459.")
  }
  if ("ContentsCode" %in% names(befolkning) &&
      any(is.na(befolkning$ContentsCode) | befolkning$ContentsCode != "Personer1")) {
    stop("Forventet befolkningsvariabel Personer1 fra tabell 07459.")
  }
  gyldige_aldre <- c(sprintf("%03d", 0:104), "105+")
  if (!all(befolkning$Alder %in% gyldige_aldre) ||
      !all(befolkning$Kjonn %in% c("1", "2"))) {
    stop("Forventet alderskoder 000–104 / 105+ og kjønnskoder 1 / 2.")
  }
  if (!all(c("aldersgrup", "kjonn", "demensprevalens") %in% names(rater))) {
    stop("Ratetabellen mangler nødvendige kolonner.")
  }
  rate_nokkel <- paste(rater$aldersgrup, rater$kjonn, sep = "|")
  if (anyDuplicated(rate_nokkel) || !is.numeric(rater$demensprevalens) ||
      any(!is.finite(rater$demensprevalens))) stop("Ugyldige eller dupliserte rater.")
  andel <- rater$demensprevalens / if (enhet == "per_1000") 1000 else 1
  if (any(andel < 0 | andel > 1)) stop("Prevalens som andel må være mellom 0 og 1.")

  d <- befolkning
  alder <- as.integer(sub("+", "", as.character(d$Alder), fixed = TRUE))
  d$aldersgrup <- as.character(cut(alder,
                                   breaks = c(0, 30, 65, 70, 75, 80, 85, 90, Inf), right = FALSE,
                                   labels = c("0-29", "30-64", "65-69", "70-74", "75-79", "80-84", "85-89", "90+")))
  d$kjonn <- ifelse(d$Kjonn == "1", "Menn", "Kvinner")
  indeks <- match(paste(d$aldersgrup, d$kjonn, sep = "|"), rate_nokkel)
  if (anyNA(indeks)) stop("Mangler prevalens for minst én alders-/kjønnsgruppe.")
  d$demensprevalens_andel <- andel[indeks]
  d$prevalens_enhet_inn <- enhet
  d$demens_estimert <- d$verdi * d$demensprevalens_andel

  # Ikke avrund før eventuell presentasjon. NA beholdes også ved summering.
  # Et kommunetotal krever alle 106 alderskoder for begge kjønn (212 rader).
  grupper <- split(seq_len(nrow(d)), interaction(d$Region, d$Tid, drop = TRUE))
  total <- do.call(rbind, lapply(grupper, function(i) {
    komplett <- length(i) == 212L && !anyNA(d$verdi[i])
    data.frame(Region = as.character(d$Region[i[1]]),
               Tid = as.character(d$Tid[i[1]]),
               befolkning = if (komplett) sum(d$verdi[i]) else NA_real_,
               demens_estimert = if (komplett) sum(d$demens_estimert[i]) else NA_real_,
               komplett = komplett, antall_rader = length(i),
               manglende_verdier = sum(is.na(d$verdi[i])),
               prevalens_enhet_inn = enhet)
  }))
  rownames(total) <- NULL
  if (any(!total$komplett)) warning(
    "Ufullstendig befolkning for minst én kommune/år. Totalestimat er satt til NA.")
  list(befolkning = d, historisk_demens = total)
}

## ============================================================================
## 4. Kjør: hent detaljert befolkning, beregn demens, koble på paneldata
## ============================================================================
for (pakke in c("httr2", "rjstat", "dplyr")) {
  if (!requireNamespace(pakke, quietly = TRUE)) {
    stop("Mangler ", pakke, ". Kjør install.packages(c('httr2','rjstat','dplyr')) først.")
  }
}

message("Leser paneldata_2024struktur...")
paneldata_2024struktur <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur.rds"))
kommuner_2024 <- sort(unique(paneldata_2024struktur$kommunenr_2024))
years <- sort(unique(paneldata_2024struktur$år))

message("Henter ettårig befolkning (alder x kjønn) for ", length(kommuner_2024),
        " kommuner, ", length(years), " år...")
befolkning <- hent_befolkning_detaljert(kommuner_2024, years)

message("Beregner demens...")
demens_resultat <- beregn_demens(befolkning, rater = dementia_dic, enhet = "andel")
historisk_demens <- demens_resultat$historisk_demens

demens_til_kobling <- historisk_demens |>
  transmute(kommunenr_2024 = Region, år = as.integer(Tid),
            demens_estimert, demens_komplett = komplett)

paneldata_med_demens <- paneldata_2024struktur |>
  left_join(demens_til_kobling, by = c("kommunenr_2024", "år"))

## ---- Lagre -------------------------------------------------------------
saveRDS(befolkning, file.path(utmappe, "befolkning_detaljert.rds"))
saveRDS(historisk_demens, file.path(utmappe, "historisk_demens.rds"))
saveRDS(paneldata_med_demens,
        file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
write.csv(paneldata_med_demens,
          file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

if (any(is.na(paneldata_med_demens$demens_estimert))) {
  message(sum(is.na(paneldata_med_demens$demens_estimert)),
          " av ", nrow(paneldata_med_demens),
          " kommune-år har manglende/ufullstendig demensestimat (se demens_komplett).")
}
message("Lagret ", nrow(paneldata_med_demens),
        " rader med demensestimat i ", normalizePath(utmappe))
# Ved senere innlesing:
# paneldata <- readRDS("data/ssb/paneldata_2007_2025_2024struktur_med_demens.rds")
