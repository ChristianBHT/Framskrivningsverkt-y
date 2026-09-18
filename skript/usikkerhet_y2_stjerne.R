# usikkerhet_y2_stjerne.R
#
# Kvantifiserer usikkerhet i framskrivningen av Y_2* (heldøgns omsorg) med
# samme metode som usikkerhet_y1.R: en Bayesiansk bootstrap PÅ KOMMUNE-NIVÅ
# (én Dirichlet(1,...,1)-vekt per kommune per iterasjon, samme vekt for alle
# år i den kommunen), refit av hovedmodellen (Poisson GLMM) med disse
# vektene, framskrivning med glidende overgang, og til slutt et 95 %
# konfidensintervall fra persentilene over iterasjonene. Se usikkerhet_y1.R
# for full begrunnelse (vektskalering, gjenbruk av befolkningsframskrivning,
# og hvorfor kun oppsummeringen - ikke alle enkeltframskrivningene - lagres).
#
# Forutsetning: kjør modell_y2_stjerne.R og framskriv_y2_stjerne.R først.
#
# Installer én gang: install.packages(c("lme4", "dplyr"))

library(lme4)
library(dplyr)

utmappe <- file.path("data", "ssb")

ANTALL_BOOTSTRAP <- 60
SEED <- 1

## ============================================================================
## 1. Last inn modelldata (nøyaktig samme filtrering som modell_y2_stjerne.R)
## ============================================================================
paneldata <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
paneldata$demensandel <- paneldata$demens_estimert / paneldata$folk_ialt
paneldata$Y_2_stjerne_ialt <- paneldata$Y_2_ialt + paneldata$Y_3_a_ialt

modelldata <- paneldata |>
  filter(!is.na(Y_2_stjerne_ialt), !is.na(demensandel), !is.na(folk_ialt),
         folk_ialt > 0, Y_2_stjerne_ialt >= 0) |>
  mutate(kommunenr_2024 = factor(kommunenr_2024), år_f = factor(år))

## Bruker BEVISST hovedmodell_slope (samme FORMEL_SLOPE som modell_y2_stjerne.R),
## IKKE intercept-only-varianten - se framskriv_y1.R/framskriv_y2_stjerne.R for
## begrunnelsen (unngår sprang mellom "trend av" og "trend = 0" i appen).
FORMEL_SLOPE <- Y_2_stjerne_ialt ~ år_f + demensandel + offset(log(folk_ialt)) +
  (1 + demensandel | kommunenr_2024)

## ============================================================================
## 2. Gjenbruk befolkningsframskrivning + siste observerte år (ingen SSB-kall)
## ============================================================================
message("Leser allerede beregnet befolkningsframskrivning fra framskrevet_y2_stjerne.rds...")
framskrevet_eksisterende <- readRDS(file.path(utmappe, "framskrevet_y2_stjerne.rds"))

SISTE_OBSERVERTE_AR <- 2025
demensandel_anker <- paneldata |>
  filter(år == SISTE_OBSERVERTE_AR) |>
  transmute(kommunenr_2024, demensandel_anker = demensandel)
siste_observert <- paneldata |>
  filter(år == SISTE_OBSERVERTE_AR) |>
  transmute(kommunenr_2024, y2s_observert = Y_2_stjerne_ialt)

framtidsdata <- framskrevet_eksisterende |>
  select(kommunenr_2024, år, folk_ialt, demens_estimert, demensandel) |>
  distinct() |>
  left_join(demensandel_anker, by = "kommunenr_2024")

## ============================================================================
## 3. Hjelpefunksjon (samme anker-metode som framskriv_y2_stjerne.R)
## ============================================================================
framskriv_y2s <- function(modell, framtidsdata) {
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

  intercept_prime <- intercept + u_intercept +
    (demens_koef + u_slope) * framtidsdata$demensandel_anker
  delta_demensandel <- framtidsdata$demensandel - framtidsdata$demensandel_anker

  lin_pred <- intercept_prime + aar_effekt_framskrevet +
    demens_koef * delta_demensandel +
    log(framtidsdata$folk_ialt)

  framtidsdata$y2s_predikert <- as.numeric(exp(lin_pred))
  framtidsdata
}

