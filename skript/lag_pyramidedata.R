# lag_pyramidedata.R
#
# Lager den kompakte datafilen til fanen "Befolkningspyramider" i appen:
# data/ssb/befolkning_pyramide.rds.
#
# Innhold: antall personer per 2024-kommune x år x kjønn x 5-årig aldersgruppe
# (0-4, ..., 85-89, 90+), 2007-2050:
#   * 2007-2025: observert, fra data/ssb/befolkning_detaljert.rds (tabell 07459,
#     allerede på 2024-kommunestruktur, laget av legg_til_demens.R)
#   * 2026-2050: SSBs befolkningsframskrivning, hovedalternativet MMMM (tabell
#     12882), hentet med samme kommunehistorikk-logikk som framskriv_y1.R
# I tillegg legges "0000" = hele landet (sum av alle kommuner) til.
#
# Hvorfor forhåndsberegne i stedet for å regne i appen: SSBs tall er fasit og
# skal bare vises, ikke modelleres. Appen slipper da API-kall og
# aggregering, og fanen blir rask. Kjøres på nytt bare når SSB oppdaterer
# framskrivningen.
#
# Kjør fra prosjektroten: source("skript/lag_pyramidedata.R")
# Installer én gang: install.packages(c("httr2", "dplyr"))

library(httr2)
library(dplyr)

utmappe <- file.path("data", "ssb")
AR_FRAMOVER <- 2026:2050
ALTERNATIV <- "Personer"   # hovedalternativet MMMM

ALDERSGRUPPER <- c(paste(seq(0, 85, 5), seq(4, 89, 5), sep = "-"), "90+")

alder_til_gruppe <- function(alder_tekst) {
  alder <- as.integer(sub("+", "", as.character(alder_tekst), fixed = TRUE))
  faktor <- cut(alder, breaks = c(seq(0, 90, 5), Inf), right = FALSE, labels = ALDERSGRUPPER)
  as.character(faktor)
}

## ----------------------------------------------------------------------------
## 1. Observert 2007-2025
## ----------------------------------------------------------------------------
message("Leser observert befolkning...")
obs <- readRDS(file.path(utmappe, "befolkning_detaljert.rds"))
obs <- obs |>
  transmute(kommunenr = Region, år = as.integer(Tid),
            kjonn = ifelse(Kjonn == "1", "Menn", "Kvinner"),
            aldersgruppe = alder_til_gruppe(Alder), antall = verdi) |>
  group_by(kommunenr, år, kjonn, aldersgruppe) |>
  summarise(antall = sum(antall), .groups = "drop") |>
  mutate(type = "Observert")
kommuner_2024 <- sort(unique(obs$kommunenr))
message("  ", length(kommuner_2024), " kommuner, ", min(obs$år), "-", max(obs$år))

## ----------------------------------------------------------------------------
## 2. Framskrevet 2026-2050 (tabell 12882)
## ----------------------------------------------------------------------------
## Tabell 12882 bruker rå, år-spesifikke kommunenummer (se kommentar i
## framskriv_y1.R), så vi prøver alle historiske nummer for hver 2024-kommune
## og summerer.
hent_kommunehistorikk <- function() {
  url <- "https://data.ssb.no/api/pxwebapi/v2/codeLists/agg_KommSummer?lang=no"
  resp <- request(url) |> req_timeout(60) |> req_perform() |>
    resp_body_json(simplifyVector = FALSE)
  rader <- lapply(resp$values, function(v) {
    data.frame(kommunenr_2024 = sub("^K-", "", v$code),
               kommunenr_hist = unlist(v$valueMap), stringsAsFactors = FALSE)
  })
  do.call(rbind, rader)
}

hent_gyldige_koder <- function(table_id, dim_code) {
  resp <- request(paste0("https://data.ssb.no/api/v0/no/table/", table_id, "/")) |>
    req_timeout(60) |> req_perform()
  meta <- resp_body_json(resp, simplifyVector = TRUE)
  meta$variables$values[[which(meta$variables$code == dim_code)]]
}

hent_ett_aar <- function(koder_hist, year) {
  alder_koder <- c(sprintf("%03d", 0:104), "105+")
  body <- list(
    query = list(
      list(code = "Region", selection = list(filter = "item", values = as.list(koder_hist))),
      list(code = "Kjonn", selection = list(filter = "item", values = list("1", "2"))),
      list(code = "Alder", selection = list(filter = "item", values = as.list(alder_koder))),
      list(code = "ContentsCode", selection = list(filter = "item", values = list(ALTERNATIV))),
      list(code = "Tid", selection = list(filter = "item", values = list(as.character(year))))
    ),
    response = list(format = "json")
  )
  resp <- request("https://data.ssb.no/api/v0/no/table/12882/") |>
    req_body_json(body) |> req_timeout(120) |> req_retry(max_tries = 4) |>
    req_error(is_error = function(resp) FALSE) |> req_perform()
  if (resp_status(resp) >= 400) {
    stop(sprintf("SSB API-feil (HTTP %s) for år %s: %s", resp_status(resp), year, resp_body_string(resp)))
  }
  parsed <- resp_body_json(resp, simplifyVector = FALSE)
  col_codes <- vapply(parsed$columns, function(c) c$code, character(1))
  dim_idx <- which(vapply(parsed$columns, function(c) c$type, character(1)) %in% c("d", "t"))
  nokler <- do.call(rbind, lapply(parsed$data, function(row) unlist(row$key)))
  colnames(nokler) <- col_codes[dim_idx]
  d <- as.data.frame(nokler, stringsAsFactors = FALSE)
  d$verdi <- vapply(parsed$data, function(row) suppressWarnings(as.numeric(row$values[[1]])), numeric(1))
  d
}

