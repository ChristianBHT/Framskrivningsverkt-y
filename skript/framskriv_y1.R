# framskriv_y1.R
#
# Framskriver Y_1 (brukere av hjemmetjenester) per kommune (2024-struktur) og
# år, ved å bruke den estimerte HOVEDMODELLEN (tilfeldig intercept, se
# modell_y1.R) på SSBs BEFOLKNINGSFRAMSKRIVNINGER (tabell 12882) i stedet for
# historisk befolkning.
#
# NB: bruker bevisst `hovedmodell` (kun tilfeldig intercept), IKKE en av
# helningsvariantene (hovedmodell_slope/hovedmodell_slope_uncorr). Begge
# helningsvariantene ga en NEGATIV effektiv helning på demensandel for 90+ av
# 357 kommuner (dvs. modellen ville forutsagt FÆRRE hjemmetjenestebrukere når
# demensandelen stiger, for en firedel av kommunene) - substansielt
# implausibelt og spesielt risikabelt ved framskrivning langt forbi det
# historisk observerte området. Se modell_y1.R for hvordan dette ble
# undersøkt og bekreftet.
#
# Fremgangsmåte:
#  1. Hent framskrevet befolkning (ettårig alder x kjønn) fra tabell 12882
#     for valgt framskrivingsalternativ (default: hovedalternativet MMMM).
#  2. Beregn en framskrevet demensandel med SAMME prevalensrater
#     (dementia_dic) som ble brukt på historiske data i legg_til_demens.R.
#  3. Predikér Y_1 med hovedmodell sine faste effekter (intercept,
#     demensandel-koeffisient) + kommunens estimerte tilfeldige intercept
#     (samme som brukes i modell_y1.R sin loyo_cv()) + befolkning som
#     eksponering.
#
# VIKTIG om årseffekten: modellen har årsdummyer for 2007-2025 og har derfor
# ingen egen koeffisient for framtidige år (2026+) - nøyaktig samme problem
# som å predikere et utelatt år i kryssvalideringen. Vi bruker derfor SAMME
# forenkling som der: gjennomsnittet av de historisk estimerte årseffektene
# brukes som årseffekt for ALLE framskrevne år. Det betyr at framskrivningen
# IKKE fanger opp noen videreføring av en historisk tidstrend forbi 2025 -
# den antar at "et gjennomsnittsår" fra 2008-2025 gjelder framover. Ønsker du
# heller f.eks. bare de siste 3-5 årenes gjennomsnitt (nærmere dagens nivå),
# er det kun linjen som setter `aar_effekt_framskrevet` som må endres.
#
# GLIDENDE OVERGANG (unngår hopp ved 2025/2026-skjøten): den rene
# modellframskrivningen (se over) kan avvike fra observert 2025-nivå og gir
# da et synlig hopp i overgangen. I stedet BLANDES framskrivningen gradvis
# inn: i STARTAAR_OVERGANG (2026) vektlegges observert 2025-nivå med
# START_ANDEL_OBSERVERT (90 %), og denne vekten avtar lineært til 0 i
# SLUTTAAR_OVERGANG (2036), der framskrivningen blir 100 % modell. Den rene
# modellframskrivningen (uten denne glattingen) er beholdt i kolonnen
# `y1_predikert_modell` for sammenligning; `y1_predikert` er den glattede
# versjonen som brukes videre (bl.a. i app.R).
#
# VIKTIG om regionkoder: tabell 12882 har - i motsetning til 07459
# (historisk befolkning) - IKKE en sammenslått ("K-"-kodet) kodeliste som
# automatisk splicer historiske kommunenummer til dagens (2024) struktur.
# Tabellen bruker i stedet rå, år-spesifikke kommunenummer, og for enkelte
# kommuner (de som ble påvirket av grensejusteringene i 2020/2024) er
# nyeste tilgjengelige framskrivning fortsatt på ELDRE kommunenummer. Vi
# løser dette på samme måte som i hent_paneldata_2007_2025.R: prøv alle
# historiske kommunenummer for hver 2024-kommune, og bruk det som faktisk
# finnes i 12882 sin regiondimensjon.
#
# Forutsetning: kjør modell_y1.R først, slik at
# data/ssb/modell_y1_hovedmodell.rds finnes.
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
## v0-API, POST, px-standard "json"-format - samme mønster som i
## hent_paneldata_2007_2025.R. Ett år per kall for å unngå SSBs grense på
## antall celler per spørring (region x alder x kjønn er allerede stort).
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

