# modellsjekk_kvantil.R
#
# MODELLSJEKK: er koeffisienten
# på log(befolkning) lik 1?
#
# Alle Poisson-/log-lineære modellene bruker offset(log(folk_ialt)), dvs.
#     log(y) = 1 · log(befolkning) + X·β            (koeffisient tvunget til 1)
# Fri koeffisient:
#     log(y) = β_pop · log(befolkning) + X·β
# Trekker vi log(befolkning) fra begge sider får vi per-innbygger-formen
#     log(y / befolkning) = (β_pop - 1) · log(befolkning) + X·β
# og hypotesen β_pop = 1 blir at koeffisienten på log(befolkning) er 0.
#
# Her estimeres denne per-innbygger-regresjonen med KVANTILREGRESJON
# (quantreg::rq) for flere kvantiler τ, slik at man kan se om avviket fra
# proporsjonalitet er likt over hele fordelingen (f.eks. ulikt for kommuner
# med uvanlig lav/høy bruk) eller bare i midten.
#
#     log(y / befolkning) ~ log(befolkning) + demensandel + år (dummyer)
#
# Kun ESTIMERING er satt opp her (ingen tester/standardfeil/figurer ennå).
# Tolkning av koeffisienten `log_pop` per τ: verdi 0 = proporsjonalitet
# (offset riktig); < 0 = bruk per innbygger avtar med kommunestørrelse;
# > 0 = øker. β_pop = 1 + `log_pop`.
#
# NB (begrensninger å ha i bakhodet):
#  - rq() har ingen tilfeldige effekter, og kommune-faste effekter er ikke
#    inkludert - koeffisienten hentes derfor hovedsakelig fra forskjeller
#    MELLOM kommuner (folketall varierer lite over tid innen en kommune).
#  - Observasjoner der y = 0 utelates (log(0) er udefinert); antall
#    utelatte skrives ut.
#
# Kjør fra prosjektroten. Velg variabel under.
#
# Installer én gang: install.packages(c("quantreg", "dplyr"))

library(quantreg)
library(dplyr)

utmappe <- file.path("data", "ssb")

## Variabel kan gis som kommandolinjeargument:
##   Rscript skript/modellsjekk_kvantil.R Y_2_stjerne
args <- commandArgs(trailingOnly = TRUE)
VARIABEL <- if (length(args) >= 1) args[1] else "Y_1"   # "Y_1", "Y_2_stjerne" eller "Y_5"
TAU <- c(0.1, 0.25, 0.5, 0.75, 0.9)        # kvantiler som estimeres

## ============================================================================
## 1. Data (samme utvalg som modell_*.R for hver variabel)
## ============================================================================
paneldata <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
paneldata$demensandel <- paneldata$demens_estimert / paneldata$folk_ialt
paneldata$Y_2_stjerne_ialt <- paneldata$Y_2_ialt + paneldata$Y_3_a_ialt

oppsett <- list(
  Y_1 = list(kolonne = "Y_1_a_ialt", ekskluder_aar = 2010),   # 2010-anomali, se modell_y1.R
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
         år_f = factor(år))

message(VARIABEL, ": ", nrow(d), " kommune-år brukt; ", n_null,
        " med y = 0 utelatt (log(0) er udefinert).")

## ============================================================================
## 2. Kvantilregresjon: log(y/befolkning) ~ log(befolkning) + demensandel + år
## ============================================================================
FORMEL <- log_y_pc ~ log_pop + demensandel + år_f

modell <- rq(FORMEL, tau = TAU, data = d, method = "br")

koeff <- coef(modell)                     # rader = koeffisienter, kolonner = tau
colnames(koeff) <- paste0("tau_", TAU)

message("\n--- Koeffisient på log(befolkning) per kvantil ",
        "(0 = proporsjonalitet, dvs. beta_pop = 1) ---")
logpop <- data.frame(tau = TAU,
                     log_pop = koeff["log_pop", ],
                     beta_pop = 1 + koeff["log_pop", ],
                     row.names = NULL)
