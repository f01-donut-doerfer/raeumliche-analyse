# import importlib.util, subprocess, sys; [subprocess.run([sys.executable, "-m", "pip", "install", m]) for m in ("pandas", "numpy", "openpyxl") if importlib.util.find_spec(m) is None]
import pandas as pd
import numpy as np
import re
from itertools import combinations

EINGABE_DATEI = r"/Volumes/Untitled/M03/donut-effect-main/input/Eigentumsdaten.xlsx"
AUSGABE_DATEI = r"/Volumes/Untitled/M03/donut-effect-main/input/Eigentumsdaten_verarbeitet.xlsx"

# ---
# 1. KÖLNER PHONETIK
# ---

def koelner_phonetik(name: str) -> str:
    """
    # Kölner Phonetik nach Postel (1969).
    # Gibt einen phonetischen Code als Zeichenkette zurück.
    """
    
    if not isinstance(name, str) or not name.strip():
        return ""

    name = name.upper().strip()

    # Sonderzeichen / Umlaute normalisieren
    replacements = {
        "Ä": "AE", "Ö": "OE", "Ü": "UE", "ß": "SS",
        "PH": "3",   # vor der Regel-Ersetzung
    }
    for k, v in replacements.items():
        name = name.replace(k, v)

    # Nur Buchstaben behalten
    name = re.sub(r"[^A-Z]", "", name)
    if not name:
        return ""

    # Kölner-Phonetik Regeln (zeichenweise)
    code_map = []
    for i, ch in enumerate(name):
        prev = name[i - 1] if i > 0 else ""
        nxt  = name[i + 1] if i < len(name) - 1 else ""

        if ch in "AEIJOUY":
            code = "0"
        elif ch == "H":
            code = ""
        elif ch in "BP":
            code = "1"
        elif ch in "DT":
            if nxt in "CSZ":
                code = "8"
            else:
                code = "2"
        elif ch == "F" or (ch == "V"):
            code = "3"
        elif ch in "GKQ":
            code = "4"
        elif ch == "C":
            if i == 0:
                if nxt in "AHKLOQRUX":
                    code = "4"
                else:
                    code = "8"
            elif prev in "SZ":
                code = "8"
            elif nxt in "AHKOQUX":
                code = "4"
            else:
                code = "8"
        elif ch == "X":
            if prev in "CKQ":
                code = "8"
            else:
                code = "48"
        elif ch in "SZ":
            code = "8"
        elif ch == "L":
            code = "5"
        elif ch in "MN":
            code = "6"
        elif ch == "R":
            code = "7"
        else:
            code = ""

        code_map.append(code)

    raw = "".join(code_map)

    # Doppelte aufeinanderfolgende Ziffern entfernen
    compressed = ""
    for ch in raw:
        if not compressed or ch != compressed[-1]:
            compressed += ch

    # Führende 0 entfernen (außer wenn der Name mit Vokal beginnt)
    result = compressed.lstrip("0") if compressed and name[0] not in "AEIJOUY" else compressed

    return result if result else "0"


# ---
# 2. HILFSFUNKTIONEN
# ---

def normalize_str(s) -> str:
    # Bereinigt einen String für Vergleiche
    if pd.isna(s):
        return ""
    return str(s).strip().upper()


def build_adresse(row) -> str:
    # Erstellt einen normierten Adress-String aus den vier Adressspalten
    parts = [
        normalize_str(row.get("Straße", "")),
        normalize_str(row.get("Hausnummer", "")),
        normalize_str(row.get("Postleitzahl", "")),
        normalize_str(row.get("Ort", "")),
    ]
    return " ".join(p for p in parts if p)


def normalize_date(d) -> str:
    # Gibt ein Geburtsdatum als normierter String zurück
    if pd.isna(d) or str(d).strip() in ("", "nan", "NaT"):
        return ""
    return str(d).strip()


