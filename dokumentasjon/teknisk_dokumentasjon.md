# Teknisk dokumentasjon - modeller og estimering

Dette dokumentet beskriver de statistiske modellene som brukes til å
framskrive Y_1, Y_2*, Y_4 og Y_5: likninger, estimeringsprosedyre,
kryssvalideringsresultater, framskrivningsmetode,
usikkerhetskvantifisering, en alternativ Y_5-modell (pkt. 9, med et kjent
problem) og modellsjekk av befolkningskoeffisienten (pkt. 10). For BEGRUNNELSENE bak disse valgene (hvorfor
Poisson, hvorfor intercept-only i kryssvalideringen men slope-modell i
framskrivningen, hvorfor 2010 er utelatt for Y_1 osv.), se
[beslutningslogg.md](beslutningslogg.md).

**NB**: dette dokumentet vises som en fane i selve Shiny-appen (`app.R`),
som er offentlig og uten innlogging - se punkt 14 i beslutningsloggen.
(Tidligere var det bevisst holdt utenfor appen.)

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
demensandel - opprinnelig grunnen til at intercept-only-modellen ble brukt
til framskrivning, selv om helningsvarianten scorer bedre på CV. **Denne
policyen er reversert** (se beslutningslogg pkt. 9 og pkt. 7 lenger ned i
dette dokumentet): framskrivning bruker nå ALLTID helningsvarianten
(`hovedmodell_slope`), men med en ANKRINGSMETODE som gjør at kommunens
egen (potensielt feil-fortegnede) helning aldri brukes på framtidig
demensandel-vekst - bare på et fast, historisk ankerpunkt. CV-tallene over
gjelder fortsatt som en RÅ sammenligning av de to modellvariantene UTEN
ankring, og er derfor fortsatt informative for å forstå hvorfor
helningsvarianten historisk ble ansett som risikabel.

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
**Som for Y_1 er dette likevel ikke lenger avgjørende for framskrivningen**:
`hovedmodell_slope` brukes nå ALLTID, ankret ved 2025-nivået (se pkt. 7),
slik at fortegnsproblemet ikke kan påvirke framskrivningen uansett hvilken
modell som passer best på rå CV.

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
i den UKORRELERTE varianten - vesentlig bedre enn for de andre variablene.
Framskrivning bruker likevel samme ankrede `hovedmodell_slope`-metode som
Y_1/Y_2* (se pkt. 7), for konsistens og fordi ankringen uansett gjør
fortegnsproblemet irrelevant for selve framskrivningen.

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

**OPPDATERT METODE (rettet policy - se beslutningslogg.md, "Retur til
slope-modell")**: punktestimatet bruker nå `hovedmodell_slope` (tilfeldig
intercept OG helning på demensandel per kommune), ANKRET ved kommunens
siste observerte (2025) demensandel - IKKE en separat intercept-only-modell
som tidligere. Se punkt 2 i denne oppdateringen for hvorfor.

**Trinn**:

1. Hent SSBs befolkningsframskrivning (tabell 12882, hovedalternativ
   MMMM = `ContentsCode = "Personer"`) for 2026-2050, per kommune, alder
   og kjønn.
2. Beregn framskrevet `demensandel` med SAMME prevalensrater som i
   historikken.
3. Predikér med `hovedmodell_slope`, ANKRET ved kommunens siste observerte
   (2025) demensandel (`a_k`). Årseffekten for et framtidig år settes til
   gjennomsnittet av de historiske årseffektene, som før. La `u_k0` og
   `u_k1` være kommunens tilfeldige intercept og helning:

   ```
   intercept'_k = β_0 + u_k0 + (β_1 + u_k1) · a_k        (konstant per kommune)
   ŷ_kt = exp( intercept'_k + gjennomsnitt(γ_t) + β_1 · (demensandel_kt - a_k) + log(folk_ialt_kt) )
   ```

   **Hvorfor ankring, og hvorfor dette gjør slope-modellen TRYGG å bruke**:
   `intercept'_k` er en KONSTANT (bygget fra modellens fit VED ankeret) og
   kan derfor ikke selv eksplodere. All FRAMTIDIG vekst i demensandel
   bruker BARE det faste, nasjonale helningsanslaget β_1 - ALDRI kommunens
   egen tilfeldige helning `u_k1`. Det er nettopp bruken av `u_k1` på
   FRAMTIDIG vekst som tidligere ga et implausibelt fortegn for en andel
   kommuner (se pkt. 3 i hoveddokumentet) - siden `u_k1` her bare
   multipliserer et FAST historisk ankerpunkt (ikke en økende fremtidig
   størrelse), er denne faren eliminert.
   Uten ankring - dvs. å bruke `u_k1 · demensandel_kt` direkte, eller å
   bytte mellom en egen intercept-only-modell og denne modellen - oppstår
   et reelt inkonsistens-problem: de to modellvariantene har ULIKE faste
   effekter (β_0, β_1), så et brukergrensesnitt som lar brukeren "slå av"
   en tilfeldig-helning-effekt ved å bytte til en ANNEN modell vil vise et
   synlig sprang selv når effekten skulle vært 0 %. Dette ble funnet som en
   reell bug i appen og rettet ved å ALLTID bruke `hovedmodell_slope`,
   aldri en egen intercept-only-modell, for framskrivning.

