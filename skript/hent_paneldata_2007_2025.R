# hent_paneldata_2007_2025.R
#
# Henter et paneldatasett (kommune x år, 2007-2025) for framskrivningsmodellene:
#   Y_1_a  Brukere av hjemmetjenester, i alt og etter aldersgruppe
#   Y_2    Beboere i bolig m/ heldøgns bemanning, i alt
#   Y_3_a  Beboere i institusjon, langtidsopphold, i alt og etter aldersgruppe
#   Y_4    Gjennomsnittlig antall tildelte timer i uken, helsetjenester i hjemmet
#   Y_5    Alle sykepleiere, årsverk
# og kobler dette med befolkning etter alder og kjønn.
#
# Kilder (se prosjektnotater for hvordan disse er valgt/sammenlignet):
#   Y_1_a, Y_2, Y_4  : tabell 04686 (t.o.m. 2016) + tabell 12292 (f.o.m. 2015)
#   Y_3_a            : tabell 11645 (2009-2025, aldersoppløst per tjenestetype - ingen skjøting nødvendig)
#   Y_5              : tabell 04686 (t.o.m. 2016) + tabell 11924 (2015-2023) + tabell 14534 (2015-2025)
#   Befolkning       : tabell 07459 (2005-2026, agg_KommSummer - allerede en sammenslått tidsserie)
#
# NB: 04686 og 12292 har IKKE en sammenslått ("splittet kommune -> dagens kommune")
# kodeliste slik befolkningstabellen har. Vi løser dette ved å bygge en
# kommunehistorikk fra befolkningstabellens agg_KommSummer-kodeliste, og så
# spørre 04686/12292/11924/14534 om ALLE historiske koder for hver kommune på
# én gang - SSB returnerer "." for år der en gitt historisk kode ikke gjaldt,
# så vi trenger ikke selv vite nøyaktig hvilke år hvert kommunenummer var i bruk.
#
# Kjente hull i datagrunnlaget (se kommentarer der de oppstår i koden):
#  - Y_1_a mangler aldersgruppen 67-79 år fra og med 2015 (12292 har bare
#    0-66, 80+ og i alt for hjemmetjenestebrukere).
#  - Y_2 finnes kun som "i alt", ikke etter aldersgruppe, i noen av kildene.
#  - Y_5 har et reelt metodebrudd mellom 04686 og 11924/14534 (se
#    dokumentasjonen for detaljer) - skjøtingen er ikke perfekt for de
#    tidligste årene (2015-2017) i den nye serien.
#
# Installer én gang: install.packages(c("httr2", "dplyr", "tidyr"))
# Kjør hele scriptet i R/RStudio. Filer lagres relativt til getwd().

library(httr2)
library(dplyr)
library(tidyr)

years <- 2007:2025
utmappe <- file.path("data", "ssb")

