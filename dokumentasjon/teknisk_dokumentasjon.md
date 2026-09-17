# Teknisk dokumentasjon - modeller og estimering

Dette dokumentet beskriver de statistiske modellene som brukes til å
framskrive Y_1, Y_2*, Y_4 og Y_5: likninger, estimeringsprosedyre,
kryssvalideringsresultater og framskrivningsmetode. For BEGRUNNELSENE bak
disse valgene (hvorfor Poisson, hvorfor intercept-only, hvorfor 2010 er
utelatt for Y_1 osv.), se [beslutningslogg.md](beslutningslogg.md).

**NB**: dette dokumentet er bevisst IKKE tilgjengelig fra selve
Shiny-appen (`app.R`) - se punkt 6 i beslutningsloggen.

## 1. Datagrunnlag

| Variabel | Definisjon | Estimeringsperiode | Kommune-år (N) | Kommuner |
|---|---|---|---|---|
| Y_1 | Brukere av hjemmetjenester, i alt | 2007-2025, ekskl. 2010 | 6 337 | 357 |
| Y_2* | Y_2 (heldøgnsbolig) + Y_3_a (institusjon, langtid), i alt | 2007-2025 | 5 167 | 355 |
| Y_4 | Gjennomsnittlig timer/uke, hjemmetjenester | 2007-2025 | 6 329 | 357 |
| Y_5 | Sykepleiere, årsverk i alt | 2015-2025 (mangler helt 2007-2014) | 3 898 | 357 |

Alle modeller bruker `demensandel = demens_estimert / folk_ialt` (se
`legg_til_demens.R`) og en tilfeldig kommuneeffekt over `kommunenr_2024`
(2024-kommunestruktur, se `hent_paneldata_2007_2025.R`).

Demensestimatet beregnes som:

```
demens_estimert(kommune, år) = Σ_(alder, kjønn) [ befolkning(alder, kjønn, kommune, år) × prevalensrate(alder, kjønn) ]
```

der prevalensratene er faste, aldersgruppe- og kjønnsspesifikke andeler
(se `dementia_dic` i `legg_til_demens.R`).

## 2. Modell Y_1 - hjemmetjenestebrukere (`modell_y1.R`)

**Type**: Poisson generalisert lineær blandet modell (`lme4::glmer`,
log-lenke), befolkning som eksponering (offset).

**Likning (hovedmodell)**:

```
Y_1_a_ialt(k, t)  ~  Poisson(μ_kt)
log(μ_kt) = log(folk_ialt_kt) + β_0 + Σ_t γ_t · år_t + β_1 · demensandel_kt + u_k
u_k ~ N(0, σ_u²)
```

**Estimerte parametre (hovedmodell, alle tilgjengelige år unntatt 2010)**:

| Parameter | Estimat |
|---|---|
| Intercept (β_0) | -3,832 |
| demensandel (β_1) | 34,02 |
| Årseffekter (γ_t) | spenner fra -0,047 (2025) til 0,059 (2009), relativt til 2007 |
| Kommune-tilfeldig-intercept, SD (σ_u) | 0,188 |

**Kryssvalidering (leave-one-year-out, alle år)**:

| Modellvariant | RMSE | MAE | Korrelasjon |
|---|---|---|---|
| Kun tilfeldig intercept (brukt til framskrivning) | 104,9 | 51,4 | 0,9964 |
| Intercept + korrelert helning på demensandel | 68,0 | 34,2 | 0,9985 |

Helningsvarianten gir 91 av 357 kommuner en negativ effektiv helning på
demensandel - derfor brukes intercept-only-modellen til framskrivning,
selv om helningsvarianten scorer bedre på CV (se beslutningslogg pkt. 3).

**2010 er utelatt** fra estimeringsdataene for denne variabelen (se
beslutningslogg pkt. 1).

## 3. Modell Y_2* - heldøgns omsorg (`modell_y2_stjerne.R`)

**Type**: samme struktur som Y_1 (Poisson GLMM, log-lenke, befolkning som
offset).

**Likning**:

```
Y_2_stjerne_ialt(k, t)  ~  Poisson(μ_kt)
log(μ_kt) = log(folk_ialt_kt) + β_0 + Σ_t γ_t · år_t + β_1 · demensandel_kt + u_k
```

der `Y_2_stjerne_ialt = Y_2_ialt + Y_3_a_ialt`.

**Estimerte parametre (hovedmodell, alle år 2007-2025)**:

| Parameter | Estimat |
|---|---|
| Intercept (β_0) | -4,956 |
| demensandel (β_1) | 30,80 |
| Årseffekter (γ_t) | monotont fallende fra 2010 (0,003) til 2025 (-0,171), relativt til 2009 |
| Kommune-tilfeldig-intercept, SD (σ_u) | 0,260 |

