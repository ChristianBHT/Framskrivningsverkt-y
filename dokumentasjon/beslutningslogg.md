# Beslutningslogg - Telemarksforsknings Framskrivningsverktøy (Fram)

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
  (tabell 12882) foreløpig - LLML/HHMH og Telemarksforskning sine
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
- **[TIDLIGERE POLICY - opphevet, se punkt 14]** Ingen metodikk/modelldetaljer skal vises i appen selv - "Om"-fanen
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
  befolkningsframskrivninger fra Telemarksforskning som alternativ til
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
- **Publisert URL**: https://christianbht.shinyapps.io/Fram/ (konto
  `christianbht`, appnavn `Fram`). Redeployet én gang etter at appens
  tittel ble endret til "Framskrivningsmodellen Fram - Resultater".
- **Status per 2026-09-21**: den publiserte versjonen inneholder IKKE den
  alternative Y_5-linjen (punkt 11) - de to nye filene er lagt til i
  opplastingslisten, men appen er ikke redeployet siden.
- `deployApp()` oppretter en `rsconnect/`-mappe i prosjektroten med
  publiseringsmetadata; den er ikke en del av appen og bør holdes utenfor
  versjonskontroll.

## 11. Alternativ estimering av Y_5 (Poisson) - KJENT PROBLEM

- **Bestilling**: en alternativ Y_5-estimering med samme modellfamilie som
  Y_1 og Y_2\* (Poisson med befolkningsoffset og tilfeldig kommuneeffekt),
  uten konfidensintervall, vist i SAMME plott som hovedestimatet.
- **Løsning**: `modell_y5_poisson.R` (modell + leave-one-year-out-CV),
  `framskriv_y5_poisson.R` (samme ankermetode og glidende overgang som de
  øvrige framskrivningene, gjenbruker cachet befolkning/demensandel fra
  `framskrevet_y5.rds`). I appen vises den som en grønn, stiplet linje
  ("Alternativ modell (MMMM)") uten usikkerhetsbånd, og følger
  trend-bryteren/slideren. Etiketten er bevisst nøytral (avslører ikke
  modelltype, jf. punkt 6).
- **Valg som viste seg å være feil**: årsverk er ikke heltall. Modellen ble
  først estimert på de uavrundede årsverkene (Poisson pseudo-likelihood),
  og tolket som gyldig ut fra en god kryssvalidering (RMSE 14,1 / MAE 5,6 /
  korrelasjon 0,9974). **Ved kontroll ved oppdatering av dokumentasjonen ble
  det oppdaget at de tilfeldige effektenes varianser ikke estimeres:**
  `theta` står på lme4s startverdier (1, 0, 1), det gis advarselen "Gradient
  contains NAs", og det samme gjelder en ren intercept-modell på de samme
  dataene. Kryssvalideringen så altså fornuftig ut selv om modellen ikke
  var riktig estimert. Modellen som ligger i appen er derfor **ikke
  gyldig** som alternativ estimering - nivåene (bl.a. en
  `demensandel`-koeffisient på 3,7 mot ~14-34 i de andre modellene) er ikke
  til å stole på, og de rapporterte 2050-verdiene for alternativlinjen
  (f.eks. Halden 209 mot 275 for hovedestimatet) bør ikke tolkes.
- **Test av mulig rettelse (ikke innført)**: avrunding til heltall gir en
  modell der variansene faktisk estimeres (SD intercept 0,58, SD helning
  24,9, korrelasjon -0,91, `demensandel` 21,7, 32/357 kommuner med negativ
  effektiv helning), men med en konvergensadvarsel (bobyqa nådde maks antall
  funksjonskall, maks |gradient| 0,010 mot toleranse 0,002) - trenger
  høyere `maxfun` og ny kontroll. Alternativ til avrunding: en modell
  for kontinuerlige positive data (f.eks. Gamma med log-lenke).
- **Åpent**: rette `modell_y5_poisson.R`, kjøre `framskriv_y5_poisson.R`
  på nytt, og først deretter redeploye.

## 12. Andre SSB-tabeller (11643 m.fl.)