4. **Glidende overgang** fra observert 2025-nivå til modellframskrivning,
   for å unngå brå hopp i grafene ved skjøten mellom historikk og
   framskrivning - nå strukket over HELE framskrivningsperioden (2026-2050)
   i stedet for bare de første 10 årene, for å unngå et kink i grafen der
   overgangsvekten tidligere flatet ut brått til 0 i 2036:

   ```
   vekt_t = max(0, 0.9 × (2050 - t) / (2050 - 2026))   for t = 2026..2050
   y_predikert_t = vekt_t × y_observert_2025 + (1 - vekt_t) × ŷ_kt
   ```

   Dette gir 90 % vekt på observert 2025-nivå i 2026, lineært avtagende
   til 0 % (100 % modell) først i 2050 (siste framskrevne år). Se
   `glatt_overgang()` i hvert `framskriv_*.R`-script. NB: dette betyr at
   observert 2025-nivå har en god del gjenværende vekt langt inn i
   perioden (f.eks. ~45-50 % ved 2036) - en bevisst avveining mellom å
   unngå kink-artefaktet og hvor lenge ett enkelt historisk datapunkt
   påvirker framskrivningen.

**Kommunespesifikk trend (appen)**: `app.R` sin `framskriv_trend()` bruker
NØYAKTIG samme ankermetode som over, men med en brukerstyrt vekt
`vekt_trend(t) = max(0, (T - (t - 2026)) / T)` multiplisert med `u_k1` i
stedet for helningsbidraget alltid værende 0 (dvs. dette er en
generalisering av pkt. 3 - "standardvisningen" i appen er nøyaktig det
samme som `T = 0`). Se kommentarblokken ved `framskriv_trend()` i `app.R`.

**Kun ett befolkningsscenario** (MMMM) er beregnet så langt - `ALTERNATIV`
-variabelen i skriptene kan endres til `"Personer1"` (LLML) eller
`"Personer2"` (HHMH) for å beregne alternative scenarioer.

**Kommunens egne tall som anker (appen)**: brukeren kan skrive inn kommunens
egen verdi `e_k` for 2025 for Y_1, Y_2-stjerne og Y_5. Den erstatter SSBs observerte
2025-verdi `o_k` som anker i den glidende overgangen. Overgangen er

```
verdi(t) = w(t) * anker + (1 - w(t)) * modell(t),   w(t) = 0,9 * (2050 - t) / (2050 - 2026)
```

så en endring av ankeret fra `o_k` til `e_k` endrer verdien med
`w(t) * (e_k - o_k)` (og med `w(t) * (e_k - modell(t))` hvis SSBs 2025-tall
mangler). Skiftet er likt for hver bootstrap-trekning, så det ferdige
95 %-båndet (persentiler av de glattede verdiene) flyttes nøyaktig like mye,
uten ny bootstrap (`juster_anker()` i `app.R`). Nedre og øvre grense klippes ved 0.
Egne tall påvirker hverken modellparametrene, kommuneeffektene eller
demensandel-ankeret `a_k` (som er en modellparametrisering); de flytter bare
nivået, med effekt som er borte i 2050. Det samme skiftet brukes i
trend-varianten. Båndet uttrykker fortsatt bare modellusikkerhet, ikke
usikkerhet i det innlagte tallet. Tallene lagres ikke (bare i økten).

## 8. Kvantifisering av usikkerhet (`usikkerhet_y1.R`, `usikkerhet_y2_stjerne.R`, `usikkerhet_y5.R`)

**Metode**: Bayesiansk bootstrap PÅ KOMMUNE-NIVÅ, ikke radnivå - dette
respekterer panelstrukturen (en kommune, ikke en kommune-år-rad, er
enheten som varieres, siden radene innad i en kommune deler samme
tilfeldige kommuneeffekt).

