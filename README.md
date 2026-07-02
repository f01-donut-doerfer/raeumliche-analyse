# Räumliche Analyse unternutzter Flurstücke und der Eigentümer:innenstruktur in Siedlungsbereichen

Dieses Repository stellt einen Workflow bereit, um *unternutzte* Flurstücke mit Eigentümer:innenstrukturen, Landnutzungen, dem Gebäudealter und räumlichen Clusterungen in Beziehung zu setzen. Unter *Unternutzung* werden hier drei Zustände verstanden, die auf einem Flurstück vorkommen können: Leerstand, Baulücke und aktive Bauvorhaben. Der Ansatz kombiniert Katasterdaten der Flurstücke, Unternutzungsdaten, Eigentumsdaten und Zensusdaten und wendet räumlich-statistische Verfahren an, um zu beschreiben, *wo* Unternutzung auftritt und *wer* die betroffenen Flurstücke besitzt.

Ein zentraler Vorprozessierungsschritt bereitet die Eigentumsdaten auf: Die Eigentümer:innen werden in eine begrenzte Anzahl von Typen klassifiziert, dieselben Personen oder Institution werden zusammengeführt. Diese Typisierung und Konsolidierung folgt dem Ansatz von Tietz et al. (2021), kombiniert mit einem phonetischen Namensabgleich auf Basis der Kölner Phonetik (Postel 1969). Ergebnis ist ein Datensatz, in dem jede:r Eigentümer:in nur einmal vorkommt, ergänzt um abgeleitete Merkmale wie die Anzahl der Eigentümer:innen pro Flurstück, die Anzahl der Flurstücke pro Eigentümer:in und das Eigentümeralter.

Der Workflow ist auf einen einzelnen Siedlungskörper (Ortslage) ausgelegt, der durch eine Eingabegeometrie definiert wird. Der Code stammt aus einer Anwendung des Ansatzes auf eine Gemeinde in Rheinland-Pfalz (Deutschland); die exakte Reproduktion mit den im Beispiel verwendeten Daten ist nicht das Hauptziel dieses Repositories.

## Workflow

Zunächst werden die Eigentumsdaten typisiert und konsolidiert. Ausgehend von den Flurstücken wird die Landnutzung angefügt und korrigiert, die konsolidierten Eigentümer:innenmerkmale werden übernommen, das Ergebnis wird auf einen Datensatz je Flurstück aggregiert und auf den Siedlungskörper zugeschnitten. Anschließend werden Unternutzungen auf diese Flurstücke übertragen und nach ihrer Art aufgeteilt (Leerstand, Baulücke, aktives Bauvorhaben).

Mit dem entstehenden Datensatz werden mehrere Analysen durchgeführt. Eine Hotspot-Analyse nach Getis-Ord Gi\* identifiziert statistisch signifikante Cluster hoher oder niedriger Werte für die Anzahl der Eigentümer:innen pro Flurstück, die Anzahl der Flurstücke pro Eigentümer:in und das Alter; die Distanzklasse je Variable wird automatisch über eine inkrementelle Bestimmung der räumlichen Autokorrelation nach Moran's I gewählt. Kreuztabellen fassen den Anteil der Unternutzung nach Landnutzung und nach Eigentümer:innen-Typ zusammen und werden als formatiertes Tabellendokument exportiert. Das Gebäudealter wird auf einem zensusbasierten 100-m-Gitter ausgewertet, wobei in jeder Zelle das dominante Baujahrzehnt bestimmt wird. Die räumliche Clusterung der Unternutzungen werden mit der Ripley-L-Funktion untersucht; ihre lokalen Maxima liefern charakteristische Clusterungsdistanzen auf mikro-, meso- und makrostruktureller Ebene. Diese Distanzen werden als Suchradien für die Kerndichteschätzung wiederverwendet und ergeben Heatmaps der Unternutzungsintensität.

## Output

Der Workflow erzeugt mehrere geografische Datensätze (GeoPackage) und Rasterlayer:

