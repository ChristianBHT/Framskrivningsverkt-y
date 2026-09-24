# To-do: Shiny-appen (Fram)

Opprettet 2026-09-24. Oppgaveliste for videreutvikling av selve appen.
Dette er et internt arbeidsdokument og vises ikke som fane i appen. For
metodisk arbeid (modellsjekker, glatting, andre tabeller), se
[videre_arbeid.md](videre_arbeid.md).

Status: `[ ]` ikke påbegynt, `[~]` delvis, `[x]` ferdig.
Størrelse (grovt anslag): S = timer, M = dager, L = uker.

| # | Oppgave | Størrelse | Avhengigheter |
|---|---|---|---|
| 1 | Tilbudsframskrivning (sykepleiere) | L | Tilgang til data (se under) |
| 2 | Fane med nøkkeltall (KPI) | M | Bør vente på/ta hensyn til 1 for gap-KPI |
| 3 | Fane med befolkningspyramider | M | Lagre alder x kjønn fra tabell 12882 |
| 4 | Nytt stilskjema | S-M | Fargepalett fra Telemarksforskning |
| 5 | Telemarksforskning-logo | S | Logofil fra Telemarksforskning |
| 6 | Produktkontekst og abonnementsklarhet | M-L | Beslutninger om hosting og tilgang (punkt 6.1) |

Rask gevinst først: 5 og 4 er små og uavhengige. 3 og 2 er middels store.
1 er det store prosjektet og har en reell datarisiko (punkt 1.1).

---

## 1. Tilbudsframskrivning (sykepleiere)

**Bakgrunn.** SSBs rapport RAPP 2026/18 (Helsemod) framskriver tilbud som en
bestandsmodell: `bestand(t+1) = bestand(t) + tilgang − avgang`, og
konverterer til årsverk med `S(g,a) = M(g,a) · P(g,a) · E(g,a)`, der
`P` er sannsynlighet for å jobbe i HO-tjenestene (logit) og `E` forventet
årsverk gitt at man jobber der (lineær regresjon). Begge modelleres som et
**5.-gradspolynom i alder**, separat per kjønn og utdanningsgruppe.

**Problem med 5.-gradspolynom.** Høygradspolynom oscillerer og er ustabile i
endene av aldersintervallet (her 20-25 og 65-75 år, der det også er få
observasjoner og der pensjonsatferden skifter raskt), er dårlig
betinget numerisk, og gir dårlige/urealistiske verdier ved liten
utvalgsstørrelse. SSB løser det selv med en nødløsning: for grupper under
500 personer brukes bare gjennomsnitt for to brede aldersbånd (20-61 og
62-75 år). Det er et symptom på at polynomet ikke er robust.

### 1.1 Avklar data først (mulig blokker)

- [ ] SSB bruker **individdata tilrettelagt av SSB** (utdanningsregister
      koblet mot sysselsettingsregisteret). Dette er ikke offentlig
      tilgjengelig. Avklar om Telemarksforskning har tilgang (f.eks. via
      mikrodata.no eller avtale med SSB).
- [ ] Hvis ikke: kartlegg hva som finnes offentlig i SSBs statistikkbank
      (sysselsatte helsepersonell etter utdanning, alder og kjønn; antall
      med utdanning i befolkningen; avtalte årsverk). Sjekk at alder x
      kjønn x utdanning finnes, og at tidsserien er lang nok til å estimere
      tilgang og avgang. *Tabellnumre er ikke slått opp ennå.*
- [ ] Avklar nivå: SSB modellerer nasjonalt. Skal tilbudet også gis per
      kommune? Etterspørselen i appen er per kommune, så et gap per kommune
      krever en regionaliseringsregel (arbeidsmarkedsregioner? pendling?).
      Dette er et designvalg, ikke bare teknikk.
- [ ] Avgrensning: start med **sykepleiere alene** (gruppen appen allerede
      viser etterspørsel for), utvid til andre grupper senere.

### 1.2 Bedre alternativer til 5.-gradspolynom

Rangert etter hva jeg vil anbefale å prøve først:

1. **Penalisert regresjonsspline (GAM, `mgcv`)**: `s(alder, bs = "cr")` (eller
   `"ps"`) med logit-lenke for `P` og Gaussisk/Gamma-lenke for `E`. Glattheten
   velges automatisk (REML), ingen manuell gradsvelging, og stabil i endene.
   Standardvalget.
