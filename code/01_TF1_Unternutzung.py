import os

# --- ORDNERSTRUKTUR mit relativen Pfaden ---
try:
    worksp = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
except NameError:
    worksp = "/Volumes/Untitled/M03" # Pfad zum Ordner, falls __file__ nicht funktioniert

input_dir       = os.path.join(worksp, "input")
workflow_dir    = os.path.join(worksp, "workflow")
output_dir      = os.path.join(worksp, "output")

aggr_dir    = os.path.join(workflow_dir, "0_TF1_Aggregation")
untern_dir  = os.path.join(workflow_dir, "1_TF1_Unternutzung")
hotsp_dir   = os.path.join(workflow_dir, "2_TF1_Hotspots")
tab_dir     = os.path.join(workflow_dir, "3_TF2_Tabellen")
bauj_dir    = os.path.join(workflow_dir, "4_FF1_Baujahr")
kde_dir     = os.path.join(workflow_dir, "5_FF1_KDE")

for d in [untern_dir]:
    os.makedirs(d, exist_ok=True)

# --- DATEIPFADE: Inputs ---
erhebung_unternutzung               = os.path.join(input_dir, "erhebung_unternutzung.gpkg")
p4_Clip_ParzellenEigentum_Ortslage  = os.path.join(aggr_dir, "4_Clip_ParzellenEigentum_Ortslage.gpkg")

# --- DATEIPFADE: Zwischenergebnisse ---
p0_SpatialJoin_ParzellenEigentum_Unternutzung       = os.path.join(untern_dir, "0_SpatialJoin_ParzellenEigentum_Unternutzung.gpkg")
p1_SpatialJoin_ParzellenEigentum_NurUnternutzung    = os.path.join(untern_dir, "1_SpatialJoin_ParzellenEigentum_NurUnternutzung.gpkg")
p2_Extract_ParzellenEigentum_Bauvorhaben            = os.path.join(untern_dir, "2_Extract_ParzellenEigentum_Bauvorhaben.gpkg")
p3_Extract_ParzellenEigentum_Bauluecke              = os.path.join(untern_dir, "3_Extract_ParzellenEigentum_Bauluecke.gpkg")
p4_Extract_ParzellenEigentum_Leerstand              = os.path.join(untern_dir, "4_Extract_ParzellenEigentum_Leerstand.gpkg")

# --- HAUPTPROZESSIERUNG ---

# 4. Spatial Join der Unternutzung in die Eigentums-Parzellen der Ortslage, alle Parzellen bleiben erhalten
processing.run("native:joinattributesbylocation", {
    'INPUT':               f"{p4_Clip_ParzellenEigentum_Ortslage}|layername=eigentum_ortslage",
    'PREDICATE':           [0],
    'JOIN':                f"{erhebung_unternutzung}|layername=unternutzung",
    'JOIN_FIELDS':         [],
    'METHOD':              0,
    'DISCARD_NONMATCHING': False,
    'PREFIX':              '',
    'OUTPUT':              f"ogr:dbname='{p0_SpatialJoin_ParzellenEigentum_Unternutzung}' table=\"unternutzung_vollstaendig\" (geom)"
    })

# 5. Spatial Join der Unternutzung in die Eigentums-Parzellen der Ortslage, nur betroffene Parzellen bleiben erhalten
processing.run("native:joinattributesbylocation", {
    'INPUT':               f"{p4_Clip_ParzellenEigentum_Ortslage}|layername=eigentum_ortslage",
    'PREDICATE':           [0],
    'JOIN':                f"{erhebung_unternutzung}|layername=unternutzung",
    'JOIN_FIELDS':         [],
    'METHOD':              0,
    'DISCARD_NONMATCHING': True,
    'PREFIX':              '',
    'OUTPUT':              f"ogr:dbname='{p1_SpatialJoin_ParzellenEigentum_NurUnternutzung}' table=\"unternutzung\" (geom)"
    })


# --- Unternutzung nach Art jeweils exportieren ---

# 6. Aktive Bauvorhaben
processing.run("native:extractbyattribute", {
    'INPUT':    f"{p1_SpatialJoin_ParzellenEigentum_NurUnternutzung}|layername=unternutzung",
    'FIELD':    'typ_2',
    'OPERATOR': 0,
    'VALUE':    'Aktives Bauvorhaben',
    'OUTPUT':   f"ogr:dbname='{p2_Extract_ParzellenEigentum_Bauvorhaben}' table=\"parzellen_bauvorhaben\" (geom)"
    })

# 7. Baulücken
processing.run("native:extractbyattribute", {
    'INPUT':    f"{p1_SpatialJoin_ParzellenEigentum_NurUnternutzung}|layername=unternutzung",
    'FIELD':    'typ_2',
    'OPERATOR': 0,
    'VALUE':    'Baulücke',
    'OUTPUT':   f"ogr:dbname='{p3_Extract_ParzellenEigentum_Bauluecke}' table=\"parzellen_bauluecke\" (geom)"
    })

# 8. Leerstände
processing.run("native:extractbyattribute", {
    'INPUT':    f"{p1_SpatialJoin_ParzellenEigentum_NurUnternutzung}|layername=unternutzung",
    'FIELD':    'typ_2',
    'OPERATOR': 0,
    'VALUE':    'Leerstand',
    'OUTPUT':   f"ogr:dbname='{p4_Extract_ParzellenEigentum_Leerstand}' table=\"parzellen_leerstand\" (geom)"
    })
