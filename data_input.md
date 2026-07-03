# Benötigte Daten, um den Code zu reproduzieren
Dieses Dokument benennt Datenquellen, um den vorliegenden Code reproduzierbar zu gestalten. Das Hauptziel ist es, einen Workflow für zukünftige explorative Forschungen im Zusammenhang mit Eigentumsdaten im Kontext des Donut-Effekts bereitzustellen. Welche Datensätze prozessiert werden, wird im Folgenden erklärt.

Der Code aus dem gleichnamigen Ordner prozessiert Datensätze innerhalb eines Ordnersystems. Die zu verarbeitenden Datensätze sind im Ordner `input` enthalten; diese stammen aus der Fallstudie des Forschungs- und Studierendenprojektes „Grund zum Wohnen – Donut-Dörfer in der Pfalz“.

Die Gemeinde Dirmstein stellt das Untersuchungsobjekt dar, und an ihr werden Eigentümer:innenstrukturen und Unternutzungen im Kontext des Donut-Effektes verarbeitet.

## Eigentumsdaten
* Ein tabellarischer Datensatz mit jeglichen Eigentümer:innen-Informationen aus dem Innenbereich eines Ortes
* **Folgende Angaben sollten mindestens enthalten sein:**
	* Flurstückskennzeichen
	* Buchungsart des Grundstücks
	* Vorname der Eigentümer:in
	* Nachname der Eigentümer:in / Firmenname
	* Geburtsdatum der Eigentümer:in
	* Angaben zur Adresse

> Anmerkung: Die Eigentumsdaten sind aufgrund des Datenschutzes nicht in dem Repository enthalten



## Amtliches Liegenschaftskatasterinformationssystem (ALKIS)
* Eine GeoPackage-Datei mit Polygonlayer von Flurstücken aus dem ALKIS. Diese sollten das gleiche Untersuchungsgebiet wie die Eigentumsdaten abdecken.
* Eine GeoPackage-Datei mit einem Polygonlayer von zusammengeführten Landnutzungen aus dem ALKIS. Umfasst werden sollten alle tatsächlichen Nutzungen aus dem Katalog in dem ALKIS.
* Quelle: LVermGeoRP, 2025: ALKIS (ohne Personen- und Bestandsdaten) © GeoBasis-DE / LVermGeoRP (2026) dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]


## Amtliches Topographisch-Kartographisches Informationssystem (ATKIS)
* Eine GeoPackage-Datei mit Polygonlayer von der Ortslage des Untersuchungsgebiets.
* Eine optionale GeoPackage-Datei mit Polygonlayer von den Verwaltungsgrenzen des Untersuchungsgebiets.
* Quelle: LVermGeoRP, 2024: ATKIS Basis-DLM RP (Digitales Basis-Landschaftsmodell) © GeoBasis-DE / LVermGeoRP (2026) dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]


## Datenerhebung städtebaulicher Unternutzungen / Funktionsverluste
* Ein selbst zu erhebender Datensatz im Format einer GeoPackage-Datei mit vier Punktlayern, welche Arten städtebaulicher Funktionsverluste behandeln
* Städtebauliche Unternutzungen richten sich sinngemäß nach der Definition städtebaulicher Funktionsverluste aus § 171a Abs. 2 S. 2 BauGB (Leerstand und Baulücke) mit zusätzlichen temporären Funktionsverlusten (Aktives Bauvorhaben)
* Die vier Punktlayer sind dementsprechend jeweils für die aktiven Bauvorhaben, Baulücken, Leerstände und Unternutzungen im gesamten
* In der Attributtabelle sollte mindestens eine Kennzeichnung zur Art der Unternutzung (`typ`) enthalten sein

### Vorgehen bei der Erhebung

In der Fallstudie des Forschungsprojektes wurde für die Datenerhebung ein phänomenologischer Ansatz für die Bestimmung von Unternutzungen verfolgt. Die Indikatoren und die zugrunde liegende Inferenzlogik werden im Folgenden in einer Tabelle erläutert:

