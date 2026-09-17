# usikkerhet_y1.R
#
# Kvantifiserer usikkerhet i framskrivningen av Y_1 (hjemmetjenestebrukere)
# med en BAYESIANSK BOOTSTRAP på KOMMUNE-NIVÅ (ikke radnivå):
#
#   For hver av R iterasjoner:
#     1. Trekk ÉN vekt PER KOMMUNE fra en flat Dirichlet(1,...,1)-prior
#        (K = antall kommuner i modelldata). Alle år for en gitt kommune får
#        SAMME vekt i den iterasjonen - dette respekterer panelstrukturen
#        (en kommune er den egentlige "enheten" som varieres, ikke hver
#        kommune-år-rad for seg, siden radene innad i en kommune deler samme
#        tilfeldige kommuneeffekt).
#     2. Refit hovedmodellen (samme FORMEL som modell_y1.R) med disse
#        vektene som `weights` i glmer().
#     3. Framskriv Y_1 2026-2050 med den refittede modellen, med SAMME
#        glidende overgang som framskriv_y1.R (observert 2025-nivå -> modell).
#     4. Behold BARE framskrivningen for denne iterasjonen i en midlertidig
#        matrise i minnet (kommune x år, R kolonner) - skrives ikke til disk.
#
#   Etter alle R iterasjoner: beregn 2,5 %- og 97,5 %-persentilen over R for
#   hver (kommune, år) - dette blir et 95 %-konfidensintervall. BARE denne
#   oppsummeringen (nedre/øvre grense) lagres til disk, ikke de R
#   enkeltframskrivningene - i tråd med ønsket om å ikke lagre alle
#   bootstrap-utvalgene.
#
# VEKTSKALERING: en Dirichlet(1,...,1)-trekning summerer til 1 (hver vekt er
# i størrelsesorden 1/K). Brukt direkte som `weights` i glmer() ville dette
# kunstig blåst opp den estimerte residual-/tilfeldig-effekt-variansen (glmer
# tolker `weights` som presisjonsvekter, ikke sannsynlighetsvekter). Vi
# skalerer derfor opp med K, slik at vektene i gjennomsnitt er 1 - dette er
# den vanlige praktiske tilpasningen av Bayesiansk bootstrap til vektet
# estimering, og endrer ikke SELVE Dirichlet-fordelingens relative form
# (bare skalaen), så bootstrap-variasjonen mellom iterasjonene er uendret.
#
# GJENBRUK AV BEFOLKNINGSFRAMSKRIVNING: befolkning/demensandel for 2026-2050
# er UAVHENGIG av bootstrap-vektene (de kommer fra SSBs befolknings-
# framskrivning, ikke fra modellestimeringen) - hentes derfor bare fra den
# allerede lagrede framskrevet_y1.rds (som inneholder folk_ialt/demensandel
# per kommune x år), IKKE på nytt fra SSB for hver iterasjon. Dette sparer
# 25x unødvendige API-kall.
#
# Forutsetning: kjør modell_y1.R og framskriv_y1.R først.
#
# Installer én gang: install.packages(c("lme4", "dplyr"))

library(lme4)
library(dplyr)

utmappe <- file.path("data", "ssb")

ANTALL_BOOTSTRAP <- 60
SEED <- 1  # sett til NULL for en "fersk" tilfeldig kjøring hver gang

## ============================================================================
## 1. Last inn modelldata (nøyaktig samme filtrering som modell_y1.R)
## ============================================================================
paneldata <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
paneldata$demensandel <- paneldata$demens_estimert / paneldata$folk_ialt
paneldata <- paneldata |> filter(år != 2010)  # se modell_y1.R for begrunnelse

modelldata <- paneldata |>
  filter(!is.na(Y_1_a_ialt), !is.na(demensandel), !is.na(folk_ialt),
         folk_ialt > 0, Y_1_a_ialt >= 0) |>
  mutate(kommunenr_2024 = factor(kommunenr_2024), år_f = factor(år))

FORMEL <- Y_1_a_ialt ~ år_f + demensandel + offset(log(folk_ialt)) + (1 | kommunenr_2024)

## ============================================================================
## 2. Gjenbruk befolkningsframskrivning + siste observerte år (ingen SSB-kall)
## ============================================================================
message("Leser allerede beregnet befolkningsframskrivning fra framskrevet_y1.rds...")
framskrevet_y1_eksisterende <- readRDS(file.path(utmappe, "framskrevet_y1.rds"))
framtidsdata <- framskrevet_y1_eksisterende |>
  select(kommunenr_2024, år, folk_ialt, demens_estimert, demensandel) |>
  distinct()

historisk <- paneldata  # allerede lest over
SISTE_OBSERVERTE_AR <- 2025
siste_observert <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds")) |>
  filter(år == SISTE_OBSERVERTE_AR) |>
  transmute(kommunenr_2024, y1_observert = Y_1_a_ialt)

## ============================================================================
## 3. Hjelpefunksjoner (samme logikk som framskriv_y1.R)
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

framskriv_y1 <- function(modell, framtidsdata) {
  faste <- fixef(modell)
  intercept <- faste[["(Intercept)"]]
  demens_koef <- faste[["demensandel"]]
  aar_koef <- faste[grepl("^år_f", names(faste))]
  aar_effekt_framskrevet <- mean(aar_koef)

  kjente_kommuner <- rownames(ranef(modell)$kommunenr_2024)
  kjent <- as.character(framtidsdata$kommunenr_2024) %in% kjente_kommuner
  if (!all(kjent)) framtidsdata <- framtidsdata[kjent, ]

  lin_pred <- intercept + aar_effekt_framskrevet +
    demens_koef * framtidsdata$demensandel +
    re_bidrag(modell, "kommunenr_2024", framtidsdata) +
    log(framtidsdata$folk_ialt)

  framtidsdata$y1_predikert <- as.numeric(exp(lin_pred))
  framtidsdata
}