- Aggregierte Flurstücke innerhalb des Siedlungskörpers
- Unternutzungs-Flurstücke, sowohl vollständig als auch nach Art aufgeteilt (Leerstand, Baulücke, aktives Bauvorhaben).
- Hotspot-Layer (Gi\*-Werte sowie Hot-/Cold-Spot-Klassen auf dem 90-%-, 95-%- und 99-%-Konfidenzniveau) für Eigentümer:innen pro Flurstück, Flurstücke pro Eigentümer:in und Eigentümeralter.
- Ein Gitterlayer mit der dominanten Bauepoche je Zelle.
- Punktlayer je Unternutzungsart sowie KDE-Heatmap-Raster der Unternutzungsintensität.
- Ein Tabellendokument (Word) mit Kreuztabellen der Unternutzung nach Landnutzung und Eigentümertyp.

## Erste Schritte

Zweck dieses Repositories ist die Dokumentation des Ansatzes und die Bereitstellung eines reproduzierbaren Workflows. Aufgrund des stark explorativen Charakters und der Menge an Datensätzen ist eine Anwendung auf andere Untersuchungsräume mit hohen Aufwänden verbunden.

### Eingangsdaten

Die Eingabedateien werden in einen Unterordner
`input` des Projektordners gelegt. Die wichtigsten Eingangsdaten sind:

- Flurstücke und Landnutzung (ALKIS), z. B. `alkis_flurstueck.gpkg`,
  `alkis_nutzung.gpkg`.
- Eine Geometrie des Siedlungskörpers (ATKIS), z. B. `dlm_ortslage.gpkg`.
- Eigentumsdaten im Tabellenformat: `Eigentumsdaten.xlsx`.
- Selbst erhobene Daten zu Unternutzungen: `erhebung_unternutzung.gpkg`.
- Ein 100-Meter-Gitternetz des Zensus (Baujahrzehnte):`zensus2022_gebaeudeJZ.gpkg`.

Dateinamen, Layernamen und die Korrekturregeln für einzelne Flurstücke sind an die eigenen Daten anzupassen.

### Voraussetzungen

Der Workflow verwendet **Python**, **QGIS** und **R**.

- Das eigenständige Vorprozessierungsskript läuft in reinem Python und benötigt `pandas`, `numpy` und `openpyxl`.
- Die `.py`-Workflow-Skripte nutzen das QGIS-Processing-Framework (`processing.run`) und
  werden innerhalb von QGIS in der Python-Konsole ausgeführt.
- Die `.R`-Skripte benötigen je nach Schritt `sf`, `dplyr`, `tidyr`, `spdep`, `spatstat.geom`, `spatstat.explore`, `flextable`, `officer` und `scales`. Fehlende Pakete werden von den Skripten automatisch installiert.

### Vor der Ausführung

- Projektordner festlegen. Alle Skripte leiten ihre Pfade relativ zum Skriptverzeichnis ab; bei Bedarf kann am Anfang jeder Datei ein fester Ersatzpfad gesetzt werden. Der Standard ist das einfache Herunterladen des Repositories als Ordner.
- Die Eingabedateien in den Ordner `input` legen.
- Die Eigentums-Vorprozessierung zuerst ausführen, damit die konsolidierte Eigentümertabelle für den Aggregationsschritt bereitsteht.

## Beschreibung des Codes

Der Prozess umfasst diese Hauptschritte:

1. **Eigentums-Vorprozessierung** (`tietz_eigentuemer_typisierung.py`) – Typisierung und Konsolidierung der Roh-Eigentumsdaten (siehe eigener Abschnitt unten).
2. **Aggregation** (`00_TF1_Aggregation.py`, QGIS) – Spatial Join und manuelle Korrektur der Landnutzung, Join der konsolidierten Eigentümermerkmale über das Flurstückskennzeichen, Aggregation auf einen Datensatz je Flurstück und Zuschnitt auf den Siedlungskörper.
3. **Unternutzung** (`01_TF1_Unternutzung.py`, QGIS) – Spatial Join der Unternutzungserhebung auf die Flurstücke und Extraktion der einzelnen
   Unternutzungsarten.