def dates_plausibly_same(d1: str, d2: str) -> bool:
    """
    Prüft ob zwei Datumsstrings trotz Zahlendreher / Tippfehler auf dasselbe Datum hinweisen (Stufe 3 des Algorithmus).
    Strategie: Alle Ziffern extrahieren und prüfen, ob diese zu unterscheiden sind
    """
    if d1 == d2:
        return True
    if not d1 or not d2:
        return False

    dig1 = re.sub(r"\D", "", d1)
    dig2 = re.sub(r"\D", "", d2)

    if len(dig1) != len(dig2) or len(dig1) < 6:
        return False

    # Segmentierung TT MM JJJJ (8 Ziffern) oder TT MM JJ (6 Ziffern)
    if len(dig1) == 8:
        segs1 = [dig1[0:2], dig1[2:4], dig1[4:8]]
        segs2 = [dig2[0:2], dig2[2:4], dig2[4:8]]
    elif len(dig1) == 6:
        segs1 = [dig1[0:2], dig1[2:4], dig1[4:6]]
        segs2 = [dig2[0:2], dig2[2:4], dig2[4:6]]
    else:
        return False

    # Unterschiede zählen
    diffs = sum(1 for a, b in zip(segs1, segs2) if a != b)
    if diffs == 0:
        return True

    # Bei 1-2 Segmenten verschieden: prüfe Zahlendreher innerhalb eines Segments
    if diffs <= 2:
        for a, b in zip(segs1, segs2):
            if a != b and sorted(a) != sorted(b):
                return False  # nicht nur Zahlendreher
        return True

    return False


# ---
# 3. SCHRITT 1 - KATEGORISIERUNG
# ---

# Schlüsselwort-Listen für die automatische Kategorisierung

KEYWORDS = {
    "Bund": [
        "BUNDESREPUBLIK", "BUND ",
        "BUNDESMINISTERIUM", "BUNDESANSTALT",
        "BUNDESAMT", "BUNDESBEHÖRDE",
        "BUNDESWEHR",
        "BUNDESPOST", "DEUTSCHE POST",
        "DEUTSCHE BAHN", "DB NETZ",
        "TELEKOM",
    ],
    "Land": [
        "LAND RHEINLAND-PFALZ", "RHEINLAND-PFALZ",
        "FREISTAAT",
        "LANDESANSTALT", "LANDESBETRIEB", "LANDESAMT", "LANDESFORST", "LANDESSTRASSENBAU", "LANDESUMWELTAMT",
        "STAATSBETRIEB", "STAATLICHES",
        "MINISTERIUM", "SENATSVERWALTUNG",
        "STRASSENVERWALTUNG", "STRAßENVERWALTUNG", " (STRAßENVERWALTUNG)",
    ],
    "Kommune": [
        "DIRMSTEIN",
        "GEMEINDE", "ORTSGEMEINDE",
        "VERBANDSGEMEINDE", "SAMTGEMEINDE",
        "GRÜNSTADT", "GRÜNSTADT-LAND",
        "STADT ",
        "LANDKREIS", "KREIS ", "AMT ",
        "STADTWERKE", "KOMMUNAL",
    ],
    "Kirche": [
        "KIRCHE", "KIRCHENGEMEINDE",
        "BISTUM", "ERZBISTUM",
        "DIÖZESE",
        "EVANGELISCH", "EVANGELISCHE",
        "KATHOLISCH", "KATHOLISCHE",
        "PROTESTANTISCH", "PROTESTANTISCHE",
        "PFARR", "PFARRPFRÜNDE", "KLOSTER", "STIFT ",
        "CARITAS", "DIAKONIE",
    ],
    "Unternehmen": [
        " GMBH", " MBH", " EGMBH", " GMBH & CO", " GMBH & CO. KG",
        " AG ", " KG ", " OHG",
        " & ", " GBR", " eGBR", "BGB",
        " EG ", " EV ", " E V", " E.V.", " E.V",
        "STIFTUNG",
        "VOLKSBANK",
        "IMMOBILIEN", "VERWALTUNGS",
        "WOHNUNGSBAU", "BAUTRÄGER", "GRUNDBESITZ",
        "GENOSSENSCHAFT", "ELEKTRIZITÄTS",
    ],
}

KATEGORIE_REIHENFOLGE = [
    "Bund", "Land", "Kirche", "Kommune", "Unternehmen",
]


