# Demografi i planverket til Buskerud-kommunene: vurdering og skisse til boligplanleggingsverktøy

Arbeidsnotat, 2026-09-23. Bygger på 49 plandokumenter for de 18 kommunene i
Buskerud (samfunnsdel, planstrategi, kunnskapsgrunnlag og helse- og
omsorgsplaner), lastet ned og konvertert med
`skript/hent_planverk_buskerud.R`. Tekstene og demografiuttrekkene ligger i
`data/planverk/buskerud/`. Se [README](../data/planverk/buskerud/README.md)
der for dokumentliste og kjente hull.

**Forbehold.** Vurderingen gjelder bare dokumentene som er lastet ned.
Kommunene kan ha andre planer som dekker temaet, for eksempel boligstrategier,
demensplaner og økonomiplaner, som ikke er med her. Det er nevnt der det er
kjent. For Drammen (Drammenstrender 2023) og Ål (planstrategi 2024–2027),
som er bildebaserte PDF-er, er de relevante sidene lest direkte.

---

## 1. Sammendrag

- **Tre kommuner skiller seg klart ut positivt: Drammen, Lier og Kongsberg.**
  - De har egne eller alternative befolkningsframskrivinger ved siden av SSB:
    KOMPAS i Drammen og Lier, Prognosesenteret i Kongsberg.
  - De kobler framskrivingen eksplisitt til boligbygging, og Drammen gjør det
    også på delområdenivå.
  - De bruker scenarier for å vise usikkerheten.
- **Nore og Uvdal og Sigdal er de beste blant de små kommunene.** De bruker
  Telemarksforskings scenarier og regner ut konsekvenser for tjenestene,
  blant annet årsverk i pleie og omsorg i 2040. **Krødsherad** har det beste
  systemet for å følge utviklingen med indikatorer.
- **Ål, Hole og Flå har det svakeste planverket for demografiske endringer.**
  - Ål og Hole har de eldste samfunnsdelene (2015 og 2018).
  - Ingen av de tre har egen analyse av hva befolkningsutviklingen betyr for
    tjenester og boliger.
  - Flås samfunnsdel fra 2022 har nesten ingen demografisk analyse.
  - **Nesbyen og Hemsedal** kommer like etter. Grunnlaget deres er utdatert,
    men Nesbyen har startet revisjon.
- **Fire gjennomgående svakheter:**
  1. Mange kommuner **blander befolkningsmål og prognose**. Hol, Gol og
     Hemsedal har mål om henholdsvis 5 000, 5 000 og 3 000 innbyggere i 2030,
     godt over SSBs framskriving.
  2. De fleste bruker **bare SSBs hovedalternativ** og drøfter ikke
     usikkerheten.
  3. Svært få **regner om demografi til boligbehov** etter type og størrelse,
     og få dimensjonerer omsorgsboliger og heldøgnsplasser.
  4. I hyttekommunene **tallfestes ikke deltidsbefolkningen** (fritidsbeboere)
     i tjenesteplanleggingen.
- **Et felles boligplanleggingsverktøy kan tette hullene for de små
  kommunene.** Det kan bygges som en utvidelse av Fram (kapittel 6) og gjøre
  det Drammen, Lier og Kongsberg kjøper eller lager selv: fra
  befolkningsframskriving via husholdninger til boligbehov etter type,
  omsorgsboliger og planreserve, med scenarier.

---

## 2. Vurderingsramme

Hver kommune er vurdert på seks dimensjoner som til sammen beskriver evnen
til å planlegge for demografiske endringer:

| Kode | Dimensjon | «Sterk» betyr |
|---|---|---|
| A | Kunnskapsgrunnlag | Oppdatert og lokalt tilpasset, gjerne med delområder (grend, skolekrets) |
| B | Framskriving og usikkerhet | Flere alternativer eller scenarier, ikke bare SSB MMMM. Prognose skilt fra mål |
| C | Demografi → tjenester | Tallfestet behov for omsorg og skole: plasser, årsverk, dekningsgrad |
| D | Demografi → bolig og areal | Boligbyggeprogram og boligbehov etter type og livsfase, koblet til arealreserve |
| E | Oppfølging | Indikatorer og måltall som følges over tid |
| F | Aktualitet | Samfunnsdel og planstrategi fra de siste 3–4 årene |

Skala: ● sterk, ◐ delvis, ○ svak eller mangler.

## 3. Oversikt

