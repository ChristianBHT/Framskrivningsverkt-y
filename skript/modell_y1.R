# modell_y1.R
#
# Estimerer Y_1 (brukere av hjemmetjenester, alle aldre) som funksjon av
# årseffekter, demensprevalens og en kommuneeffekt, og validerer modellens
# prediktive treffsikkerhet med leave-one-year-out kryssvalidering.
#
# Modell (Poisson, log-lenke, befolkning som eksponering/offset):
#   log(E[Y_1_a_ialt]) = log(folk_ialt) + årseffekt + b*demensandel + u_kommune
# der u_kommune er en TILFELDIG kommuneeffekt (kommunespesifikt intercept) -
# samme prinsipp ("M1[kommunenr]") som ble brukt gjennomgående i det
# opprinnelige Stata-arbeidet. demensandel = demens_estimert / folk_ialt
# brukes i stedet for rå demens_estimert, fordi et råtall bare ville fanget
# opp kommunestørrelse, som allerede ligger i eksponeringen.
#
# Kryssvalidering (leave-one-year-out): for hvert testår estimeres modellen
# på ALLE ANDRE år og predikerer det utelatte året. NB: en modell med
# årsdummyer kan pr. definisjon ikke ha en egen koeffisient for et år den
# ikke er trent på. Her brukes GJENNOMSNITTET av de andre estimerte
# årseffektene som en enkel erstatning for det utelatte årets effekt (se
# kommentar i loyo_cv()) - dette er en forenkling, ikke en eksakt løsning.
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

# 2010 er utelatt fra estimeringen: stikkprøver i Halden og Eigersund viste
# et brått, proporsjonalt fall (~90 %) i Y_1_a_ialt i ALLE aldersgrupper i
# 2010, med full gjenoppretting i 2011 - et mønster som er langt mer typisk
# for en rapporteringsfeil enn en reell endring i tjenestebruk. 04686s egne
# metadata nevner også en IPLOS-versjonsendring som påvirket sammenlignbarhet
# "for 2009 og senere", noe som kan ha gjort 2010 spesielt utsatt landsdekkende
# (ikke bekreftet systematisk for alle 357 kommuner - se plott_y1_kommune.R
# hvis du vil sjekke flere kommuner før du evt. stoler mer/mindre på dette).
paneldata <- paneldata |> filter(år != 2010)

modelldata <- paneldata |>
  filter(!is.na(Y_1_a_ialt), !is.na(demensandel), !is.na(folk_ialt),
         folk_ialt > 0, Y_1_a_ialt >= 0) |>
  mutate(kommunenr_2024 = factor(kommunenr_2024))

message(nrow(paneldata) - nrow(modelldata), " av ", nrow(paneldata),
        " kommune-år utelatt pga. manglende/ugyldige data (se filter() over; ",
        "2010 er allerede fjernet før dette).")

FORMEL <- Y_1_a_ialt ~ år_f + demensandel + offset(log(folk_ialt)) + (1 | kommunenr_2024)

## Utvidelse: tilfeldig KOMMUNEEFFEKT PÅ HELNINGEN til demensandel, ikke bare
## på intercept. "(1 + demensandel | kommunenr_2024)" gir en korrelert
## tilfeldig intercept OG helning per kommune (dvs. både hvor mange brukere
## en kommune har "i utgangspunktet", og hvor sterkt antall brukere endrer
## seg med demensandelen, får lov til å variere fra kommune til kommune).
## NB: det opprinnelige Stata-arbeidet prøvde nettopp dette ("RC" -
## tilfeldig koeffisient) for flere av utfallene, og fant at det noen ganger
## ga svært sterkt korrelerte latente effekter og passet DÅRLIGERE enn en
## enkel tilfeldig intercept - se derfor alltid på AIC/BIC og
## konvergensvarsler før du bytter til denne modellen i praksis.
FORMEL_SLOPE <- Y_1_a_ialt ~ år_f + demensandel + offset(log(folk_ialt)) +
  (1 + demensandel | kommunenr_2024)

