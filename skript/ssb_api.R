# Historisk befolkning fra SSB, tabell 07459, API v2.
# Installer én gang: install.packages(c("httr2", "rjstat"))
# Kjør hele scriptet i R/RStudio. Filer lagres relativt til getwd().
# Kilde: https://www.ssb.no/statbank/table/07459/
# Regiongrupperingen agg_KommSummer brukes slik den er definert av SSB.
# Tallene gjelder 1. januar. Manglende verdier beholdes som NA.

# ---- Innstillinger ----------------------------------------------------------
years <- 2005:2026
utmappe <- file.path("data", "ssb")

regioner <- c(
  "K-3101", "K-3103", "K-3105", "K-3107", "K-3110", "K-3112",
  "K-3114", "K-3116", "K-3118", "K-3120", "K-3122", "K-3124",
  "K-3201", "K-3203", "K-3205", "K-3207", "K-3209", "K-3212",
  "K-3214", "K-3216", "K-3218", "K-3220", "K-3222", "K-3224",
  "K-3226", "K-3228", "K-3230", "K-3232", "K-3234", "K-3236",
  "K-3238", "K-3240", "K-3242", "K-0301",
  "K-3301", "K-3303", "K-3305", "K-3310", "K-3312", "K-3314",
  "K-3316", "K-3318", "K-3320", "K-3322", "K-3324", "K-3326",
  "K-3328", "K-3330", "K-3332", "K-3334", "K-3336", "K-3338",
  "K-3401", "K-3403", "K-3405", "K-3407", "K-3411", "K-3412",
  "K-3413", "K-3414", "K-3415", "K-3416", "K-3417", "K-3418",
  "K-3419", "K-3420", "K-3421", "K-3422", "K-3423", "K-3424",
  "K-3425", "K-3426", "K-3427", "K-3428", "K-3429", "K-3430",
  "K-3431", "K-3432", "K-3433", "K-3434", "K-3435", "K-3436",
  "K-3437", "K-3438", "K-3439", "K-3440", "K-3441", "K-3442",
  "K-3443", "K-3446", "K-3447", "K-3448", "K-3449", "K-3450",
  "K-3451", "K-3452", "K-3453", "K-3454",
  "K-3901", "K-3903", "K-3905", "K-3907", "K-3909", "K-3911",
  "K-4001", "K-4003", "K-4005", "K-4010", "K-4012", "K-4014",
  "K-4016", "K-4018", "K-4020", "K-4022", "K-4024", "K-4026",
  "K-4028", "K-4030", "K-4032", "K-4034", "K-4036",
  "K-4201", "K-4202", "K-4203", "K-4204", "K-4205", "K-4206",
  "K-4207", "K-4211", "K-4212", "K-4213", "K-4214", "K-4215",
  "K-4216", "K-4217", "K-4218", "K-4219", "K-4220", "K-4221",
  "K-4222", "K-4223", "K-4224", "K-4225", "K-4226", "K-4227",
  "K-4228",
  "K-1101", "K-1103", "K-1106", "K-1108", "K-1111", "K-1112",
  "K-1114", "K-1119", "K-1120", "K-1121", "K-1122", "K-1124",
  "K-1127", "K-1130", "K-1133", "K-1134", "K-1135", "K-1144",
  "K-1145", "K-1146", "K-1149", "K-1151", "K-1160",
  "K-4601", "K-4602", "K-4611", "K-4612", "K-4613", "K-4614",
  "K-4615", "K-4616", "K-4617", "K-4618", "K-4619", "K-4620",
  "K-4621", "K-4622", "K-4623", "K-4624", "K-4625", "K-4626",
  "K-4627", "K-4628", "K-4629", "K-4630", "K-4631", "K-4632",
  "K-4633", "K-4634", "K-4635", "K-4636", "K-4637", "K-4638",
  "K-4639", "K-4640", "K-4641", "K-4642", "K-4643", "K-4644",
  "K-4645", "K-4646", "K-4647", "K-4648", "K-4649", "K-4650",
  "K-4651",
  "K-1505", "K-1506", "K-1508", "K-1511", "K-1514", "K-1515",
  "K-1516", "K-1517", "K-1520", "K-1525", "K-1528", "K-1531",
  "K-1532", "K-1535", "K-1539", "K-1547", "K-1554", "K-1557",
  "K-1560", "K-1563", "K-1566", "K-1573", "K-1576", "K-1577",
  "K-1578", "K-1579", "K-1580",
  "K-5001", "K-5006", "K-5007", "K-5014", "K-5020", "K-5021",
  "K-5022", "K-5025", "K-5026", "K-5027", "K-5028", "K-5029",
  "K-5031", "K-5032", "K-5033", "K-5034", "K-5035", "K-5036",
  "K-5037", "K-5038", "K-5041", "K-5042", "K-5043", "K-5044",
  "K-5045", "K-5046", "K-5047", "K-5049", "K-5052", "K-5053",
  "K-5054", "K-5055", "K-5056", "K-5057", "K-5058", "K-5059",
  "K-5060", "K-5061",
  "K-1804", "K-1806", "K-1811", "K-1812", "K-1813", "K-1815",
  "K-1816", "K-1818", "K-1820", "K-1822", "K-1824", "K-1825",
  "K-1826", "K-1827", "K-1828", "K-1832", "K-1833", "K-1834",
  "K-1835", "K-1836", "K-1837", "K-1838", "K-1839", "K-1840",
  "K-1841", "K-1845", "K-1848", "K-1851", "K-1853", "K-1856",
  "K-1857", "K-1859", "K-1860", "K-1865", "K-1866", "K-1867",
  "K-1868", "K-1870", "K-1871", "K-1874", "K-1875",
  "K-5501", "K-5503", "K-5510", "K-5512", "K-5514", "K-5516",
  "K-5518", "K-5520", "K-5522", "K-5524", "K-5526", "K-5528",
  "K-5530", "K-5532", "K-5534", "K-5536", "K-5538", "K-5540",
  "K-5542", "K-5544", "K-5546",
  "K-5601", "K-5603", "K-5605", "K-5607", "K-5610", "K-5612",
  "K-5614", "K-5616", "K-5618", "K-5620", "K-5622", "K-5624",
  "K-5626", "K-5628", "K-5630", "K-5632", "K-5634", "K-5636"
)

