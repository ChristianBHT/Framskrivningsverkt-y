# deploy_shinyapps.R
#
# Publiserer appen til shinyapps.io (https://christianbht.shinyapps.io/Fram/).
# Kjør fra prosjektroten. Krever at kontoen er koblet lokalt én gang,
# i EGEN R-konsoll (inneholder et hemmelig token - skal ikke deles/sendes):
#   rsconnect::setAccountInfo(name = "...", token = "...", secret = "...")
# (hentes fra shinyapps.io: Account -> Tokens).
#
# Kun filene appen faktisk leser lastes opp (`appFiles`), ikke hele
# data/ssb/ (ca. 144 MB, mens appen trenger ca. 5 MB). `.rscignore` støtter
# ikke wildcards, så utvalget gjøres her. app.R leser ALLE filene under ved
# oppstart - mangler en av dem, krasjer appen. Skal en ny fil leses i app.R,
# må den legges til her.
#
# Fil-listen må holdes i sync med Y_VARIABLER i app.R.

appfiler <- c(
  "app.R",
  # Logo (vises i topplinjen og på Start-fanen; serveres via addResourcePath).
  file.path("resources", "telemarks-logo.png"),
  # Vises som faner i appen (leses ved oppstart).
  file.path("dokumentasjon", c(
    "teknisk_dokumentasjon.md",
    "beslutningslogg.md",
    "videre_arbeid.md"
  )),
  file.path("data", "ssb", c(
    "paneldata_2007_2025_2024struktur_med_demens.rds",
    "framskrevet_y1.rds",
    "framskrevet_y2_stjerne.rds",
    "framskrevet_y5.rds",
    "framskrevet_y1_usikkerhet.rds",
    "framskrevet_y2_stjerne_usikkerhet.rds",
    "framskrevet_y5_usikkerhet.rds",
    "modell_y1_hovedmodell_slope.rds",
    "modell_y2s_hovedmodell_slope.rds",
    "modell_y5_hovedmodell_slope.rds",
    # Fanen "Analyse stordriftsfordeler" (skript/modellsjekk_kvantil.R)
    "modellsjekk_kvantil_y_1_sammendrag.rds",
    "modellsjekk_kvantil_y_2_stjerne_sammendrag.rds",
    "modellsjekk_kvantil_y_5_sammendrag.rds",
    # Fanen "Befolkningspyramider" (skript/lag_pyramidedata.R)
    "befolkning_pyramide.rds"
  ))
)
stopifnot(all(file.exists(appfiler)))

rsconnect::deployApp(
  appDir = ".",
  appFiles = appfiler,
  appName = "Fram",
  account = "christianbht",
  server = "shinyapps.io",
  forceUpdate = TRUE,
  launch.browser = FALSE
)
