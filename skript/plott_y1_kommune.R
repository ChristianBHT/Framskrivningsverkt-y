# plott_y1_kommune.R
#
# Plotter den sammensatte Y_1_a_ialt-serien for EN valgt kommune (2007-2025)
# sammen med rå tall hentet direkte fra de to underliggende SSB-tabellene
# (04686 t.o.m. 2016, 12292 f.o.m. 2015), for å visuelt og tallmessig
# bekrefte at skjøtingen stemmer med det SSB selv rapporterer.
#
# Generalisert versjon av plott_y1_halden.R: historiske kommunenummer for
# valgt kommune finnes AUTOMATISK via SSBs egen sammenslåtte kodeliste
# (samme prinsipp som i hent_paneldata_2007_2025.R) - du trenger altså ikke
# selv vite om/når kommunen har byttet nummer.
#
# Installer én gang: install.packages(c("httr2", "ggplot2", "dplyr"))

library(httr2)
library(ggplot2)
library(dplyr)

utmappe <- file.path("data", "ssb")
KOMMUNE_2024 <- "1101"   # <- bytt til ønsket 2024-kommunenummer
KOMMUNE_NAVN <- "Eigersund"  # <- kun brukt i plottittelen

## ============================================================================
## 1. Kommunehistorikk og gyldige koder per tabell (samme mønster som
##    hent_paneldata_2007_2025.R)
## ============================================================================
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

kommunehistorikk <- hent_kommunehistorikk()
koder_hist <- unique(kommunehistorikk$kommunenr_hist[kommunehistorikk$kommunenr_2024 == KOMMUNE_2024])
message("Historiske kommunenummer for ", KOMMUNE_2024, ": ", paste(koder_hist, collapse = ", "))

## ============================================================================
## 2. Hent rå tall for ALLE kommunens historiske koder samtidig - SSB
##    returnerer manglende ("."/NA) for koder som ikke gjaldt et gitt år, så
##    vi filtrerer bort NA i stedet for selv å vite nøyaktig årsintervall
##    per kode.
## ============================================================================
hent_tall <- function(table_id, region_dim, region_koder, cc, years) {
  body <- list(
    query = list(
      list(code = region_dim, selection = list(filter = "item", values = as.list(region_koder))),
      list(code = "ContentsCode", selection = list(filter = "item", values = list(cc))),
      list(code = "Tid", selection = list(filter = "item", values = as.list(as.character(years))))
    ),
    response = list(format = "json")
  )
  resp <- request(paste0("https://data.ssb.no/api/v0/no/table/", table_id, "/")) |>
    req_body_json(body) |> req_timeout(60) |>
    req_error(is_error = function(resp) FALSE) |> req_perform()
  if (resp_status(resp) >= 400 || length(region_koder) == 0) return(data.frame())
  parsed <- resp_body_json(resp, simplifyVector = FALSE)
  if (length(parsed$data) == 0) return(data.frame())
  d <- data.frame(
    region = vapply(parsed$data, function(r) r$key[[1]], character(1)),
    år = as.integer(vapply(parsed$data, function(r) r$key[[2]], character(1))),
    verdi = suppressWarnings(as.numeric(vapply(parsed$data, function(r) r$values[[1]], character(1))))
  )
  d[!is.na(d$verdi), ]
}

gyldige_04686 <- intersect(koder_hist, hent_gyldige_koder("04686", "Region"))
raa_04686 <- hent_tall("04686", "Region", gyldige_04686, "CRC747899133", 2007:2016)
raa_04686$kilde <- "04686 (rå)"

gyldige_12292 <- intersect(koder_hist, hent_gyldige_koder("12292", "KOKkommuneregion0000"))
raa_12292 <- hent_tall("12292", "KOKkommuneregion0000", gyldige_12292, "KOSkjernetotalt0000", 2015:2025)
raa_12292$kilde <- "12292 (rå)"

raa_samlet <- bind_rows(raa_04686, raa_12292)
# NB: sjekkes PER KILDE, ikke på raa_samlet - 2015/2016 finnes med vilje i
# BÅDE 04686 og 12292 (det er selve overlappet vi vil se etter i punkt 4),
# så en duplikatsjekk på den sammenslåtte tabellen ville alltid slått ut der.
if (anyDuplicated(raa_04686$år) || anyDuplicated(raa_12292$år)) {
  warning("Flere av kommunens historiske koder ga data for SAMME år i samme ",
          "tabell - dette tyder på en periode med overlappende/feil koder.")
}

## ============================================================================
## 3. Den sammensatte serien vi faktisk bruker i modellene
## ============================================================================
paneldata <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur.rds"))
kommune_sammensatt <- paneldata[paneldata$kommunenr_2024 == KOMMUNE_2024,
                                 c("år", "Y_1_a_ialt")]

## ============================================================================
## 4. Kontroller overlappet (2015-2016) tallmessig, ikke bare visuelt
## ============================================================================
overlapp <- merge(raa_04686[c("år", "verdi")], raa_12292[c("år", "verdi")],
                   by = "år", suffixes = c("_04686", "_12292"))
if (nrow(overlapp)) {
  message("Overlapp 04686 vs. 12292 (bør være like eller svært nære):")
  print(overlapp)
} else {
  message("Ingen overlappende år funnet mellom 04686 og 12292 for denne kommunen.")
}

## ============================================================================
## 5. Plott
## ============================================================================
p <- ggplot() +
  geom_line(data = kommune_sammensatt, aes(x = år, y = Y_1_a_ialt),
            color = "grey40", linewidth = 0.8) +
  geom_point(data = raa_samlet, aes(x = år, y = verdi, color = kilde, shape = kilde),
             size = 3) +
  geom_vline(xintercept = 2016.5, linetype = "dashed", color = "grey70") +
  annotate("text", x = 2016.5, y = max(kommune_sammensatt$Y_1_a_ialt, na.rm = TRUE),
           label = "skjøtepunkt 04686 -> 12292", hjust = -0.05, size = 3, color = "grey50") +
  scale_color_manual(values = c("04686 (rå)" = "#D55E00", "12292 (rå)" = "#0072B2")) +
  labs(title = paste0(KOMMUNE_NAVN, " (", KOMMUNE_2024, "): Y_1_a_ialt (brukere av hjemmetjenester i alt)"),
       subtitle = "Grå linje = sammensatt serie brukt i modellene. Punkter = rå tall direkte fra SSB.",
       x = "År", y = "Antall brukere", color = "Kilde", shape = "Kilde") +
  theme_minimal()

utfil <- file.path(utmappe, paste0("plott_y1_", KOMMUNE_2024, ".png"))
ggsave(utfil, p, width = 9, height = 5.5, dpi = 150)
message("Plott lagret: ", normalizePath(utfil))
