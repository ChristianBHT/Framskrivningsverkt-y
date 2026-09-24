# Kommuneframsyn (arbeidstittel) - Telemarksforskning

R Shiny-app som viser historisk og framskrevet etterspørsel etter kommunale
helse- og omsorgstjenester per kommune, 2007-2050:

- brukere av hjemmesykepleie
- brukere av boliger (heldøgns omsorg)
- sykepleiere (avtalte årsverk)

Framskrivningen bygger på statistiske modeller estimert på SSB-data og på
SSBs befolkningsframskrivning (hovedalternativet MMMM). Appen vises med et
95 % usikkerhetsintervall og har en valgfri "kommunens egen trend" som kan
fases ut over 0-10 år. Kommunen kan i tillegg skrive inn egne tall for 2025
(hjemmetjenester, bolig, sykepleiere), som da erstatter SSBs tall som
utgangspunkt for framskrivningen (lagres ikke).

**Publisert (beta):** https://christianbht.shinyapps.io/Fram/

## Kjøre lokalt

Fra prosjektroten:

```r
install.packages(c("shiny", "bslib", "httr2", "dplyr", "plotly", "DT", "lme4"))
shiny::runApp()
```

Appen leser ferdig beregnede filer fra `data/ssb/` (se listen i
`skript/deploy_shinyapps.R`) og henter kommunenavn fra SSBs Klass-API ved
oppstart (faller tilbake til kommunenummer uten internett).

## Mapper

| Sti | Innhold |
|---|---|
| `app.R` | Appen. Må ligge i prosjektroten - Shiny kjører alle `.R`-filer i roten og i `R/` automatisk ved oppstart, derfor ligger alle arbeidsflyt-script i `skript/` |
| `skript/` | Frittstående script for datainnhenting, modellering, framskrivning, usikkerhet og modellsjekker |
| `data/ssb/` | Nedlastede data og alle resultatfiler (`.rds`/`.csv`) |
| `dokumentasjon/` | Beslutningslogg, teknisk dokumentasjon og arbeidsplan |

## Arbeidsflyt (kjøres fra prosjektroten, i rekkefølge)

1. `skript/hent_paneldata_2007_2025.R` - henter SSB-tabeller (04686, 12292,
   11645, 11924, 14534, 07459) og slår sammen til 2024-kommunestruktur
2. `skript/legg_til_demens.R` - estimerer demensandel per kommune og år
3. `skript/modell_y1.R`, `modell_y2_stjerne.R`, `modell_y5.R` - estimerer
   modellene (Poisson-GLMM for Y_1 og Y_2\*, log-lineær blandet modell for
   Y_5) med leave-one-year-out-kryssvalidering
4. `skript/framskriv_y1.R`, `framskriv_y2_stjerne.R`, `framskriv_y5.R` -
   framskriver med SSBs befolkningsframskrivning (tabell 12882)
5. `skript/usikkerhet_y1.R`, `usikkerhet_y2_stjerne.R`, `usikkerhet_y5.R` -
   95 % konfidensintervall med Bayesiansk bootstrap over kommuner (60
   iterasjoner)

Øvrige script:

- `modell_y5_poisson.R` / `framskriv_y5_poisson.R` - alternativ Y_5-modell
  (Poisson), **fjernet fra appen** fordi variansparametrene ikke estimeres
  (se `dokumentasjon/beslutningslogg.md` pkt. 11 og 21). Scriptene er beholdt
  til dokumentasjon
- `lag_pyramidedata.R` - lager `data/ssb/befolkning_pyramide.rds` (alder x
  kjønn per kommune og år, observert 2007-2025 og SSBs framskrivning
  2026-2050) til fanen Befolkningspyramider
- `modellsjekk_kvantil.R` - sjekker om koeffisienten på log(befolkning) er 1
  (kvantilregresjon + Bayesiansk bootstrap)
- `hent_timer_11643.R` - laster ned SSB-tabell 11643 (timer, helsetjenester
  i hjemmet) og plotter de 10 største kommunene
- `modell_y4.R` - modell for Y_4 (timer/uke); ingen framskrivning ennå,
  svak modellfit
- `hent_planverk_buskerud.R` - laster ned og konverterer samfunnsdel,
  planstrategi og kunnskapsgrunnlag for de 18 Buskerud-kommunene og
  trekker ut demografiavsnitt (se `data/planverk/buskerud/README.md`)
- `deploy_shinyapps.R` - publisering

## Publisere

Koble kontoen én gang i egen R-konsoll med
`rsconnect::setAccountInfo(...)` (token hentes fra shinyapps.io, deles
ikke), deretter fra prosjektroten:

```r
source("skript/deploy_shinyapps.R")
```

Bare filene appen leser lastes opp (ca. 5 MB). Gratisnivået på
shinyapps.io har en grense på 25 aktive timer per måned, og appen sovner
etter ca. 15 minutters inaktivitet.

## Dokumentasjon

- [dokumentasjon/beslutningslogg.md](dokumentasjon/beslutningslogg.md) -
  hva som er valgt og hvorfor
- [dokumentasjon/teknisk_dokumentasjon.md](dokumentasjon/teknisk_dokumentasjon.md) -
  modellformler, estimering og framskrivningsmetode
- [dokumentasjon/videre_arbeid.md](dokumentasjon/videre_arbeid.md) -
  arbeidsplan

I beta-versjonen vises dokumentasjonen også som faner i appen (teknisk
dokumentasjon, beslutningslogg, videre arbeid); appen er offentlig og uten
innlogging, og `dokumentasjon/*.md` lastes derfor opp sammen med appen
(`skript/` gjør det ikke). I den ENDELIGE appen skal metodikk bare forklares
overfladisk: sett `VIS_FULL_DOKUMENTASJON <- FALSE` i `app.R` (da vises bare
et kort avsnitt i "Om"-fanen) og fjern `dokumentasjon/*.md` fra
`skript/deploy_shinyapps.R`.

## Datakilder (SSB statistikkbank) og lisens

Statistikken er hentet fra Statistisk sentralbyrå (SSB) og brukes under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), som tillater
kommersiell bruk mot kreditering ([SSBs lisensvilkår](https://www.ssb.no/diverse/lisens)).
Tallene er bearbeidet av Telemarksforskning (framskrivningene er ikke SSBs
tall). Krediteringen vises i appens bunntekst og i Om-fanen.

04686, 12292 (omsorgstjenester), 11645 (institusjonstjenester), 11924,
14534 (sykepleiere, avtalte årsverk), 07459 (befolkning), 12882
(befolkningsframskrivninger).
