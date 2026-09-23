# Videre arbeid - Telemarksforsknings Framskrivningsverktøy (Fram)

Arbeidsdokument for neste faser, opprettet 2026-09-21. Beskriver HVA som
skal sjekkes/gjøres og hvorfor, ikke ferdige resultater. For bakgrunn og
allerede tatt beslutninger, se [beslutningslogg.md](beslutningslogg.md); for
modellformler, se [teknisk_dokumentasjon.md](teknisk_dokumentasjon.md).

Status-merking: `[ ]` ikke påbegynt, `[~]` delvis gjort, `[x]` ferdig.

---

## 1. Andre variabler / tabeller å sjekke

Tittel og dimensjoner er hentet direkte fra SSBs API (metadata for hver
tabell). Sjekkpunktene under er forslag, ikke gjennomført.

| Tabell | Offisiell tittel | Enhet | Nivå / periode | Viktigste dimensjoner |
|---|---|---|---|---|
| **11643** | Timar til omsorgstenester i løpet av året | Timer per år (`Timeforbruk`) | Kommune, 2009-2025 | Alder (7), TenesteType (12, bl.a. `15` = Helsetenester i heimen, `01` = praktisk hjelp: daglege gjeremål, `00` = alle tenester) |
| **09933** | Timar i veka til praktisk bistand og helsetenester i heimen (etter alder og **bistandsbehov**) | Gj.snitt timer per uke (`TimariVeka`) | Kommune (167 regioner), 2007-2025 | Alder (8), Bistandsbehov (5: noko/avgrensa, middels til stort, omfattande, i alt, uoppgitt) |
| **06975** | Timar i veka til praktisk bistand og helsetenester i heimen (etter alder og **husstand**) | Gj.snitt timer per uke (`GjTimeUka`) | Kommune (167 regioner), 2007-2025 | Alder (7), Husstand (4: bur åleine, bur saman med andre, i alt, uoppgitt) |
| **12657** | Gjennomsnittlig antall tildelte timer i uken til helsetjenester i hjemmet og praktisk bistand i henhold til vedtak (etter **tilgang på privat hjelp**) | Tildelte timer per uke | **Kun Landet** (ingen kommuner), 2015-2025 | Tilgang på privat hjelp (8 kategorier, fra "mottar ikke hjelp" til "15 timer/uke og mer") |
| **11644** | Døgn til omsorgstenester i løpet av året | **Døgn** per år (`ForbrukDogn`) | Kommune (987 regioner), 2009-2025 | Alder (7), TenesteType (12, bl.a. `21` = Langtidsopphald i institusjon, `18`-`20` = tidsavgrensa opphald, `25` = kommunal øyeblikkeleg hjelp - døgnopphald) |

### Kobling til dagens variabler

- **Y_4 (gj.snitt tildelte timer/uke)**: 09933 og 06975 er nærmeste
  kandidater til å utdype/erstatte Y_4, med oppdeling på bistandsbehov og
  husstand. **Pass på forskjell i begrep**: Y_4 er *tildelte* timer (vedtak,
  tabell 04686/12292), mens 09933/06975 heter "timar i veka" uten
  "tildelte" - sjekk i tabellens fotnoter om dette er tildelt eller
  faktisk levert tid. 12657 er eksplisitt *tildelte* timer, men kun
  nasjonalt.
- **Timer per år (11643) vs. timer per uke × brukere**: 11643 er
  totalvolum. Bør kunne relateres til Y_1 (brukere) × Y_4 (timer/uke) × 52 -
  en konsistenssjekk mellom tabellene, og et mulig nytt utfall
  (totalt timeforbruk) som er nærmere det som faktisk trengs for
  arbeidskraftbehov.
- **Y_3 / Y_2\* (institusjon/bolig)**: 11644 gir *døgn*, ikke personer. Sjekk
  mot Y_3_a (beboere i institusjon, langtidsopphold) for TenesteType `21`.
  Døgn per beboer ≈ liggetid/belegg og kan avsløre kapasitetsendringer
  som antall beboere alene ikke fanger.

### Sjekkliste per tabell

