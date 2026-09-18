# Beslutningslogg - Omsorg 2050 / Framskrivningsverktøy

Dette er en samlet, begrunnet logg over de viktigste valgene som er tatt i
dette prosjektet: datakilder, metodevalg, funn under validering, og
feilrettinger. Formålet er at noen som tar over eller viderefører
prosjektet skal forstå HVORFOR ting er gjort som de er gjort, ikke bare
hva koden gjør (det står i kodekommentarene). For de statistiske
modellenes formler og estimeringsdetaljer, se
[teknisk_dokumentasjon.md](teknisk_dokumentasjon.md).

## 1. Datakilder og datainnhenting (`hent_paneldata_2007_2025.R`)

- **Datakilde**: SSBs PxWebApi (statistikkbanken), både v0 (POST,
  px-json-format) og v2 (GET, JSON-stat2), avhengig av hva som fungerer
  best for den enkelte tabellen.
- **Tabelloversikt**:
  - `04686` (t.o.m. 2016) + `12292` (f.o.m. 2015): Y_1_a (hjemmetjeneste-
    brukere), Y_2 (heldøgnsbolig), Y_4 (timer/uke)
  - `11645` (2009-2025): Y_3_a (institusjon, langtidsopphold) - aldersoppløst
    per tjenestetype, krever ingen skjøting
  - `04686` + `11924` (2015-2023) + `14534` (2015-2025): Y_5 (sykepleier-
    årsverk)
  - `07459` (2005-2026, `agg_KommSummer`): befolkning etter alder/kjønn -
    allerede en sammenslått tidsserie fra SSB
  - `12882`: befolkningsframskrivninger (brukes i framskriv_*.R)
- **Historisk kommunekode-harmonisering**: `07459` bruker SSBs egen
  sammenslåtte kodeliste (`agg_KommSummer`, "K-"-prefiks) og er derfor
  allerede i dagens (2024) kommunestruktur. De andre tabellene (`04686`,
  `12292`, `11924`, `12882`, `11645`) har IKKE dette - løsningen er å hente
  full kommunehistorikk og for hver tabell prøve alle historiske koder for
  en 2024-kommune, og beholde den/de som faktisk finnes/har data i tabellen.
- **Tabell `11645` dekker bare 2009-2025**: et forsøk på å hente 2007-2008
  ga HTTP 400 (SSB avviser hele forespørselen hvis ÉN kode er ugyldig for
  en dimensjon). Løst med et årsfilter (`years[years >= 2009]`) ved kallet.
- **Sammenslåtte kommuner (`lag_2024_struktur()`)**: valgte å slå alle
  historiske kommuner sammen til dagens (2024) kommunestruktur FØR
  modellering, i stedet for å modellere på historisk struktur og
  konvertere etterpå. Prinsipp:
  - Antallsvariabler (brukere, beboere, årsverk) **summeres** over
    kildekommunene.
  - `Y_4` (timer/uke, som allerede er et snitt) tas som et **vektet snitt**
    av kildekommunenes verdier, vektet med kildekommunens `Y_1_a_ialt`
    (antall hjemmetjenestemottakere) - IKKE folketall, fordi folketallet
    fra `07459` allerede er den sammenslåtte 2024-kommunens tall og derfor
    identisk på hver kildekommune-rad (å vekte med det ville gitt et
    reelt uvektet snitt).
  - Befolkningskolonnene tas fra FØRSTE rad per kommune-år (ikke summeres),
    av samme grunn som over - de er allerede den fulle summen.
- **Bug funnet og rettet: `Y_5` (årsverk) ble feilaktig vektet-snittet**
  som `Y_4`, selv om årsverk er en additiv størrelse (ikke et snitt).
  Flyttet til `SUM_KOLONNER`. Data regenerert fra allerede lagrede
  mellomresultater (ingen nye SSB-kall nødvendig). Effekt: betydelig for
  store sammenslåtte kommuner, f.eks. Drammen (0220+0627+0628) 2019 endret
  fra 210 til 460 årsverk - den gamle metoden underrapporterte kraftig for
  slike kommuner.
- **Datadekning, `Y_5`**: mangler HELT for 2007-2014 (100 % manglende alle
  disse årene) - reell dekning er 2015-2025, kortere enn de andre
  variablene. Ikke undersøkt videre hvorfor `04686` ikke bidro med data
  så langt tilbake for denne variabelen, selv om kildelisten i
  koden opprinnelig antydet det.
