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
  (tabell 12882) foreløpig - LLML/HHMH er ikke beregnet.
- **Årseffekt for framtidige år**: satt til gjennomsnittet av de
  historiske årseffektene, av samme grunn som i kryssvalideringen (en
  årsdummy-modell har ingen egen koeffisient for et år utenfor
  treningsdataene).
- **Glidende overgang** (`glatt_overgang()`) fra observert til
  modellbasert nivå, for å unngå brå hopp i grafene ved overgangen fra
  historikk til framskrivning: 90 % vekt på observert 2025-verdi i 2026,
  lineært ned til 0 % (100 % modell) i 2036. Se
  [teknisk_dokumentasjon.md](teknisk_dokumentasjon.md) for eksakt formel.
- **Duplisert kode** mellom `framskriv_y1.R`/`framskriv_y2_stjerne.R`/
  `framskriv_y5.R` i stedet for en delt hjelpefil - et bevisst valg for å
  unngå regresjonsrisiko på allerede fungerende kode. Vurder en felles
  hjelpefil hvis flere Y-variabler gjør duplikasjonen upraktisk å
  vedlikeholde.

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