STARTAAR_OVERGANG <- 2026
SLUTTAAR_OVERGANG <- 2036
START_ANDEL_OBSERVERT <- 0.9

glatt_overgang <- function(framskrevet_raa, siste_observert) {
  d <- merge(framskrevet_raa, siste_observert, by = "kommunenr_2024", all.x = TRUE)
  vekt <- pmax(0, START_ANDEL_OBSERVERT *
                 (SLUTTAAR_OVERGANG - d$år) / (SLUTTAAR_OVERGANG - STARTAAR_OVERGANG))
  d$y1_predikert_modell <- d$y1_predikert
  d$y1_predikert <- ifelse(is.na(d$y1_observert), d$y1_predikert_modell,
                            vekt * d$y1_observert + (1 - vekt) * d$y1_predikert_modell)
  d$y1_observert <- NULL
  d
}

## ============================================================================
## 4. Bayesiansk bootstrap: R refits med kommune-vis Dirichlet-vekting
## ============================================================================
kommune_nivaa <- levels(modelldata$kommunenr_2024)
K <- length(kommune_nivaa)

## Fast (kommunenr_2024, år)-nøkkel i framtidsdata, brukt til å garantere at
## hver iterasjons resultater lagres i nøyaktig samme radorden i
## bootstrap-matrisen, uavhengig av eventuell radomsortering i merge().
basis <- framtidsdata |> select(kommunenr_2024, år) |> arrange(kommunenr_2024, år)
basis_nokkel <- paste(basis$kommunenr_2024, basis$år)

if (!is.null(SEED)) set.seed(SEED)

boot_resultater <- vector("list", ANTALL_BOOTSTRAP)
n_ok <- 0

for (r in seq_len(ANTALL_BOOTSTRAP)) {
  ## Dirichlet(1,...,1): normaliserte Gamma(1,1)-trekk, skalert til
  ## gjennomsnittsvekt 1 (se forklaring i toppen av filen).
  g <- rgamma(K, shape = 1, rate = 1)
  vekt_kommune <- setNames(g / sum(g) * K, kommune_nivaa)
  radvekt <- vekt_kommune[as.character(modelldata$kommunenr_2024)]

  modell_r <- tryCatch(
    suppressWarnings(suppressMessages(
      glmer(FORMEL, data = modelldata, family = poisson, weights = radvekt)
    )),
    error = function(e) {
      message("  Iterasjon ", r, ": konvergerte ikke (", conditionMessage(e), ") - hoppes over.")
      NULL
    }
  )
  if (is.null(modell_r)) next

  framskrevet_r <- framskriv_y1(modell_r, framtidsdata) |>
    glatt_overgang(siste_observert)

  ## Match til basis-nøkkelen, IKKE stol på radorden fra merge().
  idx <- match(basis_nokkel, paste(framskrevet_r$kommunenr_2024, framskrevet_r$år))
  n_ok <- n_ok + 1
  boot_resultater[[n_ok]] <- framskrevet_r$y1_predikert[idx]

  if (r %% 5 == 0) message("  Iterasjon ", r, "/", ANTALL_BOOTSTRAP, " fullført (", n_ok, " OK).")
}

message(n_ok, " av ", ANTALL_BOOTSTRAP, " bootstrap-iterasjoner konvergerte.")

## boot_mat er en (kommune x år) x n_ok matrise - holdt KUN i minnet, aldri
## lagret til disk. Persentilene beregnes fra denne og deretter kastes den.
boot_mat <- do.call(cbind, boot_resultater[seq_len(n_ok)])

persentiler <- t(apply(boot_mat, 1, quantile, probs = c(0.025, 0.975), na.rm = TRUE))

## ============================================================================
## 5. Kombiner med punktestimatet fra framskrevet_y1.rds og lagre KUN dette
## ============================================================================
usikkerhet <- basis |>
  mutate(y1_nedre = persentiler[, 1], y1_ovre = persentiler[, 2]) |>
  left_join(
    framskrevet_y1_eksisterende |> select(kommunenr_2024, år, y1_predikert),
    by = c("kommunenr_2024", "år")
  ) |>
  mutate(n_bootstrap_ok = n_ok) |>
  select(kommunenr_2024, år, y1_predikert, y1_nedre, y1_ovre, n_bootstrap_ok)

saveRDS(usikkerhet, file.path(utmappe, "framskrevet_y1_usikkerhet.rds"))
write.csv(usikkerhet, file.path(utmappe, "framskrevet_y1_usikkerhet.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message("Lagret 95 %-konfidensintervall (", n_ok, " bootstrap-utvalg) for ",
        length(unique(usikkerhet$kommunenr_2024)), " kommuner, ",
        length(unique(usikkerhet$år)), " år, i ", normalizePath(utmappe))

## ---- Eksempel: vis resultat for et par kommuner -------------------------
for (kn in c("3101", "5001", "0301")) {
  if (kn %in% usikkerhet$kommunenr_2024) {
    cat("\n--- Kommune", kn, "---\n")
    print(usikkerhet |> filter(kommunenr_2024 == kn, år %in% c(2026, 2030, 2040, 2050)) |>
            mutate(across(c(y1_predikert, y1_nedre, y1_ovre), \(x) round(x, 1))))
  }
}
