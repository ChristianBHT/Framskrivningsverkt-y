# modell_y2_stjerne.R
#
# Estimerer Y_2* = Y_2_ialt + Y_3_a_ialt ("heldøgns omsorg i alt": beboere i
# bolig m/ heldøgns bemanning + beboere i institusjon med langtidsopphold) -
# altså den samme "mottakere av heldøgns omsorg"-definisjonen som ble brukt
# tidlig i prosjektet (se databestilling.docx/plan_23_nov_24.docx: langtids-
# opphold i institusjon + bolig m/ heldøgns bemanning).
#
# Samme modellstruktur som Y_1 (se modell_y1.R): Poisson-regresjon med
# årsdummyer, demensandel som forklaringsvariabel, befolkning som
# eksponering (offset), og en tilfeldig kommuneeffekt - testet både som kun
# intercept og med tilfeldig helning på demensandel (korrelert/ukorrelert),
# for å kunne gjøre samme vurdering som for Y_1 av om helningen er trygg å
# bruke til framskrivning.
#
# OM 2010: for Y_1 fant vi at 2010 hadde et brått, sannsynlig
# rapporteringsfeil-drevet fall i ALLE aldersgrupper (se plott_y1_kommune.R).
# Dette er SJEKKET FOR Y_2*/Y_3 SPESIFIKT og gjentar seg IKKE på samme måte:
# Halden har helt normale 2010-verdier for både Y_2_ialt (364->380->381,
# 2009-2011) og Y_3_a_ialt (148->153->135), og selv Eigersunds litt lave
# Y_3_a_ialt i 2010 (26->8->38) er langt mildere enn Y_1s ~90 % kollaps og
# kan være ordinær støy i en liten kommune. 2010 er derfor IKKE utelatt her.
#
# Forutsetning: kjør hent_paneldata_2007_2025.R og legg_til_demens.R først.
#
# Installer én gang: install.packages(c("lme4", "dplyr"))

library(lme4)
library(dplyr)

utmappe <- file.path("data", "ssb")

## ============================================================================
## 1. Last inn og klargjør data
## ============================================================================
paneldata <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
paneldata$demensandel <- paneldata$demens_estimert / paneldata$folk_ialt
paneldata$Y_2_stjerne_ialt <- paneldata$Y_2_ialt + paneldata$Y_3_a_ialt

modelldata <- paneldata |>
  filter(!is.na(Y_2_stjerne_ialt), !is.na(demensandel), !is.na(folk_ialt),
         folk_ialt > 0, Y_2_stjerne_ialt >= 0) |>
  mutate(kommunenr_2024 = factor(kommunenr_2024), år_f = factor(år))

message(nrow(paneldata) - nrow(modelldata), " av ", nrow(paneldata),
        " kommune-år utelatt pga. manglende/ugyldige data (Y_2_ialt og/eller ",
        "Y_3_a_ialt mangler for en del kommuner/år - Y_2_ialt har generelt ",
        "dårligere KOSTRA-dekning enn Y_3_a_ialt, se kommentarer i ",
        "hent_paneldata_2007_2025.R).")

FORMEL <- Y_2_stjerne_ialt ~ år_f + demensandel + offset(log(folk_ialt)) + (1 | kommunenr_2024)
FORMEL_SLOPE <- Y_2_stjerne_ialt ~ år_f + demensandel + offset(log(folk_ialt)) +
  (1 + demensandel | kommunenr_2024)
FORMEL_SLOPE_UNCORR <- Y_2_stjerne_ialt ~ år_f + demensandel + offset(log(folk_ialt)) +
  (1 | kommunenr_2024) + (0 + demensandel | kommunenr_2024)

## ============================================================================
## 2. Hovedmodeller (estimert på alle tilgjengelige år)
## ============================================================================
hovedmodell <- glmer(FORMEL, data = modelldata, family = poisson)
message("\n--- Hovedmodell: tilfeldig intercept ---")
print(summary(hovedmodell))