**Kryssvalidering (leave-one-year-out, alle år)**:

| Modellvariant | RMSE | MAE | Korrelasjon |
|---|---|---|---|
| Kun tilfeldig intercept (brukt til framskrivning) | 35,7 | 19,2 | 0,9968 |
| Intercept + korrelert helning på demensandel | 46,4 | 20,7 | 0,9950 |

Her er intercept-only-modellen faktisk BEST på kryssvalidering i tillegg
til å unngå fortegnsproblemet (95/355 kommuner med negativ effektiv
helning i den korrelerte helningsvarianten, 78/355 i den ukorrelerte).

**2010 er IKKE utelatt** for denne variabelen - sjekket spesifikt og ikke
funnet noe tilsvarende avvik (se beslutningslogg pkt. 1).

## 4. Modell Y_4 - timer/uke (`modell_y4.R`)

**Type**: lineær blandet modell (`lme4::lmer`, identitetslenke) - IKKE
Poisson, siden Y_4 allerede er et gjennomsnitt (timer/uke per bruker), ikke
et antall. Ingen offset.

**Likning**:

```
Y_4_ialt(k, t) = β_0 + Σ_t γ_t · år_t + β_1 · demensandel_kt + u_k + ε_kt
u_k ~ N(0, σ_u²),  ε_kt ~ N(0, σ_ε²)
```

**Estimerte parametre (hovedmodell, alle år 2007-2025)**:

| Parameter | Estimat |
|---|---|
| Intercept (β_0) | 4,093 |
| demensandel (β_1) | -0,899 |
| Årseffekter (γ_t) | stigende fra 2009 (0,460) til 2022 (1,022), noe fallende mot 2025 (0,937) |
| Kommune-tilfeldig-intercept, SD (σ_u) | 2,105 |
| Residual-SD (σ_ε) | 1,774 |

**Kryssvalidering (leave-one-year-out, alle år)**:

| Modellvariant | RMSE | MAE | Korrelasjon |
|---|---|---|---|
| Kun tilfeldig intercept (brukt til framskrivning) | 1,77 | 1,20 | 0,736 |
| Intercept + korrelert helning på demensandel | 1,53 | 0,98 | 0,813 |

Vesentlig svakere prediktiv treffsikkerhet enn de øvrige variablene
(forventet - se `modell_y4.R`s egen kommentar om at Y_4 er et gjennomsnitt
beregnet over få brukere i mange, særlig små, kommuner). Helningsvarianten
har et enda mer utbredt fortegnsproblem enn de andre variablene: 195/357
kommuner (korrelert) / 192/357 (ukorrelert) får en negativ effektiv
helning på demensandel.

**Forkastet variant**: `Y_1_a_ialt` (antall hjemmetjenestemottakere) ble
testet som en ekstra, rå forklaringsvariabel på oppfordring. Ga ingen
meningsfull forbedring i CV-korrelasjon (~0,735 med og uten), og fikk
`demensandel`s koeffisient til å bli enda mer negativ - et tegn på at
`Y_1_a_ialt` i stor grad fanger opp kommunestørrelse (kollinearitet), ikke
en selvstendig effekt. Ikke tatt i bruk. Koden for dette forsøket ligger
fortsatt i `modell_y4.R` (kommentert inn i formlene), men brukes ikke i
`framskriv_y4.R` (som ikke er skrevet ennå).

## 5. Modell Y_5 - sykepleierårsverk (`modell_y5.R`)

**Type**: lineær blandet modell (`lme4::lmer`) på LOGARITMEN av Y_5, med
befolkning som offset (koeffisient tvunget til 1) - samme multiplikative
populasjonsskalering som Poisson-modellene for Y_1/Y_2*, men med
normalfordelte feil på logskala i stedet for Poisson-varians, siden
årsverk ikke er et heltall.

**Likning**:

```
log(Y_5_ialt(k, t)) = log(folk_ialt_kt) + β_0 + Σ_t γ_t · år_t + β_1 · demensandel_kt + u_k + ε_kt
u_k ~ N(0, σ_u²),  ε_kt ~ N(0, σ_ε²)
```

**Estimerte parametre (hovedmodell, alle år 2015-2025)**:

| Parameter | Estimat |
|---|---|
| Intercept (β_0) | -5,256 |
| demensandel (β_1) | 13,83 |
| Årseffekter (γ_t) | stigende fra 2016 (0,016) til 2020 (0,070), fallende mot 2025 (0,031), relativt til 2015 |
| Kommune-tilfeldig-intercept, SD (σ_u) | 0,264 |
| Residual-SD (σ_ε) | 0,107 |

