# hent_planverk_buskerud.R
#
# Laster ned kommuneplanens samfunnsdel, planstrategi og tilhørende
# kunnskapsgrunnlag / helse- og omsorgsplaner for de 18 kommunene i Buskerud
# (2024-struktur, 3301-3338), konverterer PDF-ene til tekst og trekker ut
# avsnitt som handler om demografi (befolkningsutvikling, aldring,
# framskrivinger, flytting, innvandring o.l.).
#
# Dokumentlisten ligger i data/planverk/buskerud/manifest.csv (kilde-URL-er
# hentet fra kommunenes nettsider september 2026). Rader med format
# "framsikt" er nettpublikasjoner (pub.framsikt.net) uten PDF; teksten
# hentes direkte fra publikasjonens JSON/HTML-filer (se avsnitt 2b). Rader med
# format "web" er planer publisert som vanlige nettsider (Drammen); alle
# undersider under planens sti hentes (avsnitt 2c).
#
# Kjent begrensning: skannede sider / sider der teksten bare finnes i bilder
# (infografikk) gir ingen tekst - det gjelder bl.a. Drammenstrender 2023 og
# Åls planstrategi. Disse krever OCR.
#
# Resultat (data/planverk/buskerud/):
#   pdf/<fil>.pdf                 - originaldokumentene (ikke i git)
#   tekst/<fil>.md                - full tekst med sidemarkører
#   demografi/<kommunenr>_<kommune>.md - demografiavsnitt per kommune
#   demografi_avsnitt.csv/.rds    - alle demografiavsnitt i ett datasett
#   dokumentstatus.csv            - nedlastingsstatus, sider og antall treff
#
# PDF-konvertering: pdftools hvis installert, ellers pdftotext (Poppler,
# følger bl.a. med Git for Windows og MiKTeX).

library(httr2)
library(dplyr)
library(readr)
library(stringr)

rotmappe <- file.path("data", "planverk", "buskerud")
mapper <- file.path(rotmappe, c("pdf", "tekst", "demografi"))
for (m in mapper) dir.create(m, showWarnings = FALSE, recursive = TRUE)

manifest <- read_csv(file.path(rotmappe, "manifest.csv"),
                     col_types = cols(.default = col_character()))

## ---- 1. Nedlasting -------------------------------------------------------
last_ned <- function(url, fil) {
  if (file.exists(fil) && file.size(fil) > 0) return("finnes")
  res <- tryCatch({
    request(url) |>
      req_user_agent("Telemarksforsking Fram (planverk Buskerud)") |>
      req_timeout(120) |>
      req_retry(max_tries = 3) |>
      req_perform(path = fil)
    "lastet ned"
  }, error = function(e) paste("feil:", conditionMessage(e)))
  if (startsWith(res, "feil")) {
    if (file.exists(fil)) file.remove(fil)  # feilside skrevet til disk
  } else if (!identical(readBin(fil, "raw", 4), charToRaw("%PDF"))) {
    file.remove(fil)
    res <- "feil: ikke en PDF"
  }
  Sys.sleep(1)  # vær snill mot kommunenes servere
  res
}

pdf_rader <- manifest |> filter(format == "pdf")
pdf_rader$pdf_fil <- file.path(rotmappe, "pdf", paste0(pdf_rader$fil, ".pdf"))
pdf_rader$nedlasting <- mapply(last_ned, pdf_rader$url, pdf_rader$pdf_fil)
print(count(pdf_rader, nedlasting))

## ---- 2. PDF -> tekst -----------------------------------------------------
# Returnerer en tegnvektor med én streng per side.
pdf_til_sider <- function(fil) {
  if (requireNamespace("pdftools", quietly = TRUE)) {
    return(pdftools::pdf_text(fil))
  }
  exe <- Sys.which("pdftotext")
  if (exe == "") {
    kandidater <- c("C:/Program Files/Git/mingw64/bin/pdftotext.exe",
                    Sys.glob("C:/Users/*/AppData/Local/Programs/MiKTeX/miktex/bin/x64/pdftotext.exe"))
    exe <- kandidater[file.exists(kandidater)][1]
  }
  if (is.na(exe) || exe == "") stop("Fant verken pdftools eller pdftotext")
  ut <- tempfile(fileext = ".txt")
  system2(exe, c("-enc", "UTF-8", shQuote(fil), shQuote(ut)))
  if (!file.exists(ut)) {  # skadet PDF
    warning("Kunne ikke konvertere ", fil)
    return(character(0))
  }
  tekst <- read_file(ut, locale = locale(encoding = "UTF-8"))
  sider <- strsplit(tekst, "\f", fixed = TRUE)[[1]]
  sider
}