def kategorisiere(row) -> str:
    """
    Weist jedem Datensatz eine der sechs Typen zu.
    Logik gemäß Tietz et al.:
        Wenn Vorname vorhanden: Natürliche Person
        Sonst:                  Schlüsselwortabgleich mit nachnameoderfirma (hier: Nachname)
    """
    vorname = normalize_str(row.get("Vorname", ""))
    nachname = normalize_str(row.get("Nachname", ""))

    if vorname:
        return "Natürliche Person"

    # Schlüsselwortabgleich
    for kategorie in KATEGORIE_REIHENFOLGE:
        for kw in KEYWORDS[kategorie]:
            if kw in nachname:
                return kategorie

    # Rückfallverfahren: wenn kein Treffer, dann sind es Unternehmen
    if nachname:
        return "Unternehmen"

    return "Natürliche Person"


# ---
# 4. SCHRITTE 2 & 3 - STRING-MATCHING / ZUSAMMENFÜHRUNG
# ---

def finde_gruppen(df: pd.DataFrame) -> pd.Series:
    """
    Führt den dreiteiligen String-Matching-Algorithmus durch und
    gibt eine Serie an Gruppen-IDs zurück (gleiche ID = zusammengeführt).

    Stufe 1: Kölner Phonetik:
        NP:   phonetisch ähnlich + gleiches Geburtsdatum
        Rest: phonetisch ähnlich + gleiche Adresse

    Stufe 2: Exact Match (Fallback wenn kein Geburtsdatum):
        NP ohne GebDatum:       gleicher Name + gleiche Adresse
        Unternehmen / Kirche:   gleiche Adresse
        Land:                   gleiches Bundesland
        Kommune:                gleiche Kommune
        Bund:                   alle zusammengeführt

    Stufe 3: Zahlendreher im Geburtsdatum:
        NP gleicher Name + gleiche Adresse + plausibel gleiches GebDatum
    """

    n = len(df)
    gruppe = list(range(n))   # Union-Find: jeder ist zunächst seine eigene Gruppe

    def find(x):
        while gruppe[x] != x:
            gruppe[x] = gruppe[gruppe[x]]
            x = gruppe[x]
        return x

    def union(x, y):
        rx, ry = find(x), find(y)
        if rx != ry:
            gruppe[ry] = rx

    # Vorberechnete Felder
    df = df.copy()
    df["_adresse"]      = df.apply(build_adresse, axis=1)
    df["_phonetik_vn"]  = df["Vorname"].apply(lambda x: koelner_phonetik(normalize_str(x)))
    df["_phonetik_nn"]  = df["Nachname"].apply(lambda x: koelner_phonetik(normalize_str(x)))
    df["_phonetik"]     = df["_phonetik_vn"] + "|" + df["_phonetik_nn"]
    df["_gebdat"]       = df["Geburtsdatum"].apply(normalize_date)
    df["_vorname_n"]    = df["Vorname"].apply(normalize_str)
    df["_nachname_n"]   = df["Nachname"].apply(normalize_str)

    kat = df["Typ"].values
    idx = df.index.tolist()

    # Indizes nach Typ
    def mask(cats):
        return [i for i, k in enumerate(kat) if k in cats]

    np_idx   = mask(["Natürliche Person"])
    u_idx    = mask(["Unternehmen", "Kirche"])
    land_idx = mask(["Land"])
    kom_idx  = mask(["Kommune"])
    bund_idx = mask(["Bund"])

    # Hilfsfunktion: Union über eine gruppierte Liste von Positional-Indizes
    def union_gruppe(gruppe_dict):
        """Führt alle Einträge innerhalb jeder Gruppe zusammen."""
        for members in gruppe_dict.values():
            if len(members) < 2:
                continue
            first = members[0]
            for other in members[1:]:
                union(first, other)

    # -- SCHRITT 1: Kölner Phonetik --
    # Strategie: erst nach Schlüssel gruppieren, dann nur innerhalb der Gruppe
    # vergleichen -> O(n) statt O(n2)

    # Natürliche Personen: phonetisch ähnlich + gleiches Geburtsdatum
    # Schlüssel = (phonetischer_code, geburtsdatum)
    np_phonetik_geb: dict = {}
    for i in np_idx:
        gi = idx[i]
        geb = df.at[gi, "_gebdat"]
        if not geb:
            continue
        key = (df.at[gi, "_phonetik"], geb)
        np_phonetik_geb.setdefault(key, []).append(i)
    union_gruppe(np_phonetik_geb)

    # Unternehmen etc.: phonetisch ähnlich + gleiche Adresse
    # Schlüssel = (phonetischer_code_nn, adresse)
    u_phonetik_adr: dict = {}
    for i in u_idx:
        gi = idx[i]
        adr = df.at[gi, "_adresse"]
        if not adr:
            continue
        key = (df.at[gi, "_phonetik_nn"], adr)
        u_phonetik_adr.setdefault(key, []).append(i)
    union_gruppe(u_phonetik_adr)

    # -- SCHRITT 2: Exact-Match-Fallback --

    # NP ohne Geburtsdatum: gleicher Name + gleiche Adresse
    np_name_adr: dict = {}
    for i in np_idx:
        gi = idx[i]
        if df.at[gi, "_gebdat"]:
            continue  # hat Geburtsdatum -> bereits in Schritt 1 behandelt
        adr = df.at[gi, "_adresse"]
        if not adr:
            continue
        key = (df.at[gi, "_vorname_n"], df.at[gi, "_nachname_n"], adr)
        np_name_adr.setdefault(key, []).append(i)
    union_gruppe(np_name_adr)

    # Unternehmen etc.: gleiche Adresse
    u_adr: dict = {}
    for i in u_idx:
        gi = idx[i]
        adr = df.at[gi, "_adresse"]
        if not adr:
            continue
        u_adr.setdefault(adr, []).append(i)
    union_gruppe(u_adr)

    # Land: alle zusammenführen (ein Bundesland)
    if len(land_idx) > 1:
        for i in land_idx[1:]:
            union(land_idx[0], i)

    # Kommune: alle pro Ort zusammenführen
    kom_ort: dict = {}
    for i in kom_idx:
        gi = idx[i]
        ort = normalize_str(df.at[gi, "Ort"])
        if not ort:
            continue
        kom_ort.setdefault(ort, []).append(i)
    union_gruppe(kom_ort)

    # Bund: alle zusammenführen
    if len(bund_idx) > 1:
        for i in bund_idx[1:]:
            union(bund_idx[0], i)

    # -- SCHRITT 3: Zahlendreher im Geburtsdatum --
    # Nur innerhalb von Gruppen gleicher Name + gleiche Adresse vergleichen
    np_name_adr_mit_geb: dict = {}
    for i in np_idx:
        gi = idx[i]
        if not df.at[gi, "_gebdat"]:
            continue
        adr = df.at[gi, "_adresse"]
        if not adr:
            continue
        key = (df.at[gi, "_vorname_n"], df.at[gi, "_nachname_n"], adr)
        np_name_adr_mit_geb.setdefault(key, []).append(i)

    for members in np_name_adr_mit_geb.values():
        if len(members) < 2:
            continue
        for i, j in combinations(members, 2):
            if find(i) == find(j):
                continue
            gi, gj = idx[i], idx[j]
            d1, d2 = df.at[gi, "_gebdat"], df.at[gj, "_gebdat"]
            if dates_plausibly_same(d1, d2):
                union(i, j)

    # Kanonische Gruppen-IDs erzeugen
    root_to_id = {}
    result = []
    for i in range(n):
        r = find(i)
        if r not in root_to_id:
            root_to_id[r] = len(root_to_id)
        result.append(root_to_id[r])

    return pd.Series(result, index=df.index, name="Eigentümer_Gruppe_ID")