| Kommune | A | B | C | D | E | F | Samfunnsdel | Kort karakteristikk |
|---|---|---|---|---|---|---|---|---|
| Drammen (3301) | ● | ● | ◐ | ● | ◐ | ● | 2021–2040 | KOMPAS med to lokale alternativer per kommunedel, planreserve etter utbyggingsmodenhet, boligpreferanser |
| Kongsberg (3303) | ● | ● | ◐ | ● | ◐ | ● | 2026–2040 | Prognosesenteret med tre scenarier, bolig og KDA-sysselsetting som drivere, boligbehov for SSBs ni alternativer |
| Ringerike (3305) | ◐ | ○ | ◐ | ◐ | ○ | ◐ | 2021–2030 | God boligpolitikk og arealstrategi, men lite tallfestet framskriving i dokumentene |
| Hole (3310) | ○ | ○ | ○ | ◐ | ○ | ○ | 2018–2030 | Eget vekstanslag på 2 %, framskrivingen er oppgitt å være usikker på grunn av FRE16, og planstrategi ble ikke funnet |
| Lier (3312) | ● | ● | ● | ● | ◐ | ◐→● | 2019–2028, ny 2040 på høring | KOMPAS med boligbyggeprogram, egen prognose mot SSB, 87 sykehjemsplasser innen 2034, boligpreferanser |
| Øvre Eiker (3314) | ◐ | ◐ | ◐ | ◐ | ◐ | ◐ | 2021–2033 | SSB middel har truffet godt, boligprogram og stedsprosjekter, mål om 1,4 % vekst |
| Modum (3316) | ◐ | ○ | ◐ | ◐ | ○ | ● | 2022–2032 | Gode nøkkeltall fra SSB (80+ fra 711 til ca. 1 600), men bare ett alternativ og ingen oppfølging |
| Krødsherad (3318) | ● | ◐ | ◐ | ◐ | ● | ◐ | 2019–2032 | Eget indikatorsett (vedlegg 3) med bostedsattraktivitet og boligbyggingstakt |
| Flå (3320) | ○ | ○ | ○ | ○ | ○ | ◐ | 2022–2034 | Nesten ingen demografisk analyse, uklart folketallsmål, boligmangel omtalt uten program |
| Nesbyen (3322) | ◐ | ○ | ◐ | ◐ | ○ | ○ | 2018–2030 | Statistikkhefte fra 2018, 71 heldøgns omsorgsboliger, boligbyggeprogram var planlagt, revisjon startet 2025 |
| Gol (3324) | ◐ | ◐ | ◐ | ○ | ◐ | ○ | 2018–2030, ny 2026–2038 under arbeid | Bruker flere SSB-alternativer og beregner demografikostnader, men har lite om bolig |
| Hemsedal (3326) | ○ | ◐ | ○ | ◐ | ○ | ○ | 2019–2030 | Administrativ prognose på 1 % årlig vekst, Ungbo og Eldrebu, mål om 3 000 innbyggere |
| Ål (3328) | ○ | ○ | ○ | ◐ | ○ | ○ | 2015–2027 | Eldste samfunnsdel, tynn demografidel i planstrategien, men har kartlagt utbyggingsreserver |
| Hol (3330) | ◐ | ○ | ● | ◐ | ◐ | ○ | 2018–2030 | Kommunedelplan for helse og omsorg med heldøgns dekningsgrad fra 35 % til 22 %, og mål om 5 000 innbyggere |
| Sigdal (3332) | ◐ | ● | ◐ | ◐ | ○ | ● | 2022–2035 | Fire Telemarksforsking-scenarier og SSB, 1,1–1,4 personer i yrkesaktiv alder per eldre i 2050 |
| Flesberg (3334) | ● | ◐ | ◐ | ◐ | ◐ | ● | 2025–2040 | Grundig kunnskapsgrunnlag med demenskart og husholdninger. SSB viser uvanlig vekst på 16 % |
| Rollag (3336) | ◐ | ◐ | ◐ | ○ | ○ | ◐ | 2023–2033 | Telemarksforskings attraktivitetsmodell og demens, men lite om bolig, og siste planstrategi er fra 2020–2023 |
| Nore og Uvdal (3338) | ● | ● | ● | ◐ | ◐ | ● | 2024 | Telemarksforsking-scenarier (1 815–1 911 innbyggere i 2050 mot SSBs 2 261), årsverksmodell og boligstrategisk gruppe |

---

## 4. Kommune for kommune: hvordan styrke evnen til å planlegge for demografiske endringer

### Drammen (3301)
**Status.** Drammenstrender 2023 er det mest komplette kunnskapsgrunnlaget i
fylket.
- Befolkning, husholdninger og forsørgerbrøk: 0,31 i 2023 og 0,43 i 2040.
- 80+ ventes å bli doblet og 90+ tredoblet fram mot 2040.
- Boligmasse etter type og størrelse per kommunedel, og boligproduksjon.
- Planreserve på ca. 20 000 boliger. Av disse er 2 700 byggeklare, og 2 600
  har rekkefølgekrav uten avklart finansiering.
- Boligpreferanser fra Buskerudby-undersøkelsen.
- Drammen lager egne framskrivinger i KOMPAS i to alternativer (trendflytting
  og boligtilbud). Kommunen skriver åpent at både SSB og de egne
  framskrivingene har ligget over faktisk utvikling det siste tiåret.

Samfunnsdelen løfter fram den demografiske utfordringen, men oversetter den i
liten grad til tallfestede mål.

**Styrke:**
- Knytte samfunnsdelen tydeligere til kunnskapsgrunnlaget med noen få
  måltall, for eksempel andel nye boliger som er tilgjengelige for eldre per
  kommunedel.
- Etterprøve framskrivingene systematisk. Når begge har truffet for høyt, bør
  det dokumenteres hvordan lokale og SSB-baserte prognoser har truffet, og
  dimensjoneringen bør justeres.
- Beregne behovet for tilgjengelige boliger for 80+ per omsorgsdistrikt. Det
  finnes data, men koblingen mangler i samfunnsdelen.

### Kongsberg (3303)
**Status.** Samfunnsdelen 2026–2040 er ny.
- Prognosesenteret (2025) har laget en kohort-komponent-framskriving med
  boligbygging, KDA-sysselsetting (4 000 ansatte i 2029) og bosettingsandel
  som drivere, i tre scenarier.
- Analysen inkluderer flyttestrømmer (primær- og sekundærflytting per
  boligtype) og boligbehov for SSBs ni alternativer og sju aldersgrupper.
- Planstrategien legger til grunn ca. 200 nye boliger per år, og
  administrasjonen kaller selv anslaget høyt.
- En livsfasestrategi er planlagt.

**Styrke:**
- Omsette boligbehovsberegningen til en boligtypemiks i arealdelen. Analysen
  viser at boligtype styrer alderen på tilflytterne.