**Kryssvalidering (leave-one-year-out, alle 11 år)**:

| Modellvariant | RMSE | MAE | Korrelasjon |
|---|---|---|---|
| Kun tilfeldig intercept (brukt til framskrivning) | 13,9 | 5,6 | 0,9975 |
| Intercept + korrelert helning på demensandel | 12,7 | 4,9 | 0,9979 |

God prediktiv treffsikkerhet, på linje med Y_1/Y_2*. Helningsvarianten:
103/357 kommuner med negativ effektiv helning (korrelert), men bare 10/357
i den UKORRELERTE varianten - vesentlig bedre enn for de andre variablene,
men intercept-only brukes likevel til framskrivning, i tråd med
prosjektets generelle policy.

**Datadekning**: kun 2015-2025 (11 år) har faktiske observasjoner - 2007-
2014 mangler helt i datagrunnlaget. Modellen er derfor trent på et
vesentlig kortere tidsvindu enn de andre variablene.

## 6. Kryssvalideringsmetode (gjelder alle modeller)

Leave-one-year-out (LOYO): for hvert år t i datasettet estimeres modellen
på ALLE ANDRE år, og brukes til å predikere år t. Siden alle modellene har
årsdummyer (`år_f`), har den re-estimerte modellen per definisjon ingen
egen koeffisient for det utelatte året. Dette løses med en forenkling:

```
γ_t(utelatt år) ≈ gjennomsnitt(γ_t for alle andre år i treningsdataene)
```

Dette er en tilnærming, ikke en eksakt løsning - se `loyo_cv()`-funksjonen
i hvert `modell_*.R`-script. RMSE, MAE og korrelasjon rapporteres både per
utelatt år og samlet over alle utelatte år.

## 7. Framskrivningsmetode (`framskriv_y1.R`, `framskriv_y2_stjerne.R`, `framskriv_y5.R`)

**Trinn**:

1. Hent SSBs befolkningsframskrivning (tabell 12882, hovedalternativ
   MMMM = `ContentsCode = "Personer"`) for 2026-2050, per kommune, alder
   og kjønn.
2. Beregn framskrevet `demensandel` med SAMME prevalensrater som i
   historikken (pkt. 1).
3. Predikér med hovedmodellen (kun tilfeldig intercept), med samme
   linear-prediktor-formel som i CV-en, men der årseffekten for et
   framtidig år også settes til gjennomsnittet av de historiske
   årseffektene:

   For Y_1/Y_2* (Poisson-skala):
   ```
   ŷ_kt = exp( β_0 + gjennomsnitt(γ_t) + β_1 · demensandel_kt + u_k + log(folk_ialt_kt) )
   ```
   For Y_5 (log-lineær skala, samme form siden begge eksponensierer en
   log-lineær prediktor med offset):
   ```
   ŷ_kt = exp( β_0 + gjennomsnitt(γ_t) + β_1 · demensandel_kt + u_k + log(folk_ialt_kt) )
   ```

4. **Glidende overgang** fra observert 2025-nivå til modellframskrivning,
   for å unngå brå hopp i grafene ved skjøten mellom historikk og
   framskrivning:

   ```
   vekt_t = max(0, 0.9 × (2036 - t) / (2036 - 2026))   for t = 2026..2050
   y_predikert_t = vekt_t × y_observert_2025 + (1 - vekt_t) × ŷ_kt
   ```

   Dette gir 90 % vekt på observert 2025-nivå i 2026, lineært avtagende
   til 0 % (100 % modell) i 2036, og deretter ren modellframskrivning for
   2037-2050. Se `glatt_overgang()` i hvert `framskriv_*.R`-script.

**Kun ett befolkningsscenario** (MMMM) er beregnet så langt - `ALTERNATIV`
-variabelen i skriptene kan endres til `"Personer1"` (LLML) eller
`"Personer2"` (HHMH) for å beregne alternative scenarioer.

## 8. Kjente begrensninger / videre arbeid

- Ingen konfidens- eller prediksjonsintervall er beregnet ennå (bare
  punktestimater).
- Kun ett befolkningsscenario (MMMM) er beregnet.
- `Y_3` er ikke modellert som egen variabel (kun som del av `Y_2*`).
- `framskriv_y4.R` er ikke skrevet - `Y_4`s svake prediktive treffsikkerhet
  (korrelasjon ~0,74) gjør at videre arbeid her bør vurderes nøye før
  framskrivning tas i bruk.
- LOYO-kryssvalideringens håndtering av årseffekt for utelatt år
  (gjennomsnitt av andre år) er en forenkling - se pkt. 6.