# ---
# 5. HAUPTPROGRAMM
# ---

def verarbeite_eigentuemer(eingabe_pfad: str, ausgabe_pfad: str):
    """
    Liest die Excel-Datei, führt Typisierung und Konsolidierung durch
    und schreibt das Ergebnis zurück in eine neue Excel-Datei.
    """
    print(f"Lese Datei: {eingabe_pfad}")
    df = pd.read_excel(eingabe_pfad, dtype=str)
    print(f"  -> {len(df)} Zeilen geladen.")

    # Fehlende Spalten auffüllen (Robustheit)
    for col in ["Vorname", "Nachname", "Geburtsdatum",
                "Straße", "Hausnummer", "Postleitzahl", "Ort"]:
        if col not in df.columns:
            df[col] = ""

    # -- Schritt 1: Kategorisierung --
    print("Kategorisiere Eigentümer ...")
    df["Typ"] = df.apply(kategorisiere, axis=1)

    verteilung = df["Typ"].value_counts()
    print("  Typverteilung:")
    for k, v in verteilung.items():
        print(f"    {k}: {v}")

    # -- Schritte 2 & 3: String-Matching / Zusammenführung --
    print("Führe String-Matching durch ...")
    df["Eigentümer_Gruppe_ID"] = finde_gruppen(df)

    n_gruppen  = df["Eigentümer_Gruppe_ID"].nunique()
    n_original = len(df)
    print(f"  {n_original} Einträge -> {n_gruppen} konsolidierte Eigentümer.")

    # -- Statistik-Spalten (nach Konsolidierung) --
    print("Berechne Statistikspalten ...")

    # Anzahl Eigentümer pro Flurstück: konsolidierte Gruppen-IDs je FSK zählen
    # (nicht Rohdatenzeilen, sondern eindeutige konsolidierte Eigentümer)
    fsk_gruppe = df[df["FSK"].notna() & (df["FSK"].str.strip() != "") & (df["FSK"] != "nan")][["FSK", "Eigentümer_Gruppe_ID"]].drop_duplicates()
    fsk_eigentümer_anzahl = fsk_gruppe.groupby("FSK")["Eigentümer_Gruppe_ID"].count().rename("Anzahl_Eigentümer_pro_Flurstück")
    df = df.merge(fsk_eigentümer_anzahl, on="FSK", how="left")
    df["Anzahl_Eigentümer_pro_Flurstück"] = df["Anzahl_Eigentümer_pro_Flurstück"].astype("Int64")

    # Totales Eigentum: Anzahl eindeutiger Flurstücke pro konsolidierter Gruppe
    flurstücke_je_gruppe = (
        df.groupby("Eigentümer_Gruppe_ID")["FSK"]
        .nunique()
        .rename("Anzahl_Flurstücke_pro_Eigentümer")
    )
    df = df.merge(flurstücke_je_gruppe, on="Eigentümer_Gruppe_ID", how="left")

    # Alter: aus Geburtsdatum berechnen
    import re as _re
    from datetime import date as _date, datetime as _datetime
    def berechne_alter(s):
        if pd.isna(s) or str(s).strip() in ("", "nan", "NaT"):
            return None
        if hasattr(s, "year"):
            geb = s
        else:
            m = _re.match(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", str(s).strip())
            if not m:
                return None
            geb = _datetime(int(m.group(3)), int(m.group(2)), int(m.group(1)))
        heute = _date.today()
        return heute.year - geb.year - ((heute.month, heute.day) < (geb.month, geb.day))

    # Geburtsdatum nochmals ohne dtype=str einlesen für datetime-Erkennung
    df_dates = pd.read_excel(eingabe_pfad, usecols=["Geburtsdatum"], header=0)
    # Index explizit angleichen, damit kein Misalignment durch vorherige merges entsteht
    df_dates.index = df.index
    df["Alter"] = df_dates["Geburtsdatum"].apply(berechne_alter).astype("Int64")

    # -- Ausgabe: ein einziges Tabellenblatt --
    NEUE_SPALTEN = [
        "Eigentümer_Gruppe_ID",
        "Typ",
        "Anzahl_Eigentümer_pro_Flurstück",
        "Anzahl_Flurstücke_pro_Eigentümer",
        "Alter",
    ]

    print(f"Schreibe Ergebnis: {ausgabe_pfad}")
    with pd.ExcelWriter(ausgabe_pfad, engine="openpyxl") as writer:
        df.to_excel(writer, sheet_name="Eigentumsdaten", index=False)

        # Neue Spalten in der Kopfzeile fett markieren
        from openpyxl.styles import Font as _Font
        wb = writer.book
        ws = wb["Eigentumsdaten"]
        header = [cell.value for cell in ws[1]]
        for col_name in NEUE_SPALTEN:
            if col_name in header:
                ws.cell(row=1, column=header.index(col_name) + 1).font = _Font(bold=True)

    print("Fertig.")
    return df


# ---
# 6. EINSTIEGSPUNKT
# ---

if __name__ == "__main__":
    import sys

    # Kommandozeilenargumente ueberschreiben die oben gesetzten Pfade (optional)
    if len(sys.argv) == 3:
        EINGABE_DATEI = sys.argv[1]
        AUSGABE_DATEI = sys.argv[2]

    verarbeite_eigentuemer(EINGABE_DATEI, AUSGABE_DATEI)