2. **Naturlig kubisk spline med få faste knuter** (f.eks. 30, 45, 60, 67 år)
   via `splines::ns()` i en vanlig `glm`. Enklere, mer gjennomsiktig og lett
   å forklare, men krever valg av knuter.
3. **Formbegrensede splines (`scam`)**: pensjonsalderen gir et fall i
   yrkesdeltaking som er monotont avtakende etter en viss alder. Kan
   pålegge dette, slik at kurven aldri stiger igjen i 65-75-årsområdet.
4. **Hierarkisk/delt estimering for små grupper**: i stedet for SSBs
   to-aldersbånd-nødløsning, estimer en felles aldersprofil med
   gruppe-spesifikke avvik (`gamm`/`lme4`). Gir "låne styrke" mellom
   utdanningsgrupper og kjønn.
5. **Kohortbasert tilnærming**: la yrkesdeltaking avhenge av fødselskohort,
   ikke bare alder, siden nyere kohorter har annen tilknytning til
   arbeidslivet (SSB antar stabile aldersprofiler; det er en sterk
   antakelse over 15 år).

- [ ] Sammenlign polynom (grad 3, 5, 7), spline (ns) og GAM med
      **kryssvalidering/back-testing**: bruk data fram til f.eks. 2015 og
      prediker 2016-2024. Velg på faktisk treffsikkerhet, ikke på teori.
- [ ] Sjekk spesielt oppførselen i 20-25 og 65-75 år (plott
      aldersprofilene, se etter oscillasjon).
- [ ] Bruk samme rammeverk for både `P(g,a)` og `E(g,a)`.

### 1.3 Bestandsmodell og scenarier

- [ ] Implementer `bestand(t+1) = bestand(t) + tilgang − avgang` med
      tilgang og avgang holdt konstante på observert nivå (referansebane som
      i RAPP), per kjønn og alder.
- [ ] **Basisår**: SSB brukte 2023 i stedet for 2024 for sykepleiere fordi
      tilgangen i 2024 så unormalt lav ut, og årsaken er ukjent. Bør
      undersøkes og begrunnes på våre egne data.
- [ ] Scenarier fra RAPP 5.3 som oppgaver: økt sannsynlighet for arbeid
      over 60 år (+10 % relativt), utsatt avgang (1 år), utdanningskapasitet
      følger befolkningsveksten, +10 % tilgang fra 2028.
- [ ] Usikkerhet: samme Bayesianske bootstrap-tilnærming som for
      etterspørselen er mulig, men bootstrap over hva? (individer,
      kohorter?). Avklares når datakilden er kjent.

### 1.4 Gap og visning i appen

- [ ] **Enhetskonsistens**: etterspørselen i appen er *avtalte årsverk*
      (SSB 11924/14534). RAPP definerer årsverk som 37,5 timer/uke og bruker
      utførte/avtalte på en bestemt måte. Sjekk at tilbud og etterspørsel er
      i samme enhet før noe differanse tas.
- [ ] Gap = etterspørsel − tilbud (positiv = mangel), som i RAPP kap. 6.
- [ ] Vis tilbud som egen linje i Y_5-plottet og gap som eget felt/figur.
- [ ] Merk tydelig at gapet ikke er en prognose for faktisk mangel (RAPP
      sier det selv).

**Ferdig når:** tilbud for sykepleiere er framskrevet med en spline-basert
aldersprofil, validert mot polynom via back-testing, og vises sammen med
etterspørsel og gap.

---

## 2. Fane med nøkkeltall (KPI)

Mål: gi en rask oppsummering for valgt kommune og variabel, uten å lese
grafen.

### 2.0 Hva kommunene ser ut til å trenge (research 2026-09-24)

Det finnes ingen nyere undersøkelse som spør kommunene direkte om KPI-ønsker.
Grunnlaget er (a) KS-rapporten *Et verktøy for helhetlig styring* (Asplan Viak
for KS-FoU, desember 2008; ligger i `resources/`), som bygger på telefonintervju
med rådmenn i 14 kommuner (1 500 til 38 000 innbyggere, mest Møre og Romsdal,
Nord-Trøndelag, Vestfold), og (b) løs nettresearch om hva kommunene i dag får
tilbudt og bruker. **Forbehold:** 2008-rapporten er 18 år gammel, gjelder et
bredt styringsverktøy (medarbeidere, økonomi, samfunn, tjenester), ikke
behovsframskriving, og intervjuene er med rådmenn. Bruk den som hypotese å
teste, ikke som fasit.