kommuner_2024 <- c(
  "3101", "3103", "3105", "3107", "3110", "3112", "3114", "3116", "3118",
  "3120", "3122", "3124", "3201", "3203", "3205", "3207", "3209", "3212",
  "3214", "3216", "3218", "3220", "3222", "3224", "3226", "3228", "3230",
  "3232", "3234", "3236", "3238", "3240", "3242", "0301",
  "3301", "3303", "3305", "3310", "3312", "3314", "3316", "3318", "3320",
  "3322", "3324", "3326", "3328", "3330", "3332", "3334", "3336", "3338",
  "3401", "3403", "3405", "3407", "3411", "3412", "3413", "3414", "3415",
  "3416", "3417", "3418", "3419", "3420", "3421", "3422", "3423", "3424",
  "3425", "3426", "3427", "3428", "3429", "3430", "3431", "3432", "3433",
  "3434", "3435", "3436", "3437", "3438", "3439", "3440", "3441", "3442",
  "3443", "3446", "3447", "3448", "3449", "3450", "3451", "3452", "3453",
  "3454",
  "3901", "3903", "3905", "3907", "3909", "3911",
  "4001", "4003", "4005", "4010", "4012", "4014", "4016", "4018", "4020",
  "4022", "4024", "4026", "4028", "4030", "4032", "4034", "4036",
  "4201", "4202", "4203", "4204", "4205", "4206", "4207", "4211", "4212",
  "4213", "4214", "4215", "4216", "4217", "4218", "4219", "4220", "4221",
  "4222", "4223", "4224", "4225", "4226", "4227", "4228",
  "1101", "1103", "1106", "1108", "1111", "1112", "1114", "1119", "1120",
  "1121", "1122", "1124", "1127", "1130", "1133", "1134", "1135", "1144",
  "1145", "1146", "1149", "1151", "1160",
  "4601", "4602", "4611", "4612", "4613", "4614", "4615", "4616", "4617",
  "4618", "4619", "4620", "4621", "4622", "4623", "4624", "4625", "4626",
  "4627", "4628", "4629", "4630", "4631", "4632", "4633", "4634", "4635",
  "4636", "4637", "4638", "4639", "4640", "4641", "4642", "4643", "4644",
  "4645", "4646", "4647", "4648", "4649", "4650", "4651",
  "1505", "1506", "1508", "1511", "1514", "1515", "1516", "1517", "1520",
  "1525", "1528", "1531", "1532", "1535", "1539", "1547", "1554", "1557",
  "1560", "1563", "1566", "1573", "1576", "1577", "1578", "1579", "1580",
  "5001", "5006", "5007", "5014", "5020", "5021", "5022", "5025", "5026",
  "5027", "5028", "5029", "5031", "5032", "5033", "5034", "5035", "5036",
  "5037", "5038", "5041", "5042", "5043", "5044", "5045", "5046", "5047",
  "5049", "5052", "5053", "5054", "5055", "5056", "5057", "5058", "5059",
  "5060", "5061",
  "1804", "1806", "1811", "1812", "1813", "1815", "1816", "1818", "1820",
  "1822", "1824", "1825", "1826", "1827", "1828", "1832", "1833", "1834",
  "1835", "1836", "1837", "1838", "1839", "1840", "1841", "1845", "1848",
  "1851", "1853", "1856", "1857", "1859", "1860", "1865", "1866", "1867",
  "1868", "1870", "1871", "1874", "1875",
  "5501", "5503", "5510", "5512", "5514", "5516", "5518", "5520", "5522",
  "5524", "5526", "5528", "5530", "5532", "5534", "5536", "5538", "5540",
  "5542", "5544", "5546",
  "5601", "5603", "5605", "5607", "5610", "5612", "5614", "5616", "5618",
  "5620", "5622", "5624", "5626", "5628", "5630", "5632", "5634", "5636"
)

