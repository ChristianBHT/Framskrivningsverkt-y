population <- read_csv("~/Framskrivningsverktøy/data/ssb/07459.csv")
# Dette scriptet genererer analysedatasett.
# Dictionary with dementia prevalence per 1000

# Estimater = folkemengde 1. januar * oppgitt prevalens, ikke observerte tilfeller.
# Samme prevalens brukes i alle år; historiske endringer skyldes demografien.

prevalens_enhet <- "andel"  # "andel" eller "per_1000". 
demens_utmappe <- file.path("data", "ssb")

# Brukeroppgitte rater. Tolket som andeler: 0.509160 = 50.916 %.
# Teksten "0.509160D17" for kvinner 90+ er tolket som 0.509160,
# i samsvar med den siste tallkolonnen i den oppgitte tabellen.
dementia_dic <- data.frame(
  alder_grup = rep(0:7, 2),
  aldersgrup = rep(c("0-29", "30-64", "65-69", "70-74", "75-79",
                     "80-84", "85-89", "90+"), 2),
  kjonn = rep(c("Menn", "Kvinner"), each = 8),
  demensprevalens = c(
    0, 0.000838, 0.005717, 0.063894, 0.100285, 0.177985, 0.304476, 0.414735,
    0, 0.000873, 0.008860, 0.048112, 0.089572, 0.180180, 0.345687, 0.509160
  ),
  stringsAsFactors = FALSE
)

beregn_demens <- function(befolkning, rater = dementia_dic,
                          enhet = c("andel", "per_1000")) {
  enhet <- match.arg(enhet)
  krav <- c("Region", "Tid", "Kjonn", "Alder", "verdi")
  if (!all(krav %in% names(befolkning)) || !nrow(befolkning)) {
    stop("befolkning må ha rader og kolonnene: ", paste(krav, collapse = ", "))
  }
  if (!is.numeric(befolkning$verdi) ||
      any(!is.finite(befolkning$verdi[!is.na(befolkning$verdi)])) ||
      any(befolkning$verdi < 0, na.rm = TRUE)) stop("Ugyldig folkemengde.")
  nokler <- c("Region", "Tid", "Kjonn", "Alder")
  if (anyNA(befolkning[nokler]) || anyDuplicated(befolkning[nokler])) {
    stop("Manglende eller dupliserte nøkler for kommune, år, kjønn og alder.")
  }
  if ("ssb_tabell" %in% names(befolkning) &&
      any(is.na(befolkning$ssb_tabell) | befolkning$ssb_tabell != "07459")) {
    stop("Bruk historisk befolkning fra tabell 07459.")
  }
  if ("ContentsCode" %in% names(befolkning) &&
      any(is.na(befolkning$ContentsCode) | befolkning$ContentsCode != "Personer1")) {
    stop("Forventet befolkningsvariabel Personer1 fra tabell 07459.")
  }
  gyldige_aldre <- c(sprintf("%03d", 0:104), "105+")
  if (!all(befolkning$Alder %in% gyldige_aldre) ||
      !all(befolkning$Kjonn %in% c("1", "2"))) {
    stop("Forventet alderskoder 000–104 / 105+ og kjønnskoder 1 / 2.")
  }
  if (!all(c("aldersgrup", "kjonn", "demensprevalens") %in% names(rater))) {
    stop("Ratetabellen mangler nødvendige kolonner.")
  }
  rate_nokkel <- paste(rater$aldersgrup, rater$kjonn, sep = "|")
  if (anyDuplicated(rate_nokkel) || !is.numeric(rater$demensprevalens) ||
      any(!is.finite(rater$demensprevalens))) stop("Ugyldige eller dupliserte rater.")
  andel <- rater$demensprevalens / if (enhet == "per_1000") 1000 else 1
  if (any(andel < 0 | andel > 1)) stop("Prevalens som andel må være mellom 0 og 1.")
  
  d <- befolkning
  alder <- as.integer(sub("+", "", as.character(d$Alder), fixed = TRUE))
  d$aldersgrup <- as.character(cut(alder,
                                   breaks = c(0, 30, 65, 70, 75, 80, 85, 90, Inf), right = FALSE,
                                   labels = c("0-29", "30-64", "65-69", "70-74", "75-79", "80-84", "85-89", "90+")))
  d$kjonn <- ifelse(d$Kjonn == "1", "Menn", "Kvinner")
  indeks <- match(paste(d$aldersgrup, d$kjonn, sep = "|"), rate_nokkel)
  if (anyNA(indeks)) stop("Mangler prevalens for minst én alders-/kjønnsgruppe.")
  d$demensprevalens_andel <- andel[indeks]
  d$prevalens_enhet_inn <- enhet
  d$demens_estimert <- d$verdi * d$demensprevalens_andel
  
  # Ikke avrund før eventuell presentasjon. NA beholdes også ved summering.
  # Et kommunetotal krever alle 106 alderskoder for begge kjønn (212 rader).
  grupper <- split(seq_len(nrow(d)), interaction(d$Region, d$Tid, drop = TRUE))
  total <- do.call(rbind, lapply(grupper, function(i) {
    komplett <- length(i) == 212L && !anyNA(d$verdi[i])
    data.frame(Region = as.character(d$Region[i[1]]),
               Tid = as.character(d$Tid[i[1]]),
               befolkning = if (komplett) sum(d$verdi[i]) else NA_real_,
               demens_estimert = if (komplett) sum(d$demens_estimert[i]) else NA_real_,
               komplett = komplett, antall_rader = length(i),
               manglende_verdier = sum(is.na(d$verdi[i])),
               prevalens_enhet_inn = enhet)
  }))
  rownames(total) <- NULL
  if (any(!total$komplett)) warning(
    "Ufullstendig befolkning for minst én kommune/år. Totalestimat er satt til NA.")
  list(befolkning = d, historisk_demens = total)
}

if (!exists("befolkning", inherits = TRUE)) {
  befolkning <- readRDS(file.path(demens_utmappe, "07459.rds"))
}
demens_resultat <- beregn_demens(befolkning, enhet = prevalens_enhet)
befolkning <- demens_resultat$befolkning
historisk_demens <- demens_resultat$historisk_demens

dir.create(demens_utmappe, recursive = TRUE, showWarnings = FALSE)
saveRDS(befolkning, file.path(demens_utmappe, "befolkning_med_demens.rds"))
saveRDS(historisk_demens, file.path(demens_utmappe, "historisk_demens.rds"))
write.csv(historisk_demens, file.path(demens_utmappe, "historisk_demens.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")
saveRDS(list(rater = dementia_dic, enhet = prevalens_enhet,
             kilde = "Brukeroppgitte rater; kilde og referanseår ikke oppgitt",
             forutsetning = "Konstant prevalens etter alder og kjønn i alle år"),
        file.path(demens_utmappe, "demens_forutsetninger.rds"))
message("Beregnet demens_estimert i befolkning og totaler i historisk_demens.")
