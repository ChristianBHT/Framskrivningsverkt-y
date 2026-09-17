# modell_y5.R
#
# Estimerer Y_5 (alle sykepleiere, årsverk) som funksjon av årseffekter,
# demensandel og en tilfeldig kommuneeffekt.
#
# MODELLVALG: Y_5 er en additiv størrelse som skalerer sterkt med
# kommunestørrelse (spenner fra ca. 2 til over 3000 årsverk), akkurat som
# Y_1/Y_2* - men i motsetning til disse er årsverk IKKE et heltall, så
# Poisson (glmer) er ikke strengt egnet. Vi bruker derfor en lineær
# blandet modell (lmer) på LOGARITMEN av Y_5, med befolkning som offset
# (koeffisient tvunget til 1, som i Poisson-modellene) - dette gir samme
# multiplikative populasjonsskalering som Y_1/Y_2*, men med normalfordelte
# feil på logskala i stedet for Poisson-varians, som passer bedre for en
# kontinuerlig størrelse.
#
# DATAENS DEKNING: Y_5_ialt mangler HELT for 2007-2014 (sjekket: 100 % NA
# alle disse årene) - tabell 04686 dekker altså IKKE årsverk så langt
# tilbake som de andre variablene, i motsetning til det som opprinnelig
# antatt i hent_paneldata_2007_2025.R sin kildeliste. Reell datadekning er
# 2015-2025 (11 år), vesentlig kortere enn for Y_1/Y_2*/Y_4 - forvent bredere
# konfidensintervaller på årseffekter og svakere kryssvalidering pga. færre
# år å teste/trene på.
#
# MERGER-RETTING: Y_5 ble tidligere (feilaktig) vektet-snitt-slått sammen
# for sammenslåtte kommuner i hent_paneldata_2007_2025.R, samme som Y_4 -
# men Y_5 er en additiv størrelse (årsverk), ikke et snitt, så dette er
# rettet til SUMMERING der (se kommentarer i lag_2024_struktur()). Data er
# regenerert med denne rettingen før dette scriptet ble skrevet.
#
# OM 2010: ikke relevant her - hele 2007-2014 mangler uansett, se over.
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

modelldata <- paneldata |>
  filter(!is.na(Y_5_ialt), !is.na(demensandel), !is.na(folk_ialt),
         folk_ialt > 0, Y_5_ialt > 0) |>
  mutate(kommunenr_2024 = factor(kommunenr_2024), år_f = factor(år))

message(nrow(paneldata) - nrow(modelldata), " av ", nrow(paneldata),
        " kommune-år utelatt pga. manglende/ugyldige data (i hovedsak hele ",
        "2007-2014, som mangler Y_5_ialt helt - reell datadekning er 2015-2025).")

## log(Y_5) ~ ... + offset(log(folk_ialt)): samme populasjonsskalering som
## Poisson-modellene for Y_1/Y_2*, men med normalfordelte feil på logskala.
FORMEL <- log(Y_5_ialt) ~ år_f + demensandel + offset(log(folk_ialt)) + (1 | kommunenr_2024)
FORMEL_SLOPE <- log(Y_5_ialt) ~ år_f + demensandel + offset(log(folk_ialt)) +
  (1 + demensandel | kommunenr_2024)
FORMEL_SLOPE_UNCORR <- log(Y_5_ialt) ~ år_f + demensandel + offset(log(folk_ialt)) +
  (1 | kommunenr_2024) + (0 + demensandel | kommunenr_2024)

## ============================================================================
## 2. Hovedmodeller (estimert på alle tilgjengelige år)
## ============================================================================
hovedmodell <- lmer(FORMEL, data = modelldata)
message("\n--- Hovedmodell: tilfeldig intercept ---")
print(summary(hovedmodell))

hovedmodell_slope <- lmer(FORMEL_SLOPE, data = modelldata, control = lmerControl(optimizer = "bobyqa"))
message("\n--- Hovedmodell: tilfeldig intercept + helning på demensandel (korrelert) ---")
print(summary(hovedmodell_slope))

hovedmodell_slope_uncorr <- lmer(FORMEL_SLOPE_UNCORR, data = modelldata, control = lmerControl(optimizer = "bobyqa"))
message("\n--- Hovedmodell: tilfeldig intercept + helning på demensandel (ukorrelert) ---")
print(summary(hovedmodell_slope_uncorr))

message("\n--- Sammenligning (foretrekk lavest AIC/BIC, se også konvergensvarsler over) ---")
print(anova(hovedmodell, hovedmodell_slope_uncorr, hovedmodell_slope))

## Samme sjekk som for Y_1/Y_2*/Y_4: andel kommuner der fast + tilfeldig
## helning på demensandel bytter fortegn.
eff_slope_korr <- fixef(hovedmodell_slope)[["demensandel"]] +
  ranef(hovedmodell_slope)$kommunenr_2024[["demensandel"]]
eff_slope_ukorr <- fixef(hovedmodell_slope_uncorr)[["demensandel"]] +
  ranef(hovedmodell_slope_uncorr)$kommunenr_2024[["demensandel"]]
message("\n--- Andel kommuner med NEGATIV effektiv helning på demensandel ---")
message("Korrelert:   ", sum(eff_slope_korr < 0), " av ", length(eff_slope_korr))
message("Ukorrelert:  ", sum(eff_slope_ukorr < 0), " av ", length(eff_slope_ukorr))

## ============================================================================
## 3. Leave-one-year-out kryssvalidering
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

  resultater <- lapply(years, function(testaar) {
    trening <- data[data$år != testaar, ]
    trening$år_f <- factor(trening$år)
    test <- data[data$år == testaar, ]

    modell <- tryCatch(
      lmer(formel, data = trening),
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
      observert = test$Y_5_ialt,
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
message("Til sammenligning, observert Y_5 spenner: ",
        paste(round(range(modelldata$Y_5_ialt), 1), collapse = " - "),
        " (median ", round(median(modelldata$Y_5_ialt), 1), ") - se RMSE/MAE over i lys av dette.")

message("\n--- Leave-one-year-out kryssvalidering: intercept + helning (alle år) ---")
cv_resultat_slope <- loyo_cv(modelldata, formel = FORMEL_SLOPE)
message("Resultat per utelatt år:")
print(cv_resultat_slope$metrikker_per_aar)
message("\nSamlet over alle utelatte år:")
print(cv_resultat_slope$samlet)

message("\n--- Sammenligning av samlet CV-treffsikkerhet (lavest rmse/mae er best) ---")
print(rbind(intercept = cv_resultat$samlet, intercept_og_helning = cv_resultat_slope$samlet))

## ---- Lagre -------------------------------------------------------------
saveRDS(hovedmodell, file.path(utmappe, "modell_y5_hovedmodell.rds"))
saveRDS(hovedmodell_slope, file.path(utmappe, "modell_y5_hovedmodell_slope.rds"))
saveRDS(hovedmodell_slope_uncorr, file.path(utmappe, "modell_y5_hovedmodell_slope_uncorr.rds"))
saveRDS(cv_resultat, file.path(utmappe, "modell_y5_cv_resultat.rds"))
saveRDS(cv_resultat_slope, file.path(utmappe, "modell_y5_cv_resultat_slope.rds"))
write.csv(cv_resultat$prediksjoner,
          file.path(utmappe, "modell_y5_cv_prediksjoner.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message("\nModeller og kryssvalideringsresultater lagret i ", normalizePath(utmappe))
# For å teste kun ett tilfeldig år: loyo_cv(modelldata, formel = FORMEL, n_random = 1, seed = 1)