## ============================================================================
## 1. Kommunehistorikk: hvilke gamle kommunenummer tilhører hvert dagens (2024)?
## ============================================================================
## Bruker den samme sammenslåtte kodelisten ("agg_KommSummer") som
## befolkningstabellen (07459) allerede er hentet med, som generell kilde til
## historiske kommunenummer - de underliggende rå-kodene er de samme uansett
## hvilken SSB-tabell de brukes i.
hent_kommunehistorikk <- function() {
  url <- "https://data.ssb.no/api/pxwebapi/v2/codeLists/agg_KommSummer?lang=no"
  resp <- request(url) |> req_timeout(60) |> req_perform() |>
    resp_body_json(simplifyVector = FALSE)
  rader <- lapply(resp$values, function(v) {
    kode_2024 <- sub("^K-", "", v$code)
    data.frame(kommunenr_2024 = kode_2024,
               kommunenr_hist = unlist(v$valueMap),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rader)
}

## ============================================================================
## 2. Generisk SSB-henter (v0 API, POST, px-standard "json"-format)
## ============================================================================
## Alle tabellene under (04686, 11645, 11924, 12292, 14534) hentes med denne
## - de har alle en KOSTRA-aktig regiondimensjon der vi selv styrer hvilke
## rå-kommunenummer som skal spørres om, uten å gå via en kodeliste.
ssb_query <- function(table_id, query, debug = FALSE) {
  url <- paste0("https://data.ssb.no/api/v0/no/table/", table_id, "/")
  body <- list(query = query, response = list(format = "json"))
  if (debug) {
    message("POST ", url)
    message(jsonlite::toJSON(body, auto_unbox = TRUE, pretty = TRUE))
  }
  resp <- request(url) |>
    req_body_json(body) |>
    req_timeout(120) |>
    req_retry(max_tries = 4) |>
    req_error(is_error = function(resp) FALSE) |>
    req_perform()

  if (resp_status(resp) >= 400) {
    # Skriv alltid ut URL, spørring og SSBs feilmelding når noe går galt -
    # dette er det du trenger for å se nøyaktig hva som ble sendt.
    message("POST ", url)
    message(jsonlite::toJSON(body, auto_unbox = TRUE, pretty = TRUE))
    message("Svar fra SSB: ", resp_body_string(resp))
    stop(sprintf("SSB API-feil (HTTP %s) mot tabell %s", resp_status(resp), table_id))
  }
  resp_body_json(resp, simplifyVector = FALSE)
}

## Konverterer et px-standard JSON-svar til en lang, tidy data.frame med én
## rad per (dimensjon-kombinasjon x ContentsCode). Leser kolonnenavn fra
## svaret i stedet for å anta spørringens rekkefølge - SSB kan returnere
## ContentsCode-kolonner i tabellens EGEN faste rekkefølge, ikke den vi ba om.
ssb_to_long <- function(parsed, verdi_navn = "verdi") {
  cols <- parsed$columns
  col_codes <- vapply(cols, function(c) c$code, character(1))
  col_types <- vapply(cols, function(c) c$type, character(1))
  col_texts <- vapply(cols, function(c) c$text, character(1))
  dim_idx <- which(col_types %in% c("d", "t"))
  val_idx <- which(col_types == "c")
  if (length(parsed$data) == 0) return(data.frame())

  n_dim <- length(dim_idx)
  ut <- vector("list", length(parsed$data) * length(val_idx))
  k <- 0L
  for (row in parsed$data) {
    dims <- as.list(unlist(row$key))
    names(dims) <- col_codes[dim_idx]
    for (i in seq_along(val_idx)) {
      v <- row$values[[i]]
      k <- k + 1L
      ut[[k]] <- c(dims, list(variabel = col_texts[val_idx[i]],
                               kode = col_codes[val_idx[i]],
                               verdi = if (is.null(v) || v == ".") NA_real_ else suppressWarnings(as.numeric(v))))
    }
  }
  do.call(rbind, lapply(ut, function(x) as.data.frame(x, stringsAsFactors = FALSE)))
}

## Henter listen over gyldige verdier for en gitt dimensjon i en tabell.
## SSBs API avviser HELE spørringen (HTTP 400) hvis bare én "item"-verdi ikke
## finnes i tabellens dimensjon, så vi må filtrere til gyldige koder FØR vi
## spør - historiske koder fra andre tidsperioder enn tabellen dekker,
## finnes rett og slett ikke i dens regiondimensjon.
hent_gyldige_koder <- function(table_id, dim_code) {
  resp <- request(paste0("https://data.ssb.no/api/v0/no/table/", table_id, "/")) |>
    req_timeout(60) |> req_perform()
  meta <- resp_body_json(resp, simplifyVector = TRUE)
  meta$variables$values[[which(meta$variables$code == dim_code)]]
}

## Bytter ut SSBs egen ContentsCode (i kolonnen `kode`) med vårt eget
## variabelnavn (Y_1_a_ialt osv.), ved oppslag i en navngitt kodeliste
## (navn = vårt variabelnavn, verdi = SSBs ContentsCode).
omkod_variabel <- function(df, kodeliste) {
  if (!nrow(df)) return(df)
  df$variabel <- names(kodeliste)[match(df$kode, unname(unlist(kodeliste)))]
  df[!is.na(df$variabel), ]
}

## Spør en tabell om ALLE historiske koder for en region-dimensjon samtidig
## (begrenset til de kodene tabellen faktisk kjenner), for de gitte årene, og
## fjern rader uten verdi (dvs. koder som ikke gjaldt det året). Ekstra
## dimensjoner (f.eks. TenesteType, Alder) kan sendes med.
hent_med_historikk <- function(table_id, region_dim, contents_codes, years,
                                kommunehistorikk, ekstra_dims = list()) {
  gyldige <- hent_gyldige_koder(table_id, region_dim)
  koder_hist <- intersect(unique(kommunehistorikk$kommunenr_hist), gyldige)
  if (!length(koder_hist)) return(data.frame())
  query <- c(
    list(list(code = region_dim,
              selection = list(filter = "item", values = as.list(koder_hist)))),
    ekstra_dims,
    list(list(code = "ContentsCode",
              selection = list(filter = "item", values = as.list(unname(contents_codes))))),
    list(list(code = "Tid",
              selection = list(filter = "item", values = as.list(as.character(years)))))
  )
  parsed <- ssb_query(table_id, query)
  df <- ssb_to_long(parsed)
  if (nrow(df) == 0) return(df)
  names(df)[names(df) == region_dim] <- "kommunenr_hist"
  df <- df[!is.na(df$verdi), ]
  df$Tid <- as.integer(df$Tid)
  merge(df, kommunehistorikk, by = "kommunenr_hist")
}

## ============================================================================
## 3. Innholdskoder (ContentsCode) per tabell
## ============================================================================

# --- 04686: F. Pleie og omsorg - grunnlagsdata (K), t.o.m. 2016 -------------
CC_04686 <- list(
  Y_1_a_ialt   = "CRC747899133",
  Y_1_a_0_66   = "CRC924095442",
  Y_1_a_67_79  = "CRC954440742",
  Y_1_a_80p    = "CRC1362622823",
  Y_2_ialt     = "CRC3384594087",
  Y_4_ialt     = "CRC1195083792",
  # Sykepleier-kategorier som sammen utgjør Y_5 ("alle sykepleiere")
  Y_5_psyk     = "CRC147558361",
  Y_5_geriatri = "CRC1600056472",
  Y_5_annenvdu = "CRC3602971177",
  Y_5_andre    = "CRC1818371153"
)

# --- 12292: Omsorgstjenester - supplerende grunnlagstall (K), f.o.m. 2015 --
CC_12292 <- list(
  Y_1_a_ialt  = "KOSkjernetotalt0000",
  Y_1_a_0_66  = "KOSkjerne066aar0000",
  Y_1_a_80p   = "KOSkjerne80aarov0000",
  # NB: 12292 har ingen egen 67-79-kode for hjemmetjenestebrukere.
  Y_2_ialt    = "KOSbialthelsum0000",
  Y_4_ialt    = "KOSgjtimerhjsyk0000"
)

# --- 11924: Omsorgstjenestene - avtalte årsverk etter utdanning (K, avslutta
# serie), 2015-2023. Fire sykepleierkategorier summeres til "alle sykepleiere".
UT_11924_SYKEPLEIER <- c("KF01", "KF02", "KF03", "KF04")

# --- 14534: Årsverk i omsorgstjenestene etter stillingstype og utdanning (K),
# 2015-2025 (gjeldende). Utdanningskode "01" = alle sykepleiere (summen av
# alle videreutdanningskategoriene), stillingstype "TOT" = alle stillinger.
UT_14534_ALLE_SYKEPLEIERE <- "01"

# --- 11645: Brukarar av omsorgstenester per 31.12 (2009-2025). TenesteType
# "21" = langtidsopphald i institusjon, med full aldersoppløsning - ingen
# skjøting nødvendig, samme tabell/definisjon for hele perioden.
TENESTETYPE_LANGTID <- "21"
ALDER_11645 <- c("00-49", "50-66", "67-79", "80-89", "90+")

## ============================================================================
## 4. Hent hver variabel
## ============================================================================

hent_04686 <- function(kommunehistorikk, years) {
  aar <- years[years <= 2016]
  if (!length(aar)) return(data.frame())
  df <- hent_med_historikk("04686", "Region", CC_04686, aar, kommunehistorikk)
  omkod_variabel(df, CC_04686)
}

hent_12292 <- function(kommunehistorikk, years) {
  aar <- years[years >= 2015]
  if (!length(aar)) return(data.frame())
  df <- hent_med_historikk("12292", "KOKkommuneregion0000", CC_12292, aar,
                            kommunehistorikk)
  omkod_variabel(df, CC_12292)
}

hent_11924 <- function(kommunehistorikk, years) {
  aar <- years[years >= 2015 & years <= 2023]
  if (!length(aar)) return(data.frame())
  df <- hent_med_historikk(
    "11924", "KOKkommuneregion0000", "KOSARBAARSVERKST0000", aar,
    kommunehistorikk,
    ekstra_dims = list(list(code = "KOKkyrk200000",
                            selection = list(filter = "item",
                                             values = as.list(UT_11924_SYKEPLEIER))))
  )
  if (!nrow(df)) return(df)
  df |>
    group_by(kommunenr_2024, kommunenr_hist, Tid) |>
    summarise(variabel = "Y_5_ialt", kode = "11924_sum", verdi = sum(verdi),
              .groups = "drop")
}

hent_14534 <- function(kommunehistorikk, years) {
  aar <- years[years >= 2015]
  if (!length(aar)) return(data.frame())
  df <- hent_med_historikk(
    "14534", "KOKkommuneregion0000", "KOSARBAARSVERKST0000", aar,
    kommunehistorikk,
    ekstra_dims = list(
      list(code = "KOKstillingkode0000", selection = list(filter = "item", values = list("TOT"))),
      list(code = "KOKutdanningoms0000", selection = list(filter = "item", values = list(UT_14534_ALLE_SYKEPLEIERE)))
    )
  )
  if (!nrow(df)) return(df)
  df$variabel <- "Y_5_ialt"
  df$kode <- "14534_01_TOT"
  df
}

hent_11645_langtid <- function(kommunehistorikk, years) {
  df <- hent_med_historikk(
    "11645", "Region", "Brukere1", years, kommunehistorikk,
    ekstra_dims = list(
      list(code = "TenesteType", selection = list(filter = "item", values = list(TENESTETYPE_LANGTID))),
      list(code = "Alder", selection = list(filter = "item", values = as.list(c("Ialt", ALDER_11645))))
    )
  )
  if (!nrow(df)) return(df)
  gruppe <- case_when(
    df$Alder == "Ialt" ~ "Y_3_a_ialt",
    df$Alder %in% c("00-49", "50-66") ~ "Y_3_a_0_66",
    df$Alder == "67-79" ~ "Y_3_a_67_79",
    df$Alder %in% c("80-89", "90+") ~ "Y_3_a_80p",
    TRUE ~ NA_character_
  )
  df$variabel <- gruppe
  df$kode <- paste0("11645_TT21_", df$Alder)
  df |>
    filter(!is.na(variabel)) |>
    group_by(kommunenr_2024, kommunenr_hist, Tid, variabel) |>
    summarise(verdi = sum(verdi), kode = "11645_TT21", .groups = "drop")
}

## ============================================================================
## 5. Befolkning (uendret mønster fra det opprinnelige scriptet, tabell 07459)
## ============================================================================

## Henter befolkning for ETT sett kommuner (én GET-forespørsel).
hent_befolkning_batch <- function(kommuner, years) {
  url <- paste0(
    "https://data.ssb.no/api/pxwebapi/v2/tables/07459/data",
    "?lang=no&outputFormat=json-stat2",
    "&valuecodes%5BContentsCode%5D=Personer1",
    "&valuecodes%5BTid%5D=", paste(sort(unique(years)), collapse = ","),
    "&valuecodes%5BRegion%5D=", paste0("K-", kommuner, collapse = ","),
    "&codelist%5BRegion%5D=agg_KommSummer",
    "&valuecodes%5BAlder%5D=*",
    "&codelist%5BAlder%5D=vs_AlleAldre00B",
    "&valuecodes%5BKjonn%5D=1,2",
    "&heading=ContentsCode,Tid&stub=Region,Kjonn,Alder"
  )
  resp <- request(url) |> req_timeout(120) |> req_retry(max_tries = 4) |> req_perform()
  rjstat::fromJSONstat(resp_body_string(resp), naming = "id")
}

## Henter befolkning for ALLE kommuner, i biter av 100 kommuner per
## forespørsel. Nødvendig fordi en URL med alle ~357 kommuner samtidig blir
## for lang (over ca. 2000 tegn) og avvises av webserveren FØR den når SSBs
## API - man får da en generisk "404 - File or directory not found"-side
## (IIS' egen feilside), ikke en feilmelding fra SSB selv.
hent_befolkning <- function(kommuner_2024, years, batch_size = 100) {
  batcher <- split(kommuner_2024, ceiling(seq_along(kommuner_2024) / batch_size))
  d <- bind_rows(lapply(batcher, hent_befolkning_batch, years = years))
  names(d)[names(d) == "value"] <- "verdi"
  d$kommunenr_2024 <- sub("^K-", "", d$Region)
  d$Tid <- as.integer(d$Tid)
  d$alder_num <- suppressWarnings(as.numeric(sub("\\+$", "", d$Alder)))
  d |>
    mutate(aldersgruppe = case_when(
      alder_num <= 66 ~ "0_66",
      alder_num <= 79 ~ "67_79",
      TRUE ~ "80p"
    )) |>
    group_by(kommunenr_2024, Tid, aldersgruppe) |>
    summarise(befolkning = sum(verdi, na.rm = TRUE), .groups = "drop") |>
    pivot_wider(names_from = aldersgruppe, values_from = befolkning,
                names_prefix = "folk_") |>
    mutate(folk_ialt = folk_0_66 + folk_67_79 + folk_80p)
}

## ============================================================================
## 6. Kjør alt, sett sammen og lagre
## ============================================================================

for (pakke in c("httr2", "rjstat", "dplyr", "tidyr")) {
  if (!requireNamespace(pakke, quietly = TRUE)) {
    stop("Mangler ", pakke, ". Kjør install.packages(c('httr2','rjstat','dplyr','tidyr')) først.")
  }
}

message("Bygger kommunehistorikk...")
kommunehistorikk <- hent_kommunehistorikk()
kommunehistorikk <- kommunehistorikk[kommunehistorikk$kommunenr_2024 %in% kommuner_2024, ]

message("Henter 04686 (t.o.m. 2016)...")
d_04686 <- hent_04686(kommunehistorikk, years)

message("Henter 12292 (f.o.m. 2015)...")
d_12292 <- hent_12292(kommunehistorikk, years)

message("Henter 11924 (2015-2023, sykepleiere)...")
d_11924 <- hent_11924(kommunehistorikk, years)

message("Henter 14534 (f.o.m. 2015, alle sykepleiere)...")
d_14534 <- hent_14534(kommunehistorikk, years)

message("Henter 11645 (langtidsopphold, aldersoppløst, 2009-2025)...")
years_d_11645 <- years[years >= 2009]
d_11645 <- hent_11645_langtid(kommunehistorikk, years_d_11645)

message("Henter befolkning (07459)...")
befolkning <- hent_befolkning(kommuner_2024, years)

## Sett sammen alle Y-variabler til én lang tabell, med `kilde_tabell` bevart
## slik at du kan se/velge selv ved overlapp. Faktiske overlapp:
##  - Y_1_a, Y_2, Y_4: 04686 og 12292 overlapper bare 2015-2016, og er der
##    verifisert tallmessig identiske - den brede tabellen under tar
##    gjennomsnitt, men det spiller ingen rolle siden verdiene er like.
##  - Y_5: 04686 (t.o.m. 2016), 11924 (2015-2023) og 14534 (2015-2025)
##    overlapper i HELE 2015-2023. Disse er IKKE identiske de første årene
##    (se dokumentasjonen om metodebruddet) - 11924 og 14534 konvergerer mot
##    hverandre fra ca. 2018/2019, men avviker noe fra 04686 og fra hverandre
##    i 2015-2017. Gjennomsnittet under er derfor en forenkling for disse
##    årene - bytt til f.eks. `filter(kilde_tabell == "14534")` i stedet hvis
##    du heller vil bruke bare én kilde.
y_variabler <- bind_rows(
  if (nrow(d_04686)) mutate(d_04686, kilde_tabell = "04686") else NULL,
  if (nrow(d_12292)) mutate(d_12292, kilde_tabell = "12292") else NULL,
  if (nrow(d_11924)) mutate(d_11924, kilde_tabell = "11924") else NULL,
  if (nrow(d_14534)) mutate(d_14534, kilde_tabell = "14534") else NULL,
  if (nrow(d_11645)) mutate(d_11645, kilde_tabell = "11645") else NULL
) |>
  filter(variabel %in% c("Y_1_a_ialt", "Y_1_a_0_66", "Y_1_a_67_79", "Y_1_a_80p",
                          "Y_2_ialt", "Y_4_ialt", "Y_5_ialt",
                          "Y_3_a_ialt", "Y_3_a_0_66", "Y_3_a_67_79", "Y_3_a_80p")) |>
  rename(år = Tid)

## Lang versjon: én rad per kommune x år x variabel x kilde.
paneldata_lang <- y_variabler |>
  select(kommunenr_2024, kommunenr_hist, år, variabel, verdi, kilde_tabell)

## Bred versjon: én rad per (kommunenr_2024, kommunenr_hist, år), koblet med
## befolkning. NB: i år hvor en 2024-kommune besto av flere den gang
## selvstendige kommuner (f.eks. Ski + Oppegård -> Nordre Follo), gir dette
## FLERE rader for samme kommunenr_2024 x år - én per kommunenr_hist. Bruk
## lag_2024_struktur() under for å slå disse sammen til én rad per kommune x
## år i dagens (2024) kommunestruktur.
paneldata_bred <- y_variabler |>
  group_by(kommunenr_2024, kommunenr_hist, år, variabel) |>
  summarise(verdi = mean(verdi, na.rm = TRUE), .groups = "drop") |>
  pivot_wider(names_from = variabel, values_from = verdi) |>
  left_join(befolkning, by = c("kommunenr_2024", "år" = "Tid"))

## ============================================================================
## 7. Kollaps til ren 2024-kommunestruktur (slå sammen sammenslåtte kommuner)
## ============================================================================
## Slår de(t) historiske kommunenummer som utgjør hver 2024-kommune sammen
## til én rad per kommune x år, også for år FØR en eventuell sammenslåing -
## den nye (2024-)kommunens tall for de gamle årene blir da summen/snittet av
## det de daværende selvstendige kommunene rapporterte hver for seg:
##  - Antallsvariabler (brukere, beboere, befolkning, sykepleierårsverk)
##    SUMMERES.
##  - Y_4 (tildelte timer/uke) tas som et gjennomsnitt av kildekommunenes
##    verdier, vektet med hver kildekommunes Y_1_a_ialt (antall
##    hjemmetjenestemottakere) det året - Y_4 er i seg selv et snitt, ikke en
##    additiv størrelse, så det skal ikke summeres.
##  - folk_0_66/folk_67_79/folk_80p/folk_ialt SUMMERES IKKE her, selv om de
##    ellers ligner "antallsvariabler": befolkningstabellen (07459) bruker
##    allerede SSBs egen sammenslåtte kodeliste (agg_KommSummer), så
##    folk_ialt er FRA FØR summen for hele 2024-kommunen, uansett hvilken
##    kommunenr_hist-rad man ser på (samme tall er duplisert på hver rad før
##    sammenslåing) - å summere den på nytt her ville dobbelttalt den. De tas
##    derfor bare fra første rad.
##
## NB: valg av vekt. Vi vekter med Y_1_a_ialt (ikke folkemengde) fordi
## folkemengden - som forklart over - allerede er den sammenslåtte
## 2024-kommunens tall og derfor IDENTISK på hver kildekommune-rad; å vekte
## med den ville gitt et uvektet snitt i praksis, ikke et ekte befolkningsvektet
## snitt. Y_1_a_ialt varierer derimot faktisk per kildekommune, og er en
## rimelig proxy for "aktivitetsstørrelse" for begge variablene. For en enda
## mer presis Y_4-rekonstruksjon (siden Y_4 er nettopp et snitt beregnet over
## Y_1_a_ialt-mottakerne) er dette faktisk det matematisk riktige valget.
## Y_5 (sykepleierårsverk) er en additiv størrelse, i motsetning til Y_4 -
## den SUMMERES derfor her, ikke vektes som et snitt.
SUM_KOLONNER <- c("Y_1_a_ialt", "Y_1_a_0_66", "Y_1_a_67_79", "Y_1_a_80p",
                   "Y_2_ialt",
                   "Y_3_a_ialt", "Y_3_a_0_66", "Y_3_a_67_79", "Y_3_a_80p",
                   "Y_5_ialt")
BEFOLKNING_KOLONNER <- c("folk_0_66", "folk_67_79", "folk_80p", "folk_ialt")
VEKTET_SNITT_KOLONNER <- c("Y_4_ialt")
VEKT_KOLONNE <- "Y_1_a_ialt"

sum_na <- function(x) if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE)
vektet_snitt_na <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & w > 0
  if (!any(ok)) return(NA_real_)
  weighted.mean(x[ok], w[ok])
}