- Vurderer tabell **11643** (timer til omsorgstjenester per år) med
  TenesteType 15 (helsetjenester i hjemmet) som mulig nytt utfall.
  `hent_timer_11643.R` laster ned 2009-2025, kobler historiske
  kommunenumre til 2024-strukturen (timer er additive, summeres) og
  plotter de 10 største kommunene etter folketall 2025.
- **Funn**: SSB fyller kommunekoder som ikke eksisterer et gitt år med **0**
  (ikke manglende verdi), så summering over forgjengerkoder er trygg, men en
  reell rapporteringsmangel ville også blitt 0. Noen serier har store hopp
  som ikke er forklart (Bergen ~1,29 mill. timer 2020 → ~0,77 mill. 2024;
  Trondheim ~0,19 mill. 2010 → ~0,29 mill. 2012; Stavanger 2009 ser lav ut).
- De øvrige tabellene (09933, 06975, 12657, 11644), alternative
  glattingsmetoder og sjekk av befolkningskoeffisienten er beskrevet i
  [videre_arbeid.md](videre_arbeid.md). Tabelloversikten der bygger på
  metadata hentet fra SSBs API.

## 13. Modellsjekk: er koeffisienten på log(befolkning) lik 1?

- **Bakgrunn**: alle modellene tvinger koeffisienten på log(befolkning) til
  1 via `offset(log(folk_ialt))`, dvs. bruk antas proporsjonal med
  folketallet. Dette er en antakelse som ikke er testet.
- **Beslutning: ingen "Modellsjekker"-fane i appen** (brukerens valg).
  Modellsjekker gjøres i frittstående script i `skript/`, i tråd med
  prosjektets daværende policy om at metodikk ikke vises i appen (punkt 6,
  senere opphevet, se punkt 14; valget om script fremfor fane står ved lag). Dette
  erstatter forslaget om en egen fane i en tidligere versjon av
  videre_arbeid.md.
- **Metode** (`modellsjekk_kvantil.R`): kvantilregresjon
  (`quantreg::rq`) på per-innbygger-formen
  `log(y/befolkning) ~ log(befolkning) + demensandel + år`, for
  τ = 0,1 / 0,25 / 0,5 / 0,75 / 0,9. Koeffisienten på `log(befolkning)` er
  β_pop − 1, så 0 betyr proporsjonalitet. Usikkerhet fra Bayesiansk
  bootstrap over kommuner (B = 100, samme Dirichlet-vekting som
  `usikkerhet_*.R`, vekter sendt til `rq(weights = )`).
- **Første resultat (Y_1)**: β_pop ≈ 1,00 ved τ = 0,1 (intervall
  [0,985, 1,021], forenlig med 1), men under 1 for høyere kvantiler:
  0,974 (τ = 0,25), 0,949 (0,5), 0,916 (0,75) og 0,894 (0,9), med 95 %
  intervaller som utelukker 1. Proporsjonalitet forkastes altså fra medianen
  og oppover: bruk per innbygger avtar med kommunestørrelse, mest blant
  kommuner med høy bruk.
- **Forbehold**: ingen tilfeldige effekter eller kommune-faste effekter i
  `rq` - koeffisienten hentes hovedsakelig fra forskjeller MELLOM kommuner;
  2 observasjoner med y = 0 utelates; kun Y_1 er kjørt (ikke Y_2\*/Y_5).
- **Ikke innført ennå**: modellene bruker fortsatt offset. En fri
  koeffisient krever at ankerformelen endres (se videre_arbeid.md pkt. 3).

## 14. Dokumentasjon som faner i appen; ingen innlogging (2026-09-21)

- **Beslutning (brukerens)**: appen forblir OFFENTLIG, uten innlogging. Et
  passordbeskyttet område ble vurdert (Shiny har ingen innebygd
  autentisering; alternativer er `shinymanager`/`shinyauthr`, en egen
  passordport med serverside-rendering, eller innlogging på plattformnivå på
  betalte shinyapps.io-planer) men ikke innført. Det finnes derfor ingen
  innloggingskode i appen.
- **Dokumentasjon åpent i appen**: teknisk dokumentasjon, beslutningslogg og
  videre arbeid vises som egne faner ("Teknisk dokumentasjon",
  "Beslutningslogg", "Videre arbeid"). Dette **opphever** den tidligere
  policyen om at metodikk ikke skal vises i appen (punkt 6). Fanene leser
  `dokumentasjon/*.md` ved oppstart og viser dem som HTML
  (`commonmark`). Lenker til lokale `.md`-filer vises som ren tekst, siden
  de ikke finnes som sider i appen; eksterne lenker åpnes i ny fane.
