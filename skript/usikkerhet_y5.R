# usikkerhet_y5.R
#
# Kvantifiserer usikkerhet i framskrivningen av Y_5 (sykepleierårsverk) med
# samme metode som usikkerhet_y1.R: en Bayesiansk bootstrap PÅ KOMMUNE-NIVÅ
# (én Dirichlet(1,...,1)-vekt per kommune per iterasjon, samme vekt for alle
# år i den kommunen), refit av hovedmodellen med disse vektene,
# framskrivning med glidende overgang, og til slutt et 95 %
# konfidensintervall fra persentilene over iterasjonene. Se usikkerhet_y1.R
# for full begrunnelse (vektskalering, gjenbruk av befolkningsframskrivning,
# og hvorfor kun oppsummeringen - ikke alle enkeltframskrivningene - lagres).
#
# NB: modell_y5.R er en `lmer` (lineær, ikke Poisson) på log(Y_5), med
# befolkning som offset - se modell_y5.R for hvorfor. Refit her bruker derfor
# `lmer(..., weights = )`, ikke `glmer(..., family = poisson, weights = )`
# som i usikkerhet_y1.R/usikkerhet_y2_stjerne.R, men ELLERS samme prinsipp:
# `weights` er en presisjonsvekt som skaleres til gjennomsnitt 1.
#
# Forutsetning: kjør modell_y5.R og framskriv_y5.R først.
#
# Installer én gang: install.packages(c("lme4", "dplyr"))

library(lme4)
library(dplyr)

utmappe <- file.path("data", "ssb")

ANTALL_BOOTSTRAP <- 60
SEED <- 1

## ============================================================================
## 1. Last inn modelldata (nøyaktig samme filtrering som modell_y5.R)
## ============================================================================
paneldata <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
paneldata$demensandel <- paneldata$demens_estimert / paneldata$folk_ialt

modelldata <- paneldata |>
  filter(!is.na(Y_5_ialt), !is.na(demensandel), !is.na(folk_ialt),
         folk_ialt > 0, Y_5_ialt > 0) |>
  mutate(kommunenr_2024 = factor(kommunenr_2024), år_f = factor(år))

## Bruker BEVISST hovedmodell_slope (samme FORMEL_SLOPE som modell_y5.R),
## IKKE intercept-only-varianten - se framskriv_y1.R for begrunnelsen.
FORMEL_SLOPE <- log(Y_5_ialt) ~ år_f + demensandel + offset(log(folk_ialt)) +
  (1 + demensandel | kommunenr_2024)

## ============================================================================
## 2. Gjenbruk befolkningsframskrivning + siste observerte år (ingen SSB-kall)
## ============================================================================
message("Leser allerede beregnet befolkningsframskrivning fra framskrevet_y5.rds...")
framskrevet_eksisterende <- readRDS(file.path(utmappe, "framskrevet_y5.rds"))

SISTE_OBSERVERTE_AR <- 2025
demensandel_anker <- paneldata |>
  filter(år == SISTE_OBSERVERTE_AR) |>
  transmute(kommunenr_2024, demensandel_anker = demensandel)
siste_observert <- paneldata |>
  filter(år == SISTE_OBSERVERTE_AR) |>
  transmute(kommunenr_2024, y5_observert = Y_5_ialt)

framtidsdata <- framskrevet_eksisterende |>
  select(kommunenr_2024, år, folk_ialt, demens_estimert, demensandel) |>
  distinct() |>
  left_join(demensandel_anker, by = "kommunenr_2024")

## ============================================================================
## 3. Hjelpefunksjon (samme anker-metode som framskriv_y5.R)
## ============================================================================
framskriv_y5 <- function(modell, framtidsdata) {
  faste <- fixef(modell)
  intercept <- faste[["(Intercept)"]]
  demens_koef <- faste[["demensandel"]]
  aar_koef <- faste[grepl("^år_f", names(faste))]
  aar_effekt_framskrevet <- mean(aar_koef)

  re <- ranef(modell)$kommunenr_2024
  kjent <- as.character(framtidsdata$kommunenr_2024) %in% rownames(re)
  if (!all(kjent)) framtidsdata <- framtidsdata[kjent, ]

  u_intercept <- re[as.character(framtidsdata$kommunenr_2024), "(Intercept)"]
  u_slope <- re[as.character(framtidsdata$kommunenr_2024), "demensandel"]

  ## Log-lineær-med-offset-form (se modell_y5.R) - eksponensier tilbake til
  ## opprinnelig skala (årsverk).
  intercept_prime <- intercept + u_intercept +
    (demens_koef + u_slope) * framtidsdata$demensandel_anker
  delta_demensandel <- framtidsdata$demensandel - framtidsdata$demensandel_anker

  lin_pred <- intercept_prime + aar_effekt_framskrevet +
    demens_koef * delta_demensandel +
    log(framtidsdata$folk_ialt)

  framtidsdata$y5_predikert <- as.numeric(exp(lin_pred))
  framtidsdata
}