message("Henter kommunehistorikk og framskrevet befolkning (12882)...")
kh <- hent_kommunehistorikk()
kh <- kh[kh$kommunenr_2024 %in% kommuner_2024, ]
koder_hist <- intersect(unique(kh$kommunenr_hist), hent_gyldige_koder("12882", "Region"))

fram <- bind_rows(lapply(AR_FRAMOVER, function(year) {
  message("  ", year, "...")
  d <- hent_ett_aar(c(koder_hist, "0"), year)   # "0" = hele landet
  d <- merge(d, rbind(kh, data.frame(kommunenr_2024 = "0000", kommunenr_hist = "0")),
             by.x = "Region", by.y = "kommunenr_hist")
  d |>
    transmute(kommunenr = kommunenr_2024, år = as.integer(Tid),
              kjonn = ifelse(Kjonn == "1", "Menn", "Kvinner"),
              aldersgruppe = alder_til_gruppe(Alder), verdi) |>
    group_by(kommunenr, år, kjonn, aldersgruppe) |>
    summarise(antall = sum(verdi), .groups = "drop")
})) |> mutate(type = "Framskrevet")

## ----------------------------------------------------------------------------
## 3. Sett sammen, kontroller og lagre
## ----------------------------------------------------------------------------
# Kommuner som mangler i SSBs framskrivning (Haram, 1580) tas ut, slik at
# hver kommune har en sammenhengende serie 2007-2050 (samme som i modellene).
mangler <- setdiff(kommuner_2024, fram$kommunenr)
if (length(mangler) > 0) {
  message("Utelatt (finnes ikke i tabell 12882): ", paste(mangler, collapse = ", "))
  obs <- obs |> filter(!kommunenr %in% mangler)
}
# Hele landet, observert: sum over ALLE kommuner (inkl. utelatte, slik at
# landstallet er komplett)
land_obs <- readRDS(file.path(utmappe, "befolkning_detaljert.rds")) |>
  transmute(år = as.integer(Tid), kjonn = ifelse(Kjonn == "1", "Menn", "Kvinner"),
            aldersgruppe = alder_til_gruppe(Alder), antall = verdi) |>
  group_by(år, kjonn, aldersgruppe) |>
  summarise(antall = sum(antall), .groups = "drop") |>
  mutate(kommunenr = "0000", type = "Observert")
alle <- bind_rows(obs, land_obs, fram)
alle <- alle |>
  mutate(antall = as.integer(round(antall)),
         aldersgruppe = factor(aldersgruppe, levels = ALDERSGRUPPER),
         kjonn = factor(kjonn, levels = c("Menn", "Kvinner")),
         type = factor(type)) |>
  arrange(kommunenr, år, kjonn, aldersgruppe)

stopifnot(!anyNA(alle$antall), !anyNA(alle$aldersgruppe))
# Hver kommune skal ha komplett rutenett (44 år x 2 kjønn x 19 grupper)
rutenett <- alle |> count(kommunenr)
forventet <- length(c(2007:2025, AR_FRAMOVER)) * 2 * length(ALDERSGRUPPER)
if (any(rutenett$n != forventet)) {
  print(rutenett[rutenett$n != forventet, ])
  print(alle |> filter(kommunenr %in% rutenett$kommunenr[rutenett$n != forventet]) |>
          count(kommunenr, type))
  stop("Ufullstendig rutenett for kommunene over.")
}

# Kontroll mot framskrevet_y1.rds: samme folketall for 2026 og 2050?
kontroll <- readRDS(file.path(utmappe, "framskrevet_y1.rds"))
tot <- alle |> filter(kommunenr != "0000") |> group_by(kommunenr, år) |>
  summarise(folk = sum(antall), .groups = "drop")
k <- merge(kontroll[, c("kommunenr_2024", "år", "folk_ialt")], tot,
           by.x = c("kommunenr_2024", "år"), by.y = c("kommunenr", "år"))
message(sprintf("Kontroll mot framskrevet_y1.rds: %d kommune-år, maks avvik %.1f personer",
                nrow(k), max(abs(k$folk_ialt - k$folk))))

saveRDS(alle, file.path(utmappe, "befolkning_pyramide.rds"), compress = "xz")
message("Lagret data/ssb/befolkning_pyramide.rds (",
        round(file.size(file.path(utmappe, "befolkning_pyramide.rds")) / 1e6, 1),
        " MB, ", format(nrow(alle), big.mark = " "), " rader)")