- **Konsekvens for publisering**: `dokumentasjon/*.md` må nå med i
  opplastingen (`skript/deploy_shinyapps.R`), og `dokumentasjon` er fjernet
  fra `.rscignore`. Dokumentene beskriver også kjente feil (bl.a. den
  ugyldige alternative Y_5-modellen, punkt 11) - de blir dermed synlige
  for alle som åpner appen.
- **Kontekst**: serveren skal tas ned om noen dager, så dette er en
  midlertidig visning for gjennomgang, ikke en permanent publisering.
- **Krav til den ENDELIGE appen (brukerens presisering)**: metodikk skal
  bare forklares overfladisk. De tre dokumentasjonsfanene gjelder derfor
  kun beta-versjonen til gjennomgang. Dette er gjort til én bryter i
  `app.R`: `VIS_FULL_DOKUMENTASJON <- TRUE` (beta) / `FALSE` (endelig). Ved
  `FALSE` vises ingen dokumentasjonsfaner, og "Om"-fanen har i stedet et kort,
  generelt avsnitt ("Kort om metoden", alltid synlig) uten formler,
  modelltyper eller filnavn. Ved overgang til endelig versjon: sett bryteren
  til `FALSE` og fjern `dokumentasjon/*.md` fra `skript/deploy_shinyapps.R`.

## 15. Analyse av stordriftsfordeler (fane i appen) (2026-09-21)

- **Bestilling**: kjør modellsjekken (punkt 13) også for Y_2\* og Y_5, og vis
  resultatene for Y_1, Y_2\* og Y_5 i en egen fane, "Analyse stordriftsfordeler".
  Dette er en bevisst reversering av valget i punkt 13 om ikke å ha
  modellsjekker i appen - nå gjelder det denne ene analysen, som vises åpent.
- **Tolkning**: β_pop < 1 betyr at bruken vokser saktere enn folketallet, dvs.
  at større kommuner bruker mindre per innbygger (stordriftsfordeler).
  **Presisering**: kvantilene τ rangerer kommunene etter *bruk per innbygger*
  (justert for `demensandel` og år), IKKE etter kommunestørrelse. "Høy
  kvantil" betyr høy bruk per innbygger, ikke store kommuner. Dette står også
  eksplisitt i fanen. Å undersøke om de STØRSTE kommunene har
  stordriftsfordeler ville krevd en annen analyse (f.eks. flere hellingsledd
  eller å dele utvalget etter størrelse).
- **Resultat** (β_pop, 95 % bootstrap-intervall, B = 100 per variabel):

| Variabel | τ = 0,1 | τ = 0,25 | τ = 0,5 | τ = 0,75 | τ = 0,9 |
|---|---|---|---|---|---|
| Hjemmetjenester (Y_1) | 1,001 [0,985, 1,021] | 0,974 [0,958, 0,993] | 0,949 [0,931, 0,967] | 0,916 [0,898, 0,934] | 0,894 [0,878, 0,913] |
| Bolig (Y_2\*) | 1,041 [1,016, 1,066] | 1,011 [0,984, 1,031] | 0,964 [0,941, 0,984] | 0,914 [0,884, 0,946] | 0,892 [0,858, 0,915] |
| Sykepleier, årsverk (Y_5) | 0,957 [0,904, 0,996] | 0,930 [0,904, 0,957] | 0,907 [0,882, 0,939] | 0,885 [0,866, 0,908] | 0,865 [0,840, 0,889] |

  - Mønsteret er likt for alle tre: β_pop faller jevnt fra lave til høye
    kvantiler. For Y_1 og Y_2\* er lav kvantil forenlig med proporsjonalitet
    (Y_2\* er til og med litt over 1 ved τ = 0,1, altså det motsatte av
    stordriftsfordeler), mens de høye kvantilene ligger klart under 1.
  - Y_5 (sykepleierårsverk) skiller seg ut ved å ligge under 1 for alle
    kvantiler, også den laveste.