- Lage en egen prognose for eldreboliger og omsorgsboliger. Framskrivingen
  bruker bare én gruppe for 66+, og det er for grovt for omsorgsplanlegging.
- Følge opp KDA-antakelsen (bosettingsandel 35–70 %) årlig, fordi den er
  største kilde til usikkerhet.

### Ringerike (3305)
**Status.**
- Ringerike har en helhetlig boligpolitikk «for folk i alle livsfaser», en
  kompakt arealstrategi og kart over befolkningstetthet i 200 m-rutenett.
- Bakgrunnsdokumentet beskriver eldrebølgen og konsekvensene for
  arbeidskraften. I dokumentene som er lastet ned, finnes det likevel ingen
  tallfestet framskriving og ingen omsorgsdimensjonering.
- Planstrategien for 2024–2027 ble ikke funnet som PDF.

**Styrke:**
- Lage et samlet og tallfestet demografisk kunnskapsgrunnlag med
  framskriving per tettsted eller skolekrets. Som den nest største kommunen i
  fylket bør Ringerike ha dette på Drammens og Liers nivå.
- Lage et boligbyggeprogram koblet til vekstgrensen og vedlegget om
  befolkning og boliger.
- Tallfeste behovet for omsorgsplasser og tilrettelagte boliger fram mot
  2040.

### Hole (3310)
**Status.** Samfunnsdelen er fra 2018.
- Den legger til grunn «inntil 2 %» vekst, med ca. 8 700 innbyggere i 2030,
  og sier at framskrivingen er spesielt usikker på grunn av FRE16.
- Den nevner at antallet over 80 år dobles, men viser til andre
  strategiplaner, og har få konkrete grep.
- Planstrategien for 2024–2027 er omtalt på nettsiden, men ble ikke funnet
  som dokument.

**Styrke:**
- Revidere samfunnsdelen, som er blant de eldste i fylket, og skille mellom
  vekstmål og planleggingsprognose.
- Lage scenarier for FRE16, med og uten boligutbygging på Sundvollen, i
  stedet for ett vekstanslag.
- Tallfeste omsorgsbehovet når 80+ dobles, og legge inn tilgjengelige boliger
  i kommunedelplanene for Vik og Sundvollen.

### Lier (3312)
**Status.** Lier er sammen med Drammen den mest modne kommunen.
- KOMPAS brukes med et boligbyggeprogram, der den realiserbare reserven er
  3 394 boenheter fram til 2040.
- Kommunens egen prognose gir 37 000 innbyggere i 2040, mot SSBs 32 000.
  Prognosen driver også skolekapasiteten per krets.
- Boligpreferansene viser at et flertall over 60 år ønsker sentrumsnær
  leilighet. Kommunen bruker dette til å argumentere for at eneboliger
  frigjøres til barnefamilier.
- Temaplanen for helse, omsorg og velferd tallfester behovet for 87 nye
  sykehjemsplasser innen 2034 (Agenda Kaupang).

**Styrke:**
- Etterprøve den egne prognosen mot faktisk utvikling. Den ligger 5 000 over
  SSB, og Drammen har erfart at slike prognoser treffer for høyt.
- Tallfeste frigjøringseffekten, altså hvor mange eneboliger eldre faktisk
  forlater, i stedet for å anta den.
- Følge opp samfunnsdelen 2040 med få og målbare indikatorer.
  Planstrategien peker selv på at mål og økonomiplan er for løst koblet.

### Øvre Eiker (3314)
**Status.**
- Kommunen konstaterer at SSBs middelalternativ har truffet godt og
  jobber med prognoser for boligprogram og dimensjonering av tjenester.
- Den har konkrete boligprosjekter (Liesaga ca. 170 leiligheter, Hokksund
  Vest, Darbu og Fiskum), en strategi for helse- og velferdstjenester for
  2025–2035 og et mål om minst 1,4 % årlig befolkningsvekst.

**Styrke:**
- Sammenligne vekstmålet på 1,4 % med SSB-banen og vise konsekvensen for
  tjenestene hvis målet ikke nås.
- Tallfeste kapasitetsbehovet for institusjon og bemannede boliger.
  Strategien nevner det, men uten tall.
- Knytte stedsutviklingen på hvert sted til en egen befolkningsprognose.

### Modum (3316)
**Status.** Samfunnsdelen oppgir tydelige SSB-tall:
- 15 700 innbyggere i 2041, og 95 % av veksten er over 67 år.
- 80+ øker fra 711 til ca. 1 600.
- Antall i yrkesaktiv alder per pensjonist går fra 3,5 til ca. 2.

Den sier at «en hovedutfordring vil være å legge til rette for et godt
boligtilbud og tjenester», men har ingen oppfølgingsplan og bare ett
alternativ. Planstrategien ble ikke funnet.

**Styrke:**
- Sette tall på boligbehovet for eldre, fordi nesten all vekst er 67+, og
  lage et boligprogram som prioriterer tilgjengelige boliger i Vikersund og
  Åmot/Geithus.
- Lage scenarier med lav og høy innflytting. Målet om vekst i yrkesaktive
  aldersgrupper krever at flyttevirkningen tallfestes.
- Innføre et indikatorsett etter mønster fra Krødsherad.

### Krødsherad (3318)
**Status.**
- Samfunnsdelen fra 2019 bruker Telemarksforskings scenarier og peker på
  «stor risiko for nedgang».
- Planstrategien 2024–2027 har et eget indikatorsett i vedlegg 3:
  - befolkningsendringer siden 1951 og framskriving
  - boligbyggingstakt mot forventet
  - bostedsattraktivitet, som har gått fra positiv til negativ
  - arbeidsplasser