# Rydder opp i PDF-tekst: orddeling over linjeskift, mange mellomrom osv.
rens_side <- function(x) {
  x |>
    str_replace_all("\r", "") |>
    str_replace_all("(\\p{L})-\n(\\p{Ll})", "\\1\\2") |>
    str_replace_all("[ \t]+", " ") |>
    str_replace_all(" *\n *", "\n") |>
    str_replace_all("\n{3,}", "\n\n") |>
    str_trim()
}

skriv_tekst <- function(rad, sider, enhet = "side") {
  hode <- c(paste0("# ", rad$kommune, ": ", rad$tittel), "",
            paste0("- Kommunenr: ", rad$kommunenr),
            paste0("- Dokumenttype: ", rad$dokumenttype),
            paste0("- Status: ", rad$status),
            paste0("- Kilde: <", rad$url, ">"),
            paste0("- Konvertert: ", Sys.Date()), "")
  kropp <- unlist(lapply(seq_along(sider), function(i) {
    c(paste0("<!-- ", enhet, " ", i, " -->"), "", sider[i], "")
  }))
  write_lines(c(hode, kropp), file.path(rotmappe, "tekst", paste0(rad$fil, ".md")))
}

ok <- file.exists(pdf_rader$pdf_fil)
sider_liste <- list()
for (i in which(ok)) {
  sider <- vapply(pdf_til_sider(pdf_rader$pdf_fil[i]), rens_side, character(1))
  sider_liste[[pdf_rader$fil[i]]] <- sider
  skriv_tekst(pdf_rader[i, ], sider)
}

## ---- 2b. Framsikt-publikasjoner -> tekst ---------------------------------
# pub.framsikt.net er en Angular-app som leser statiske filer. Visningen
# "Vis planen på én side" (summary/1111...) har en content.html med
# overskrifter og plassholdere (dataId) for hvert tekstavsnitt; selve
# teksten ligger i content/text/<dataId>/description.json. Hver
# h1/h2-seksjon behandles som én "side".
html_til_tekst <- function(html) {
  if (is.null(html) || !nzchar(html)) return("")
  html <- str_replace_all(html, "(?i)<br\\s*/?>", "\n")
  html <- str_replace_all(html, "(?i)</(p|li|h[1-6]|tr|div|table|ul|ol)>", "\n\n")
  html <- str_replace_all(html, "(?i)</t[dh]>", " | ")
  xml2::xml_text(xml2::read_html(paste0("<body>", html, "</body>")))
}

hent_framsikt <- function(url) {
  base <- paste0(sub("/(#.*)?$", "", url), "/content")
  hent <- function(sti) {
    request(paste0(base, sti)) |> req_timeout(60) |> req_retry(max_tries = 3) |>
      req_perform() |> resp_body_string(encoding = "UTF-8")
  }
  side_id <- "summary/11111111-1111-1111-1111-111111111111"
  html <- hent(paste0("/html/", side_id, "/content.html"))
  # Overskrifter og avsnitt i dokumentrekkefølge
  m <- str_match_all(html, paste0(
    "class=\"row h([1-6])\"[^>]*>([^<]*)</div>|",
    "dataId\\s*=\\s*\"([^\"]+)\""))[[1]]
  seksjoner <- character(0)
  gjeldende <- character(0)
  for (r in seq_len(nrow(m))) {
    if (!is.na(m[r, 2])) {
      nivaa <- as.integer(m[r, 2])
      overskrift <- html_til_tekst(m[r, 3])
      if (nivaa <= 2 && length(gjeldende) > 0) {
        seksjoner <- c(seksjoner, paste(gjeldende, collapse = "\n\n"))
        gjeldende <- character(0)
      }
      gjeldende <- c(gjeldende, paste(strrep("#", nivaa + 1), overskrift))
    } else {
      d <- tryCatch(jsonlite::fromJSON(hent(paste0("/text", m[r, 4], "/description.json"))),
                    error = function(e) NULL)
      if (!is.null(d$description)) gjeldende <- c(gjeldende, html_til_tekst(d$description))
    }
  }
  if (length(gjeldende) > 0) seksjoner <- c(seksjoner, paste(gjeldende, collapse = "\n\n"))
  seksjoner
}