- **Forbehold** (som i punkt 13): ingen kommune-faste effekter, så resultatet
  sammenligner kommuner med hverandre og sier lite om utvikling over tid i
  samme kommune; sammenheng, ikke nødvendigvis årsak. Y_5 dekker bare
  2015-2025.
- **Teknisk**: `modellsjekk_kvantil.R` tar variabelen som kommandolinjeargument
  og lagrer en kompakt sammendragsfil per variabel
  (`modellsjekk_kvantil_<var>_sammendrag.rds`) som appen leser; de fulle
  `rq`-modellene leses ikke av appen og lastes ikke opp.
- Fanen vises uavhengig av bryteren `VIS_FULL_DOKUMENTASJON` (punkt 14). Den
  er ikke redeployet ennå.

## 16. Startside, Telemarksforskning-profil og bunntekst (2026-09-24)

- **Startfane** ("Start", første fane og valgt ved oppstart): logo, kort
  beskrivelse av appen, en knapp som går til fanen Framskrivning, og en
  boks med teksten om Stiftelsen Telemarksforskning (formulert av brukeren)
  og lenke til https://telemarksforsking.no/.
- **Logo**: `resources/telemarks-logo.png` (levert av brukeren) vises på
  startsiden og i topplinjen (klikkbar lenke til Telemarksforskning, med
  alt-tekst). Filen serveres med `addResourcePath("resources", "resources")`
  i stedet for å flyttes til `www/`, og er lagt til i opplastingslisten i
  `skript/deploy_shinyapps.R`.
- **Bunntekst på alle faner** (også dokumentasjonsfanene): "© [inneværende
  år] Copyright Telemarksforskning" og "Utviklet av Christian Thorjussen"
  (navnet er en mailto-lenke til christian.b.thorjussen@tmforsk.no).
  Årstallet beregnes ved oppstart. Implementert som `panel_fot()` som legger
  bunnteksten til hvert `nav_panel`, så nye faner bør lages med den.
- **Sidepanelet** (variabel/kommune/trend) åpnes bare på Framskrivning og
  Datatabell og skjules ellers, siden det er irrelevant på Start, Om,
  analyse og dokumentasjon.
- Ikke redeployet ennå.

## 17. Plattformnavn, startside som verktøykasse og stavemåte (2026-09-24)

