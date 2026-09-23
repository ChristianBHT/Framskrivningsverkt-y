# modellsjekk_kvantil_lqmm.R
#
# PROTOTYPE: multilevel (blandet-effekt) kvantilregresjon for
# log(befolkning)-sjekken, som et alternativ til den enkle
# `quantreg::rq()`-sjekken i modellsjekk_kvantil.R.
#
# BAKGRUNN: modellsjekk_kvantil.R har INGEN tilfeldig/fast kommuneeffekt -
# se forbeholdet der og i teknisk_dokumentasjon.md pkt. 10. Siden hver
# kommune bidrar med 15-19 år i datasettet, ignorerer `rq()` at disse
# observasjonene ikke er uavhengige (samme kommune gjentatt over år).
# `lqmm` (Geraci & Bottai 2014, "Linear quantile mixed models",
# Statistics and Computing - IKKE Domenico Vistocco, som har en annen,
# ikke-hierarkisk metode for å håndtere heterogenitet via gruppering av
# strata) løser dette med en tilfeldig kommuneeffekt i selve
# kvantilregresjonen, analogt til `lme4::lmer` for vanlig regresjon.
#
# Samme modell som modellsjekk_kvantil.R, men med tilfeldig INTERCEPT per
# kommune lagt til:
#     log(y / befolkning) ~ log(befolkning) + demensandel + år (dummyer)
#                            + (1 | kommune)
# Ingen tilfeldig helning på log(befolkning) - befolkningen endrer seg lite
# år for år innad i en kommune, så en tilfeldig helning ville vært svakt
# identifisert (nesten all variasjon i log(befolkning) er MELLOM kommuner,
# ikke innad).
#
# Standardfeil: lqmm sin innebygde kommune-klynge-bootstrap
# (`summary.lqmm(method = "boot")`, R replikater, se BOOT_R under) - en
# annen mekanisme enn den håndskrevne Bayesianske bootstrappen i
# modellsjekk_kvantil.R, men samme prinsipp (trekker på kommunenivå).
#
# Kun ESTIMERING + sammendrag er satt opp - ingen sammenligning mot rq()
# eller figur ennå (prototype).
#
# Kjør fra prosjektroten. Installer én gang: install.packages("lqmm")

library(lqmm)
library(dplyr)

utmappe <- file.path("data", "ssb")

args <- commandArgs(trailingOnly = TRUE)
VARIABEL <- if (length(args) >= 1) args[1] else "Y_1"   # "Y_1", "Y_2_stjerne" eller "Y_5"
TAU <- c(0.1, 0.25, 0.5, 0.75, 0.9)
BOOT_R <- 50     # antall bootstrap-replikater for standardfeil (lqmm sin default)
SEED <- 1

## ============================================================================
## 1. Data (identisk med modellsjekk_kvantil.R)
## ============================================================================
paneldata <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
paneldata$demensandel <- paneldata$demens_estimert / paneldata$folk_ialt
paneldata$Y_2_stjerne_ialt <- paneldata$Y_2_ialt + paneldata$Y_3_a_ialt

oppsett <- list(
  Y_1 = list(kolonne = "Y_1_a_ialt", ekskluder_aar = 2010),
  Y_2_stjerne = list(kolonne = "Y_2_stjerne_ialt", ekskluder_aar = integer(0)),
  Y_5 = list(kolonne = "Y_5_ialt", ekskluder_aar = integer(0))
)
o <- oppsett[[VARIABEL]]
stopifnot(!is.null(o))

d <- paneldata |>
  mutate(y = .data[[o$kolonne]]) |>
  filter(!(år %in% o$ekskluder_aar),
         !is.na(y), !is.na(demensandel), !is.na(folk_ialt), folk_ialt > 0)

n_null <- sum(d$y <= 0)
d <- d |>
  filter(y > 0) |>
  mutate(log_y_pc = log(y / folk_ialt),
         log_pop = log(folk_ialt),
         år_f = factor(år),
         kommunenr_2024 = factor(kommunenr_2024))

message(VARIABEL, ": ", nrow(d), " kommune-år, ", nlevels(d$kommunenr_2024),
        " kommuner; ", n_null, " med y = 0 utelatt.")

