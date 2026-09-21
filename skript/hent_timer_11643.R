# hent_timer_11643.R
#
# Laster ned SSB-tabell 11643 ("Timar til omsorgstenester i løpet av året")
# for TenesteType = 15 (Helsetenester i heimen), alle aldre, 2009-2025, og
# plotter de 10 største kommunene (etter folketall 2025).
#
# Historiske kommunenummer kobles til dagens (2024) struktur via SSBs
# agg_KommSummer-kodeliste (samme prinsipp som hent_paneldata_2007_2025.R);
# timer er additive og summeres over kildekommunene.
#
# Resultat: data/ssb/timer_11643_helsetjenester_i_heimen.rds/.csv og
# data/ssb/plott_timer_11643_topp10.png

library(httr2)
library(dplyr)
library(ggplot2)

utmappe <- file.path("data", "ssb")
TABELL <- "11643"

## ---- 1. Metadata: alle regionkoder --------------------------------------
meta <- request(paste0("https://data.ssb.no/api/v0/no/table/", TABELL, "/")) |>
  req_perform() |> resp_body_json(simplifyVector = TRUE)
region_koder <- meta$variables$values[[which(meta$variables$code == "Region")]]

## ---- 2. Hent data (én spørring, alle regioner, alle år) ------------------
body <- list(
  query = list(
    list(code = "Region", selection = list(filter = "item", values = as.list(region_koder))),
    list(code = "Alder", selection = list(filter = "item", values = list("Ialt"))),
    list(code = "TenesteType", selection = list(filter = "item", values = list("15"))),
    list(code = "ContentsCode", selection = list(filter = "item", values = list("Timeforbruk"))),
    list(code = "Tid", selection = list(filter = "item", values = as.list(as.character(2009:2025))))
  ),
  response = list(format = "json")
)
resp <- request(paste0("https://data.ssb.no/api/v0/no/table/", TABELL, "/")) |>
  req_body_json(body) |> req_timeout(180) |> req_retry(max_tries = 3) |>
  req_error(is_error = function(r) FALSE) |> req_perform()
if (resp_status(resp) >= 400) stop("SSB API-feil ", resp_status(resp), ": ", resp_body_string(resp))
parsed <- resp_body_json(resp, simplifyVector = FALSE)

cols <- parsed$columns
kode <- vapply(cols, function(c) c$code, character(1))
typ <- vapply(cols, function(c) c$type, character(1))
dim_kol <- kode[typ %in% c("d", "t")]
rader <- lapply(parsed$data, function(r) {
  v <- as.list(unlist(r$key)); names(v) <- dim_kol
  v$timer <- suppressWarnings(as.numeric(r$values[[1]]))
  as.data.frame(v, stringsAsFactors = FALSE)
})
rå <- bind_rows(rader) |> transmute(kommunenr_hist = Region, år = as.integer(Tid), timer)
message("Hentet ", nrow(rå), " rader (", sum(!is.na(rå$timer)), " med verdi)")

## ---- 3. Koble til 2024-struktur ------------------------------------------
kh_resp <- request("https://data.ssb.no/api/pxwebapi/v2/codeLists/agg_KommSummer?lang=no") |>
  req_timeout(60) |> req_perform() |> resp_body_json(simplifyVector = FALSE)
kh <- bind_rows(lapply(kh_resp$values, function(v) {
  data.frame(kommunenr_2024 = sub("^K-", "", v$code), kommunenr_hist = unlist(v$valueMap),
             stringsAsFactors = FALSE)
}))

timer <- rå |>
  inner_join(kh, by = "kommunenr_hist", relationship = "many-to-many") |>
  filter(!is.na(timer)) |>
  group_by(kommunenr_2024, år) |>
  summarise(timer = sum(timer), kilder = paste(sort(unique(kommunenr_hist)), collapse = "+"),
            .groups = "drop")

saveRDS(timer, file.path(utmappe, "timer_11643_helsetjenester_i_heimen.rds"))
write.csv(timer, file.path(utmappe, "timer_11643_helsetjenester_i_heimen.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

## ---- 4. De 10 største kommunene (folketall 2025) og plott ----------------
pan <- readRDS(file.path(utmappe, "paneldata_2007_2025_2024struktur_med_demens.rds"))
topp10 <- pan |> filter(år == 2025) |> arrange(desc(folk_ialt)) |> slice_head(n = 10) |>
  select(kommunenr_2024, folk_ialt)

navn_resp <- request("https://data.ssb.no/api/klass/v1/classifications/131/codesAt?date=2025-01-01") |>
  req_perform() |> resp_body_json(simplifyVector = TRUE)
navn <- navn_resp$codes[, c("code", "name")]

d <- timer |> inner_join(topp10, by = "kommunenr_2024") |>
  left_join(navn, by = c("kommunenr_2024" = "code")) |>
  mutate(kommune = factor(name, levels = navn$name[match(topp10$kommunenr_2024, navn$code)]))

print(d |> select(kommunenr_2024, kommune, år, timer, kilder) |> filter(år %in% c(2009, 2015, 2020, 2025)))
message("Antall år per kommune: ", paste(names(table(d$kommune)), table(d$kommune), collapse = ", "))

p <- ggplot(d, aes(år, timer / 1000, color = kommune)) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.4) +
  scale_x_continuous(breaks = seq(2009, 2025, 2)) +
  labs(title = "Timer helsetjenester i hjemmet (SSB tabell 11643, tjenestetype 15)",
       subtitle = "De 10 største kommunene etter folketall 2025, alle aldre",
       x = "År", y = "Timer per år (tusen)", color = NULL) +
  theme_minimal(base_size = 12)
ggsave(file.path(utmappe, "plott_timer_11643_topp10.png"), p, width = 11, height = 6, dpi = 150)
message("Lagret plott")
