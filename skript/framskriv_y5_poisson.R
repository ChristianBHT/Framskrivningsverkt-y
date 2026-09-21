# framskriv_y5_poisson.R
#
# Framskriver den ALTERNATIVE Y_5-modellen (Poisson, se modell_y5_poisson.R)
# med nøyaktig samme metode som framskriv_y5.R: hovedmodell_slope ankret ved
# kommunens siste observerte (2025) demensandel, gjennomsnittlig årseffekt
# for framtidige år, og glidende overgang mot observert 2025-nivå over hele
# framskrivningsperioden (se framskriv_y1.R for full begrunnelse).
#
# Befolkning/demensandel 2026-2050 er uavhengig av modellvalg og gjenbrukes
# fra den allerede lagrede framskrevet_y5.rds (ingen nye SSB-kall) - samme
# fremgangsmåte som usikkerhet_*.R. Kjør framskriv_y5.R først.
#
# Ingen usikkerhetsintervall beregnes for denne alternative modellen.
#
# Forutsetning: kjør modell_y5_poisson.R og framskriv_y5.R først.

library(lme4)
library(dplyr)

utmappe <- file.path("data", "ssb")

STARTAAR_OVERGANG <- 2026
START_ANDEL_OBSERVERT <- 0.9
SISTE_OBSERVERTE_AR <- 2025

modell <- readRDS(file.path(utmappe, "modell_y5p_hovedmodell_slope.rds"))
historisk <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
historisk$demensandel <- historisk$demens_estimert / historisk$folk_ialt

demensandel_anker <- historisk |>
  filter(år == SISTE_OBSERVERTE_AR) |>
  transmute(kommunenr_2024, demensandel_anker = demensandel)
siste_observert <- historisk |>
  filter(år == SISTE_OBSERVERTE_AR) |>
  transmute(kommunenr_2024, observert = Y_5_ialt)

framtidsdata <- readRDS(file.path(utmappe, "framskrevet_y5.rds")) |>
  select(kommunenr_2024, år, folk_ialt, demens_estimert, demensandel) |>
  distinct() |>
  left_join(demensandel_anker, by = "kommunenr_2024")

faste <- fixef(modell)
aar_effekt_framskrevet <- mean(faste[grepl("^år_f", names(faste))])
re <- ranef(modell)$kommunenr_2024
d <- framtidsdata[as.character(framtidsdata$kommunenr_2024) %in% rownames(re), ]
k <- as.character(d$kommunenr_2024)

intercept_prime <- faste[["(Intercept)"]] + re[k, "(Intercept)"] +
  (faste[["demensandel"]] + re[k, "demensandel"]) * d$demensandel_anker
lin_pred <- intercept_prime + aar_effekt_framskrevet +
  faste[["demensandel"]] * (d$demensandel - d$demensandel_anker) +
  log(d$folk_ialt)
d$y5p_predikert <- as.numeric(exp(lin_pred))

sluttaar <- max(d$år)
m <- merge(d, siste_observert, by = "kommunenr_2024", all.x = TRUE)
vekt <- pmax(0, START_ANDEL_OBSERVERT * (sluttaar - m$år) / (sluttaar - STARTAAR_OVERGANG))
m$y5p_predikert_modell <- m$y5p_predikert
m$y5p_predikert <- ifelse(is.na(m$observert), m$y5p_predikert_modell,
                           vekt * m$observert + (1 - vekt) * m$y5p_predikert_modell)
m$observert <- NULL
m$demensandel_anker <- NULL

saveRDS(m, file.path(utmappe, "framskrevet_y5_poisson.rds"))
write.csv(m, file.path(utmappe, "framskrevet_y5_poisson.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")
message("Lagret framskrivning (Poisson, Y_5) for ", length(unique(m$kommunenr_2024)),
        " kommuner, ", length(unique(m$år)), " år")