For hver av R = 60 iterasjoner:

1. **Trekk vekter**: for K kommuner i modelldata, trekk `g_1, ..., g_K`
   uavhengig fra `Gamma(1, 1)` (= `Exponential(1)`), og normaliser:

   ```
   w_k = (g_k / Σ_j g_j) × K
   ```

   `g_k / Σ_j g_j` er en eksakt Dirichlet(1,...,1)-trekning (flat prior på
   simpleksen). Multiplikasjonen med K skalerer opp fra gjennomsnitt 1/K
   til gjennomsnitt 1 - nødvendig fordi `glmer`/`lmer` tolker `weights`
   som presisjonsvekter (en vekt på ~1/K ville kunstig blåst opp den
   estimerte residual-/tilfeldig-effekt-variansen), ikke som
   sannsynlighetsvekter. Skaleringen endrer ikke selve Dirichlet-
   fordelingens relative form, bare dens skala.

2. **Refit**: `w_k` tildeles til ALLE rader for kommune k, og
   `hovedmodell_slope` (samme `FORMEL_SLOPE` som i `modell_<variabel>.R`)
   refittes med disse som `weights` i `glmer`/`lmer`.

3. **Framskriv**: den refittede modellens koeffisienter og tilfeldige
   effekter settes inn i NØYAKTIG samme ankermetode som punktestimatet
   (pkt. 7) - inkludert samme glidende overgang mot observert 2025-nivå.

4. Resultatet for denne iterasjonen legges til en midlertidig
   (kommune × år)-matrise HOLDT KUN I MINNET.

**Etter alle R iterasjoner**: 2,5- og 97,5-persentilen beregnes radvis
(per kommune × år) over de R lagrede framskrivningene - dette gir et 95 %
konfidensintervall. Persentilene (og punktestimatet fra den ikke-vektede
modellen) lagres; de R RÅ enkeltframskrivningene lagres ALDRI til disk -
kun holdt transient i minnet under kjøringen, for å unngå å bygge opp
store mellomresultatfiler for noe som uansett bare skal oppsummeres til to
tall per (kommune, år).

**Gjenbruk av befolkningsframskrivning**: `folk_ialt`/`demensandel` for
2026-2050 er uavhengig av bootstrap-vektene (de kommer fra SSBs
befolkningsframskrivning, ikke fra modellestimeringen) - hentes fra de
allerede lagrede `framskrevet_<variabel>.rds`-filene i stedet for på nytt
fra SSB for hver av de 60 iterasjonene.

**Eksempel** (Y_1, Halden, alle 60 iterasjoner konvergerte):

| År | Punktestimat | 95 % KI |
|---|---|---|
| 2026 | 1 086,1 | [1 083,0 - 1 095,7] |
| 2030 | 1 124,9 | [1 111,0 - 1 155,0] |
| 2040 | 1 440,1 | [1 341,9 - 1 591,4] |
| 2050 | 2 043,8 | [1 753,4 - 2 442,2] |

Intervallet er smalt nær 2026 (dominert av den glidende overgangens vekt
på det observerte, ikke-tilfeldige 2025-nivået) og videre ut mot 2050
etter hvert som modell-/parameterusikkerheten får dominere.

**Viktig begrensning**: usikkerheten er KUN beregnet for standard-
framskrivningen (`T` implisitt = 0, dvs. ingen kommunespesifikk trend). Når
"Bruk kommunens egen trend" er slått på i appen (`T` > 0, se pkt. 7), vises
IKKE noe usikkerhetsbånd - bootstrap er ikke kjørt for T > 0-varianten.
Dette er en bevisst avgrensning av omfanget (ikke en bug): trend-varianten
ble bygget for å "se hvordan resultatet ser ut" først, før eventuell
usikkerhetskvantifisering utvides til den.

**R = 60** ble valgt som et praktisk startpunkt (se beslutningslogg pkt. 8)
- kan økes ved å endre `ANTALL_BOOTSTRAP` i hvert `usikkerhet_*.R`-script,
på bekostning av lengre kjøretid (hvert R-refit av `hovedmodell_slope` tar
lengre tid enn intercept-only-varianten, pga. flere parametre og en
korrelert tilfeldig helning).

## 9. Alternativ Y_5-modell: Poisson (`modell_y5_poisson.R`, `framskriv_y5_poisson.R`) - KJENT PROBLEM, FJERNET FRA APPEN