## ---- 2c. Planer publisert som vanlige nettsider -> tekst -----------------
# Format "web": url er rotmappen til planen (f.eks. Drammens temaplaner under
# /politikk-samfunn/planer/<plan>/). Alle undersider under samme sti hentes
# (inntil 60 sider), og innholdet i <main> blir én "seksjon" per side.
hent_web <- function(url, maks_sider = 60) {
  u <- httr2::url_parse(url)
  prefiks <- sub("[^/]*$", "", u$path)
  vert <- paste0(u$scheme, "://", u$hostname)
  les <- function(side) {
    tryCatch(request(side) |> req_user_agent("Mozilla/5.0") |> req_timeout(60) |>
               req_perform() |> resp_body_string(encoding = "UTF-8") |> xml2::read_html(),
             error = function(e) NULL)
  }
  lenker_under <- function(doc) {
    h <- xml2::xml_attr(xml2::xml_find_all(doc, "//a[@href]"), "href")
    h <- sub("#.*$", "", sub(paste0("^", vert), "", h))
    unique(h[startsWith(h, prefiks)])
  }
  sider <- prefiks
  besokt <- list()
  i <- 1
  while (i <= length(sider) && length(besokt) < maks_sider) {
    doc <- les(paste0(vert, sider[i]))
    if (!is.null(doc)) {
      besokt[[sider[i]]] <- doc
      sider <- unique(c(sider, lenker_under(doc)))
    }
    i <- i + 1
  }
  vapply(besokt, function(doc) {
    main <- xml2::xml_find_first(doc, "//main")
    if (inherits(main, "xml_missing")) main <- xml2::xml_find_first(doc, "//body")
    xml2::xml_remove(xml2::xml_find_all(main, ".//script|.//style|.//nav"))
    noder <- xml2::xml_find_all(main, ".//h1|.//h2|.//h3|.//h4|.//p|.//li|.//tr")
    tekst <- vapply(noder, function(n) {
      t <- str_squish(xml2::xml_text(n))
      navn <- xml2::xml_name(n)
      if (grepl("^h[1-4]$", navn)) paste(strrep("#", as.integer(substr(navn, 2, 2)) + 1), t)
      else if (navn == "li") paste("-", t) else t
    }, character(1))
    paste(unique(tekst[nzchar(tekst)]), collapse = "\n\n")
  }, character(1), USE.NAMES = FALSE)
}

for (i in which(manifest$format == "web")) {
  seksjoner <- tryCatch(hent_web(manifest$url[i]), error = function(e) {
    message(manifest$fil[i], ": ", conditionMessage(e)); NULL
  })
  if (length(seksjoner) == 0) next
  seksjoner <- vapply(seksjoner, rens_side, character(1), USE.NAMES = FALSE)
  sider_liste[[manifest$fil[i]]] <- seksjoner
  skriv_tekst(manifest[i, ], seksjoner, enhet = "seksjon")
}

for (i in which(manifest$format == "framsikt")) {
  seksjoner <- tryCatch(hent_framsikt(manifest$url[i]), error = function(e) {
    message(manifest$fil[i], ": ", conditionMessage(e)); NULL
  })
  if (length(seksjoner) == 0) next
  seksjoner <- vapply(seksjoner, rens_side, character(1), USE.NAMES = FALSE)
  sider_liste[[manifest$fil[i]]] <- seksjoner
  skriv_tekst(manifest[i, ], seksjoner, enhet = "seksjon")
}

## ---- 3. Demografiuttrekk -------------------------------------------------
# Sterke termer gir alltid treff. Svake termer ("befolkningen",
# "innbyggere", "eldre", "SSB" ...) brukes også generelt ("tjenester til
# befolkningen", "eldre planer") og gir bare treff når avsnittet har minst
# to svake treff og i tillegg inneholder et tall (år, antall eller
# prosent). Aldersuttrykk som "80 år", "80+" og "over 90" fanger
# eldrebølgen og behovet for omsorgstjenester.
sterk_regex <- regex(paste(
  "befolkningsutvikl\\w*", "befolkningsvekst\\w*", "befolkningsnedgang\\w*",
  "befolkningsøkning\\w*", "befolknings(fram|frem)skriv\\w*",
  "befolkningsprognose\\w*", "befolkningssammensetning\\w*",
  "befolkningsstruktur\\w*", "befolkningspyramide\\w*",
  "folketal\\w*", "innbyggertal\\w*", "antall innbyggere",
  "innbyggerutvikl\\w*", "demografi\\w*", "aldersbære\\w*",
  "aldersstruktur\\w*", "alderssammensetning\\w*", "aldersfordeling\\w*",
  "aldring\\w*", "eldrebølg\\w*", "(flere|andel(en)?|antall(et)?) eldre",
  "(fram|frem)skriv\\w*", "MMMM", "fødselstall\\w*", "fødselsoverskudd\\w*",
  "fødselsunderskudd\\w*", "fødte", "fruktbarhet\\w*", "tilflytting\\w*",
  "fraflytting\\w*", "nettoflytting\\w*", "netto innflytting",
  "innflytting\\w*", "utflytting\\w*", "flyttemønster\\w*",
  "innvandr\\w*", "levealder\\w*", "forsørgerbrøk\\w*",
  "forsørgelsesbyrde\\w*", "yrkesaktiv alder", "arbeidsfør alder",
  "\\b(67|70|75|80|85|90) ?år( og eldre)?", "\\b(67|80|90) ?\\+",
  "over (67|80|90)",
  sep = "|"), ignore_case = TRUE)