STARTAAR_OVERGANG <- 2026
SLUTTAAR_OVERGANG <- max(framtidsdata$år)
START_ANDEL_OBSERVERT <- 0.9

glatt_overgang <- function(framskrevet_raa, siste_observert) {
  d <- merge(framskrevet_raa, siste_observert, by = "kommunenr_2024", all.x = TRUE)
  vekt <- pmax(0, START_ANDEL_OBSERVERT *
                 (SLUTTAAR_OVERGANG - d$år) / (SLUTTAAR_OVERGANG - STARTAAR_OVERGANG))
  d$y2s_predikert_modell <- d$y2s_predikert
  d$y2s_predikert <- ifelse(is.na(d$y2s_observert), d$y2s_predikert_modell,
                             vekt * d$y2s_observert + (1 - vekt) * d$y2s_predikert_modell)
  d$y2s_observert <- NULL
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
      glmer(FORMEL_SLOPE, data = modelldata, family = poisson, weights = radvekt,
            control = glmerControl(optimizer = "bobyqa"))
    )),
    error = function(e) {
      message("  Iterasjon ", r, ": konvergerte ikke (", conditionMessage(e), ") - hoppes over.")
      NULL
    }
  )
  if (is.null(modell_r)) next

  framskrevet_r <- framskriv_y2s(modell_r, framtidsdata) |>
    glatt_overgang(siste_observert)

  idx <- match(basis_nokkel, paste(framskrevet_r$kommunenr_2024, framskrevet_r$år))
  n_ok <- n_ok + 1
  boot_resultater[[n_ok]] <- framskrevet_r$y2s_predikert[idx]

  if (r %% 10 == 0) message("  Iterasjon ", r, "/", ANTALL_BOOTSTRAP, " fullført (", n_ok, " OK).")
}

message(n_ok, " av ", ANTALL_BOOTSTRAP, " bootstrap-iterasjoner konvergerte.")

boot_mat <- do.call(cbind, boot_resultater[seq_len(n_ok)])
persentiler <- t(apply(boot_mat, 1, quantile, probs = c(0.025, 0.975), na.rm = TRUE))

## ============================================================================
## 5. Kombiner med punktestimatet fra framskrevet_y2_stjerne.rds, lagre kun dette
## ============================================================================
usikkerhet <- basis |>
  mutate(y2s_nedre = persentiler[, 1], y2s_ovre = persentiler[, 2]) |>
  left_join(
    framskrevet_eksisterende |> select(kommunenr_2024, år, y2s_predikert),
    by = c("kommunenr_2024", "år")
  ) |>
  mutate(n_bootstrap_ok = n_ok) |>
  select(kommunenr_2024, år, y2s_predikert, y2s_nedre, y2s_ovre, n_bootstrap_ok)

saveRDS(usikkerhet, file.path(utmappe, "framskrevet_y2_stjerne_usikkerhet.rds"))
write.csv(usikkerhet, file.path(utmappe, "framskrevet_y2_stjerne_usikkerhet.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message("Lagret 95 %-konfidensintervall (", n_ok, " bootstrap-utvalg) for ",
        length(unique(usikkerhet$kommunenr_2024)), " kommuner, ",
        length(unique(usikkerhet$år)), " år, i ", normalizePath(utmappe))

for (kn in c("3101", "5001", "0301")) {
  if (kn %in% usikkerhet$kommunenr_2024) {
    cat("\n--- Kommune", kn, "---\n")
    print(usikkerhet |> filter(kommunenr_2024 == kn, år %in% c(2026, 2030, 2040, 2050)) |>
            mutate(across(c(y2s_predikert, y2s_nedre, y2s_ovre), \(x) round(x, 1))))
  }
}