**Hva 2008-rapporten sier (og som fortsatt virker relevant):**

1. **Analyse og tolkning er større problem enn datainnhenting.** Rapportens
   hovedkonklusjon: kommunenes største utfordring er "å analysere og tolke data
   for bruk som beslutningsunderlag", og det oppleves som krevende å forstå hva
   en indikator sier og ikke sier. Anbefaler kompetanseprogram. Rådmannen i
   Steinkjer: uten forståelse blir det "god dag mann, økseskaft". Rådmannen i
   Tingvoll var skeptisk til "mirakelløsninger": utfordringen ligger i
   organisasjonskultur og lederskap, ikke i verktøyet.
2. **Indikatorplukk er vanskelig.** Rådmenn synes det er vanskelig å velge
   indikatorer; de vil ha et kvalitetssikret, begrenset utvalg av
   eksisterende data. Små og mellomstore kommuner ønsker "nøye utvalgt sett".
3. **Enkelhet og lav brukerterskel** er et gjennomgående krav: nettbasert,
   ingen ny programvare, minimal opplæring. Kommuner med Corporater og
   KvalitetsLosen opplevde høy terskel og brukte bare deler av funksjonene.
   Skodje: "en forutsetning er at verktøyet har lav brukerterskel med en enkel
   brukermeny som er selvforklarende".
4. **Lokal tilpasning og egne data.** Alle de 14 kommunene sa at verktøyet må
   kunne tilpasses, og at det må være rom for egne data, egne indikatorer,
   måltall og historikk. Lokal forankring gir eierskap.
5. **Sammenligning med sammenlignbare kommuner.** Lierne (1 500 innb.)
   fant KOSTRA-gruppen (gruppe 6) lite egnet: tre skoler pga. spredt
   bosetting gjør kostnadssammenligning med like store kommuner misvisende.
   Kommunen ønsker sammenligning med kommuner med lignende utfordringer
   (avstand, bosetting). Verdal føler seg "alene i verden" på pleie og
   omsorg og etterlyser felles indikatorer.
6. **Pleie og omsorg er området med størst behov for bedre indikatorer.**
   Lierne, Verdal og Vestnes trekker fram helse og omsorg (særlig
   institusjon, åpen omsorg, bofellesskap, rus) som svakest dekket; Lierne
   ønsker standardiserte indikatorer for sykehjem, åpen omsorg og bofellesskap.
   Eksempel: kostnad per sykehjemsplass varierte fra 350 000 til 600 000 kr
   mellom sammenlignbare kommuner, mest pga. ulik regnskapsføring.
7. **Tillit til tallene og forklaring av avvik.** Kostnadstall "hopper" pga.
   slurv i innrapportering. Leksvik: KOSTRA viser *at* kostnader avviker,
   ikke *hvorfor*; trenger fotnoter/forklaring. Verran: SSB, NAV og egne tall
   for sykefravær viser tre ulike nivåer, som blir problematisk overfor
   media og politikere.
8. **Ferskhet og hyppighet.** Data er ofte et halvt til ett år gamle
   (Steinkjer), KOSTRA-tall kommer først 15. mars og er ufullstendig da
   (Lierne, Leksvik); lokale data som sykefravær trengs oftere enn årlig.
9. **Verktøyet bør ikke bare være for rådmannen**, men også for
   enhetsledere (Leksvik, Verdal).
10. **Behov for planleggingsdata som "Befolkning".** Rapporten har
    befolkning som eget undertema: "folkemengde og framskrevet
    befolkningstall, som grunnlag for dimensjonering av tjenestetilbudet",
    og "Demografiske opplysninger må holdes opp mot alderssammensetning blant
    medarbeiderne" (turnover/rekruttering). Under Medarbeidere nevnes
    sykefravær, turnover og kompetanse.
11. **Betalingsvillighet er ikke belyst**: respondentene kunne ikke anslå
    den før konseptet var utviklet. Leksvik er "ikke interessert i å betale
    før man er trygg på at det kan imøtekomme relevante utfordringer" og
    kaller et tidligere KS-portalprosjekt en "flopp". Driftskostnad for et
    slikt system ble anslått til 30-100 000 kr/år i lisenser pluss ca. ett
    årsverk (2008-tall). Finansiering: brukerbetaling, medlemskontingent
    eller annonser.
