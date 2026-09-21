# modell_y5_poisson.R
#
# ALTERNATIV estimering av Y_5 (sykepleierårsverk): Poisson GLMM (log-lenke,
# befolkning som offset) - SAMME modellfamilie som Y_1 og Y_2* (se
# modell_y1.R), i stedet for hovedmodellen i modell_y5.R (lmer på log(Y_5)).
#
# NB: årsverk er ikke heltall, mens Poisson-likelihooden formelt forutsetter
# heltall. Modellen estimeres her på de opprinnelige (ikke-avrundede)
# årsverkene - dvs. en Poisson pseudo-likelihood ("PPML"), som gir
# konsistente estimater av forventningsverdien så lenge middelverdi-
# strukturen er riktig spesifisert, selv om Poisson-variansantakelsen ikke
# holder. lme4 gir en advarsel om ikke-heltall; den undertrykkes under.
# Standardfeil/likelihood-baserte mål (AIC osv.) er derfor IKKE strengt
# gyldige for denne modellen - bruk kryssvalideringen under for å vurdere den.
#
# Estimerer kun helningsvarianten (`(1 + demensandel | kommune)`), siden det
# er den som brukes i framskrivningen (ankret ved 2025-nivået, se
# framskriv_y1.R). Data: 2015-2025 (Y_5 mangler for 2007-2014, se
# modell_y5.R).
#
# Forutsetning: kjør hent_paneldata_2007_2025.R og legg_til_demens.R først.

library(lme4)
library(dplyr)

utmappe <- file.path("data", "ssb")

paneldata <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
paneldata$demensandel <- paneldata$demens_estimert / paneldata$folk_ialt

modelldata <- paneldata |>
  filter(!is.na(Y_5_ialt), !is.na(demensandel), !is.na(folk_ialt),
         folk_ialt > 0, Y_5_ialt >= 0) |>
  mutate(kommunenr_2024 = factor(kommunenr_2024), år_f = factor(år))

FORMEL_SLOPE <- Y_5_ialt ~ år_f + demensandel + offset(log(folk_ialt)) +
  (1 + demensandel | kommunenr_2024)

hovedmodell_slope <- suppressWarnings(
  glmer(FORMEL_SLOPE, data = modelldata, family = poisson,
        control = glmerControl(optimizer = "bobyqa"))
)
message("\n--- Poisson (PPML) hovedmodell_slope, Y_5 ---")
print(summary(hovedmodell_slope))

eff_slope <- fixef(hovedmodell_slope)[["demensandel"]] +
  ranef(hovedmodell_slope)$kommunenr_2024[["demensandel"]]
message("Kommuner med NEGATIV effektiv helning: ", sum(eff_slope < 0), " av ", length(eff_slope))

## ---- Leave-one-year-out kryssvalidering (samme prinsipp som modell_y1.R) ----
loyo_cv <- function(data, formel = FORMEL_SLOPE) {
  resultater <- lapply(sort(unique(data$år)), function(testaar) {
    trening <- data[data$år != testaar, ]
    trening$år_f <- factor(trening$år)
    test <- data[data$år == testaar, ]

    modell <- tryCatch(
      suppressWarnings(glmer(formel, data = trening, family = poisson,
                             control = glmerControl(optimizer = "bobyqa"))),
      error = function(e) NULL)
    if (is.null(modell)) return(NULL)

    faste <- fixef(modell)
    aar_effekt <- mean(faste[grepl("^år_f", names(faste))])
    re <- ranef(modell)$kommunenr_2024
    test <- test[as.character(test$kommunenr_2024) %in% rownames(re), ]
    k <- as.character(test$kommunenr_2024)

    lin_pred <- faste[["(Intercept)"]] + aar_effekt +
      faste[["demensandel"]] * test$demensandel +
      re[k, "(Intercept)"] + re[k, "demensandel"] * test$demensandel +
      log(test$folk_ialt)

    data.frame(år = testaar, kommunenr_2024 = test$kommunenr_2024,
               observert = test$Y_5_ialt, predikert = as.numeric(exp(lin_pred)))
  })
  p <- bind_rows(resultater)
  list(prediksjoner = p,
       samlet = data.frame(rmse = sqrt(mean((p$observert - p$predikert)^2)),
                           mae = mean(abs(p$observert - p$predikert)),
                           korrelasjon = cor(p$observert, p$predikert),
                           n = nrow(p)))
}

message("\n--- Leave-one-year-out kryssvalidering (Poisson, intercept + helning) ---")
cv_resultat <- loyo_cv(modelldata)
print(cv_resultat$samlet)

saveRDS(hovedmodell_slope, file.path(utmappe, "modell_y5p_hovedmodell_slope.rds"))
saveRDS(cv_resultat, file.path(utmappe, "modell_y5p_cv_resultat_slope.rds"))
message("\nLagret modell_y5p_hovedmodell_slope.rds i ", normalizePath(utmappe))