STARTAAR_OVERGANG <- 2026
SLUTTAAR_OVERGANG <- max(framtidsdata$år)
START_ANDEL_OBSERVERT <- 0.9

glatt_overgang <- function(framskrevet_raa, siste_observert) {
  d <- merge(framskrevet_raa, siste_observert, by = "kommunenr_2024", all.x = TRUE)
  vekt <- pmax(0, START_ANDEL_OBSERVERT *
                 (SLUTTAAR_OVERGANG - d$år) / (SLUTTAAR_OVERGANG - STARTAAR_OVERGANG))
  d$y5_predikert_modell <- d$y5_predikert
  d$y5_predikert <- ifelse(is.na(d$y5_observert), d$y5_predikert_modell,
                            vekt * d$y5_observert + (1 - vekt) * d$y5_predikert_modell)
  d$y5_observert <- NULL
  d
}

## ============================================================================
## 4. Bayesiansk bootstrap: R refits med kommune-vis Dirichlet-vekting
## ============================================================================
kommune_nivaa <- levels(modelldata$kommunenr_2024)
K <- length(kommune_nivaa)

basis <- framtidsdata |> select(kommunenr_2024, år) |> arrange(kommunenr_2024, år)
basis_nokkel <- paste(basis$kommunenr_2024, basis$år)

if (!is.null(SEED)) set.seed(SEED)

boot_resultater <- vector("list", ANTALL_BOOTSTRAP)
n_ok <- 0

for (r in seq_len(ANTALL_BOOTSTRAP)) {
  g <- rgamma(K, shape = 1, rate = 1)
  vekt_kommune <- setNames(g / sum(g) * K, kommune_nivaa)
  radvekt <- vekt_kommune[as.character(modelldata$kommunenr_2024)]

  modell_r <- tryCatch(
    suppressWarnings(suppressMessages(
      lmer(FORMEL_SLOPE, data = modelldata, weights = radvekt,
           control = lmerControl(optimizer = "bobyqa"))
    )),
    error = function(e) {
      message("  Iterasjon ", r, ": konvergerte ikke (", conditionMessage(e), ") - hoppes over.")
      NULL
    }
  )
  if (is.null(modell_r)) next

  framskrevet_r <- framskriv_y5(modell_r, framtidsdata) |>
    glatt_overgang(siste_observert)

  idx <- match(basis_nokkel, paste(framskrevet_r$kommunenr_2024, framskrevet_r$år))
  n_ok <- n_ok + 1
  boot_resultater[[n_ok]] <- framskrevet_r$y5_predikert[idx]

  if (r %% 10 == 0) message("  Iterasjon ", r, "/", ANTALL_BOOTSTRAP, " fullført (", n_ok, " OK).")
}

message(n_ok, " av ", ANTALL_BOOTSTRAP, " bootstrap-iterasjoner konvergerte.")

boot_mat <- do.call(cbind, boot_resultater[seq_len(n_ok)])
persentiler <- t(apply(boot_mat, 1, quantile, probs = c(0.025, 0.975), na.rm = TRUE))

## ============================================================================
## 5. Kombiner med punktestimatet fra framskrevet_y5.rds, lagre kun dette
## ============================================================================
usikkerhet <- basis |>
  mutate(y5_nedre = persentiler[, 1], y5_ovre = persentiler[, 2]) |>
  left_join(
    framskrevet_eksisterende |> select(kommunenr_2024, år, y5_predikert),
    by = c("kommunenr_2024", "år")
  ) |>
  mutate(n_bootstrap_ok = n_ok) |>
  select(kommunenr_2024, år, y5_predikert, y5_nedre, y5_ovre, n_bootstrap_ok)

saveRDS(usikkerhet, file.path(utmappe, "framskrevet_y5_usikkerhet.rds"))
write.csv(usikkerhet, file.path(utmappe, "framskrevet_y5_usikkerhet.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message("Lagret 95 %-konfidensintervall (", n_ok, " bootstrap-utvalg) for ",
        length(unique(usikkerhet$kommunenr_2024)), " kommuner, ",
        length(unique(usikkerhet$år)), " år, i ", normalizePath(utmappe))

for (kn in c("3101", "5001", "0301")) {
  if (kn %in% usikkerhet$kommunenr_2024) {
    cat("\n--- Kommune", kn, "---\n")
    print(usikkerhet |> filter(kommunenr_2024 == kn, år %in% c(2026, 2030, 2040, 2050)) |>
            mutate(across(c(y5_predikert, y5_nedre, y5_ovre), \(x) round(x, 1))))
  }
}