print(logpop)

message("\n--- Alle koeffisienter (unntatt årsdummyer) ---")
print(round(koeff[!grepl("^år_f", rownames(koeff)), , drop = FALSE], 4))

## ============================================================================
## 3. Bayesiansk bootstrap over kommuner (samme prinsipp som usikkerhet_*.R)
## ============================================================================
## For hver av B iterasjoner: én Dirichlet(1,...,1)-vekt PER KOMMUNE (samme
## vekt for alle år i kommunen), skalert med K slik at gjennomsnittsvekten er
## 1, og brukt som `weights` i rq(). Hele kvantilregresjonen (alle tau)
## estimeres på nytt for hver iterasjon.
B <- 100
SEED <- 1

kommuner <- levels(factor(d$kommunenr_2024))
K <- length(kommuner)
set.seed(SEED)

boot_logpop <- matrix(NA_real_, nrow = B, ncol = length(TAU),
                      dimnames = list(NULL, paste0("tau_", TAU)))
boot_demens <- boot_logpop

for (b in seq_len(B)) {
  g <- rgamma(K, shape = 1, rate = 1)
  w_kommune <- setNames(g / sum(g) * K, kommuner)
  vekt <- w_kommune[as.character(d$kommunenr_2024)]

  m_b <- tryCatch(
    suppressWarnings(rq(FORMEL, tau = TAU, data = d, weights = vekt, method = "br")),
    error = function(e) NULL)
  if (is.null(m_b)) next
  cb <- coef(m_b)
  boot_logpop[b, ] <- cb["log_pop", ]
  boot_demens[b, ] <- cb["demensandel", ]
  if (b %% 10 == 0) message("  Bootstrap ", b, "/", B)
}
n_ok <- sum(complete.cases(boot_logpop))
message(n_ok, " av ", B, " iterasjoner fullført.")

oppsummer <- function(x) c(snitt = mean(x), sd = sd(x),
                           nedre95 = unname(quantile(x, 0.025)),
                           ovre95 = unname(quantile(x, 0.975)),
                           p_under_0 = mean(x < 0))
sammendrag <- do.call(rbind, lapply(seq_along(TAU), function(j) {
  data.frame(tau = TAU[j], estimat = koeff["log_pop", j],
             t(oppsummer(boot_logpop[, j])), row.names = NULL)
}))
sammendrag$beta_pop_estimat <- 1 + sammendrag$estimat
sammendrag$beta_pop_nedre95 <- 1 + sammendrag$nedre95
sammendrag$beta_pop_ovre95 <- 1 + sammendrag$ovre95

message("\n--- Koeffisient på log(befolkning): punktestimat og Bayesiansk bootstrap (B = ", B, ") ---")
message("(p_under_0 = andel bootstrap-trekk med koeffisient < 0, dvs. beta_pop < 1;",
        " 95 %-intervall som inneholder 0 => forenlig med proporsjonalitet)")
print(round(sammendrag, 4))

saveRDS(list(variabel = VARIABEL, tau = TAU, formel = FORMEL, modell = modell,
             logpop = logpop, n = nrow(d), n_null_utelatt = n_null,
             B = B, seed = SEED, boot_logpop = boot_logpop, boot_demensandel = boot_demens,
             sammendrag = sammendrag),
        file.path(utmappe, paste0("modellsjekk_kvantil_", tolower(VARIABEL), ".rds")))
## Kompakt sammendrag (uten selve rq-modellen) som appen leser i fanen
## "Analyse stordriftsfordeler".
saveRDS(list(variabel = VARIABEL, n = nrow(d), n_null_utelatt = n_null, B = B,
             sammendrag = sammendrag),
        file.path(utmappe, paste0("modellsjekk_kvantil_", tolower(VARIABEL), "_sammendrag.rds")))
message("\nLagret modellsjekk_kvantil_", tolower(VARIABEL), ".rds i ", normalizePath(utmappe))
