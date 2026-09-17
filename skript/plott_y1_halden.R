# plott_y1_halden.R
#
# Plotter den sammensatte Y_1_a_ialt-serien for Halden (2007-2025, fra
# paneldata_2024struktur) sammen med de RÅ tallene hentet direkte fra de to
# underliggende SSB-tabellene (04686 t.o.m. 2016, 12292 f.o.m. 2015) - for å
# visuelt bekrefte at skjøtingen stemmer med det SSB selv rapporterer, og at
# det ikke er noe brudd ved overgangen mellom tabellene.
#
# Installer én gang: install.packages(c("httr2", "ggplot2"))

library(httr2)
library(ggplot2)

utmappe <- file.path("data", "ssb")
HALDEN_2024 <- "3101"

## ============================================================================
## 1. Den sammensatte serien vi faktisk bruker i modellene
## ============================================================================
paneldata <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur.rds"))
halden_sammensatt <- paneldata[paneldata$kommunenr_2024 == HALDEN_2024,
                                c("år", "Y_1_a_ialt", "kommunenr_hist_kilder")]

## ============================================================================
## 2. Rå tall hentet direkte fra SSB, uavhengig av skjøtelogikken vår
## ============================================================================
hent_ett_tall <- function(table_id, region_dim, region, cc, years) {
  body <- list(
    query = list(
      list(code = region_dim, selection = list(filter = "item", values = list(region))),
      list(code = "ContentsCode", selection = list(filter = "item", values = list(cc))),
      list(code = "Tid", selection = list(filter = "item", values = as.list(as.character(years))))
    ),
    response = list(format = "json")
  )
  resp <- request(paste0("https://data.ssb.no/api/v0/no/table/", table_id, "/")) |>
    req_body_json(body) |> req_timeout(60) |> req_perform()
  parsed <- resp_body_json(resp, simplifyVector = FALSE)
  data.frame(
    år = as.integer(vapply(parsed$data, function(r) r$key[[2]], character(1))),
    verdi = as.numeric(vapply(parsed$data, function(r) r$values[[1]], character(1)))
  )
}

raa_04686 <- hent_ett_tall("04686", "Region", "0101", "CRC747899133", 2007:2016)
raa_04686$kilde <- "04686 (rå, kode 0101)"

# Halden byttet kommunenummer to ganger: 0101 (-2019) -> 3001 (Viken 2020-2023)
# -> 3101 (2024-). 12292 bruker år-spesifikk kode, ikke en sammenslått serie.
raa_12292 <- rbind(
  hent_ett_tall("12292", "KOKkommuneregion0000", "0101", "KOSkjernetotalt0000", 2015:2019),
  hent_ett_tall("12292", "KOKkommuneregion0000", "3001", "KOSkjernetotalt0000", 2020:2023),
  hent_ett_tall("12292", "KOKkommuneregion0000", "3101", "KOSkjernetotalt0000", 2024:2025)
)
raa_12292$kilde <- "12292 (rå)"

raa_samlet <- rbind(raa_04686, raa_12292)

## ============================================================================
## 3. Kontroller overlappet (2015-2016) tallmessig, ikke bare visuelt
## ============================================================================
overlapp <- merge(raa_04686[c("år", "verdi")], raa_12292[c("år", "verdi")],
                   by = "år", suffixes = c("_04686", "_12292"))
message("Overlapp 04686 vs. 12292 (bør være like eller svært nære):")
print(overlapp)

## ============================================================================
## 4. Plott
## ============================================================================
p <- ggplot() +
  geom_line(data = halden_sammensatt, aes(x = år, y = Y_1_a_ialt),
            color = "grey40", linewidth = 0.8) +
  geom_point(data = raa_samlet, aes(x = år, y = verdi, color = kilde, shape = kilde),
             size = 3) +
  geom_vline(xintercept = 2016.5, linetype = "dashed", color = "grey70") +
  annotate("text", x = 2016.5, y = max(halden_sammensatt$Y_1_a_ialt, na.rm = TRUE),
           label = "skjøtepunkt 04686 -> 12292", hjust = -0.05, size = 3, color = "grey50") +
  scale_color_manual(values = c("04686 (rå, kode 0101)" = "#D55E00",
                                 "12292 (rå)" = "#0072B2")) +
  labs(title = "Halden: Y_1_a_ialt (brukere av hjemmetjenester i alt)",
       subtitle = "Grå linje = sammensatt serie brukt i modellene. Punkter = rå tall direkte fra SSB.",
       x = "År", y = "Antall brukere", color = "Kilde", shape = "Kilde") +
  theme_minimal()

utfil <- file.path(utmappe, "plott_y1_halden.png")
ggsave(utfil, p, width = 9, height = 5.5, dpi = 150)
message("Plott lagret: ", normalizePath(utfil))
