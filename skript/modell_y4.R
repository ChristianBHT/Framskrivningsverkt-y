# modell_y4.R
#
# Estimerer Y_4 (gjennomsnittlig antall tildelte timer i uken, helsetjenester
# i hjemmet) som funksjon av årseffekter, demensandel og en tilfeldig
# kommuneeffekt - men med LINEÆR regresjon (lmer), IKKE Poisson som for
# Y_1/Y_2*: Y_4 er allerede et gjennomsnitt (timer/uke per bruker), ikke et
# antall, så en telledata-modell med log-lenke og befolkning som eksponering
# gir ikke mening her. Ingen offset i denne modellen.
#
# FORVENTET SVAKERE MODELL enn Y_1/Y_2*: Y_4 er et gjennomsnitt beregnet over
# et lite antall brukere i mange (særlig små) kommuner, og trolig langt mer
# støyfullt fra år til år enn et brukerantall. Variabelen spenner fra 0,7 til
# 31,9 timer/uke (median 4,0) - den høye maksverdien tyder på nettopp slik
# støy/små-tall-variasjon i enkeltkommuner. Se CV-resultatene under for hvor
# mye dette faktisk svekker prediktiv treffsikkerhet.
#
# OM 2010: sjekket spesifikt for Y_4 - INGEN tilsvarende anomali som for Y_1
# (Halden 4,7->5,0->4,5->3,6 i 2008-2011, Trondheim helt stabil rundt 1,5,
# Eigersund har år-til-år-støy men ikke et brått kollaps-og-gjenopprettings-
# mønster). 2010 er derfor IKKE utelatt her.
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
  filter(!is.na(Y_4_ialt), !is.na(demensandel), !is.na(Y_1_a_ialt), Y_4_ialt >= 0) |>
  mutate(kommunenr_2024 = factor(kommunenr_2024), år_f = factor(år))

message(nrow(paneldata) - nrow(modelldata), " av ", nrow(paneldata),
        " kommune-år utelatt pga. manglende/ugyldige data.")

## Ingen offset(log(folk_ialt)) her - Y_4 er allerede et gjennomsnitt, ikke
## et antall som skal normeres mot befolkning.
##
## Y_1_a_ialt (antall hjemmetjenestemottakere) er lagt til som forklarings-
## variabel på oppfordring - testes RÅTT (ikke som andel av befolkningen),
## så tolk koeffisienten i lys av at den også kan fange opp ren
## kommunestørrelse (Y_1_a_ialt korrelerer sterkt med folk_ialt, og modellen
## har ingen eksponeringsledd som ellers ville nøytralisert dette).
FORMEL <- Y_4_ialt ~ år_f + demensandel + Y_1_a_ialt + (1 | kommunenr_2024)
FORMEL_SLOPE <- Y_4_ialt ~ år_f + demensandel + Y_1_a_ialt + (1 + demensandel | kommunenr_2024)
FORMEL_SLOPE_UNCORR <- Y_4_ialt ~ år_f + demensandel + Y_1_a_ialt +
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

## Samme sjekk som for Y_1/Y_2*: andel kommuner der fast + tilfeldig helning
## på demensandel bytter fortegn (mindre alarmerende her enn for et
## brukerantall, siden Y_4 er mer støyfullt til å begynne med - men fortsatt
## relevant hvis modellen skal brukes til framskrivning).
eff_slope_korr <- fixef(hovedmodell_slope)[["demensandel"]] +
  ranef(hovedmodell_slope)$kommunenr_2024[["demensandel"]]
eff_slope_ukorr <- fixef(hovedmodell_slope_uncorr)[["demensandel"]] +
  ranef(hovedmodell_slope_uncorr)$kommunenr_2024[["demensandel"]]
message("\n--- Andel kommuner med NEGATIV effektiv helning på demensandel ---")
message("Korrelert:   ", sum(eff_slope_korr < 0), " av ", length(eff_slope_korr))
message("Ukorrelert:  ", sum(eff_slope_ukorr < 0), " av ", length(eff_slope_ukorr))

## ============================================================================
## 3. Leave-one-year-out kryssvalidering (lineær variant - ingen log/offset)
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

  utfall <- all.vars(formel)[1]  # "Y_4_ialt"

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
    y1_koef <- faste[["Y_1_a_ialt"]]
    aar_koef <- faste[grepl("^år_f", names(faste))]
    aar_effekt_testaar <- mean(aar_koef)

    kjente_kommuner <- rownames(ranef(modell)$kommunenr_2024)
    kjent <- as.character(test$kommunenr_2024) %in% kjente_kommuner
    if (!all(kjent)) {
      warning(sum(!kjent), " kommune(r) i testår ", testaar,
              " fantes ikke i treningsdataene og utelates fra evalueringen.")
      test <- test[kjent, ]
    }

    # Ingen log/eksponensiering her - lineær modell, identitetslenke.
    prediksjon <- intercept + aar_effekt_testaar +
      demens_koef * test$demensandel +
      y1_koef * test$Y_1_a_ialt +
      re_bidrag(modell, "kommunenr_2024", test)

    data.frame(
      år = testaar,
      kommunenr_2024 = test$kommunenr_2024,
      observert = test[[utfall]],
      predikert = as.numeric(prediksjon)
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
message("Til sammenligning, observert Y_4 spenner: ",
        paste(round(range(modelldata$Y_4_ialt), 1), collapse = " - "),
        " (median ", round(median(modelldata$Y_4_ialt), 1), ") - se RMSE/MAE over i lys av dette.")

message("\n--- Leave-one-year-out kryssvalidering: intercept + helning (alle år) ---")
cv_resultat_slope <- loyo_cv(modelldata, formel = FORMEL_SLOPE)
message("Resultat per utelatt år:")
print(cv_resultat_slope$metrikker_per_aar)
message("\nSamlet over alle utelatte år:")
print(cv_resultat_slope$samlet)

message("\n--- Sammenligning av samlet CV-treffsikkerhet (lavest rmse/mae er best) ---")
print(rbind(intercept = cv_resultat$samlet, intercept_og_helning = cv_resultat_slope$samlet))

## ---- Lagre -------------------------------------------------------------
saveRDS(hovedmodell, file.path(utmappe, "modell_y4_hovedmodell.rds"))
saveRDS(hovedmodell_slope, file.path(utmappe, "modell_y4_hovedmodell_slope.rds"))
saveRDS(hovedmodell_slope_uncorr, file.path(utmappe, "modell_y4_hovedmodell_slope_uncorr.rds"))
saveRDS(cv_resultat, file.path(utmappe, "modell_y4_cv_resultat.rds"))
saveRDS(cv_resultat_slope, file.path(utmappe, "modell_y4_cv_resultat_slope.rds"))
write.csv(cv_resultat$prediksjoner,
          file.path(utmappe, "modell_y4_cv_prediksjoner.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message("\nModeller og kryssvalideringsresultater lagret i ", normalizePath(utmappe))
# For å teste kun ett tilfeldig år: loyo_cv(modelldata, formel = FORMEL, n_random = 1, seed = 1)