**Status (2026-09-24): modellen er fjernet fra appen** (linjen vises ikke lenger, og filene er tatt ut av opplastingslisten). Scriptene er beholdt til dokumentasjon; se beslutningslogg pkt. 21.

**Hensikt**: alternativ estimering av Y_5 med samme modellfamilie som
Y_1/Y_2\* (i stedet for log-lineær `lmer` i pkt. 5), vist som en egen linje
uten konfidensintervall i appen.

**Likning** (som pkt. 2, men på årsverk):

```
Y_5_ialt(k, t) ~ Poisson(μ_kt)
log(μ_kt) = log(folk_ialt_kt) + β_0 + Σ_t γ_t · år_t + β_1 · demensandel_kt + u_k0 + u_k1 · demensandel_kt
(u_k0, u_k1) ~ N(0, Σ)
```

Framskrivning, ankring og glidende overgang er nøyaktig som i pkt. 7
(`hovedmodell_slope`, ankret ved 2025). Data: 2015-2025.

**Ikke-heltall**: årsverk er ikke heltall, mens Poisson-likelihooden
forutsetter det. Første versjon ble estimert på de uavrundede årsverkene
(Poisson pseudo-likelihood).

**Feil funnet: variansparametrene estimeres ikke.** For den uavrundede
modellen står `theta` på lme4s startverdier (1, 0, 1) - dvs.
tilfeldig-intercept-SD = 1, tilfeldig-helning-SD = 1 og korrelasjon 0 - og
optimereren melder "Gradient contains NAs". Samme resultat fås for en ren
intercept-modell på de samme dataene. Konsekvenser:

| | Uavrundet (i appen nå) | Avrundet til heltall (test) |
|---|---|---|
| Tilfeldig intercept, SD | 1 (startverdi) | 0,577 |
| Tilfeldig helning, SD | 1 (startverdi) | 24,95 |
| Korrelasjon | 0 (startverdi) | -0,913 |
| Intercept (β_0) | -5,034 | -5,443 |
| `demensandel` (β_1) | 3,66 | 21,74 |
| Kommuner med negativ effektiv helning | ikke meningsfullt | 32 / 357 |
| Konvergens | "Gradient contains NAs" | Advarsel: maks funksjonskall nådd, maks \|grad\| 0,0101 (toleranse 0,002) |

Kryssvalideringen for den uavrundede modellen (RMSE 14,07, MAE 5,57,
korrelasjon 0,9974, n = 3 898) ser fornuftig ut, men sier ingenting om at
variansparametrene er riktig estimert. **Modellen og alternativlinjen i
appen skal ikke tolkes** før dette er rettet. Neste steg: avrunding (eller
en Gamma-modell med log-lenke) med høyere `maxfun`, ny CV, kjøre
`framskriv_y5_poisson.R` på nytt.

## 10. Modellsjekk av koeffisienten på log(befolkning) (`modellsjekk_kvantil.R`)

Modellene bruker `offset(log(folk_ialt))`, dvs. koeffisienten på
log(befolkning) er tvunget til 1. Sjekken lar den estimeres fritt og
undersøker om den avviker fra 1. Trekkes log(befolkning) fra begge sider av
`log(y) = β_pop · log(pop) + X·β` får vi

```
log(y / befolkning) = (β_pop - 1) · log(befolkning) + X·β
```

og hypotesen β_pop = 1 blir at koeffisienten på `log(befolkning)` er 0.

**Estimering**: kvantilregresjon (`quantreg::rq`, metode `br`) på

```
log(y / befolkning) ~ log(befolkning) + demensandel + år (dummyer)
```

for τ ∈ {0,1; 0,25; 0,5; 0,75; 0,9}. Observasjoner med y = 0 utelates
(2 av 6 337 for Y_1); Y_1 bruker samme utvalg som `modell_y1.R` (uten 2010).

**Usikkerhet**: Bayesiansk bootstrap over kommuner, B = 100. For hver
iterasjon trekkes `w_k = K · g_k / Σ_j g_j` med `g_k ~ Gamma(1, 1)`, samme
vekt for alle år i kommune k, og alle kvantilregresjonene estimeres på nytt
med `weights = w_k`. Hele fordelingen for `log(befolkning)`-koeffisienten
lagres (`data/ssb/modellsjekk_kvantil_y_1.rds`).

**Resultat, Y_1** (alle 100 iterasjoner fullført):