- **2010-anomali i `Y_1`**: stikkprøver i Halden og Eigersund viste et
  brått ~90 % fall i `Y_1_a_ialt` i ALLE aldersgrupper i 2010, med full
  gjenoppretting i 2011 - tolket som en rapporteringsfeil (sannsynligvis
  knyttet til en IPLOS-versjonsovergang nevnt i `04686`s metadata), ikke en
  reell endring i tjenestebruk. **2010 er derfor utelatt fra
  `Y_1`-modelleringen.** Sjekket EKSPLISITT for `Y_2`/`Y_3`/`Y_4` og IKKE
  funnet der - 2010 er beholdt for disse variablene. Ikke bekreftet
  systematisk for alle 357 kommuner, bare stikkprøver.

## 2. Demensprevalensestimering (`legg_til_demens.R`)

- Bruker aldersgruppe- og kjønnsspesifikke prevalensrater (fra brukerens
  opprinnelige `dementia_dic`), multiplisert med ETTÅRIG befolkning
  (alder x kjønn) fra `07459` og summert til kommune x år.
- Krever et FULLSTENDIG datasett (alle 106 aldersgrupper x 2 kjønn = 212
  rader) for at et kommune-år skal regnes som "komplett" - hvis ikke,
  settes estimatet til NA i stedet for å regne på et ufullstendig grunnlag.
- **`demensandel` (andel av befolkningen), ikke råtallet
  `demens_estimert`, brukes som forklaringsvariabel i alle modeller** - et
  råtall ville i stor grad bare fanget opp kommunestørrelse, som allerede
  er representert andre steder i modellene (eksponering/offset).

## 3. Valg av modellstruktur per variabel

- **`Y_1` (hjemmetjenestebrukere) og `Y_2*` (heldøgns omsorg)**: Poisson
  GLMM (log-lenke, befolkning som eksponering/offset, tilfeldig
  kommuneintercept, årsdummyer, `demensandel`) - naturlig valg siden begge
  er heltallige brukerantall som skalerer med befolkning.
- **`Y_4` (timer/uke)**: lineær blandet modell (`lmer`), IKKE Poisson -
  `Y_4` er allerede et gjennomsnitt (ikke et antall), så en tellemodell med
  log-lenke og befolkningseksponering gir ikke mening.
- **`Y_5` (sykepleierårsverk)**: log-lineær blandet modell (`lmer` på
  `log(Y_5)` med befolkning som offset) - årsverk skalerer med
  kommunestørrelse på samme måte som `Y_1`/`Y_2*`, men er ikke heltallig,
  så ren Poisson er ikke strengt egnet. Valgt som en pragmatisk mellomting:
  samme multiplikative populasjonsskalering som Poisson-modellene, men med
  normalfordelte feil på logskala.
- **`Y_3` (institusjon, langtidsopphold)**: ikke modellert separat ennå -
  inngår i dag bare som del av `Y_2*`.
- **Tilfeldig helning vs. kun tilfeldig intercept**: testet konsekvent for
  ALLE variabler (korrelert og ukorrelert helning på `demensandel` per
  kommune). Helningsvariantene gir konsekvent bedre AIC/BIC og ofte bedre
  kryssvalidert treffsikkerhet, MEN gir en betydelig andel kommuner med en
  implausibel NEGATIV effektiv helning (fast + tilfeldig) på `demensandel`
  - dvs. modellen ville antatt at FLERE med demens gir FÆRRE
  brukere/årsverk i disse kommunene. Andeler med negativt fortegn
  (korrelert variant): 91/357 (`Y_1`), 95/355 (`Y_2*`), 195/357 (`Y_4`),
  103/357 (`Y_5`). **Beslutning: bruk ALLTID hovedmodellen (kun tilfeldig
  intercept) for faktisk framskrivning**, uansett bedre passform for
  helningsvarianten - risikoen for et absurd fortegn utenfor det
  historisk observerte området vurderes som viktigere enn litt bedre
  in-sample/CV-passform. Helningsvariantene beregnes og lagres likevel,
  for diagnostisk fullstendighet.
  **OPPDATERT (se punkt 9)**: denne policyen er senere reversert for
  FRAMSKRIVNING (ikke for kryssvalideringen over, som fortsatt er gyldig
  akkurat som beskrevet) - en ankringsmetode gjør det trygt å bruke
  helningsmodellen likevel, og løser samtidig en reell inkonsistens-bug.