hovedmodell_slope <- glmer(FORMEL_SLOPE, data = modelldata, family = poisson,
                            control = glmerControl(optimizer = "bobyqa"))
message("\n--- Hovedmodell: tilfeldig intercept + helning på demensandel (korrelert) ---")
print(summary(hovedmodell_slope))

hovedmodell_slope_uncorr <- glmer(FORMEL_SLOPE_UNCORR, data = modelldata, family = poisson,
                                   control = glmerControl(optimizer = "bobyqa"))
message("\n--- Hovedmodell: tilfeldig intercept + helning på demensandel (ukorrelert) ---")
print(summary(hovedmodell_slope_uncorr))

message("\n--- Sammenligning (foretrekk lavest AIC/BIC, se også konvergensvarsler over) ---")
print(anova(hovedmodell, hovedmodell_slope_uncorr, hovedmodell_slope))

## Sjekk om noen av helningsvariantene gir samme "feil fortegn"-problem som
## ble funnet for Y_1 (se modell_y1.R): kommuner der fast + tilfeldig helning
## på demensandel blir negativ, dvs. modellen antar FÆRRE heldøgns
## omsorgsmottakere når demensandelen stiger.
eff_slope_korr <- fixef(hovedmodell_slope)[["demensandel"]] +
  ranef(hovedmodell_slope)$kommunenr_2024[["demensandel"]]
eff_slope_ukorr <- fixef(hovedmodell_slope_uncorr)[["demensandel"]] +
  ranef(hovedmodell_slope_uncorr)$kommunenr_2024[["demensandel"]]
message("\n--- Andel kommuner med NEGATIV effektiv helning på demensandel ---")
message("Korrelert:   ", sum(eff_slope_korr < 0), " av ", length(eff_slope_korr))
message("Ukorrelert:  ", sum(eff_slope_ukorr < 0), " av ", length(eff_slope_ukorr))

## ============================================================================
## 3. Leave-one-year-out kryssvalidering (samme funksjon som i modell_y1.R)
## ============================================================================
re_bidrag <- function(modell, gruppevar, nydata) {
  re_df <- ranef(modell)[[gruppevar]]
  grupper <- as.character(nydata[[gruppevar]])
  bidrag <- numeric(nrow(nydata))
  for (kolonne in names(re_df)) {
    verdier <- re_df[grupper, kolonne]
    if (identical(kolonne, "(Intercept)")) {
      bidrag <- bidrag + verdier
    } else {
      bidrag <- bidrag + verdier * nydata[[kolonne]]
    }
  }
  bidrag
}