lag_2024_struktur <- function(paneldata_bred) {
  paneldata_bred |>
    group_by(kommunenr_2024, år) |>
    summarise(
      kommunenr_hist_kilder = paste(sort(unique(kommunenr_hist)), collapse = "+"),
      # Vektet snitt beregnes FØR summeringen under, slik at vektkolonnen
      # (Y_1_a_ialt) her fortsatt er de opprinnelige, usummerte tallene per
      # kildekommune - ikke den nye, summerte 2024-kommunens tall.
      across(any_of(VEKTET_SNITT_KOLONNER),
             ~ vektet_snitt_na(.x, .data[[VEKT_KOLONNE]])),
      across(any_of(BEFOLKNING_KOLONNER), dplyr::first),
      across(any_of(SUM_KOLONNER), sum_na),
      .groups = "drop"
    )
}

paneldata_2024struktur <- lag_2024_struktur(paneldata_bred)

## ---- Lagre -------------------------------------------------------------
dir.create(utmappe, recursive = TRUE, showWarnings = FALSE)
saveRDS(paneldata_lang, file.path(utmappe, "paneldata_2007_2025_lang.rds"))
saveRDS(paneldata_bred, file.path(utmappe, "paneldata_2007_2025_bred.rds"))
write.csv(paneldata_bred, file.path(utmappe, "paneldata_2007_2025_bred.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")
saveRDS(paneldata_2024struktur,
        file.path(utmappe, "paneldata_2007_2025_2024struktur.rds"))
write.csv(paneldata_2024struktur,
          file.path(utmappe, "paneldata_2007_2025_2024struktur.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")

message(nrow(paneldata_bred), " rader (kommune x historisk kommunenr x år) lagret i ",
        normalizePath(utmappe))
message(nrow(paneldata_2024struktur), " rader (kommune x år, 2024-struktur) lagret")
message("Kolonner: ", paste(names(paneldata_2024struktur), collapse = ", "))
# Ved senere innlesing:
# paneldata <- readRDS("data/ssb/paneldata_2007_2025_2024struktur.rds")