| Indikator | Inferenzlogik | Art der Unternutzung |
|---|---|---|
| **Verfall der Bausubstanz**<br>• heruntergefallene, nicht ersetzte Dachziegel<br>• bröckelnde Fassade | • Unterlassene Instandhaltung signalisiert fehlenden Eingriff von Nutzer:innen/Eigentümer:innen<br>• Bewohner:innen reparieren funktionsrelevante Schäden zeitnah | Leerstand |
| **Defekte Öffnungen**<br>• kaputte Fenster<br>• eingeschlagene Scheiben | • Schäden, die niemand behebt<br>• offene Hülle wäre für Bewohner:innen unzumutbar (Witterung, Sicherheit) | Leerstand |
| **Blockierte Zugänge**<br>• kaputte Türen<br>• verriegelte/vernagelte Tore | • Defekte, unersetzte Tür / Vernagelung deutet auf bewusste Sicherung eines ungenutzten Objekts hin | Leerstand |
| **Dauerhafter Verschluss tagsüber**<br>• Rollläden tagsüber unten<br>• Fensterläden auffällig/durchgängig geschlossen | • Fehlende Tagesnutzung<br>• Mehrdeutig: auch Abwesenheit/Urlaub (nur in Kombination wertbar) | Leerstand |
| **Keine Beleuchtung in der Dämmerung** | • Keine abendliche Anwesenheit<br>• Erst über mehrere Beobachtungen wertbar | Leerstand |
| **Fehlende Entsorgungsspuren**<br>• am Abfuhrtag keine Mülltonne herausgestellt | • Kein Haushaltsbetrieb, kein Abfallaufkommen<br>• Zeitpunktgebunden, daher an Abfuhrlogik koppeln | Leerstand |
| **Akkumulierte/ungeleerte Post**<br>• überfüllter Briefkasten<br>• liegengebliebene Zeitung | • Keine Person entnimmt Post, also keine regelmäßige Anwesenheit | Leerstand |
| **Verwilderung der Freiflächen**<br>• Unkraut in Pflasterfugen/Einfahrt<br>• verwilderter Garten | • Ausbleibende Pflege über eine Vegetationsperiode von Nutzenden<br>• Gibt grob Aufschluss über Dauer des Leerstands | Leerstand<br>(Aktives Bauvorhaben) |
| **Fehlende Adressierung**<br>• leere/fehlende Klingel- und Namensschilder<br>• abgeklebte Briefkästen | • Keine gemeldete/zuordenbare Partei an der Adresse<br>• Achtung: unzuverlässig bei Neubezug oder Datenschutz | Leerstand<br>(Aktives Bauvorhaben) |
| **Befragungsevidenz**<br>• Walking-Interview-Aussage | • Soziale/lokale Wissensquelle<br>• keine phänomenologische Beobachtung<br>• als Validierung führen, nicht als Primärbefund | Leerstand<br>Baulücke<br>Aktives Bauvorhaben |
| **Fehlende Bebauung**<br>• Parzelle unbebaut trotz Bebauungsplan / im Siedlungszusammenhang<br>• Abgleich mit älteren Luftbildern / Bebauungsplänen | • Definitorisches Kernmerkmal der Baulücke<br>• erschlossenes, aber freies Grundstück im bebauten Gefüge<br>• Sekundärquelle | Baulücke |
| **In Nutzung befindliches Baumaterial**<br>• gestapeltes Material mit geringer Witterungsspur<br>• Geräte<br>• Container<br>• Gerüst<br>• Frischer Aushub | • Geringe Verwitterung als Indikator für Verwendung<br>• laufende Tätigkeit<br>• Arbeiten durch Personen | Baulücke<br>Aktives Bauvorhaben |

*Anmerkung: Einige Indikatoren gelten für mehrere Arten der Unternutzung gleichermaßen.*

## Zensusdaten der Baujahrzehnte der Gebäude
* Ein tabellarischer Zensusdatensatz mit Baujahrzehnten von Gebäuden im 100-Meter-Gitternetz
* Tabelle wird in die Form eines Punktlayers in einer GeoPackage-Datei übersetzt und auf das Untersuchungsgebiet begrenzt
* alle Binde-/Gedanken-/Spiegelstriche der originalen Tabelle aus den Anteilen der jeweiligen Baujahrzehnte werden mit der Zahl `0` ersetzt 
* **Quelle**: [Statistische Ämter des Bundes und der Länder, 2026: Ergebnisse des Zensus 2022. Gebäude nach Baujahr (Jahrzehnte) in Gitterzellen](https://www.destatis.de/static/DE/zensus/gitterdaten/Gebaeude_nach_Baujahr_Jahrzehnte.zip)