12. **Markedet (2008):** dominert av SSB (KOSTRA/Statistikkbanken) og
    sektorportaler (Skoleporten, bedrekommune.no, Livskraftige kommuner).
    BMS-systemer (Corporater, KvalitetsLosen) er tunge og brukes av få og
    større kommuner.

**Nyere nettfunn (ikke verifisert mot kildene):**

- KS' gratisverktøy [Omsorg 2050](https://www.ks.no/fagomrader/helse-og-omsorg/eldreomsorg/bedre-planlegging-av-helse-og-omsorgstjenester/)
  (Helseøkonomisk Analyse) framskriver hjemmetjenester, heldøgn, demens og
  befolkning til 2050 for alle kommuner; kun offentlig sektor. Det er den
  nærmeste konkurrenten til Fram-fanen. KS' Fremtidsverktøyet 2040 og Norge i
  tall dekker demografi. Kommunebarometeret og Eldrebarometeret viser hvilke
  helse- og omsorgsindikatorer kommunene blir målt på (andel årsverk med
  fagutdanning 35 %, lege-/fysioterapitimer per bruker, kostnad per bruker).
- 81 % av kommunene opplevde i 2025 sykepleierrekruttering som svært eller
  ganske krevende (93 % i 2023); KS anslår 45 000 flere årsverk innen 2031.
  Helsedirektoratet skriver at mange kommuner, særlig små, mangler kapasitet
  til analyse og planlegging, og at få planer er politisk forankret.

**Konsekvenser for produktet (forslag):**

- [ ] **Kuratert, lite utvalg** nøkkeltall (6-8) i stedet for et stort
      KOSTRA-lignende bibliotek; hver KPI får en kort forklaring "hva dette
      betyr / hva det ikke betyr" og et usikkerhetsbånd der vi har det.
      Tolkning og forklaring er en del av produktet (punkt 1 og 2 over).
- [ ] **Sammenlign mot sammenlignbare kommuner**, ikke bare KOSTRA-gruppe:
      la brukeren velge egne sammenligningskommuner, og vis landet. Vurder
      også sammenligning med kommuner med lignende alders- og
      bosettingsstruktur (punkt 5).
- [ ] **Forklar avvik**: vis når et tall avviker fra sammenlignbare kommuner
      og hva som kan forklare det (f.eks. andel 80+, størrelse), og merk tall
      som er usikre eller foreløpige (punkt 7).
- [~] **Egne data:** første versjon bygget (beslutningslogg pkt. 21): kommunen
      kan legge inn egen 2025-verdi for Y_1, Y_2* og Y_5, som blir nytt anker.
      Gjenstår: 2026-tall (egen "gjelder år"-velger), flere egne måltall/år som
      overlegg, og lagring mellom økter (krever innlogging eller lokal lagring).
- [ ] **Lav terskel**: nettbasert, selvforklarende, ingen opplæring.
      Startsiden og faner bør fungere for både rådmann og enhetsleder (punkt
      3 og 9).
- [ ] **Tydelig fokus på pleie og omsorg** (punkt 6) og bemanning (punkt
      10 og nettfunnene); dette er også der vi har unik framskriving.
- [ ] **Differensier mot KS Omsorg 2050:** usikkerhet, kommunens egen trend,
      sykepleier-/bemanningsside, stordriftsanalyse, tolkning. Avklar hva KS'
      lisensvilkår ("ikke kommersiell bruk") betyr for oss.
- [ ] **Test hypotesene med 3-5 kommuner** (intervju/demo) før KPI-fanen
      bygges ferdig, inkludert betalingsvillighet og hvilken rolle
      (rådmann, helse-/omsorgssjef, økonomisjef, enhetsleder) som er kunden.
- [ ] **Vurder kompetansetilbud** (kurs, veiledning, mal for lokal
      analyse) som del av abonnementet (punkt 1; jf. 2008-rapportens
      anbefaling om kompetanseprogram).

**Forslag til nøkkeltall** (vises som `bslib::value_box`):