- «Helhetlig plan for livsløp» og et mål om at eldre skal bo lenger hjemme
  nevnes.

**Styrke:**
- Oppdatere samfunnsdelen med de nye indikatorene.
- Lage en helhetlig plan for livsløp med tallfestet behov for omsorgsboliger
  og tilgjengelige leiligheter i Noresund og Krøderen.
- Koble målet om bostedsattraktivitet til et konkret boligtilbud for
  tilflyttere, som leie og etablererboliger.

### Flå (3320)
**Status.**
- Samfunnsdelen 2022–2034 beskriver folketallet historisk med en figur fra
  1950 til 2022, noe næringsvekst, ca. 2 400 hytter og boligmangel.
- Den har ingen framskriving, ingen omtale av aldring eller tjenestebehov,
  og målet er formulert som «et folketall som bidrar til å nå våre mål».
- Planstrategien ble ikke funnet.

**Styrke:**
- Lage et enkelt demografisk kunnskapsgrunnlag med SSB-framskriving,
  aldersgrupper og forsørgerbrøk. Dette er et minimum etter planstrategikravet
  i plan- og bygningsloven § 10-1.
- Tallfeste boligmangelen og lage en enkel boligplan: antall, type og
  kommunale tomter.
- Beregne tjenestebehovet for fastboende og for hyttebefolkningen, som i
  perioder er stor sammenlignet med de fastboende.

### Nesbyen (3322)
**Status.** Samfunnsdelen er fra 2018 og har et eget statistikkhefte.
- Heftet inneholder SSB middel, demensframskriving og KOSTRA.
- Kommunen har 71 omsorgsboliger med heldøgns omsorg og 13
  institusjonsplasser.
- Et av målene er å «øke andelen innbyggere 18–50 år».
- Et boligbyggeprogram og flere eldreboliger var planlagt.
- Planstrategien for 2024–2027 er skrevet i en ROBEK-situasjon og utsetter
  flere planbehov.

**Styrke:**
- Gjøre ferdig revisjonen av samfunnsdelen, som startet i 2025, med oppdatert
  framskriving og scenarier.
- Etterprøve om boligbyggeprogrammet fra 2018 ble laget, og lage et nytt som
  inkluderer eldreboliger.
- Ta demensframskrivingen inn i en plan for dimensjonering av
  omsorgsboligene, siden kommunen allerede er «boliggjort».

### Gol (3324)
**Status.**
- Planstrategien 2024–2027 viser flere SSB-alternativer:
  - hovedalternativet gir +3,8 % i 2025–2045
  - høy vekst gir +13 %
  - lav innvandring gir flatt folketall
- Gruppen 20–66 år ventes å gå ned med ca. 200 (−8 %).
- Samfunnsdelen fra 2018 regner ut demografikostnader for 80+ og har
  indikatorer.
- Målet om 5 000 innbyggere i 2030 er høyere enn SSBs hovedalternativ.
- Boligtemaet er tynt. Kommunen mener boligsosiale behov bør drøftes regionalt.

**Styrke:**
- Bruke den nye samfunnsdelen (2026–2038) til å erstatte vekstmålet med
  scenarier og et realistisk planleggingsgrunnlag.
- Lage en boligbehovsanalyse. Gol er vekstsenter og knutepunkt, med
  innpendling og press på sentrumsnære boliger.
- Ta resultatene fra tjenestekonseptutviklingen i helse og omsorg inn i
  dimensjonering av plasser.

### Hemsedal (3326)
**Status.**
- Samfunnsdelen fra 2019 har en administrativ prognose på 1 % årlig vekst,
  mens faktisk vekst har vært 0,2–1,4 % per år. Målet er 3 000 innbyggere
  innen 2030.
- Den har gode boligvirkemidler: Ungbo for unge under 35, Eldrebu og
  utredning av «hytte som mellombels bustad».
- Den omtaler press på hjemmetjenester og sykehjem, og tjenestebehov hos
  personer som ikke er fastboende.
- Planstrategien 2024–2027 nevner store demografiske endringer, men uten
  tall.

**Styrke:**
- Oppdatere samfunnsdelen med SSB-alternativer og tallfestet utvikling for
  67+ og 80+.
- Tallfeste tjenestebehovet fra deltidsbefolkningen, som Hemsedal selv peker
  på som en svakhet.
- Evaluere Ungbo og Eldrebu og skalere dem ut fra et beregnet behov.

### Ål (3328)
**Status.** Samfunnsdelen er fra 2015 og er den eldste i fylket.
- Planstrategien fra 2024 er skannet. Demografidelen er kort:
  - folketallet er stabilt, men «kunstig høyt» (over 5 000) på grunn av
    asylmottaket
  - prognosene viser nedgang
  - 80+ ventes å bli doblet innen 2050
  - det må til en omfordeling mellom tjenesteområdene
- Det positive er at Ål har kartlagt utbyggingsreservene (2024): bare 46 % av
  arealet som er avsatt til utbygging, er realisert.
- Ål har gitt tilskudd til unges første bolig.
- Planbehovet omfatter en helse- og omsorgsplan (2024–2028) og en demensplan,
  men ingen boligplan.

**Styrke:**
- Revidere samfunnsdelen i denne perioden, slik planstrategien selv
  anbefaler, med et oppdatert demografisk kunnskapsgrunnlag som ikke er
  preget av asylmottaket.
- Lage en boligplan som bruker kartleggingen av utbyggingsreserver og
  prioriterer sentrumsnære, tilgjengelige boliger. Ål mangler byggeklare
  sentrumsnære kommunale tomter.
