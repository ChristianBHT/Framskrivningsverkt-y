# Planverk for kommunene i Buskerud - demografi

Kommuneplanens samfunnsdel, planstrategi, kunnskapsgrunnlag, bolig- og
boligsosiale planer, helse-, omsorgs- og demensplaner og folkehelseoversikter for de 18 kommunene i Buskerud (3301-3338), lastet
ned og konvertert til tekst 2026-09-23, med et eget uttrekk av alt som
handler om demografi.

Generert av `skript/hent_planverk_buskerud.R` (kjøres fra prosjektroten).
Dokumentlisten og kilde-URL-ene står i `manifest.csv`.

| Fil / mappe | Innhold |
|---|---|
| `manifest.csv` | 103 dokumenter (92 PDF, 5 Framsikt, 6 nettsider): kommune, dokumenttype, status (vedtatt/høringsutkast/utkast), format, URL |
| `pdf/` | Originale PDF-er (92 stk., ca. 373 MB - ikke i git, lastes ned på nytt av scriptet) |
| `tekst/` | Full tekst per dokument som Markdown, med `<!-- side N -->`-markører |
| `demografi/` | Én fil per kommune med alle demografiavsnitt, sidehenvisning og trefford |
| `demografi_avsnitt.csv/.rds` | Samme avsnitt som ett datasett (1 382 avsnitt) |
| `dokumentstatus.csv` | Nedlastingsstatus, antall sider og antall demografiavsnitt per dokument |

Demografiuttrekket er nøkkelordbasert (befolkningsutvikling, framskriving,
aldersbæreevne, 67+/80+, fødte, flytting, innvandring o.l.) og tar heller med
for mye enn for lite. Sjekk alltid sitatet mot originalen før du bruker det.

## Kjente hull

- **Bildebasert tekst:** Drammenstrender 2023 (195 av 203 sider),
  Folkehelseoversikt Drammen 2023, Krødsherads handlingsplan for
  velferdsteknologi, halve vedlegget om demografi per skolekrets i Kongsberg,
  Åls planstrategi 2024-2027 (skannet), og deler av samfunnsdelene til Hol
  (15/36 sider) og Sigdal (10/28 sider) har tekst bare i bilder eller
  infografikk. Her mangler tekst, og de trenger OCR.
- **Gamle samfunnsdeler:** Hole, Nesbyen, Gol, Hol (2018), Hemsedal (2019) og
  Ål (2015) har samfunnsdeler med tall fra 2017-2019. Planstrategiene fra
  2024 er nyere. Gol, Nesbyen og Lier har ny samfunnsdel under arbeid, og for
  Lier er høringsutkastet (2040) tatt med.
- **Framsikt-dokumenter** (Flesberg, Rollag, Nore og Uvdal) hentes som tekst
  fra pub.framsikt.net. Tabeller og figurer kommer ikke med, og Nore og Uvdals
  planstrategi 2025-2028 består nesten bare av en tabell over planoppgaver.
- **Nettsideplaner** (Drammen: temaplan for boligutvikling, strategi for bolig-
  og omsorgsbygg, aldersvennlig samfunn, helse/sosial/omsorg, folkehelse og
  planstrategi) hentes ved å lese alle undersider under planens adresse.
- Planstrategi mangler fortsatt for Ringerike, Hole og Modum (Flå har
  høringsutgaven). Øvre Eikers vedtatte handlingsdel 2025-2028 er fjernet fra
  nettsiden (404). Kongsbergs livsfasepolitikk ligger bare i en
  dokumentviser (Elements) og er ikke hentet.
- Utvidelsen 2026-09-23 la til 54 dokumenter etter gjennomgang av hver
  kommunes planside. Den oppdaterte vurderingen (alle 103) ligger i Claude-
  dokumentet «Demografi i planverket – Buskerud»;
  `dokumentasjon/planverk_buskerud_vurdering.md` er første versjon (49).

## Hva planene sier om demografi (kort)

Oppsummert fra uttrekket. Tallene er kommunenes egne, fra planens
årstall, og ikke kontrollert mot SSB.