- [ ] Nivå i 2025 (siste observerte) og framskrevet 2035 og 2050.
- [ ] Endring 2025 → 2050 i antall og i prosent.
- [ ] Gjennomsnittlig årlig vekst.
- [ ] Bruk **per 1 000 innbyggere** (og per 1 000 innbyggere 80+) nå og i
      2050. Viser om veksten er større enn det folketallet alene tilsier.
- [ ] Andel innbyggere 80+ i 2025 og 2050.
- [ ] Sammenligning mot landet: kommunens vekst i prosent mot
      gjennomsnittet for alle kommuner, og kommunens rang.
- [ ] Usikkerhet: bredde på 95 %-intervallet i 2050 (relativt til
      punktestimatet).
- [ ] (Etter oppgave 1) Tilbud og gap i utvalgte år for sykepleiere.

**Beslutninger som må tas:**

- [ ] Skal nøkkeltallene følge "kommunens egen trend"-bryteren? Da må
      usikkerheten utelates (den finnes ikke for T > 0).
- [ ] **Nasjonale summer og intervall**: sum av kommunenes framskrivninger
      kan regnes ut direkte, men 95 %-intervallet for summen kan ikke
      settes sammen fra kommunenes intervaller. Bootstrap-trekkene lagres
      ikke (bevisst, se beslutningslogg pkt. 8), så nasjonalt intervall
      krever at `usikkerhet_*.R` utvides til å aggregere *inne i* hver
      iterasjon.
- [ ] Tallformat på norsk (mellomrom som tusenskille, komma som desimal).
- [ ] Beregn nøkkeltallene i `global`-delen ved oppstart, ikke reaktivt.

**Ferdig når:** fanen viser 6-8 nøkkeltall som oppdateres med valgt kommune og
variabel, og der alle tall kan kontrolleres mot tabellfanen.

---

## 3. Fane med befolkningspyramider fram i tid

*Status 2026-09-24: første versjon er bygget (beslutningslogg pkt. 20):
forhåndsberegnet fil, kommunevalg, fire historiske pyramider (2010, 2015,
2020, 2025), framskrevet pyramide med årsvelger (2026-2050), omriss av 2025,
%-visning og nøkkeltall over pyramiden. Gjenstår: scenarier (LLML/HHMH),
landet som sammenligningsomriss, og fremheving av demensrelevante aldre.*

**Data.** `framskriv_*.R` henter allerede ettårig alder x kjønn per kommune
for 2026-2050 fra SSB-tabell 12882 (hovedalternativ MMMM), men lagrer bare
totalen og demensandelen. Historikk finnes i `befolkning_detaljert.rds`
(tabell 07459).

- [ ] Lagre alder x kjønn per kommune og år i en egen, kompakt fil. Slå
      sammen til **5-årsgrupper** (ca. 20 grupper x 2 kjønn x 25 år x 356
      kommuner ≈ 360 000 rader) i stedet for ettårig alder (ca. 1,9 mill.
      rader), slik at filen blir noen få MB.
- [ ] Legg filen til i opplastingslisten i `skript/deploy_shinyapps.R`.
- [ ] Ta med observerte år (2007-2025) fra 07459 slik at pyramiden kan
      vises fra historikk og fram til 2050.

**Visning:**

- [ ] Klassisk pyramide (menn til venstre, kvinner til høyre, aldersgrupper
      på loddrett akse) for valgt kommune.
- [ ] **År-glidebryter** (2007-2050) og gjerne animasjon (Plotly `frame`).
- [ ] **Overlegg**: omriss av et referanseår (f.eks. 2025) bak
      pyramiden for valgt år, slik at man ser forskyvningen mot eldre.
- [ ] Vis nøkkeltall ved siden av: andel 80+ og forsørgerbrøk for valgt år.
- [ ] Vurder å fremheve aldersgruppene som driver etterspørselen
      (80+/demensrelevante aldre).
- [ ] Vurder en "landet"-pyramide og en indeksert variant (prosent av
      folketall), siden små kommuner ellers er uleselige ved siden av store.

**Beslutninger:**

- [ ] Klassifisering av alder ved sammenslåtte kommuner: tabell 07459 bruker
      `agg_KommSummer` (allerede 2024-struktur), mens 12882 trenger
      historikk-kodene. Dette er allerede løst i `framskriv_*.R` og gjenbrukes.
- [ ] Skal pyramidene også vise LLML/HHMH når disse er beregnet? Bør
      planlegges inn nå (scenariovelger).