- [~] **11643**: lastet ned (2009-2025, TenesteType `15`, alle aldre) og
  plottet for de 10 største kommunene - se `skript/hent_timer_11643.R` og
  `data/ssb/plott_timer_11643_topp10.png`. Åpne punkter:
  - [ ] Forklare store hopp: Bergen ~1,29 mill. timer (2020) → ~0,77 mill.
        (2024); Trondheim ~0,19 mill. (2010) → ~0,29 mill. (2012);
        Stavanger 2009 ser lav ut (Finnøy = 0 i 2009). Reell endring eller
        definisjons-/rapporteringsendring?
  - [ ] SSB fyller koder som ikke eksisterer et gitt år med **0** (ikke
        NA). Avklar om 0 noen ganger også betyr "ikke rapportert", og lag
        egen regel for det.
  - [ ] Sammenlign med Y_1 × Y_4 × 52 for samme kommuner.
  - [ ] Hent også andre tenestetyper (`01` praktisk hjelp, `00` alle) og
        aldersgrupper (`80-89`, `90+`) for å se om aldersfordelingen kan
        brukes i stedet for kun total `demensandel`.
- [ ] **09933**: hent gj.snitt timer/uke per bistandsbehov. Sjekk om
      "omfattande bistandsbehov" har en klarere sammenheng med
      `demensandel` enn Y_4 totalt (mulig forklaring på Y_4 sin svake
      modellfit, se teknisk_dokumentasjon pkt. 4).
- [ ] **06975**: hent gj.snitt timer/uke per husstandstype. Hypotese: "bur
      åleine" gir høyere timer per bruker og en annen demografisk
      utvikling (flere eldre som bor alene) - relevant for
      framskrivningen, ikke bare beskrivelsen.
- [ ] **12657**: kun nasjonal. Bruk som **nasjonalt referansenivå/kontroll**
      for Y_4 (summer/veid snitt av kommunene bør ligge i nærheten), og
      vurder "tilgang på privat hjelp" som forklaring på hvorfor
      tildelte timer er lavere/høyere - ikke direkte modellérbar per
      kommune.
- [ ] **11644**: hent TenesteType `21` (langtidsopphold) og evt. `00`;
      sammenlign med Y_3_a. Vurder døgn per beboer som eget utfall.
- [ ] For alle: sjekk kommunekodeharmonisering (samme prinsipp som
      `hent_paneldata_2007_2025.R`: hent ALLE historiske koder og summer/
      veid snitt), hvilke år som faktisk har data, og eventuelle brudd
      (IPLOS-endring rundt 2010 - jf. Y_1-anomalien i beslutningslogg pkt. 1).
- [ ] Beslutte per variabel: nytt utfall i appen, kontrollvariabel, eller
      bare intern validering.

---

## 2. Alternative former for glidende overgang (anker)

### Dagens metode (for referanse)

Punktestimatet blandes med observert siste år (2025) med en vekt som
avtar lineært fra 90 % (2026) til 0 % i 2050:

```
vekt_t = 0.9 · (2050 - t) / (2050 - 2026)
y_t    = vekt_t · y_obs_2025 + (1 - vekt_t) · ŷ_t          (t = 2026..2050)
```

Ankeret er alltid det **samme fastlåste 2025-punktet**, og vekten er en
funksjon av *årstall alene*. Se teknisk_dokumentasjon pkt. 7 og
beslutningslogg pkt. 5 for hvorfor sluttåret ble flyttet fra 2036 til 2050.

### Alternativ A: rekursiv glatting mot *forrige års (glattede) verdi*

Idé: ankeret flytter seg fremover - hvert år blandes modellen med FORRIGE
års glattede verdi, ikke med 2025:

```
y_2026 = 0.9 · y_2025 + 0.1 · ŷ_2026
y_2027 = 0.8 · y_2026 + 0.2 · ŷ_2027
y_2028 = 0.7 · y_2027 + 0.3 · ŷ_2028
...
y_t    = w_t · y_(t-1) + (1 - w_t) · ŷ_t ,   w_t = 0.9 - 0.1·(t - 2026)
```

(Tolker eksempelet i notatet - "2027 = 0.8·2027 + 0.2·modell" - som at
første ledd skal være 2026-verdien, dvs. forrige års glattede verdi.)

Egenskaper å være oppmerksom på:

- **Effektiv vekt på 2025-observasjonen avtar raskere** enn i dagens
  metode, fordi den ganges opp gjennom kjeden (0.9, 0.9·0.8 = 0.72,
  0.72·0.7 = 0.50, ...) og er praktisk talt borte etter ca. 5-6 år, mens
  dagens metode fortsatt har ~45-50 % vekt i 2036.
- **Modellens vekst slipper raskere gjennom**, men med etterslep:
  y_t ligger under ŷ_t når modellen stiger, og etterslepet vokser med
  brattere vekst. Kan gi *lavere* sluttnivå enn ren modell hvis w_t ikke
  når 0 før sent.