#' @param data Modelldata (må ha kolonnene i FORMEL, pluss `år`).
#' @param formel Modellformel; må bruke `år_f` (årsdummy) og `demensandel`.
#' @param years Hvilke år som skal testes (NULL = alle år i data).
#' @param n_random Trekk n_random tilfeldige år å teste, i stedet for `years`.
#' @param seed Frø for tilfeldig årstrekning (kun brukt hvis n_random er satt).
loyo_cv <- function(data, formel = FORMEL, years = NULL, n_random = NULL, seed = NULL) {
  alle_aar <- sort(unique(data$år))
  if (!is.null(n_random)) {
    if (!is.null(seed)) set.seed(seed)
    years <- sample(alle_aar, n_random)
  } else if (is.null(years)) {
    years <- alle_aar
  }

  utfall <- all.vars(formel)[1]  # navnet på utfallsvariabelen, f.eks. "Y_2_stjerne_ialt"

  resultater <- lapply(years, function(testaar) {
    trening <- data[data$år != testaar, ]
    trening$år_f <- factor(trening$år)
    test <- data[data$år == testaar, ]

    modell <- tryCatch(
      glmer(formel, data = trening, family = poisson),
      error = function(e) {
        warning("Modellen konvergerte ikke for testår ", testaar, ": ",
                conditionMessage(e))
        NULL
      }
    )
    if (is.null(modell)) return(NULL)

    faste <- fixef(modell)
    intercept <- faste[["(Intercept)"]]
    demens_koef <- faste[["demensandel"]]
    aar_koef <- faste[grepl("^år_f", names(faste))]
    aar_effekt_testaar <- mean(aar_koef)

    kjente_kommuner <- rownames(ranef(modell)$kommunenr_2024)
    kjent <- as.character(test$kommunenr_2024) %in% kjente_kommuner
    if (!all(kjent)) {
      warning(sum(!kjent), " kommune(r) i testår ", testaar,
              " fantes ikke i treningsdataene og utelates fra evalueringen.")
      test <- test[kjent, ]
    }

    lin_pred <- intercept + aar_effekt_testaar +
      demens_koef * test$demensandel +
      re_bidrag(modell, "kommunenr_2024", test) +
      log(test$folk_ialt)

    data.frame(
      år = testaar,
      kommunenr_2024 = test$kommunenr_2024,
      observert = test[[utfall]],
      predikert = as.numeric(exp(lin_pred))
    )
  })

  prediksjoner <- bind_rows(resultater)

  metrikker_per_aar <- prediksjoner |>
    group_by(år) |>
    summarise(
      rmse = sqrt(mean((observert - predikert)^2)),
      mae = mean(abs(observert - predikert)),
      korrelasjon = suppressWarnings(cor(observert, predikert)),
      n = n(),
      .groups = "drop"
    )

  samlet <- data.frame(
    rmse = sqrt(mean((prediksjoner$observert - prediksjoner$predikert)^2)),
    mae = mean(abs(prediksjoner$observert - prediksjoner$predikert)),
    korrelasjon = cor(prediksjoner$observert, prediksjoner$predikert),
    n = nrow(prediksjoner)
  )

  list(prediksjoner = prediksjoner, metrikker_per_aar = metrikker_per_aar, samlet = samlet)
}

message("\n--- Leave-one-year-out kryssvalidering: tilfeldig intercept (alle år) ---")
cv_resultat <- loyo_cv(modelldata, formel = FORMEL)
message("Resultat per utelatt år:")
print(cv_resultat$metrikker_per_aar)
message("\nSamlet over alle utelatte år:")
print(cv_resultat$samlet)

message("\n--- Leave-one-year-out kryssvalidering: intercept + helning (alle år) ---")
cv_resultat_slope <- loyo_cv(modelldata, formel = FORMEL_SLOPE)
message("Resultat per utelatt år:")
print(cv_resultat_slope$metrikker_per_aar)
message("\nSamlet over alle utelatte år:")
print(cv_resultat_slope$samlet)

message("\n--- Sammenligning av samlet CV-treffsikkerhet (lavest rmse/mae er best) ---")
print(rbind(intercept = cv_resultat$samlet, intercept_og_helning = cv_resultat_slope$samlet))

## ---- Lagre -------------------------------------------------------------
saveRDS(hovedmodell, file.path(utmappe, "modell_y2s_hovedmodell.rds"))
saveRDS(hovedmodell_slope, file.path(utmappe, "modell_y2s_hovedmodell_slope.rds"))
saveRDS(hovedmodell_slope_uncorr, file.path(utmappe, "modell_y2s_hovedmodell_slope_uncorr.rds"))
saveRDS(cv_resultat, file.path(utmappe, "modell_y2s_cv_resultat.rds"))
saveRDS(cv_resultat_slope, file.path(utmappe, "modell_y2s_cv_resultat_slope.rds"))
write.csv(cv_resultat$prediksjoner,
          file.path(utmappe, "modell_y2s_cv_prediksjoner.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message("\nModeller og kryssvalideringsresultater lagret i ", normalizePath(utmappe))
# For å teste kun ett tilfeldig år: loyo_cv(modelldata, formel = FORMEL, n_random = 1, seed = 1)