- **Kryssvalideringsmetode**: leave-one-year-out (LOYO) for alle modeller
  - modellen trenes på alle år UTENOM ett, og evalueres på det utelatte
  året. Årsdummy-modeller kan per definisjon ikke ha en egen koeffisient
  for et år de ikke er trent på - dette løses med en forenkling:
  gjennomsnittet av de ANDRE årenes estimerte årseffekt brukes som
  stand-in for det utelatte året. Dokumentert eksplisitt som en
  tilnærming, ikke en eksakt løsning.

## 4. Forsøk som ble forkastet/satt på vent

- **`Y_4` + `Y_1_a_ialt` som ekstra forklaringsvariabel**: testet på
  eksplisitt oppfordring (rå antall hjemmetjenestemottakere, ikke som
  andel). Resultat: ingen meningsfull forbedring i kryssvalidert
  treffsikkerhet (korrelasjon ~0,735 med og uten), og `demensandel`s
  koeffisient byttet fortegn (ble negativ) når `Y_1_a_ialt` ble lagt til -
  et tegn på kollinearitet med kommunestørrelse, akkurat som forhåndsvarslet
  i kodekommentaren. **Besluttet å IKKE ta denne varianten videre nå** -
  kan revurderes senere, se `skript/modell_y4.R`.

## 5. Framskrivning (`framskriv_y1.R`, `framskriv_y2_stjerne.R`, `framskriv_y5.R`)

- Bruker SSBs befolkningsframskrivning, **kun hovedalternativet MMMM**
  (tabell 12882) foreløpig - LLML/HHMH og Telemarksforsking sine
  framskrivninger er planlagt (se punkt 6, "Om"-fanens veikart), men ikke
  implementert.
- **Årseffekt for framtidige år**: satt til gjennomsnittet av de
  historiske årseffektene, av samme grunn som i kryssvalideringen (en
  årsdummy-modell har ingen egen koeffisient for et år utenfor
  treningsdataene).
- **Glidende overgang** (`glatt_overgang()`) fra observert til
  modellbasert nivå, for å unngå brå hopp i grafene ved overgangen fra
  historikk til framskrivning: 90 % vekt på observert 2025-verdi i 2026,
  lineært avtagende utover. Se
  [teknisk_dokumentasjon.md](teknisk_dokumentasjon.md) for eksakt formel.
  **OPPDATERT**: opprinnelig nådde vekten 0 % (100 % modell) allerede i
  2036, men dette ga et synlig KINK i grafene (brukeren observerte det for
  Y_1 og Y_2*) - fordi vekten hadde en konstant, negativ helning fram til
  2036 og deretter flat null, en diskontinuitet i STIGNINGSTALLET akkurat
  ved brytpunktet. Rettet ved å strekke overgangen over HELE
  framskrivningsperioden (2026-2050) i stedet for bare de første 10
  årene - vekten når nå 0 % først ved siste framskrevne år. Avveining
  bevisst akseptert: observert 2025-nivå har nå en god del gjenværende
  vekt langt inn i perioden (f.eks. ~45-50 % ved 2036, mot 0 % før), dvs.
  mindre av trajectorien er "ren" kryssvalidert modellframskrivning - men
  brukeren vurderte dette som et akseptabelt bytte mot å fjerne kinken,
  siden det uansett er en etterbehandlingsmessig glatting, ikke en endring
  av selve den statistiske modellen.
- **Duplisert kode** mellom `framskriv_y1.R`/`framskriv_y2_stjerne.R`/
  `framskriv_y5.R` i stedet for en delt hjelpefil - et bevisst valg for å
  unngå regresjonsrisiko på allerede fungerende kode. Vurder en felles
  hjelpefil hvis flere Y-variabler gjør duplikasjonen upraktisk å
  vedlikeholde.