**Ferdig når:** valgt kommune viser pyramide for et valgfritt år 2007-2050
med referanse-overlegg, og tallene stemmer mot SSB for et par kontrollkommuner.

---

## 4. Nytt stilskjema

Nåværende: `bslib` med Bootswatch-temaet **flatly**, og fargene
`#0072B2` (observert), `#D55E00` (framskrevet), `#009E73` (alternativ)
hardkodet flere steder i `app.R`.

*Status 2026-09-24: palett avledet fra logoen (petrol `#004C66` + oransje
`#D17E12`) er innført, se beslutningslogg pkt. 19. Fargene er hentet fra
logofilen, ikke fra en profilhåndbok; sjekk mot Telemarksforsknings
grafiske profil hvis den finnes.*

- [ ] **Sammenlign med Telemarksforsknings grafiske profil**
      (profilhåndbok/hex-koder) hvis den finnes, og juster `PALETT`.
- [x] Definer palett som **én konstant** øverst i `app.R` (`PALETT`) og bruk
      den i alle plott, tema og CSS.
- [x] `bs_theme()` med egne `primary`/`secondary`/`bg`/`fg` og lenkefarger
      (beholder flatly som utgangspunkt). Egen font (`font_google()`;
      krever internett ved første last) er ikke valgt.
- [x] **Kontrast/tilgjengelighet**: WCAG AA sjekket for tekst; plottfarger
      testet under simulert fargesvakhet. Linjetype er også forskjellig
      (heltrukken/stiplet/prikket).
- [ ] Ryddig layout: vurder `page_navbar` med logo (punkt 5) og
      sidepanel bare der det trengs (sidepanelet er irrelevant på
      dokumentasjons- og analysefanene).
- [ ] Plotly: felles tema for tittel, akser og legend.
- [x] Oppdater CSS for dokumentfanene (`.dokument`) slik at det passer det
      nye temaet.
- [ ] Sjekk mobil/smal skjerm (tabs brytes allerede over flere linjer).
- [ ] Vurder mørk modus (`input_dark_mode()`), kun hvis palett og plott
      støtter det.

**Ferdig når:** all farge og typografi styres fra tema + én paletkonstant, og
appen ser lik ut på tvers av faner.

---

## 5. Telemarksforskning-logo

- [x] **Få logofilen fra Telemarksforskning** (helst SVG, evt. PNG i høy
      oppløsning; lys og mørk variant hvis mørk modus brukes). Jeg har ikke
      logoen og bør ikke lage eller gjenskape den. Avklar bruksvilkår.
- [x] Legg filen i `resources/` (i stedet for `www/`) (Shiny serverer statiske filer derfra; mappen
      finnes ikke ennå).
- [x] Vis logoen i tittellinjen, f.eks. `title = tagList(tags$img(src =
      "logo.svg", height = "32px", alt = "Telemarksforskning"), "Fram")`.
- [x] **Alt-tekst** og passende størrelse på smal skjerm.
- [ ] Favicon (`tags$head(tags$link(rel = "icon", ...))`).
- [ ] Vurder bunntekst med lenke til Telemarksforskning og kontaktinfo/
      ansvarlig.
- [x] Legg logofilen til i `appFiles` i `skript/deploy_shinyapps.R`
      (ellers mangler de i den publiserte appen; `.rscignore` støtter ikke
      wildcards).