svak_regex <- regex(paste(
  "befolkning\\w*", "innbyggere\\w*", "eldre", "SSB", "prognose\\w*",
  "aleneboende", "omsorgsbehov\\w*", "demens\\w*",
  sep = "|"), ignore_case = TRUE)

tall_regex <- regex("\\b\\d[\\d  .,]{2,}\\b|\\d+ ?%|\\d+ ?prosent")

del_avsnitt <- function(side) {
  a <- str_split(side, "\n\\s*\n")[[1]]
  a <- str_squish(a)
  a[nchar(a) >= 40]
}

avsnitt <- bind_rows(lapply(names(sider_liste), function(f) {
  sider <- sider_liste[[f]]
  bind_rows(lapply(seq_along(sider), function(s) {
    a <- del_avsnitt(sider[s])
    if (length(a) == 0) return(NULL)
    tibble(fil = f, side = s, avsnitt = a)
  }))
})) |>
  mutate(n_sterk = str_count(avsnitt, sterk_regex),
         n_svak = str_count(avsnitt, svak_regex),
         har_tall = str_detect(avsnitt, tall_regex)) |>
  filter(n_sterk > 0 | (n_svak >= 2 & har_tall)) |>
  mutate(treff = mapply(\(a, b) paste(unique(tolower(c(a, b))), collapse = ", "),
                        str_extract_all(avsnitt, sterk_regex),
                        str_extract_all(avsnitt, svak_regex)),
         n_treff = n_sterk + n_svak) |>
  select(-har_tall) |>
  left_join(manifest |> select(fil, kommunenr, kommune, dokumenttype, tittel, format, url),
            by = "fil") |>
  relocate(kommunenr, kommune, fil, dokumenttype, tittel, side)

write_csv(avsnitt, file.path(rotmappe, "demografi_avsnitt.csv"))
saveRDS(avsnitt, file.path(rotmappe, "demografi_avsnitt.rds"))

## ---- 4. Én markdown-fil per kommune --------------------------------------
kommuner <- manifest |> distinct(kommunenr, kommune)
for (k in seq_len(nrow(kommuner))) {
  kn <- kommuner$kommunenr[k]
  kd <- avsnitt |> filter(kommunenr == kn)
  dok <- manifest |> filter(kommunenr == kn)
  linjer <- c(paste0("# Demografi i planverket: ", kommuner$kommune[k], " (", kn, ")"), "",
              "Avsnitt fra kommunens plandokumenter som omtaler befolkningsutvikling,",
              "aldring, framskrivinger, flytting og innvandring. Automatisk uttrekk",
              "(nøkkelord) - kontroller mot originaldokumentet før bruk.", "",
              "## Dokumenter", "",
              paste0("- [", dok$tittel, "](", dok$url, ") - ", dok$dokumenttype,
                     ", ", dok$status,
                     ifelse(dok$fil %in% names(sider_liste), "",
                            " *(ikke konvertert)*")),
              "")
  for (f in unique(kd$fil)) {
    fd <- kd |> filter(fil == f)
    linjer <- c(linjer, paste0("## ", fd$tittel[1]), "",
                unlist(lapply(seq_len(nrow(fd)), function(j) {
                  c(paste0("**", ifelse(fd$format[j] %in% c("framsikt", "web"), "Seksjon ", "Side "),
                           fd$side[j], "** _(", fd$treff[j], ")_"), "",
                    paste0("> ", fd$avsnitt[j]), "")
                })))
  }
  navn <- str_replace_all(tolower(kommuner$kommune[k]),
                          c("ø" = "o", "å" = "aa", "æ" = "ae", " " = "-"))
  write_lines(linjer, file.path(rotmappe, "demografi", paste0(kn, "_", navn, ".md")))
}

## ---- 5. Status -----------------------------------------------------------
status <- manifest |>
  left_join(pdf_rader |> select(fil, nedlasting), by = "fil") |>
  mutate(nedlasting = ifelse(format %in% c("framsikt", "web"),
                             ifelse(fil %in% names(sider_liste), "hentet", "feil"),
                             nedlasting),
         sider = vapply(fil, \(f) length(sider_liste[[f]]), integer(1))) |>
  left_join(avsnitt |> count(fil, name = "demografi_avsnitt"), by = "fil") |>
  mutate(demografi_avsnitt = coalesce(demografi_avsnitt, 0L)) |>
  select(kommunenr, kommune, fil, dokumenttype, format, nedlasting, sider, demografi_avsnitt)
write_csv(status, file.path(rotmappe, "dokumentstatus.csv"))
print(status, n = Inf)