- **Kommunespesifikk trend (i appen, ikke i de faste framskriv_*.R-filene)**:
  en brukerstyrt funksjon i `app.R` (`framskriv_trend()`) som tolker den
  tilfeldige helningen på `demensandel` per kommune som en
  kommunespesifikk TREND (f.eks. lokal politikk), og lar brukeren velge
  hvor mange år (T = 0-10) denne trenden skal fases lineært ut over, før
  framskrivningen går over til det nasjonale gjennomsnittet. Bygget først
  for Y_1 alene ("først vil jeg se hvordan resultatet ser ut"), deretter
  generalisert til Y_2*/Y_5 med samme mekanisme (én generisk funksjon
  parametrisert på variabel-ID, i stedet for tre kopier - i tråd med
  app.R sin egen etablerte "variabel-agnostisk"-stil, se punkt 6, i
  motsetning til skript/-filenes bevisste duplisering).
  Skrus på med en avkryssingsboks (AV som standard, slik at eksisterende
  oppførsel/usikkerhetsbånd ikke endres for noen som ikke aktivt velger
  dette). Se punkt 9 for en reell bug som ble funnet og rettet i
  forbindelse med denne funksjonen, og for hvorfor `hovedmodell_slope` nå
  brukes for ALL framskrivning (ikke bare når trend-bryteren er på).

## 6. Shiny-appen (`app.R`)

- **`app.R` må ligge i prosjektroten** (Shiny-krav for `runApp()`).
- **Kritisk bug funnet og rettet**: Shiny sin `runApp()` kjører automatisk
  ALLE `.R`-filer i prosjektroten og i `R/`-mappen som "helper files" ved
  oppstart - dette kjørte ved et uhell hele datainnhentingsscriptet
  (25-minutters SSB-henting for 357 kommuner) hver gang appen startet.
  Løst ved å flytte alle frittstående arbeidsflyt-script til en egen
  `skript/`-mappe, som Shiny ikke skanner.
- **Variabel-agnostisk design**: én sentral `Y_VARIABLER`-liste med
  metadata (kolonnenavn, filnavn, 2010-flagg) per variabel - resten av
  appen (kommuneutvalg, plott, tabell, nedlasting) er felles kode som
  leser fra denne listen. Gjør det enkelt å legge til en ny Y-variabel
  uten å endre UI/plott/tabell-logikk (gjort for `Y_2*` og `Y_5`).
- **Ingen metodikk/modelldetaljer skal vises i appen selv** - "Om"-fanen
  er bevisst forenklet til å IKKE avsløre hvilken modelltype, hvilke
  formler eller hvilke script som brukes, slik at eksterne brukere av
  appen ikke kan se nøyaktig hvordan framskrivningene beregnes. Fullstendig
  metodedokumentasjon finnes i stedet i
  [teknisk_dokumentasjon.md](teknisk_dokumentasjon.md), som ikke er en del
  av selve appen.
  **Datakilder er et unntak**: "Om"-fanen lister likevel opp hvilke SSB-
  statistikkbank-tabeller (04686, 12292, 11645, 11924, 14534, 07459,
  12882) som ligger til grunn - dette regnes ikke som å avsløre
  MODELLERINGSMETODIKK (statistikkbank-tabellnumre er offentlig
  informasjon, ikke prosjektets egen analyse), og er nyttig åpenhet for
  brukere/veiledere om hvor tallene kommer fra.
- **Variabelnavn i UI**: standardisert til mønsteret "Etterspørsel etter
  X (enhet)" for alle tre variabler ("hjemmetjenester (brukere)", "bolig
  (brukere)", "sykepleier (avtalte årsverk)") - mer beskrivende for en
  ekstern leser enn de opprinnelige "Y_1"/"Y_2\*"/"Y_5"-navnene, som ikke
  betyr noe utenfor prosjektets egen kode. "Avtalte årsverk" er SSBs egen
  presise betegnelse (til forskjell fra "utførte årsverk", som også
  korrigerer for fravær) - brukt her i stedet for det mer generiske
  "årsverk".