| Kommune | Hovedbilde i planverket |
|---|---|
| Drammen (3301) | Samfunnsdel 2021-2040: alderssammensetning 2020-2040 etter SSB MMMM (2020) og færre i arbeidsfør alder per innbygger 67+. Tjenestetilbudet må legges om etter behovet. |
| Kongsberg (3303) | Prognosesenteret (2025): kohort-komponent-modell med 8 aldersgrupper, 29 011 innbyggere 1.1.2025 og tre scenarier. Innflyttingen styres av boligbygging og sysselsetting ved KDA (4 000 ansatte i 2029). Alle scenarier gir flere innbyggere i 2035 enn i 2025. Fødselsoverskuddet var negativt i første halvår 2025. |
| Ringerike (3305) | Flere over 80 og færre i arbeidsaktiv alder gir utfordringer med arbeidskraft og tjenester. Eget vedlegg om befolkning og boliger innenfor langsiktig grense for vekst. |
| Hole (3310) | 6 833 innbyggere (2018). Planen legger til grunn vekst på inntil 2 %, som gir ca. 8 700 i 2030. Antallet over 80 år fordobles til 2030. Planen sier at FRE16 gjør framskrivingen spesielt usikker. |
| Lier (3312) | 28 624 innbyggere (4. kv. 2024), med moderat vekst drevet av innflytting. Kommunens egen prognose til 2040: 67-79 år +37 %, 80+ +102 %, 0-15 år +30 % og 16-66 år +28 %, altså langt høyere vekst i de yngre gruppene enn SSB. Aldersbæreevnen faller. |
| Øvre Eiker (3314) | Veksten kommer fra innvandring og innflytting. Fødselsoverskuddet i 2020 var lavest siden 2010. Antallet over 80 år dobles til 2040 (SSB middel), og SSBs middelalternativ har historisk truffet godt. |
| Modum (3316) | 15 700 innbyggere i 2041 (SSB middel), og 95 % av veksten er 67+. 80+ øker fra 711 til ca. 1 600. Antall i yrkesaktiv alder per pensjonist går fra 3,5 til ca. 2 i 2040. |
| Krødsherad (3318) | 2 212 innbyggere (2019). Flyttetallene er svakere enn forventet, og det er risiko for nedgang. Bostedsattraktiviteten har gått fra positiv til negativ. |
| Flå (3320) | Lite demografi i teksten: en figur over folketallet 1950-2022 og vekst i næringsliv og hytter (ca. 2 400). |
| Nesbyen (3322) | 3 342 innbyggere (2017), svak nedgang, og færre i yrkesaktiv alder. Statistikkheftet viser økning i demens i 67-79 år og en dobling av antallet med demens. |
| Gol (3324) | Folketallet gikk fra 4 576 til 4 767 i 2018-2022, mer enn SSB antok. MMMM gir +3,8 % i 2025-2045. Gruppen 20-66 år synker med ca. 200 (-8 %), 67+ øker markant, og fødselsoverskuddet er negativt. |
| Hemsedal (3326) | +31 % fra 2005 til 2017. Kommunens prognose er 1 % årlig vekst. Planstrategien peker på store demografiske endringer i helse og omsorg. |
| Ål (3328) | Plan fra 2015: folketallet har stagnert rundt 4 800, og SSB anslår +8,5 % i 2012-2030 med vekst hovedsakelig over 75 år. Planstrategien fra 2024 er skannet og har ingen tekst. |
| Hol (3330) | 4 491 innbyggere (1.1.2024), med mål om 5 000 i 2030. Veksten kommer bare fra tilflytting. Andelen 67+ gikk fra 20 % (2020) til 22 % (2024), og forventet levealder er over landssnittet. |
| Sigdal (3332) | 3 492 innbyggere (2021). Til 2036 ventes 67+ å øke med ca. 27 % og grunnskolealder å synke med ca. 26 %. Planen sier det blir vanskelig å unngå befolkningsnedgang. |
| Flesberg (3334) | MMMM gir 2 866 innbyggere i 2030 og 3 172 i 2050 (ca. 16 % vekst), som er uvanlig for en distriktskommune. Eldrebølgen og færre i arbeidsfør alder omtales likevel. |
| Rollag (3336) | Fødselsunderskudd gjør kommunen avhengig av netto innflytting. Gruppen 67-79 år ligger stabilt på ca. 220-250, mens 80-89 år vokser kraftig etter 2025. Utflytting er hovedutfordringen. |
| Nore og Uvdal (3338) | Telemarksforsking-framskriving til 2040: 67+ +34,7 % og 66 år og yngre -28,9 %, altså samlet nedgang. Fødselsbalansen tilsvarte -4,2 % av folketallet det siste tiåret. |

Relevans for Fram: kommunene bruker ulike befolkningsgrunnlag. Mange bruker
SSBs hovedalternativ (MMMM), mens Lier, Hole og Hemsedal har egne prognoser.
Kongsberg bruker Prognosesenteret og Nore og Uvdal bruker Telemarksforsking.
Liers egen prognose gir klart høyere vekst i yngre aldersgrupper enn SSB, og
slike avvik er et naturlig sammenligningspunkt for Frams MMMM-baserte
framskrivinger.