- Koble helse- og omsorgsplanen til en tallfestet framskriving av 80+ og
  demens.

### Hol (3330)
**Status.**
- Planstrategien 2024–2027 har folketall per grend fra 2010 til 2024 og
  aldersgrupper i 2023 og 2040 (SSB MMMM og KS Fremtidsverktøy).
- Andelen 67+ gikk fra 20 % i 2020 til 22 % i 2024.
- Kommunedelplanen for helse og omsorg 2025–2037 er blant de mest konkrete i
  fylket. Den foreslår å redusere heldøgns dekningsgrad fra 35 % til 22 % av
  80+.
- Målet om «minst 5 000 innbyggere i 2030» fra 4 491 innbyggere i 2024 krever
  ca. 1,8 % årlig vekst. Samfunnsdelen fra 2018 anslo selv 4 560 i 2030.
- Hol har en egen boligstrategi, som ikke er med i nedlastingen.

**Styrke:**
- Skille vekstmålet fra planleggingsgrunnlaget, og dimensjonere tjenester og
  infrastruktur ut fra SSB-banen med et høyt scenario som følsomhetstest.
- Koble dekningsgraden på 22 % til et konkret behov for tilrettelagte boliger
  når flere skal bo hjemme lenger, per grend (Geilo mot de mindre grendene).
- Revidere samfunnsdelen fra 2018.

### Sigdal (3332)
**Status.**
- Samfunnsdelen 2022–2035 og planstrategien 2024–2027 bruker fire
  Telemarksforsking-scenarier og SSB. Alle viser nedgang.
- 67+ ventes å øke med ca. 27 % og grunnskolealder å gå ned med ca. 26 %
  fram til 2036.
- Antall i alderen 20–66 per person over 66 går fra 3,2 i 2010 og 2,3 i 2020
  til 1,1–1,4 i 2050.
- Det er få kommunale tomter, og boligbyggingen var 4,3 per 1 000 innbyggere
  mot 5,2 i landet.
- Kommunen har ca. 5 000 fritidsboliger.
- En boligsosial handlingsplan er ny i planstrategien.

**Styrke:**
- Bruke scenariene til konkrete beslutninger om skolestruktur og
  omsorgskapasitet («pukkelkostnad»), ikke bare som beskrivelse.
- Ta inn tilgjengelige boliger for eldre i Prestfoss og Nerstad i den nye
  boligsosiale handlingsplanen.
- Innføre indikatorer for boligbygging og flytting, slik Krødsherad har gjort.

### Flesberg (3334)
**Status.**
- Samfunnsdelen 2025–2040 og kunnskapsgrunnlaget på Framsikt er grundige og
  dekker blant annet:
  - husholdningstyper og eierandel (80 %)
  - demens fra 74 personer i 2025 til 129 i 2040
  - forsørgerbrøk og sysselsetting blant innvandrere
- SSB MMMM gir ca. 16 % vekst (2 866 i 2030, 3 172 i 2050), noe som er uvanlig
  for en distriktskommune. Kommunen påpeker selv usikkerheten.
- Flesberg er ROBEK-kommune og har ressurskrevende tjenester.
- Lampeland-prosjektet skal gjøre kommunen attraktiv for arbeidskraften
  som Kongsberg-industrien henter inn.

**Styrke:**
- Lage et lavt scenario. Veksten er avhengig av Kongsberg-regionen og bør
  testes mot Prognosesenterets scenarier for Kongsberg.
- Omsette boligsosial strategi og Lampeland til et boligprogram med
  boligtyper tilpasset både tilflyttere og eldre.
- Lage en egen dimensjonering av demensplasser og bemannede boliger ut fra
  demenskartet.

### Rollag (3336)
**Status.**
- Samfunnsdelen 2023–2033 og planprogrammet bruker Telemarksforskings
  attraktivitetsmodell. Utfordringen er utflytting, og fødselsunderskuddet
  gjør kommunen avhengig av innflytting.
- 35 % av innbyggerne er 60 år eller eldre, mot 24 % nasjonalt.
- 80–89 år ventes å øke kraftig etter 2025.
- Demensandelen er 3,17 %.
- 86 % av boligene er eneboliger, og målet er byggeklare tomter i begge
  tettstedene.
- Siste planstrategi som ble funnet, er fra 2020–2023.

**Styrke:**
- Vedta en ny planstrategi med oppdatert kunnskapsgrunnlag.
- Utvikle boligtyper utover eneboliger. Med 86 % eneboliger og mange eldre
  finnes nesten ingen leiligheter å flytte til. Det gjør at eldre blir boende
  i uegnede boliger og at få boliger frigjøres til tilflyttere.
- Tallfeste omsorgsbehovet for 80–89 år fram mot 2040.

### Nore og Uvdal (3338)
**Status.**
- Kommuneplangrunnlaget 2024–2027 har Telemarksforskings fire scenarier.
  Selv med positiv attraktivitet gir de 1 815–1 911 innbyggere i 2050, mot
  SSBs 2 261.
- Grunnlaget har også bostedsattraktivitet, forsørgerbyrde og en
  årsverksmodell for 2040: −5 i barnehage, −11 i skole og +30 i pleie og
  omsorg.
- Temaplanen for helse og omsorg 2025–2030 bygger på dette og viser at 67+
  øker med 34,7 % mens 66 år og yngre går ned med 28,9 %.
- På boligsiden er det opprettet en boligstrategisk gruppe. Kommunen bygger
  modulhus, disponerer 120 kommunale boliger og vil gjøre det mulig å endre
  fritidsboliger til boliger.