#' Henter framskrevet ettårig befolkning for gitte 2024-kommuner og år.
#' `alternativ` er en ContentsCode fra tabell 12882 (default "Personer" =
#' hovedalternativet MMMM; "Personer1" = lav nasjonal vekst LLML;
#' "Personer2" = høy nasjonal vekst HHMH; se tabellens metadata for øvrige).
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
## 5. Predikér Y_1 med hovedmodell_slope, ANKRET ved 2025-nivået
## ============================================================================
## VIKTIG (rettet etter en reell inkonsistens-bug - se app.R sin
## framskriv_trend()-kommentarblokk for full begrunnelse): vi bruker
## BEVISST `hovedmodell_slope` her, IKKE en separat intercept-only-modell
## (`hovedmodell`). De to modellvariantene estimerer ULIKE faste effekter
## (intercept/demensandel-koeffisient), fordi den tilfeldige helningen i
## slope-modellen fanger opp noe av variasjonen intercept-only-modellen
## ellers ville lagt på det faste leddet. Å bruke to forskjellige modeller
## for "med trend" og "uten trend" i appen ga derfor et synlig SPRANG i
## framskrivningen selv når trend-effekten var satt til 0 % - de var
## rett og slett to forskjellige modeller, ikke samme modell med og uten
## et tillegg. Løsningen er å ALLTID bruke hovedmodell_slope, og ANKRE
## framskrivningen ved kommunens SISTE OBSERVERTE (2025) demensandel:
## - `intercept_prime` bygger inn HELE kommunens nivå ved ankeret
##   (intercept + tilfeldig intercept + (fast + tilfeldig helning) * anker).
##   Dette er en KONSTANT per kommune - den kan ikke selv eksplodere.
## - All FRAMTIDIG vekst (endring i demensandel utover ankeret) bruker BARE
##   det faste (nasjonale) helningsanslaget, IKKE kommunens egen tilfeldige
##   helning - dette er nøyaktig det samme som "0 % trend-effekt" i appens
##   T-styrte trend-funksjon (framskriv_trend() i app.R), og er derfor
##   identisk med og uten at brukeren skrur på trend-bryteren i appen.
## - Dette gjør det også trygt å bruke slope-modellen her i det hele tatt:
##   det er nettopp en kommunes EGEN tilfeldige helning brukt på FRAMTIDIG
##   demensandel-vekst som tidligere ga en implausibel NEGATIV effektiv
##   helning for en del kommuner (se modell_y1.R) - siden den nå ALDRI
##   brukes på framtidig vekst (bare på et fast, historisk ankerpunkt),
##   er faren for et absurd fortegn i framskrivningen borte.
framskriv_y1 <- function(modell, framtidsdata) {
  faste <- fixef(modell)
  intercept <- faste[["(Intercept)"]]
  demens_koef <- faste[["demensandel"]]
  aar_koef <- faste[grepl("^år_f", names(faste))]
  # Se merknad i toppen av filen: modellen har ingen koeffisient for
  # framtidige år, så gjennomsnittet av de historiske årseffektene brukes.
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

  intercept_prime <- intercept + u_intercept +
    (demens_koef + u_slope) * framtidsdata$demensandel_anker
  delta_demensandel <- framtidsdata$demensandel - framtidsdata$demensandel_anker

  lin_pred <- intercept_prime + aar_effekt_framskrevet +
    demens_koef * delta_demensandel +
    log(framtidsdata$folk_ialt)

  framtidsdata$y1_predikert <- as.numeric(exp(lin_pred))
  framtidsdata
}