- **Planlagt videre arbeid (se "Om"-fanen)**: lagt til et konkret veikart-
  punkt om å estimere TILBUD (ikke bare etterspørsel) av sykepleiere, med
  metodikk fra SSBs rapport
  ["Behov for og tilgang på arbeidskraft i offentlig helse og omsorg
  fremover" (RAPP 2026/18)](https://www.ssb.no/helse/helsetjenester/artikler/behov-for-og-tilgang-pa-arbeidskraft-i-offentlig-helse-og-omsorg-fremover/_/attachment/inline/e35491e6-e7b1-43f0-82f9-726b8b21574e:2475fafc0fdb77314f7751654ffea53725e30f2e/RAPP2026-18.pdf),
  samt å inkludere LLML- og HHMH-befolkningsframskrivninger fra SSB og
  befolkningsframskrivninger fra Telemarksforsking som alternativ til
  SSBs hovedalternativ MMMM. Ingen av disse er påbegynt - kun notert som
  neste steg.

## 7. Datavalidering underveis

- Historisk `Y_1` plottet mot SSBs rådata for Halden og Eigersund (senere
  generalisert til å fungere for alle kommuner) for å bekrefte at den
  sammensatte tidsserien (skjøtet fra flere kilde-tabeller) er korrekt før
  modellering startet.
- `lag_2024_struktur()` manuelt verifisert mot Nordre Follo-sammenslåingen
  (Ski + Oppegård) for å bekrefte at summering/vekting av sammenslåtte
  kommuner regnes riktig.
- Leave-one-year-out kryssvalidering brukt konsekvent som hovedmetode for
  å vurdere modellenes prediktive treffsikkerhet, i tillegg til
  AIC/BIC-sammenligning og eksplisitt sjekk av "feil fortegn" på
  `demensandel`-helningen per kommune.

## 8. Kvantifisering av usikkerhet (Bayesiansk bootstrap)

- **Metode**: kommune-vis Bayesiansk bootstrap - én Dirichlet(1,...,1)-vekt
  per kommune per iterasjon (samme vekt for alle år i kommunen, siden
  kommunen er den egentlige "enheten" i panelstrukturen), brukt som
  presisjonsvekt i en refit av hovedmodellen, med samme framskrivnings- og
  glidende-overgang-logikk som punktestimatet. Kjørt for Y_1, Y_2* og Y_5
  (60 iterasjoner hver, se `usikkerhet_*.R`).
- **Bevisst valg: ikke lagre enkeltiterasjonene** - bootstrap-utvalgene
  holdes kun i en midlertidig matrise i minnet, og BARE 2,5/97,5-
  persentilene (95 %-intervallet) skrives til disk. Unngår å bygge opp
  store mellomresultatfiler for noe som uansett bare skal oppsummeres.
- **Vektskalering**: en rå Dirichlet(1,...,1)-trekning summerer til 1 (hver
  vekt ~1/K). Brukt direkte som `weights` i `glmer`/`lmer` ville dette
  kunstig blåst opp den estimerte variansen (weights tolkes som
  presisjonsvekter, ikke sannsynlighetsvekter). Skalert opp med K slik at
  vektene i gjennomsnitt er 1 - endrer ikke bootstrap-variasjonens
  relative form, bare skalaen.
- **Gjenbruk av befolkningsframskrivning**: `folk_ialt`/`demensandel` for
  2026-2050 er uavhengig av bootstrap-vektene (kommer fra SSBs
  befolkningsframskrivning, ikke fra modellestimeringen) - hentes fra de
  allerede lagrede `framskrevet_*.rds`-filene i stedet for på nytt fra SSB
  for hver iterasjon.

## 9. Retur til slope-modell for framskrivning (rettet en reell bug)

- **Bakgrunn**: appen fikk en "kommunespesifikk trend"-funksjon (tilfeldig
  helning på demensandel, tolket som lokal politikk), med en bryter for å
  fase den ut over T år. Brukeren oppdaget at når bryteren var AV, ga
  framskrivningen (basert på den opprinnelige intercept-only
  `hovedmodell`) en ANNEN verdi enn når bryteren var PÅ med T = 0 år
  (som skulle bety "ingen trendeffekt", og derfor burde gitt SAMME
  resultat). Eksempel: Halden, Y_1, 2050 - 3002 (bryter av) vs. 2043
  (bryter på, T = 0).
- **Rotårsak**: de to tallene kom fra to FORSKJELLIGE modeller
  (`hovedmodell` vs. `hovedmodell_slope`), estimert separat med ULIKE
  faste effekter (intercept, demensandel-koeffisient) - ikke samme modell
  med og uten et tillegg. Å bytte modell basert på en bryter som skulle
  bety "denne ekstra effekten er 0" er derfor feil - det gir en
  diskontinuitet uansett hvordan T settes til 0.
- **Beslutning (brukerens instruks)**: bruk KUN `hovedmodell_slope` for
  all framskrivning - fjern `hovedmodell` (intercept-only) fra
  framskrivningsbruk helt. Dette reverserer den tidligere policyen i
  punkt 3 ("bruk alltid intercept-only for framskrivning pga.
  fortegnsproblemet"), men på en måte som samtidig LØSER
  fortegnsproblemet:
  - Løsningen er å ANKRE framskrivningen ved kommunens siste observerte
    (2025) demensandel (se teknisk_dokumentasjon.md pkt. 7 for eksakt
    formel). Kommunens fulle nivå VED ANKERET (som bruker BÅDE fast og
    tilfeldig helning) er en KONSTANT som ikke kan eksplodere. All
    FRAMTIDIG vekst bruker BARE det faste (nasjonale) helningsanslaget -
    ALDRI kommunens egen tilfeldige helning. Siden det nettopp var
    kommunens egen (potensielt feil-fortegnede) helning brukt på FRAMTIDIG
    vekst som var problemet, er faren eliminert når den bare brukes på et
    fast historisk ankerpunkt.
  - Dette gjør "trend-bryteren av" og "trend-bryter på med T = 0"
    MATEMATISK IDENTISKE per konstruksjon (samme modell, samme formel,
    T = 0 gir bare vekt 0 på det ekstra trend-leddet) - bekreftet numerisk
    for alle tre variabler (Y_1, Y_2*, Y_5) etter rettingen.
- **Konsekvens**: `framskriv_y1.R`/`framskriv_y2_stjerne.R`/
  `framskriv_y5.R` og `usikkerhet_y1.R`/`usikkerhet_y2_stjerne.R`/
  `usikkerhet_y5.R` bruker nå alle `hovedmodell_slope` (aldri
  intercept-only-modellen) for faktisk framskrivning og
  bootstrap-usikkerhet. Punktestimater og bootstrap-CI er begge
  regenerert med den nye metoden.

## 10. Publisering på shinyapps.io (beta)

- **Valg av vertsplattform**: shinyapps.io, gratis-nivå - valgt av
  brukeren for et raskt, enkelt førsteutkast med en delbar URL til
  veiledere, uten behov for egen serverdrift. Kjente begrensninger på
  gratis-nivået: maks 25 aktive timer/måned totalt, appen "sovner" etter
  ~15 minutters inaktivitet (kort oppstartsforsinkelse ved neste besøk).
- **Kontosikkerhet**: kontoopprettelse og token-kobling (`rsconnect::
  setAccountInfo()`) ble gjort av brukeren selv, direkte i egen
  R-konsoll - IKKE av assistenten, siden dette innebærer å taste inn et
  hemmelig token/secret. Selve opplastingen (`rsconnect::deployApp()`)
  kunne gjøres av assistenten etterpå, siden kontoinfo da allerede lå
  lagret lokalt (ikke noe hemmelig som måtte håndteres videre).
- **Minimal opplasting, ikke hele prosjektet**: `app.R` bruker i praksis
  bare 10 av de 65 filene i `data/ssb/` (~4,5 MB av totalt ~144 MB) - de
  øvrige er mellomresultater fra `skript/`-pipelinen (rå paneldata,
  CSV-kopier, ikke-slope-modeller, CV-prediksjoner, plott) som appen ikke
  leser. Løst med en EKSPLISITT fil-liste til `deployApp(appFiles = ...)`
  i stedet for å laste opp hele mappen.
  - **`.rscignore` alene var ikke nok**: filen støtter (i motsetning til
    `.gitignore`) IKKE wildcards eller negasjon - bare ett fast fil-/
    mappenavn per linje. Brukes derfor bare til å utelate hele mapper
    (`skript/`, `dokumentasjon/`), mens det fin-kornede utvalget av
    hvilke `data/ssb/`-filer som skal med, styres av `appFiles`.
- **`skript/` og `dokumentasjon/` lastes ikke opp** - appen leser dem
  aldri (se punkt 6), og de har heller ingen verdi for en ekstern bruker
  av den ferdige appen.