- Kommunen har ca. 4 100 fritidsboliger. Befolkningen varierer fra ca. 2 500
  til 20 000.

**Styrke:**
- Lage et eget boligprogram. Kommunen har bare 3 leiligheter mot 1 376
  eneboliger, og innbyggerne etterlyser egnede seniorboliger.
- Tallfeste tjenestebehovet fra hyttebefolkningen, som legevakt og
  hjemmesykepleie i høysesong.
- Følge opp scenariovalget med indikatorer, slik at kommunen ser tidlig
  hvilket scenario den er på vei inn i.

---

## 5. Hvilke kommuner mangler planverk sammenlignet med de andre?

**Klart svakest: Ål, Hole og Flå.**
- **Ål** har en samfunnsdel fra 2015. Planstrategien har en tynn demografidel
  og ingen boligplan.
- **Hole** har en samfunnsdel fra 2018 med ett vekstanslag, og planstrategien
  ble ikke funnet.
- **Flå** har en ny samfunnsdel (2022) uten demografisk analyse, prognose
  eller tjenestekonsekvenser.

Felles for de tre er at planverket ikke tallfester hva aldringen betyr for
tjenester og boliger.

**Utdatert, men med noe godt innhold: Nesbyen og Hemsedal.** Begge har
samfunnsdeler fra 2018–2019 og et gammelt tallgrunnlag. Nesbyen har startet
revisjon.

**Middels, med konkrete hull:**
- **Ringerike** har lite tallfestet demografi i forhold til størrelsen, og
  planstrategien ble ikke funnet.
- **Modum** har gode tall, men bare ett alternativ og ingen oppfølging.
- **Gol** mangler en boliganalyse.
- **Rollag** har en planstrategi fra 2020–2023.

**Mønstre på tvers av kommunene:**
1. **Mål og prognose blandes.** Hol (5 000), Gol (5 000), Hemsedal (3 000),
   Hole (8 700) og til dels Øvre Eiker (1,4 %) setter vekstmål over SSB. Når
   målet brukes som planleggingsgrunnlag, blir tjenester og infrastruktur
   feil dimensjonert. Anbefalingen er å ha ett realistisk planleggingsgrunnlag
   og ett ambisjonsscenario.
2. **Bare SSB MMMM uten usikkerhet.** Drammen skriver at SSB har overvurdert
   veksten i ti år, og i Kongsberg var veksten i 2024 90 personer lavere enn MMMM anslo.
   Bare Drammen, Lier, Kongsberg, Sigdal, Nore og Uvdal og Gol bruker flere
   alternativer.
3. **Svak kobling mellom demografi og bolig i de små kommunene.** Bare Lier
   og Drammen har et boligbyggeprogram i plandokumentene, og Kongsberg har et
   anslag på 200 boliger per år. De små kommunene har nesten bare eneboliger,
   og eldre har få steder å flytte. NIBR/NOVA har vist at tilbudet av
   aldersvennlige boliger er dårligst i distriktene.
4. **Omsorgsboliger og heldøgnsplasser tallfestes bare i Lier, Hol, Nore og
   Uvdal og Nesbyen.**
5. **Deltidsbefolkning.** Flå, Nesbyen, Gol, Hemsedal, Ål, Hol, Sigdal,
   Flesberg og Nore og Uvdal har mange fritidsboliger, men ingen tallfester
   tjenestebehovet fra fritidsbeboerne.
6. **Delområder.** Bare Drammen (kommunedeler), Lier (skolekretser), Hol
   (grender) og Ringerike (rutenett) planlegger under kommunenivå.

---

## 6. Skisse: planleggingsverktøy for bolig (arbeidstittel «Fram Bolig»)

### 6.1 Hvorfor, og hvorfor som del av Fram
De store kommunene kjøper eller lager det de trenger: KOMPAS (COWI) i Drammen
og Lier, og Prognosesenteret i Kongsberg. De små kommunene har verken
ressurser eller data til det. Nordlandsforskning og NOVA har kartlagt
kommunenes boligbehovsanalyser for Husbanken. De fant at det ikke finnes en
felles definisjon av hva en slik analyse skal inneholde, og at praksis og
kapasitet varierer mye.

Et felles verktøy med standardisert metode og ferdig data fra SSB gir alle
kommunene et minimumsgrunnlag. De som vil, kan legge inn lokale forutsetninger
som boligbyggeprogram og planreserve. Vestfold har gjort noe tilsvarende på
regionalt nivå med en regional boligbehovsanalyse (2025).

Fram har allerede mye av det som trengs:
- datainnhenting fra SSB (07459 og befolkningsframskrivingen)
- 2024-kommunestruktur
- demensandel (`legg_til_demens.R`)
- modeller for brukere av bolig og heldøgns omsorg (Y_2\*)
- usikkerhetsintervaller og Shiny-appen

Fram Bolig blir dermed en utvidelse: fra *hvor mange som trenger tjenester* til
*hvilke boliger de trenger*.

### 6.2 Moduler

```
 [1] Befolkning      SSB-framskriving (alle alternativer) + valgfritt lokalt
      |              scenario (boligdrevet eller attraktivitet)
      v
 [2] Husholdninger   husholdningsrater per alder og husholdningstype
      |              (konstant, eller trend mot mindre husholdninger)
      v
 [3] Boligbehov      husholdninger → boligtype og størrelse
      |              (dagens mønster, eller preferansescenario)
      |<------------ [4] Omsorg: Fram Y_2* + demens → heldøgnsplasser,
      |                  omsorgsboliger, tilgjengelige boliger 75+/80+
      v
 [5] Tilbud          boligmasse, boligbygging, planreserve etter status,
      |              kommunale utleieboliger, fritidsboliger
      v
 [6] Gap og flyttekjeder
                     behov − (bestand + avgang + frigjøring fra eldre)
                     → årlig byggebehov per type, sammenlignet med reserve
      v
 [7] Rapport         per kommune (valgfritt delområde) 2025–2050,
                     scenarier og usikkerhetsbånd, eksport til planstrategi
```