- [ ] Oppdater tittel i `app.R` hvis navnet endres ("Framskrivningsmodellen
      Fram - Resultater").

**Ferdig når:** logoen vises lokalt og i den publiserte appen, med alt-tekst.

---

## 6. Produktkontekst og abonnementsklarhet

**Kontekst (2026-09-24).** Appen er tenkt som et **produkt fra
Telemarksforskning til kommuner, med abonnementsmodell**, og skal utvikles
til en verktøykasse med mange nøkkeltall, verktøy og modeller som
kommunene kan bruke som ressurs. Den er altså ikke bare en
forskningsdemo. Prosjektet *planverk Buskerud* (tilbud til Buskerud
fylkeskommune om analyse av kommunale planer og konsekvenser av
demografisk endring, med fokus utenfor helsesektoren) er et **eget
prosjekt**, men erfaringer derfra kan på sikt utvides til hele landet og
gi innhold til verktøykassen. Filene der (`data/planverk/` m.m.) skal ikke
blandes med appen.

Mye av det som var greit for en åpen beta må vurderes på nytt. Under er
det som må avklares eller gjøres. Punktene er ikke prioritert av meg;
rekkefølge og pris/forretningsmodell er dine beslutninger.

### 6.1 Hosting og tilgangsstyring (avklares først)

Beslutningen 2026-09-21 var å holde appen **offentlig uten innlogging**
(beslutningslogg pkt. 14). Det holder ikke for et abonnement.

- [ ] Velg hosting. Gratisnivået på shinyapps.io har ingen innlogging
      (så vidt jeg vet finnes autentisering bare på betalte planer; må
      bekreftes), 25 aktive timer per måned og tar appen ned ved
      inaktivitet. Alternativer å vurdere: betalt shinyapps.io-plan,
      Posit Connect, egen server (Shiny Server/ShinyProxy) eller intern
      drift hos Telemarksforskning. Vurder pris, drift, oppetid og hvem som
      har ansvaret.
- [ ] Velg innloggingsløsning: plattformens egen autentisering, en
      innloggingsmodul i appen (f.eks. `shinymanager`), eller innlogging
      utenfor appen (f.eks. bak Telemarksforsknings egen portal).
- [ ] Avklar tilgangsmodell: én konto per kommune? Flere brukere per
      kommune? Skal en kommune bare se sine egne tall, eller alle
      kommuner (sammenligning)? Skal det finnes en admin-rolle?
- [ ] Avklar oppdateringsflyt: hvordan nye versjoner rulles ut uten
      nedetid, og hvem som kan publisere.
- [ ] Serveren for beta tas ned om noen dager: avklar hvor appen ligger
      etterpå, også for demonstrasjoner til potensielle kunder.

### 6.2 Innhold og profil for kunder

- [ ] `VIS_FULL_DOKUMENTASJON <- FALSE` i kundeversjonen (metodikk kun
      overfladisk forklart), og fjern `dokumentasjon/*.md` fra
      `skript/deploy_shinyapps.R`. Egen, kundevendt brukerveiledning kan
      erstatte dem.
- [ ] Fjern eller rett den **alternative Y_5-modellen** (ikke gyldig
      estimert, beslutningslogg pkt. 11) før noen betaler for tjenesten.
- [ ] Ta bort eller skjul fanen "Analyse stordriftsfordeler" hvis den ikke
      skal være en del av produktet, eller bygg den om til en kundevendt
      analyse (i dag viser den kvantiler som er lette å misforstå).
- [ ] Fjern "Beta-versjon"-formuleringer og "Under utvikling"-kort, eller
      behold dem bevisst som veikart for kundene.
- [ ] Kundevendte vilkår: ansvarsfraskrivelse (framskrivningene er
      beregnede behov gitt observerte standarder, ikke en prognose for
      faktisk bruk; usikkerhetsintervallene fanger bare estimeringsusikkerhet),
      kontaktinformasjon og hvordan man melder feil.
- [ ] Produktnavn: velg navn ("Kommuneframsyn" er en arbeidstittel) og
      sjekk varemerke og domene. Kommunekompasset er tatt (KS).
- [ ] Profil: palett og logo fra Telemarksforskning (se punkt 4 og 5).

### 6.3 Data, lisens og oppdatering

- [x] Sjekk SSBs lisens- og bruksvilkår for **kommersiell** bruk av
      statistikkbank-data, og krav til kildehenvisning. Legg inn riktig
      kildehenvisning i appen. *Gjort 2026-09-24: CC BY 4.0, kommersiell
      bruk er tillatt, kreditering (SSB + lisenslenke + opplysning om
      bearbeiding) er lagt inn i bunntekst og Om-fane, se beslutningslogg
      pkt. 18.*
- [ ] Avklar kreditering/vilkår for **demensprevalensratene**
      (`dementia_dic`, ikke fra SSB) og lisens for appen/koden selv.
- [ ] Avklar rettighetene til Telemarksforskning egne
      befolkningsframskrivninger hvis de skal inn (planlagt), og om de kan
      inngå i et abonnement.
- [ ] **Årlig oppdatering**: lag en dokumentert og helst automatisert
      rutine for å hente nye SSB-data, estimere modellene på nytt, kjøre
      framskrivning og usikkerhet og publisere. I dag er dette en manuell
      kjede av script (se README) der en kjøring av bootstrap tar timer.
- [ ] Versjonering: hvilken datadato og modellversjon en kunde ser, og
      mulighet til å reprodusere en gammel utgave.
- [ ] Datakvalitet før salg: gjennomgang av feilregistreringer i
      grunnlaget (er allerede et veikartpunkt i "Om"-fanen), særlig store
      hopp i enkelte kommuner.

### 6.4 Kvalitet, drift og personvern

- [ ] **Testing**: appen har ingen automatiserte tester. For et produkt
      bør beregninger (framskriving, ankring, nøkkeltall) ha enhetstester og
      en enkel røyktest av hele appen.
- [ ] Overvåking: oppetid og feil i drift, og logging (uten å lagre mer
      enn nødvendig).
- [ ] Personvern: appen samler i dag ingen personopplysninger. Med innlogging
      kommer brukerdata; avklar behov for personvernerklæring og
      databehandleravtale.
- [ ] Ytelse og kapasitet: appen laster alle datafiler ved oppstart (ca.
      6 MB i dag). Med mange verktøy og flere samtidige kommuner må
      minne, oppstartstid og samtidighet vurderes mot valgt hosting.
- [ ] Kodestruktur: `app.R` er én stor fil. Med mange verktøy bør den deles
      opp (Shiny-moduler, én fil per verktøy, felles datalasting).

### 6.5 Utvidelse av verktøykassen

- [ ] Beslutt hvilke verktøy som kommer først (se punkt 1-3). Hvert nytt
      verktøy legges til med `verktoy_kort()` på startsiden, og som egen
      fane.
- [ ] Vurder verktøy utenfor helse og omsorg (f.eks. skole, barnehage,
      bolig og arbeidskraft) basert på demografisk endring. Erfaringene fra
      planverk-Buskerud er et mulig utgangspunkt; vurder da også en
      landsdekkende utvidelse. Krever egne data og egne modeller for hver
      sektor, ikke bare flere kort.
- [ ] Avklar hva som er grunnleggende (alle abonnenter) og hva som er
      tilleggstjenester.

### 6.6 Åpne spørsmål (dine beslutninger)

- Prismodell og abonnementsnivåer, og hvem som er kunden i kommunen.
- Pilotkunder og hvordan tilbakemeldinger samles inn.
- Hvem hos Telemarksforskning eier drift, support og årlig oppdatering.
- Skal kunden bare se egen kommune, eller kunne sammenligne med andre?

**Ferdig når:** hosting, tilgangsstyring, lisens og driftsrutine er avklart og
beskrevet, og kundeversjonen ikke inneholder beta-innhold eller kjente feil.

---

## Tverrgående

- [ ] **Publisering**: nye filer (`www/`, pyramidedata, tilbudsdata) må
      legges i `skript/deploy_shinyapps.R`. Serveren tas ned om noen dager,
      så avklar hvor appen skal ligge etterpå.
- [x] **Åpne feil før en endelig versjon**: den ugyldig estimerte alternative
      Y_5-modellen (Poisson) er fjernet fra appen (beslutningslogg pkt. 21).
- [ ] **Endelig app**: bryteren `VIS_FULL_DOKUMENTASJON` skal settes til
      `FALSE` (metodikk kun overfladisk forklart, beslutningslogg pkt. 14).
      Nye faner (KPI, pyramider, tilbud) bør ikke avsløre mer metodikk enn
      "Om"-fanen gjør.
- [ ] Oppdater "Om"-fanen når tilbud, KPI og pyramider er på plass
      ("Planlagt videre arbeid" viser i dag tilbud som punkt 4).
- [ ] Hold beslutningslogg og teknisk dokumentasjon i takt med endringene.

## Foreslått rekkefølge

0. **Hosting og tilgang (6.1)**: beslutningen påvirker deploy-skriptet,
   innlogging og kostnader, og bør tas før mye annet bygges ovenpå.
1. **Logo (5)** og **stilskjema (4)**: raskt, og gjør resten enklere å
   presentere. Blokkeres bare av at Telemarksforskning leverer logo og
   palett.
2. **Befolkningspyramider (3)**: dataene hentes allerede; lite risiko.
3. **KPI (2)**: bygger på eksisterende tall. Avklar nasjonal usikkerhet.
4. **Tilbud (1)**: start med datatilgang (1.1). Alt annet i 1 avhenger av
   utfallet.