- **Stavemåte**: "Telemarksforsking" er endret til "Telemarksforskning" i
  appen, README og prosjektdokumentene (brukerens valg). URL-en
  (https://telemarksforsking.no/) og e-postdomenet er bevisst *ikke*
  endret, siden det er faktiske adresser. Logofilen viser fortsatt den
  gamle stavemåten, og brukerens ordrette tekst om stiftelsen inneholder
  fortsatt "forskingsinstitutt".
- **To nivåer av navn**: hele verktøyet/plattformen har ett navn
  (`APP_NAVN`, vises i topplinjen, nettleserfanen og på startsiden), mens
  **bare fanen med framskrivningene heter "Framskrivningsmodellen Fram"**
  (`MODELL_NAVN`). Bakgrunnen er at verktøyet skal bli mer omfattende enn
  én modell: mange nøkkeltall, verktøy og modeller som kan være en ressurs
  for kommunene.
- **Foreløpig plattformnavn: "Kommuneframsyn"** (arbeidstittel, endres i
  `APP_NAVN` i `app.R`). "Kommunekompasset" ble vurdert og forkastet: det er
  et etablert verktøy fra KS.
- **Startsiden** viser nå verktøyet som en verktøykasse med kort:
  *Tilgjengelig nå* (Framskrivningsmodellen Fram, Analyse
  stordriftsfordeler, begge med "Åpne"-knapp) og *Under utvikling*
  (Nøkkeltall, Befolkningspyramider, Tilbud av helsepersonell, Flere modeller
  og verktøy, uten knapp). Kortene under utvikling er bevisst merket som
  planlagte, ikke som ferdige funksjoner. Nye verktøy legges til med
  `verktoy_kort()`.
- Ikke redeployet ennå.

## 18. Kreditering og lisens for SSB-data (2026-09-24)

- **Hva SSB krever** (https://www.ssb.no/diverse/lisens): SSBs data er
  lisensiert under **Creative Commons Attribution 4.0 International (CC BY
  4.0)** (tidligere NLOD, som er forenlig). **Kommersiell bruk er tillatt**,
  også bearbeiding ("remixe, endre, og bygge videre på materialet til et
  hvilket som helst formål, inkludert kommersielle"). Vilkårene: (1) navngi
  SSB, helst med lenke til ssb.no, (2) oppgi en lenke til lisensen, (3)
  opplyse om at endringer er gjort. Unntak: bilder og fotografier, samt
  konfidensielle personopplysninger. Ingen av unntakene gjelder for
  tabellene vi bruker (aggregerte tall).
- **Dette er relevant for abonnementsproduktet** (todo_app.md pkt. 6.3): det
  betyr at bruk av SSB-tallene i et betalt produkt er lovlig så lenge
  krediteringen er på plass.
- **Implementert i appen**:
  - *Bunntekst på alle faner*: "Kilde: Statistisk sentralbyrå (SSB), lisens
    CC BY 4.0. Tallene er bearbeidet av Telemarksforskning." med lenker til
    ssb.no og til lisensen (https://creativecommons.org/licenses/by/4.0/).
  - *Om-fanen, nytt avsnitt "Kreditering og lisens"*: navngir SSB, lenker til
    lisensen og SSBs lisensvilkår, sier at kommersiell bruk er tillatt, og
    beskriver **endringene**: historiske tall er samlet til dagens
    kommunestruktur, og andel eldre med økt behov, framskrivninger og
    usikkerhetsintervall er egne beregninger.
  - *Ingen antydet støtte*: teksten sier eksplisitt at framskrivningene ikke
    er SSBs tall og ikke er godkjent eller anbefalt av SSB, og at SSBs
    befolkningsframskrivning (tabell 12882) brukes som grunnlag.
- **Ikke avklart**: kreditering og vilkår for demensprevalensratene
  (`dementia_dic` i `legg_til_demens.R`), som ikke kommer fra SSB, og for
  Telemarksforsknings egne befolkningsframskrivninger hvis de tas inn.
  Lisensen for selve appen/koden er heller ikke bestemt.
- Ikke redeployet ennå.

---

## 19. Fargepalett avledet fra Telemarksforsknings logo (2026-09-24)

- **Bestilling**: analyser logoens fargeskjema og bruk et passende skjema i
  appen.
- **Logoanalyse** (`resources/telemarks-logo.png`): to farger, petrol
  `#004C66` (ca. 55 % av pikslene) og rav/oransje `#D17E12` (ca. 45 %), på
  gjennomsiktig bakgrunn. Kontrast mot hvitt: petrol 9,4:1 (god for tekst og
  flater), rå oransje bare 3,1:1 (kun akser, streker, grafikk og
  aksenter, aldri brødtekst).
- **Palett** (én konstant `PALETT` øverst i `app.R`; alle farger i plott,
  tema og CSS hentes derfra, ingen hardkodede hex-verdier lenger):
  - Hovedfarger: petrol `#004C66` (primær, topplinje, overskrifter,
    lenker, observerte data) og oransje `#D17E12` (aksent, framskrevet,
    aktiv fane, usikkerhetsbånd med 20 % dekning).
  - Avledede: mørk petrol `#00374A` (hover), mørk oransje `#9C5A00`
    (tekst i oransje, 5,4:1 mot hvitt), tekst `#1E2A30`, grå `#5C6F78`
    (dempet tekst, 5,3:1), lyse flater `#F2F6F7` / `#E4ECEF`.
  - Status: grønn `#2F7D5B` (suksess, 5,0:1), blå `#2B7A99` (info), rød
    `#B3261E` (feil).
  - Tredje serie (alternativ modell, tredje kvantil/variabel i
    stordriftsanalysen): skifergrå `#6B7F88`.
- **Fargesynstest**: petrol mot oransje har Lab-avstand ΔE 80-97 under
  simulert deuteranopi, protanopi og tritanopi (Machado-matriser), altså
  godt atskilt. Den tredje serien er valgt som nøytral grå fordi
  alternativer som teal og dus grønn ble for like petrol eller oransje
  under simulering (grå ΔE ≥ ca. 28-33). I tillegg er linjene forskjellige
  i stil (heltrukken / stiplet / prikket), så figurene skilles også uten
  farge.
- **Endret i appen**: `bs_theme()` beholder Bootswatch *flatly* (for å ikke
  bytte skrift), men primary/secondary/success/info/warning/danger/bg/fg
  og lenkefarger settes fra paletten. Topplinjen er petrol med hvit tekst
  og logoen i en hvit boks (logoen har mørk tekst og trenger lys bakgrunn),
  aktiv fane har oransje topplinje, overskrifter på startsiden og i
  dokumentfanene er petrol, og kortene og bunnteksten bruker de lyse
  flatene. Tidligere plottfarger (`#0072B2`, `#D55E00`, `#009E73`) er
  erstattet.
- **Kontrollert** lokalt i nettleser: startside, framskrivningsfane,
  stordriftsanalyse; ingen konsollfeil. Ikke redeployet ennå.
- **Ikke gjort**: egen font, mørk modus og felles plotly-tema (se
  todo_app.md pkt. 4).

---

## 20. Fane med befolkningspyramider (2026-09-24)

- **Bestilling**: fane der brukeren velger kommune; historiske pyramider for
  2010, 2015, 2020 og 2025 på én linje, og en litt større pyramide under for
  et framskrevet år brukeren velger.
- **Forhåndsberegnet, ikke regnet i appen.** Pyramidene er SSBs egne tall
  (observert og hovedalternativet MMMM), ikke modellresultater, så det er
  ingenting som må estimeres når brukeren velger. Vi lagrer derfor alle
  kommuner x år x kjønn x aldersgruppe i én liten fil
  (`data/ssb/befolkning_pyramide.rds`, 0,5 MB, 597 000 rader) laget av
  `skript/lag_pyramidedata.R`. Fordeler: ingen API-kall i appen (raskere og
  robust mot SSB-nedetid), ingen aggregering i appen, og tallene kan
  kontrolleres én gang. I appen regnes bare prosentandeler og summer for
  valgt kommune og år. Å hente fortløpende ville gitt treg fane, avhengighet
  av SSBs API på shinyapps.io og risiko for cellegrenser; å regne ut selv er
  bare aktuelt for framtidige *scenarier* (LLML/HHMH), og da bør også disse
  forhåndsberegnes.
- **Data**: 5-årige aldersgrupper (0-4, ..., 85-89, 90+), 2007-2050. Observert
  fra `befolkning_detaljert.rds` (tabell 07459, 2024-struktur), framskrevet
  fra tabell 12882 med samme kommunehistorikk-logikk som `framskriv_y1.R`.
  "Hele landet" hentes direkte fra tabell 12882 (region "0") for
  framskrevne år. Kontroll: folketall stemmer eksakt (avvik 0) med
  `framskrevet_y1.rds` for alle 356 kommuner x 25 år.
- **Haram (1580) er utelatt**: finnes ikke i SSBs framskrivning (samme som i
  modellene). Landstallet for observerte år inkluderer likevel Haram.
- **Visning**: felles akse for alle pyramidene til en kommune (største
  verdi over alle år), slik at de kan sammenlignes og aksen ikke hopper når
  året endres. Valgfritt: andel av befolkningen (%) i stedet for antall
  (nyttig for å sammenligne små og store kommuner), og 2025 som omriss bak
  den framskrevne pyramiden. Over pyramiden vises folketall, andel 65+ og
  andel 80+ for valgt år mot 2025. Menn er petrol og kvinner oransje
  (paletten fra pkt. 19). Året velges med glidebryter som kan animeres.
- Startsidekortet "Befolkningspyramider" er flyttet fra "Under utvikling"
  til "Tilgjengelig nå". Fila er lagt til i opplastingslisten. Ikke
  redeployet ennå.

---

## 21. Kommunens egne tall som anker; alternativ Y_5-modell fjernet (2026-09-24)

- **Bestilling**: celler der kommunen kan legge inn egne tall for Y_1, Y_2\* og
  Y_5, slik at verdien blir det nye ankerpunktet. Ta bort den alternative
  Y_5-modellen.
- **Hva "anker" betyr her.** Framskrivningen har to ankre: (1) demensandelen
  i 2025, som er en modellparametrisering (pkt. 3 i teknisk dokumentasjon) og
  ikke berøres, og (2) det observerte 2025-*nivået*, som blandes inn med 90 %
  vekt i 2026 og trappes lineært ned til 0 i 2050 (glidende overgang). Det er
  (2) som byttes ut med kommunens egen verdi.
- **Effekt.** Verdien i år t flyttes med `w(t) * (egen - SSB2025)`, der `w`
  er overgangsvekten. Hele framskrivningen (også trend-varianten) løftes eller
  senkes tilsvarende i starten, og effekten er borte i 2050. Skiftet følger
  eksakt av formelen og er verifisert numerisk i appen (Halden Y_1: egen verdi
  1 281 mot SSBs 1 081 gir 2026-verdi 1 266,1 = 1 086,1 + 0,9 x 200 og uendret
  2050-verdi; Y_5 og Oslo testet; nullstilling gir tilbake de opprinnelige
  tallene).
- **Usikkerhetsbåndet** flyttes med samme beløp som punktestimatet. Det er
  eksakt, fordi bootstrap-persentilene beregnes av samme glattede formel og
  skiftet er likt i alle trekk, så ingen ny bootstrap trengs. Båndet forblir
  modellusikkerhet og sier ingenting om hvor sikkert det innlagte tallet er;
  appen sier dette eksplisitt i en merknad over grafen.
- **Brukergrensesnitt**: tre felt i sidepanelet ("Kommunens egne tall"), ett per
  variabel, for valgt kommune, med SSBs 2025-tall som veiledning under
  feltene. Egen verdi vises som en rute (diamant) i 2025 i grafen, med en
  blå merknad over grafen. Tallene huskes per kommune mens økten varer, kan
  nullstilles, og lagres **ikke** på serveren eller mellom økter (ikke delt
  mellom brukere). Datatabellen og CSV-nedlastingen får en egen rad for den
  innlagte verdien.
- **Valg**: bare 2025 (siste observerte år) er støttet som ankeråret.
  Kommuner med nyere tall (2026) kan legge dem inn, men de tolkes da som
  2025-nivå. Vurder senere en egen "gjelder år"-velger og en tilpasset vekt.
  Ikke gjort: opplasting av flere år, lagring mellom økter (krever innlogging
  eller lokal lagring), og en usikkerhet på selve tallet.
- **Alternativ Y_5-modell (Poisson) fjernet**: linjen, fargen, koden i
  `framskriv_trend()`/`lag_tidsserie()` og filene i opplastingslisten
  (`framskrevet_y5_poisson.rds`, `modell_y5p_hovedmodell_slope.rds`) er tatt
  ut, siden modellen ikke var gyldig estimert (pkt. 11). Scriptene
  (`modell_y5_poisson.R`, `framskriv_y5_poisson.R`) og resultatfilene er
  beholdt i repoet til dokumentasjon. Den åpne feilen er dermed ikke lenger
  synlig for brukerne.
- Ikke redeployet ennå.

---

## 22. Nye visningsnavn på variablene (2026-09-24)

- Y_1 heter i appen nå **"Brukere av hjemmesykepleie"** (tidligere "Etterspørsel
  etter hjemmetjenester (brukere)") og Y_2\* **"Brukere av boliger"** (tidligere
  "Etterspørsel etter bolig (brukere)"). Y_5 er uendret ("Etterspørsel etter
  sykepleier (avtalte årsverk)").
- Navnene brukes i variabelvelgeren, grafens tittel, feltene for egne tall,
  hjelpeteksten, startsidekortet, Om-fanen og legenden i stordriftsanalysen.
  Bare visningsnavn er endret; interne koder (Y_1, Y_2_stjerne, Y_5), filnavn og
  modeller er uendret.
- Merk: navnet "hjemmesykepleie" er smalere enn SSBs kategori
  "hjemmetjenester" (som også omfatter praktisk bistand). Tabellene i Om-fanen
  bruker fortsatt SSBs egne betegnelser. Ikke redeployet ennå.
- **Tillegg (samme dag):** Y_5 heter nå **"Sykepleiere (avtalte årsverk)"**
  (tidligere "Etterspørsel etter sykepleier (avtalte årsverk)"). Navnet er
  valgt av meg som forslag i samme stil som de to andre og kan endres i
  `Y_VARIABLER` i `app.R`.