**1. Befolkning.**
- Grunnlaget er SSBs framskriving i alle alternativene, ikke bare MMMM. De
  andre viser innvandrings- og flyttefølsomheten, slik Gol og Kongsberg
  bruker dem.
- Valgfritt kan kommunen legge inn et lokalt scenario.
  - For vekstkommuner er det et *boligdrevet* scenario: kommunens
    boligbyggeprogram gir tilflytting etter alder og boligtype. Metoden er
    kjent fra KOMPAS og Prognosesenterets flyttestrømsanalyse.
  - For distriktskommuner er det et *attraktivitetsscenario* etter
    Telemarksforskings modell, med strukturelle flyttebetingelser pluss
    bostedsattraktivitet. Sigdal, Krødsherad, Rollag og Nore og Uvdal bruker
    allerede denne tankegangen.

**2. Husholdninger.**
- Metoden er standardmetoden med husholdningsrater («headship rates»):
  andelen personer i hver aldersgruppe som står som hovedperson i en
  husholdning av en gitt type. Dette er også grunnlaget i Prognosesenterets
  boligbehovsberegning.
- Kilde er SSBs registerbaserte statistikk for husholdninger og boforhold.
  Drammenstrender viser til tabellene 09747 og 06070.
- Scenarier:
  - (a) konstante rater
  - (b) videreført trend mot flere aleneboende. 40 % av husholdningene i
    Drammen er aleneboende, og mange kommuner har mange aleneboende over 45
    år.

**3. Boligbehov etter type og størrelse.**
- En matrise gir sannsynligheten for å bo i enebolig, småhus eller leilighet,
  og i 1–2, 3–4 eller 5+ rom, per alder og husholdningstype. Den hentes fra
  registerbasert boforholdsstatistikk.
- Scenario A holder dagens mønster fast.
- Scenario B justerer mot uttrykte preferanser, som Liers scenario B:
  - Buskerudbyens boligpreferanseundersøkelse (2021) viser at 60–70 % av
    seniorer og «tomt rede» ønsker leilighet.
  - NIBR/NOVAs undersøkelse av 60–75-åringer (2019) viser at eldre i distrikt
    flytter mindre fordi tilbudet mangler.

**4. Omsorg og alderstilpassede boliger (koblingen til Fram).**
- Frams framskrivning av brukere av bolig og heldøgns omsorg (Y_2\*) og
  demensandelen gir behovet for heldøgnsplasser og omsorgsboliger.
- Brukeren velger dekningsgrad, for eksempel Hols 35 % mot 22 % av 80+.
- Et «Bo trygt hjemme»-tillegg beregner behovet for tilgjengelige vanlige
  boliger for 75+ og 80+ som bor alene, i tråd med Meld. St. 24 (2022–2023)
  *Fellesskap og meistring. Bu trygt heime*.
- Dette gir det flere kommuner mangler: en tallfestet sammenheng mellom
  omsorgspolitikk (dekningsgrad) og boligbehov.

**5. Tilbud.**
- Boligmasse etter bygningstype og rom, samt fullførte boliger per år, fra
  SSBs boligstatistikk og matrikkelen.
- Kommunale utleieboliger fra KOSTRA.
- Fritidsboliger (SSB 05467, som Ål viser til).
- Kommunen kan legge inn planreserve etter status, etter Drammens inndeling:
  - uregulert
  - pågående regulering
  - byggeklar
  - regulert med rekkefølgekrav
- Ål har gjort en tilsvarende kartlegging av utbyggingsreserver.

**6. Gap og flyttekjeder.**
- Årlig byggebehov per type er behovet minus bestanden, justert for avgang og
  for boliger som frigjøres når eldre flytter eller dør.
- Frigjøringen beregnes fra registerdata: antall 75+ som bor alene i
  enebolig, sannsynligheten for at de flytter eller dør, og hvor de flytter.
  Dette gjør Liers og Drammens antakelse om flyttekjeder etterprøvbar.
- Resultatet sammenlignes med planreserven. Det viser om kommunen har nok,
  og nok av riktig type, byggeklare arealer.

**7. Rapport og etterprøving.**
- Rapporten viser per kommune, og valgfritt per delområde, 2025–2050 med
  scenarier og usikkerhetsbånd. Samme bootstrap-prinsipp som ellers i Fram
  kan brukes.
- Den inkluderer en fast «etterprøvingsrapport» som viser hvordan tidligere
  SSB-framskrivinger har truffet for kommunen. Svakheten som Drammen
  beskriver, blir dermed synlig for alle.
- Resultatet kan eksporteres som tabell eller figur rett inn i planstrategi og
  kunnskapsgrunnlag.
- For hyttekommuner kommer et tillegg om deltidsbefolkning: fritidsboliger
  ganger en belegningsfaktor per sesong, som gir tjenestetrykk i høysesong.

### 6.3 Datagrunnlag (første versjon)