| τ | β_pop | 95 % intervall | Andel trekk med β_pop < 1 |
|---|---|---|---|
| 0,10 | 1,001 | [0,985, 1,021] | 0,51 |
| 0,25 | 0,974 | [0,958, 0,993] | 0,99 |
| 0,50 | 0,949 | [0,931, 0,967] | 1,00 |
| 0,75 | 0,916 | [0,898, 0,934] | 1,00 |
| 0,90 | 0,894 | [0,878, 0,913] | 1,00 |

Bootstrap-SD er ca. 0,01 for alle kvantiler. Proporsjonalitet forkastes fra
medianen og oppover; ved den laveste kvantilen er den forenlig med dataene.

**Resultat, Y_2\*** (5 167 kommune-år, 100/100 iterasjoner) og **Y_5**
(3 898 kommune-år, 100/100 iterasjoner):

| τ | β_pop Y_2\* | 95 % intervall | β_pop Y_5 | 95 % intervall |
|---|---|---|---|---|
| 0,10 | 1,041 | [1,016, 1,066] | 0,957 | [0,904, 0,996] |
| 0,25 | 1,011 | [0,984, 1,031] | 0,930 | [0,904, 0,957] |
| 0,50 | 0,964 | [0,941, 0,984] | 0,907 | [0,882, 0,939] |
| 0,75 | 0,914 | [0,884, 0,946] | 0,885 | [0,866, 0,908] |
| 0,90 | 0,892 | [0,858, 0,915] | 0,865 | [0,840, 0,889] |

Alle tre variabler viser at β_pop faller fra lave til høye kvantiler. Y_2\*
ligger over 1 ved τ = 0,1, og Y_5 under 1 for alle kvantiler. Tolkning:
β_pop < 1 = bruken vokser saktere enn folketallet (stordriftsfordeler).
**Kvantilene rangerer kommuner etter bruk per innbygger, ikke etter
størrelse.** Resultatene vises i appen i fanen "Analyse stordriftsfordeler"
(beslutningslogg pkt. 15).

**Begrensninger**: ingen tilfeldige effekter eller kommune-faste effekter
(koeffisienten hentes hovedsakelig fra forskjeller mellom kommuner, siden
folketallet varierer lite over tid innen en kommune); `rq` gir advarselen
"Solution may be nonunique" (vanlig med årsdummyer og like verdier, ikke
undersøkt nærmere); bootstrap-intervallene fanger bare
utvalgsvariasjon mellom kommuner. Y_1, Y_2\* og Y_5 er kjørt. En fri koeffisient
er ikke innført i framskrivningene - det krever at ankerformelen får
leddet `β_pop · (log(pop_t) - log(pop_anker))`.

## 11. Kjente begrensninger / videre arbeid

Se også [videre_arbeid.md](videre_arbeid.md) for arbeidsplanen.

- **Den alternative Y_5-modellen (pkt. 9) er ikke gyldig estimert** -
  variansparametrene er ikke estimert. Rettes før bruk.
- Koeffisienten på log(befolkning) avviker fra 1 for Y_1, Y_2\* og Y_5
  (pkt. 10) men er ikke innført i modellene.
- `Y_3` er ikke modellert som egen variabel (kun som del av `Y_2*`).
- `framskriv_y4.R` er ikke skrevet - `Y_4`s svake prediktive treffsikkerhet
  (korrelasjon ~0,74) gjør at videre arbeid her bør vurderes nøye før
  framskrivning tas i bruk. `Y_4` er heller ikke oppdatert til den nye
  ankrede slope-metoden (pkt. 7) - bruker fortsatt kun den opprinnelige
  intercept-only-modellen i `modell_y4.R`, siden ingen framskrivning
  finnes for denne variabelen ennå.
- Bootstrap-usikkerhet (pkt. 8) er kun beregnet for `T = 0`
  (standardframskrivningen) - ikke for den brukerstyrte
  kommunespesifikke trend-varianten (`T > 0`).
- Kun ett befolkningsscenario (MMMM) er beregnet - LLML, HHMH og
  Telemarksforskning sine befolkningsframskrivninger er planlagt, men ikke
  implementert (se "Om"-fanen i appen).
- Estimering av TILBUD av sykepleiere (i tillegg til dagens
  etterspørselsestimat) er planlagt, med metodikk fra SSB-rapporten
  RAPP 2026/18 (se "Om"-fanen) - ikke påbegynt.
- LOYO-kryssvalideringens håndtering av årseffekt for utelatt år
  (gjennomsnitt av andre år) er en forenkling - se pkt. 6.