## ============================================================================
## 2. lqmm: multilevel kvantilregresjon med tilfeldig intercept per kommune
## ============================================================================
FORMEL <- log_y_pc ~ log_pop + demensandel + år_f

set.seed(SEED)
t0 <- Sys.time()
## LP_max_iter økt fra lqmm sin default (500) - testkjøring med default ga
## konvergensadvarsler ("Lower loop did not converge") for noen
## bootstrap-replikater.
modell <- lqmm(fixed = FORMEL, random = ~ 1, group = kommunenr_2024,
               covariance = "pdDiag", tau = TAU, data = d,
               control = lqmmControl(LP_max_iter = 1000))
message("Estimeringstid (alle ", length(TAU), " kvantiler): ",
        round(difftime(Sys.time(), t0, units = "secs"), 1), " sek")

## Konvergens per kvantil: modellobjektet har ett listeelement per tau
## (navngitt med tau-verdien som streng), med $opt$low_loop == -1 hvis den
## indre løkken ikke konvergerte innen LP_max_iter.
message("\n--- Konvergens per kvantil ---")
## NB: lqmm navngir listeelementene med "%.2f"-formatering (f.eks. "0.10",
## ikke "0.1") - as.character(TAU) matcher IKKE direkte.
konv <- data.frame(
  tau = TAU,
  konvergert = vapply(sprintf("%.2f", TAU), function(tt) modell[[tt]]$opt$low_loop != -1, logical(1))
)
print(konv)
if (any(!konv$konvergert)) {
  message("OBS: ", sum(!konv$konvergert), " av ", length(TAU),
          " kvantiler konvergerte ikke innen LP_max_iter - tolk med forsiktighet.")
}

## Faste koeffisienter (rader) x kvantiler (kolonner) - theta_x er allerede
## en ferdig matrise fra lqmm.
koeff <- modell$theta_x
colnames(koeff) <- paste0("tau_", TAU)

message("\n--- Koeffisient på log(befolkning) per kvantil (lqmm, tilfeldig kommuneintercept) ---")
logpop <- data.frame(tau = TAU, log_pop = koeff["log_pop", ],
                     beta_pop = 1 + koeff["log_pop", ], row.names = NULL)
print(logpop)

## ============================================================================
## 3. Standardfeil (lqmm sin innebygde kommune-klynge-bootstrap)
## ============================================================================
message("\nBeregner standardfeil (bootstrap, R = ", BOOT_R, ") - kan ta noen minutter...")
t1 <- Sys.time()
sm <- summary(modell, R = BOOT_R)
message("Bootstrap-tid: ", round(difftime(Sys.time(), t1, units = "secs"), 1), " sek")

sammendrag <- do.call(rbind, lapply(seq_along(TAU), function(i) {
  tt <- sm$tTable[[i]]
  rad <- tt["log_pop", ]
  data.frame(tau = TAU[i], estimat = rad[["Value"]], se = rad[["Std. Error"]],
             nedre95 = rad[["lower bound"]], ovre95 = rad[["upper bound"]],
             p_verdi = rad[["Pr(>|t|)"]], row.names = NULL)
}))
sammendrag$beta_pop_estimat <- 1 + sammendrag$estimat
sammendrag$beta_pop_nedre95 <- 1 + sammendrag$nedre95
sammendrag$beta_pop_ovre95 <- 1 + sammendrag$ovre95

message("\n--- Koeffisient på log(befolkning): lqmm punktestimat + bootstrap-KI (R = ", BOOT_R, ") ---")
print(round(sammendrag, 4))

saveRDS(list(variabel = VARIABEL, tau = TAU, formel = FORMEL, modell = modell,
             summary = sm, logpop = logpop, n = nrow(d),
             n_kommuner = nlevels(d$kommunenr_2024), n_null_utelatt = n_null,
             boot_R = BOOT_R, sammendrag = sammendrag),
        file.path(utmappe, paste0("modellsjekk_kvantil_lqmm_", tolower(VARIABEL), ".rds")))
message("\nLagret modellsjekk_kvantil_lqmm_", tolower(VARIABEL), ".rds i ", normalizePath(utmappe))