| Tema | Kilde | Merknad |
|---|---|---|
| Befolkning, historisk | SSB 07459 | Allerede i Fram |
| Befolkningsframskriving | SSB (alle alternativer, tabellen Fram bruker og 13600) | Utvid fra MMMM til alle alternativer |
| Husholdninger | SSB registerbasert husholdnings- og boforholdsstatistikk (bl.a. 09747, 06070) | Tabellnummer og variabler må verifiseres |
| Boligmasse og boligbygging | SSBs boligstatistikk (bygningstype, rom, fullførte) | Verifiseres. Delområdedata via grunnkrets |
| Brukere av omsorg | Fram Y_2\* (SSB 11645, 12292 m.fl.) | Allerede i Fram |
| Demens | Fram (`legg_til_demens.R`) og Demenskartet | Allerede i Fram |
| Fritidsboliger | SSB 05467 | |
| Boligpreferanser | Buskerudbyen 2021 (Opinion), NIBR/NOVA 2019 | Brukes som scenarioparametere |
| Planreserve og boligbyggeprogram | Kommunen (skjema) | Valgfritt. Standardmal etter Drammens statusinndeling |

### 6.4 Leveranser i trinn
1. **Første versjon (kommunenivå, bare SSB-data):** demografisk boligbehov etter
   type fra modulene 1–3 i alle SSB-alternativene, og omsorgsbehov fra modul
   4 koblet til Y_2\*. Én ny fane i Fram. Dette alene løfter Ål, Hole, Flå,
   Hemsedal og Nesbyen til et grunnlag på nivå med de mellomstore kommunene.
2. **Tilbud og gap:** boligmasse, boligbygging, frigjøringsmodell og et
   planreserveskjema kommunene fyller ut.
3. **Scenarier og delområder:** boligdrevet scenario og attraktivitetsscenario,
   grunnkrets- og tettstedsnivå, og tillegg for deltidsbefolkning.
4. **Etterprøving og oppfølging:** årlig oppdatering med indikatorer
   (boligbyggingstakt mot behov, andel tilgjengelige boliger, netto flytting
   etter alder), etter mønster fra Krødsherads indikatorsett.

### 6.5 Faglige risikoer
- **Toveis årsakssammenheng mellom boligbygging og befolkning.**
  Prognosesenteret påpeker at bygging både følger og skaper etterspørsel. Det
  boligdrevne scenarioet må derfor presenteres som et scenario, ikke som en
  prognose.
- **Husholdningsdannelse avhenger av boligpriser og -tilbud.** Med konstante
  rater blir behovet undervurdert i pressområder og overvurdert i
  distriktene. Trendscenarioet dekker dette delvis.
- **Små tall.** For kommuner med under 2 000 innbyggere, som Flå, Rollag og
  Nore og Uvdal, blir tall per type og år usikre. Intervaller og
  regionale gjennomsnittsrater (Hallingdal og Numedal) bør brukes.
- **Preferanser er ikke etterspørsel.** Undersøkelser overdriver ofte viljen
  til å flytte. Scenario B bør derfor vises som et øvre anslag.

---

## Kilder

Plandokumentene står i `data/planverk/buskerud/manifest.csv`. Annen
litteratur og verktøy som er brukt:

- COWI: KOMPAS. Se [systembeskrivelse (Narvik kommune)](https://www.narvik.kommune.no/_f/p28/if4567213-0ade-45eb-80cf-171046e82c77/vedlegg-3-kompas-systembeskrivelse.pdf)
- Prognosesenteret: [boligbehov basert på SSBs befolkningsframskriving](https://blogg.prognosesenteret.no/oppdatert-boligbehov-basert-paa-ssbs-nye-befolkningsframskriving), og rapporten for Kongsberg (2025) i manifestet
- Nordlandsforskning og OsloMet NOVA: *Kommunale analyser av boligbehov og boligmarked*, for Husbanken. Se [Husbanken, rapporter](https://www.husbanken.no/rapporter/)
- OsloMet NIBR/NOVA: [Mobilitet blant eldre på boligmarkedet – holdninger, drivere og barrierer](https://www.oslomet.no/forskning/forskningsprosjekter/mobilitet-blant-eldre-boligmarkedet) ([rapport](https://biblioteket.husbanken.no/arkiv/dok/Komp/Mobilitet%20blant%20eldre%20pa%20boligmarkedet.pdf))
- Husbanken: [Boligbehovsanalyser i Oslo-Akershus-regionen](https://biblioteket.husbanken.no/arkiv/dok/Komp/Boligbehovsanalyser%20i%20Oslo%20Akershus%20regionen.pdf)
- Vestfold fylkeskommune: [Regional boligbehovsanalyse 2025, vedlegg om sosiale boformer (Asplan Viak)](https://www.vestfoldfylke.no/globalassets/vfk---hovednettsted/dokumenter/samfunnsutvikling/samfunn-og-plan/regionale-planer/rpba/regional-boligbehovsanalyse-2025/vedlegg-4-_handlingsrom-og-virkemidler_sosiale-boformer--asplan-viak-070325.pdf)
- Regjeringen: [Analyse av begrepet «tilstrekkelig boligbygging»](https://www.regjeringen.no/contentassets/2ae852c304d4437dabaaf9762a9e5359/analyse-av-begrepet-tilstrekkelig-boligbygging-pdf.pdf)
- SSB: [Samordnet statistikk for husholdninger og boliger](https://www.ssb.no/befolkning/samordnet-statistikk-for-husholdninger-og-boliger), [Boforhold, registerbasert](https://www.ssb.no/bygg-bolig-og-eiendom/statistikker/boforhold/aar)
- Buskerudbyen/Opinion (2021): *Boligpreferanser i Buskerudbyen*, med delrapporter for Drammen og Lier. Gjengitt i Drammenstrender 2023 og Liers kunnskapsgrunnlag
- Telemarksforsking: attraktivitetsmodellen og Regional analyse. Brukt i planene til Krødsherad, Rollag, Sigdal og Nore og Uvdal