# ---- Funksjoner -------------------------------------------------------------
lag_befolkningsurl <- function(region, years) {
  if (length(region) != 1L || is.na(region) ||
      !grepl("^K-[0-9]{4}$", region)) {
    stop("region må være én kode, for eksempel 'K-3101'.")
  }
  if (!is.numeric(years) || !length(years) || anyNA(years) ||
      any(!is.finite(years)) || any(years != floor(years))) {
    stop("years må være en numerisk vektor med hele årstall.")
  }
  paste0(
    "https://data.ssb.no/api/pxwebapi/v2/tables/07459/data",
    "?lang=no&outputFormat=json-stat2",
    "&valuecodes%5BContentsCode%5D=Personer1",
    "&valuecodes%5BTid%5D=", paste(sort(unique(years)), collapse = ","),
    "&valuecodes%5BRegion%5D=", region,
    "&codelist%5BRegion%5D=agg_KommSummer",
    "&valuecodes%5BAlder%5D=*",
    "&codelist%5BAlder%5D=vs_AlleAldre00B",
    "&valuecodes%5BKjonn%5D=1,2",
    "&heading=ContentsCode,Tid&stub=Region,Kjonn,Alder"
  )
}

hent_kommune <- function(region, years) {
  url <- lag_befolkningsurl(region, years)
  respons <- httr2::request(url) |>
    httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_perform()
  
  d <- rjstat::fromJSONstat(
    httr2::resp_body_string(respons), naming = "id"
  )
  krav <- c("Region", "Tid", "Kjonn", "Alder", "ContentsCode", "value")
  if (!is.data.frame(d) || !nrow(d) || !all(krav %in% names(d))) {
    stop("Uventet datastruktur fra SSB for ", region, ".")
  }
  if (anyNA(d$Region) || any(d$Region != region) ||
      !setequal(as.character(d$Tid), as.character(years))) {
    stop("Svaret fra SSB dekker ikke forespurt kommune og år: ", region, ".")
  }
  if (anyDuplicated(d[c("Region", "Tid", "Kjonn", "Alder", "ContentsCode")])) {
    stop("Dupliserte observasjoner i svaret fra SSB for ", region, ".")
  }
  names(d)[names(d) == "value"] <- "verdi"
  # Behold koder som tekst, blant annet 000 og 105+ i Alder.
  for (kolonne in setdiff(krav, "value")) d[[kolonne]] <- as.character(d[[kolonne]])
  d$ssb_tabell <- "07459"
  d$hentet_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  d
}

hent_befolkning <- function(regioner, years) {
  if (!is.character(regioner) || !length(regioner) || anyNA(regioner) ||
      any(!grepl("^K-[0-9]{4}$", regioner)) || anyDuplicated(regioner)) {
    stop("regioner må være unike kommunekoder som 'K-3101'.")
  }
  # Valider år før første nettverkskall.
  invisible(lag_befolkningsurl(regioner[1], years))
  resultater <- vector("list", length(regioner))
  n <- length(regioner)
  for (i in seq_along(regioner)) {
    region <- regioner[i]
    message(sprintf("Henter %s (%d av %d) ...", region, i, n))
    resultater[[i]] <- tryCatch(
      hent_kommune(region, years),
      error = function(e) stop("Nedlasting stoppet ved ", region, ": ",
                               conditionMessage(e), " Ingen samlet fil er lagret fra denne kjøringen.",
                               call. = FALSE)
    )
    message(sprintf("Ferdig: %.1f %%", 100 * i / n))
    if (i < n) Sys.sleep(1)  # Unngå mange forespørsler på kort tid.
  }
  befolkning <- do.call(rbind, resultater)
  rownames(befolkning) <- NULL
  if (anyNA(befolkning$verdi)) {
    warning(sum(is.na(befolkning$verdi)),
            " manglende befolkningstall. Disse er beholdt som NA.")
  }
  befolkning
}