## ============================================================================
## 6. Glidende overgang fra observert 2025-nivå til modellframskrivning
## ============================================================================
## SLUTTAAR_OVERGANG settes til siste framskrevne år (AR_FRAMOVER, definert i
## del 7 under) - dvs. den glidende overgangen strekkes over HELE
## framskrivningsperioden, ikke bare de første 10 årene. Dette unngår et kink
## i grafen der overgangsvekten tidligere flatet ut til 0 med en brå endring
## i stigningstall (var fast 2036 - endret etter tilbakemelding om at
## grafene fikk et synlig "kink" akkurat der). Selve tallet settes lenger
## ned, etter at AR_FRAMOVER er definert.
STARTAAR_OVERGANG <- 2026
START_ANDEL_OBSERVERT <- 0.9

#' Blander inn observert siste-år-nivå med avtagende vekt, for å unngå et
#' synlig hopp ved overgangen fra historikk til modellframskrivning.
#' `siste_observert` skal ha kolonnene kommunenr_2024 og y1_observert.
glatt_overgang <- function(framskrevet_raa, siste_observert) {
  d <- merge(framskrevet_raa, siste_observert, by = "kommunenr_2024", all.x = TRUE)
  # Lineær nedtrapping: 90 % i STARTAAR_OVERGANG -> 0 % i SLUTTAAR_OVERGANG.
  # pmax(0, ...) sørger for at år etter SLUTTAAR_OVERGANG blir 100 % modell
  # (uten dette ville vekten blitt negativ).
  vekt <- pmax(0, START_ANDEL_OBSERVERT *
                 (SLUTTAAR_OVERGANG - d$år) / (SLUTTAAR_OVERGANG - STARTAAR_OVERGANG))

  d$y1_predikert_modell <- d$y1_predikert
  d$y1_predikert <- ifelse(
    is.na(d$y1_observert),
    d$y1_predikert_modell,  # ingen observert verdi å blande med -> bruk modellen rått
    vekt * d$y1_observert + (1 - vekt) * d$y1_predikert_modell
  )
  d$vekt_observert_2025 <- ifelse(is.na(d$y1_observert), 0, vekt)
  d$y1_observert <- NULL
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
hovedmodell_slope <- readRDS(file.path(utmappe, "modell_y1_hovedmodell_slope.rds"))
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
  transmute(kommunenr_2024, y1_observert = Y_1_a_ialt)

message("Bygger kommunehistorikk...")
kommunehistorikk <- hent_kommunehistorikk()

message("Henter befolkningsframskrivning (", ALTERNATIV, "), ",
        min(AR_FRAMOVER), "-", max(AR_FRAMOVER), "...")
befolkning_fremtid <- hent_framskrevet_befolkning(
  kommuner_2024, AR_FRAMOVER, alternativ = ALTERNATIV, kommunehistorikk = kommunehistorikk)

message("Beregner framskrevet demensandel...")
framtidsdata <- beregn_demens_framskrevet(befolkning_fremtid) |>
  left_join(demensandel_anker, by = "kommunenr_2024")

message("Predikerer Y_1 (rå modellframskrivning)...")
framskrevet_y1_raa <- framskriv_y1(hovedmodell_slope, framtidsdata)

message("Glatter overgangen fra observert ", SISTE_OBSERVERTE_AR, " til modell (",
        STARTAAR_OVERGANG, "-", SLUTTAAR_OVERGANG, ")...")
framskrevet_y1 <- glatt_overgang(framskrevet_y1_raa, siste_observert)

## ---- Lagre -------------------------------------------------------------
saveRDS(framskrevet_y1, file.path(utmappe, "framskrevet_y1.rds"))
write.csv(framskrevet_y1, file.path(utmappe, "framskrevet_y1.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message("Lagret framskrivning for ", length(unique(framskrevet_y1$kommunenr_2024)),
        " kommuner, ", length(unique(framskrevet_y1$år)), " år, i ",
        normalizePath(utmappe))