## Variant: SAMME tilfeldig intercept + helning, men UKORRELERT (intercept og
## helning får ikke lov til å kompensere for hverandre). Skrives som to
## separate RE-termer over samme grupperingsvariabel. Testet fordi den
## korrelerte varianten (FORMEL_SLOPE) ga en nesten perfekt korrelasjon
## (-0.97) mellom intercept og helning, som igjen ga en NEGATIV effektiv
## helning (fast + tilfeldig) for 90 av 357 kommuner - dvs. modellen antok at
## flere med demens ga FÆRRE hjemmetjenestebrukere i disse kommunene, noe som
## er substansielt implausibelt og spesielt farlig ved framskrivning utenfor
## det historisk observerte området.
FORMEL_SLOPE_UNCORR <- Y_1_a_ialt ~ år_f + demensandel + offset(log(folk_ialt)) +
  (1 | kommunenr_2024) + (0 + demensandel | kommunenr_2024)

## ============================================================================
## 2. Hovedmodell (estimert på alle tilgjengelige år)
## ============================================================================
modelldata$år_f <- factor(modelldata$år)
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

## Sjekk om ukorrelert helning fjerner problemet med "feil fortegn" - dvs.
## kommuner der fast + tilfeldig helning på demensandel blir negativ.
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
#' @param data Modelldata (må ha kolonnene i FORMEL, pluss `år`).
#' @param formel Modellformel; må bruke `år_f` (årsdummy) og `demensandel`.
#' @param years Hvilke år som skal testes (NULL = alle år i data, dvs.
#'   uttømmende leave-one-year-out).
#' @param n_random Hvis satt: trekk n_random tilfeldige år å teste, i stedet
#'   for `years` - dette er "fjern ett år tilfeldig"-varianten. Bruk
#'   n_random = 1 for akkurat ett tilfeldig år.
#' @param seed Frø for tilfeldig årstrekning (kun brukt hvis n_random er satt).
##
## Beregner radvis bidrag fra ALLE tilfeldige effekter for én
## grupperingsvariabel, uavhengig av om modellen bare har en tilfeldig
## intercept, eller intercept + helning(er) - dette gjør at samme loyo_cv()
## fungerer uendret for både FORMEL (kun intercept) og FORMEL_SLOPE
## (intercept + helning). Kolonnenavn i ranef()-tabellen som matcher et
## kolonnenavn i nydata tolkes som en helning (multipliseres med
## variabelens verdi for den raden); "(Intercept)" legges til direkte.
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
    # Modellen har ingen egen koeffisient for teståret (det er per
    # definisjon ikke i treningsdataene) - vi bruker derfor gjennomsnittet
    # av de ANDRE årenes estimerte effekt som en enkel stand-in. Ønsker du
    # heller lineær interpolasjon mellom nabo-årene, er det denne ene linjen
    # som må endres.
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
      observert = test$Y_1_a_ialt,
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
saveRDS(hovedmodell, file.path(utmappe, "modell_y1_hovedmodell.rds"))
saveRDS(hovedmodell_slope, file.path(utmappe, "modell_y1_hovedmodell_slope.rds"))
saveRDS(cv_resultat, file.path(utmappe, "modell_y1_cv_resultat.rds"))
saveRDS(cv_resultat_slope, file.path(utmappe, "modell_y1_cv_resultat_slope.rds"))
write.csv(cv_resultat$prediksjoner,
          file.path(utmappe, "modell_y1_cv_prediksjoner.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")
write.csv(cv_resultat_slope$prediksjoner,
          file.path(utmappe, "modell_y1_cv_prediksjoner_slope.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message("\nModeller og kryssvalideringsresultater lagret i ", normalizePath(utmappe))
# For å teste kun ett tilfeldig år: loyo_cv(modelldata, formel = FORMEL, n_random = 1, seed = 1)
# For å teste et bestemt sett år:    loyo_cv(modelldata, formel = FORMEL, years = c(2020, 2023))