# ---- Kjør og lagre ----------------------------------------------------------
for (pakke in c("httr2", "rjstat")) {
  if (!requireNamespace(pakke, quietly = TRUE)) {
    stop("Mangler ", pakke,
         ". Kjør install.packages(c('httr2', 'rjstat')) først.")
  }
}

befolkning <- hent_befolkning(regioner, years)

dir.create(utmappe, recursive = TRUE, showWarnings = FALSE)
saveRDS(befolkning, file.path(utmappe, "07459.rds"))
utils::write.csv(befolkning, file.path(utmappe, "07459.csv"),
                 row.names = FALSE, na = "", fileEncoding = "UTF-8")
saveRDS(list(
  tabell = "07459", regioner = regioner, years = years,
  url = vapply(regioner, lag_befolkningsurl, character(1), years = years),
  regiongruppering = "agg_KommSummer", alderskodeliste = "vs_AlleAldre00B"
), file.path(utmappe, "07459_utvalg.rds"))

message(nrow(befolkning), " rader lagret i ", normalizePath(utmappe))
# Ved senere innlesing: befolkning <- readRDS("data/ssb/07459.rds")
# Bruk RDS for å bevare kommunekoder, kjønn og alder som tekst.
# Install once:
# install.packages(c("httr2", "rjstat"))

get_table_11645 <- function(region, years = 2005:2025,
                            tjenester = c("12", "29", "15", "21")) {
  url <- paste0(
    "https://data.ssb.no/api/pxwebapi/v2/tables/11645/data",
    "?lang=no&outputFormat=json-stat2",
    "&valuecodes%5BContentsCode%5D=*",
    "&valuecodes%5BTid%5D=", paste(sort(unique(years)), collapse = ","),
    "&valuecodes%5BRegion%5D=", paste(region, collapse = ","),
    "&codelist%5BRegion%5D=agg_KommSummerS",
    "&valuecodes%5BTenesteType%5D=", paste(tjenester, collapse = ","),
    "&valuecodes%5BAlder%5D=*",
    "&heading=ContentsCode,Tid,TenesteType",
    "&stub=Region,Alder"
  )
# print(url)  
  response <- httr2::request(url) |>
    httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_perform()
  
  data <- rjstat::fromJSONstat(
    httr2::resp_body_string(response),
    naming = "id"
  )
  
  names(data)[names(data) == "value"] <- "verdi"
  
  data
}

# Example — all available years:
omsorg <- get_table_11642(region = "K.3101", years = "*")

get_table_12292 <- function(region, years = 2005:2025, 
                            tjenester = c("12", "29", "15", "21")){
  url <- paste0(
    "https://data.ssb.no/api/pxwebapi/v2/tables/12292/data",
    "?lang=no&outputFormat=json-stat2",
    "&valuecodes%5BTid%5D=", paste(sort(unique(years)), collapse = ","),
    "&valuecodes%5BKOKkommuneregion0000%5D=", paste(region, collapse = ","),
    "&codelist%5BKOKkommuneregion0000%5D=agg_KOGkommuneregion000005401",
    "&valuecodes%5BContentsCode%5D=", paste(tjenester, collapse = ","),
    "&heading=Tid,ContentsCode&stub=KOKkommuneregion0000"
  )
  response <- httr2::request(url) |>
    httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_perform()
  data <- rjstat::fromJSONstat(
    httr2::resp_body_string(response),
    naming = "id"
  )
  names(data)[names(data) == "value"] <- "verdi"
  data
}
get_table_04686 <- function(region, 
                            years = 2008:2016, 
                            tjenester = c("CRC3554053040", 
                                          "CRC3050941668", 
                                          "CRC2464749921", 
                                          "CRC924095442", 
                                          "CRC954440742", 
                                          "CRC3360864005", 
                                          "CRC1362622823", 
                                          "CRC747899133", 
                                          "CRC1815124696",
                                          "CRC3285350786",
                                          "CRC1297612858",
                                          "CRC456632910",
                                          "CRC3384594087",
                                          "CRC3398236249",
                                          "CRC2628761217",
                                          "CRC2881919331",
                                          "CRC1807410924",
                                          "CRC2348993515",
                                          "CRC2794288003",
                                          "CRC1600056472")){
  url <- paste0("https://data.ssb.no/api/pxwebapi/v2/tables/04686/data",
                "?lang=no&outputFormat=json-stat2",
                "&valuecodes%5BTid%5D=", paste(sort(unique(years)), collapse = ","),
                "&valuecodes%5BRegion%5D=", paste(region, collapse = ","),
                "&codelist%5BRegion%5D=agg_KostraKommuner",
                "&valuecodes%5BContentsCode%5D=", paste(tjenester, collapse = ","),
                "&heading=Tid,ContentsCode&stub=Region"
  )
  print(url)
  response <- httr2::request(url) |> 
    httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_perform()
  
  data <- rjstat::fromJSONstat(
    httr2::resp_body_string(response),
    naming = "id"
  )
  names(data)[names(data) == "value"] <- "verdi"
  data
}
test <- get_table_04686(region = "0101", years = 2008:2010)

# All data sets downloaded here only has ContentsCode  (tjenester) these needs to be re encoded into sensible names