4. **Hotspots** (`02_TF1_Hotspots.R`, R) – inkrementelle Bestimmung der räumlichen Autokorrelation und Getis-Ord-Gi\*-Hotspot-Klassifikation für Eigentümer:innen pro Flurstück, Flurstücke pro Eigentümer:in und Eigentümeralter.
5. **Tabellen** (`03_TF2_Tabellen.r`, R) – Kreuztabellen der Unternutzung nach Landnutzung und Eigentümertyp, exportiert als formatiertes Word-Dokument.
6. **Gebäudealter** (`04_FF1_Baujahr.R`, R) – Aufbau eines am Zensus ausgerichteten 100-m-Gitters und Ableitung der dominanten Bauepoche je Zelle.
7. **Ripley-L** (`05_FF1_RipleyL.R`, R) – Clusteranalyse der Unternutzungspunkte und Bestimmung charakteristischer Clusterungsdistanzen.
8. **KDE-Heatmaps** (`06_FF1_KDE_Heatmap.py`, QGIS) – Kerndichteschätzung der Unternutzungsintensität, wobei die Clusterungsdistanzen aus dem Ripley-L-Schritt als Suchradien dienen.

Die QGIS-`.py`-Schritte werden innerhalb von QGIS ausgeführt, das eigenständige Python-Skript und die R-Schritte in ihrer jeweiligen Umgebung, in der nummerierten Reihenfolge. Die Datei-Präfixe (`TF`, `FF`) gruppieren die Skripte nach Forschungs- oder Teilfrage.

## Eigentums-Vorprozessierung (Tietz et al.)

Das Skript `tietz_eigentuemer_typisierung.py` liest die Roh-Eigentumstabelle ein und erzeugt eine aufbereitete Tabelle mit zusätzlichen Merkmalen. Es läuft in drei konzeptionellen Schritten:

1. **Kategorisierung** – jedem Datensatz wird ein Eigentümertyp zugewiesen. Datensätze mit Vornamen gelten als natürliche Personen; die übrigen Datensätze werden über einen Schlüsselwortabgleich am Eigentümernamen den Typen Bund, Land, Kommune, Kirche und Unternehmen zugeordnet.
2. **Konsolidierung (Matching)** – Datensätze, die sich auf dieselbe:n Eigentümer:in beziehen, werden über eine Union-Find-Struktur und einen mehrstufigen Abgleich zusammengeführt: phonetisch ähnliche Namen in Verbindung mit gleichem Geburtsdatum (natürliche Personen) oder gleicher Adresse (übrige Typen); ein Exact-Match-Verfahren als Rückfalloption ohne Geburtsdatum; sowie eine Prüfung auf Zahlendreher oder Tippfehler im Geburtsdatum.
3. **Abgeleitete Merkmale** – nach der Konsolidierung berechnet das Skript die Anzahl der eindeutigen Eigentümer:innen pro Flurstück, die Anzahl der eindeutigen Flurstücke je konsolidierter:m Eigentümer:in sowie das Eigentümeralter aus dem Geburtsdatum und schreibt diese in die Tabelle zurück.

Der phonetische Abgleich verwendet die Kölner Phonetik (Postel 1969). Die aufbereitete Tabelle ist die Eingabe für den Aggregationsschritt.

## Literatur

- **Postel, Hans Joachim (1969):** Die Kölner Phonetik. Ein Verfahren zur Identifizierung von Personennamen auf der Grundlage der Gestaltanalyse. In: IBM-Nachrichten, 19. Jahrgang, 1969, S. 925-931.
- **Tietz, Andreas; Bockelmann, Leo (2025):** Untersuchung von Landeigentumsstrukturen in Deutschland: Wem gehört die Landwirtschaftsfläche?, in: Raumforschung und Raumordnung: Spatial Research and Planning, Bd. 83, Nr. 4, S. 302-319.