- **Kink-faren er tilbake**: med `w_t = 0.9 - 0.1·(t-2026)` treffer vekten
  0 i 2035, og stigningstallet endres brått akkurat der (samme type
  artefakt som ble funnet i 2036 for dagens metode). Alternativer:
  geometrisk vekt `w_t = 0.9^(t-2025)` (aldri eksakt 0, jevn), eller
  la vekten treffe 0 først i 2050.
- Kan kombineres med at ankeret bare gjelder *nivå* (ikke vekst):
  blend på veksten `Δy_t = y_t - y_(t-1)` i stedet for på nivået.

### Alternativ B: bruk SSBs metode som anker

Sjekk hvordan SSB selv forankrer framskrivningene i basisåret i rapporten
["Behov for og tilgang på arbeidskraft i offentlig helse og omsorg
fremover" (RAPP 2026/18)](https://www.ssb.no/helse/helsetjenester/artikler/behov-for-og-tilgang-pa-arbeidskraft-i-offentlig-helse-og-omsorg-fremover/_/attachment/inline/e35491e6-e7b1-43f0-82f9-726b8b21574e:2475fafc0fdb77314f7751654ffea53725e30f2e/RAPP2026-18.pdf).
Dette er *ikke gjennomgått ennå* - notatet skal fylles inn etter lesing:

- [ ] Hvilket grunnår/ankernivå brukes, og er det ett år eller et
      gjennomsnitt av flere (jevner ut enkeltårsstøy)?
- [ ] Holdes bruksrater/dekningsgrader konstante per alder/kjønn fra
      basisåret (dvs. rent demografisk framskriving), eller trendjusteres
      de?
- [ ] Hvordan håndteres kommuner med få brukere (små tall)?
- [ ] Kan samme metode brukes som *alternativ* linje i appen (jf. den
      alternative Y_5-linjen), slik at ulike ankermetoder kan sammenlignes
      side om side?

### Sammenligning som bør gjøres (uavhengig av valgt alternativ)

- [ ] Plott dagens metode, alternativ A og (når tilgjengelig) B for de
      samme kommunene (f.eks. Halden, Trondheim, Oslo) og alle tre
      variabler.
- [ ] **Bakover-test (hindcast)**: bruk 2015-2019 som "framtid" og se
      hvilken glattingsmetode som gir minst feil mot faktisk observert
      2020-2025. Dette er den eneste objektive måten å velge mellom dem
      på - dagens vektfunksjon (90 % → 0 %) er et skjønnsmessig valg som
      aldri er validert.
- [ ] Sjekk følsomhet for startvekten (0.9) og sluttåret.
- [ ] Bootstrap-usikkerheten (`usikkerhet_*.R`) bruker dagens glatting
      inne i hver iterasjon - ved bytte av metode må alle tre kjøres om.

---

## 3. Sjekk av koeffisienten til log(befolkning)

### Bakgrunn

Alle modellene bruker dagens **offset**: `offset(log(folk_ialt))`, dvs.
koeffisienten på log(befolkning) er *tvunget til 1*. Det betyr at bruken
(antall brukere / årsverk) antas å være strengt **proporsjonal** med
folketallet, korrigert for `demensandel`:

```
log E[Y] = log(befolkning) + ... + β_1 · demensandel + ...        (offset, β_pop = 1)
```

Alternativet er å estimere koeffisienten fritt:

```
log E[Y] = β_pop · log(befolkning) + ... + β_1 · demensandel + ...   (β_pop estimeres)
```

- **β_pop = 1**: proporsjonalitet (offset er riktig).
- **β_pop < 1**: bruk vokser *saktere* enn folketallet (stordriftsfordeler,
  eller at små kommuner har relativt høyere dekning).
- **β_pop > 1**: bruk vokser *raskere* enn folketallet.

Dette har direkte betydning for framskrivningen: når folketallet endres
over tid, skalerer prognosen med `pop^β_pop` - så et avvik fra 1 gir
systematisk over-/undervurdering i kommuner med sterk vekst eller nedgang.

### Hva som skal gjøres

- [ ] Estimer `β_pop` fritt for Y_1, Y_2\*, Y_5 (og Y_4 der det gir mening,
      selv om Y_4 ikke bruker offset i dag), med samme tilfeldige struktur
      som dagens modeller. Rapporter estimat + 95 % KI.
- [ ] **Test H0: β_pop = 1** (Wald- eller likelihood-ratio-test mot
      offset-modellen). NB: for Y_5 (Poisson pseudo-likelihood på
      ikke-heltall) er likelihood-baserte tester *ikke* strengt gyldige -
      bruk robuste/bootstrap-baserte intervall eller kryssvalidering.
- [ ] Sammenlign **kryssvalidert treffsikkerhet** (LOYO) for offset vs. fri
      β_pop - samme metodikk som `modell_*.R`.
- [ ] Sjekk at β_pop *identifiseres*: folketall og årsdummyer er
      korrelerte (befolkningen vokser jevnt over tid), så effekten hentes
      hovedsakelig fra *forskjeller mellom kommuner*, ikke fra utvikling
      over tid. Vurder om dette er den tolkningen man vil ha.
- [ ] **Konsekvens for ankermetoden**: dagens anker-formel bruker
      `log(folk_ialt_t)` direkte. Med fri β_pop må folketalls-leddet
      også forankres: `β_pop · (log(pop_t) - log(pop_anker))`, ellers
      blandes to ulike nivåer. Formlene i framskriv_*.R, usikkerhet_*.R og
      `framskriv_trend()` i app.R må oppdateres tilsvarende.
- [ ] Sensitivitet: hvor mye endres 2050-prognosen (f.eks. Halden,
      Trondheim, Oslo) hvis β_pop settes til estimert verdi i stedet for 1?
- [ ] Vurder om alder heller bør inn som `log(folk_80+)` eller
      aldersandeler, siden det er eldre befolkning som driver bruken
      (jf. `demensandel` som allerede fanger noe av dette).

### Modellsjekker gjøres i script, IKKE i appen

**Beslutning (2026-09-21): ingen "Modellsjekker"-fane i appen.**
Modellsjekkene samles i frittstående script i `skript/` (prosjektets policy
var at metodikk ikke vises i appen, jf. beslutningslogg pkt. 6 - senere
opphevet, se pkt. 14; valget om script fremfor fane står ved lag).

- [x] **Oppsett og første kjøring**: `skript/modellsjekk_kvantil.R` -
      kvantilregresjon på `log(y/befolkning) ~ log(befolkning) +
      demensandel + år` med Bayesiansk bootstrap over kommuner (B = 100).
      Kjørt for Y_1: β_pop ≈ 1,00 ved τ = 0,1, men 0,974 / 0,949 / 0,916 /
      0,894 ved τ = 0,25 / 0,5 / 0,75 / 0,9, med intervaller som utelukker
      1 (se beslutningslogg pkt. 13).
- [x] Kjørt for Y_2\* og Y_5 (variabel gis som kommandolinjeargument).
      Resultatene vises i appen i fanen "Analyse stordriftsfordeler"
      (beslutningslogg pkt. 15).
- [ ] Undersøk om de STØRSTE kommunene har stordriftsfordeler: kvantilene i
      analysen rangerer etter bruk per innbygger, ikke størrelse. Krever
      f.eks. en helning på log(folketall) som varierer med størrelse, eller
      separate estimater for størrelsesgrupper.
- [ ] Legg til en gjennomsnittsregresjon som referanse, og sjekk om
      "Solution may be nonunique"-advarselen fra `rq` har betydning.
- [ ] Vurder kommune-faste effekter, slik at koeffisienten også kan hentes
      fra utvikling over tid innen kommune, ikke bare mellom kommuner.
- [ ] Test hypotesen mer formelt og sammenlign kryssvalidert treffsikkerhet
      for offset vs. fri β_pop (se listen over).
- [ ] Videre modellsjekker som kan samles i samme type script:
      CV-tall, andel negative helninger, intercept vs. helning, og
      Poisson vs. log-lineær for Y_5.

**Åpen feil funnet underveis**: den alternative Y_5-modellen (Poisson) i
appen er ikke gyldig estimert - de tilfeldige effektenes varianser står på
startverdier. Må rettes før den brukes til noe (beslutningslogg pkt. 11).

---

## Foreslått rekkefølge

1. **Modellsjekk av β_pop** (pkt. 3) - påvirker alle prognosene og
   ankerformelen, så bør avklares først.
2. **Bakover-test av glatting** (pkt. 2) - gir objektivt grunnlag for å
   velge anker-metode; gjøres etter at modellstrukturen er avklart.
3. **Tabellsjekk** (pkt. 1) - kan gjøres parallelt; 11643 er allerede
   lastet ned, og 09933/06975 kan potensielt forbedre Y_4.
