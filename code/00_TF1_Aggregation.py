import os

# --- ORDNERSTRUKTUR mit relativen Pfaden ---
try:
    worksp = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
except NameError:
    worksp = "/Path/to/Folder" # Pfad zum Ordner, falls __file__ nicht funktioniert
    
input_dir       = os.path.join(worksp, "input")
workflow_dir    = os.path.join(worksp, "workflow")
output_dir      = os.path.join(worksp, "output")

aggr_dir    = os.path.join(workflow_dir, "0_TF1_Aggregation")
untern_dir  = os.path.join(workflow_dir, "1_TF1_Unternutzung")
hotsp_dir   = os.path.join(workflow_dir, "2_TF1_Hotspots")
tab_dir     = os.path.join(workflow_dir, "3_TF2_Tabellen")
bauj_dir    = os.path.join(workflow_dir, "4_FF1_Baujahr")
kde_dir     = os.path.join(workflow_dir, "5_FF1_KDE")

for d in [aggr_dir]:
    os.makedirs(d, exist_ok=True)

# --- DATEIPFADE: Inputs ---
alkis_flurstueck = os.path.join(input_dir, "alkis_flurstueck.gpkg")
alkis_nutzung    = os.path.join(input_dir, "alkis_nutzung.gpkg")
dlm_ortslage     = os.path.join(input_dir, "dlm_ortslage.gpkg")
eigentumsdaten   = os.path.join(input_dir, "eigentumsdaten_verarbeitet.xlsx")

# --- DATEIPFADE: Zwischenergebnisse ---
p0_SpatialJoin_Nutzung_Flurstueck           = os.path.join(aggr_dir, "0_SpatialJoin_Nutzung_Flurstueck.gpkg")
p1_Korrektur_Landnutzung                    = os.path.join(aggr_dir, "1_Korrektur_Landnutzung.gpkg")
p2_Join_Eigentumsdaten_Parzellen            = os.path.join(aggr_dir, "2_Join_Eigentumsdaten_Parzellen.gpkg")
p3_Aggregate_ParzellenEigentum_Flurstueck   = os.path.join(aggr_dir, "3_Aggregate_ParzellenEigentum_Flurstueck.gpkg")
p4_Clip_ParzellenEigentum_Ortslage          = os.path.join(aggr_dir, "4_Clip_ParzellenEigentum_Ortslage.gpkg")

# --- HAUPTPROZESSIERUNG ---

# 0. Spatial Join der Landnutzungsdaten in die Flurstücksparzellen
processing.run("native:joinattributesbylocation", {
    'INPUT':               f"{alkis_flurstueck}|layername=parcels",
    'PREDICATE':           [0],
    'JOIN':                f"{alkis_nutzung}|layername=landuse",
    'JOIN_FIELDS':         ['layer'],
    'METHOD':              2,
    'DISCARD_NONMATCHING': False,
    'PREFIX':              '',
    'OUTPUT':              f"ogr:dbname='{p0_SpatialJoin_Nutzung_Flurstueck}' table=\"parcels_landnutzung\" (geom)"
    })

# 1. Manuelle Nachkorrektur der Landnutzung für einzelne Flurstücke
processing.run("native:fieldcalculator", {
    'INPUT':           f"{p0_SpatialJoin_Nutzung_Flurstueck}|layername=parcels_landnutzung",
    'FIELD_NAME':      'layer',
    'FIELD_TYPE':      2,
    'FIELD_LENGTH':    0,
    'FIELD_PRECISION': 0,
    'FORMULA':         "CASE WHEN \"flurstueckskennzeichen\" IN ('074408000028720009__','074408000028720020__','074408000028720025__','074408000006510011__') THEN 'AX_Wohnbauflaeche' WHEN \"flurstueckskennzeichen\" = '074408000006940005__' THEN 'AX_Landwirtschaft' ELSE \"layer\" END",
    'OUTPUT':          f"ogr:dbname='{p1_Korrektur_Landnutzung}' table=\"parcels_landnutzung\" (geom)"
    })

# 1. Join der Eigentumsdaten in die Parzellen über das Flurstückskennzeichen
processing.run("native:joinattributestable", {
    'INPUT':               f"{p1_Korrektur_Landnutzung}|layername=parcels_landnutzung",
    'FIELD':               'flurstueckskennzeichen',
    'INPUT_2':             eigentumsdaten,
    'FIELD_2':             'FSK',
    'FIELDS_TO_COPY':[
        'Buchungsart',
        # 'Nachname',
        # 'Vorname',
        'Typ',
        'Eigentümer_Gruppe_ID',
        'Anzahl_Eigentümer_pro_Flurstück',
        'Anzahl_Flurstücke_pro_Eigentümer',
        'Alter'],
    'METHOD':              0,
    'DISCARD_NONMATCHING': True,
    'PREFIX':              '',
    'OUTPUT':              f"ogr:dbname='{p2_Join_Eigentumsdaten_Parzellen}' table=\"parcels_eigentumsdaten\" (geom)"
    })

# 2. Aggregation der Eigentümer:innen nach Flurstückskennzeichen
processing.run("native:aggregate", {
    'INPUT':    f"{p2_Join_Eigentumsdaten_Parzellen}|layername=parcels_eigentumsdaten",
    'GROUP_BY': '"flurstueckskennzeichen"',
    'AGGREGATES':[
        {
            'aggregate':    'first_value',
            'delimiter':    '',
            'input':        '"fid"',
            'length':       0,
            'name':         'fid',
            'precision':    0,
            'sub_type':     0,
            'type':         4,
            'type_name':    'int8'},
        {
            'aggregate':    'first_value',
            'delimiter':    '',
            'input':        '"flurstueckskennzeichen"',
            'length':       20,
            'name':         'flurstueckskennzeichen',
            'precision':    0,
            'sub_type':     0,
            'type':         10,
            'type_name':    'text'},
        {
            'aggregate':    'first_value',
            'delimiter':    '',
            'input':        '"layer"',
            'length':       0,
            'name':         'landnutzung',
            'precision':    0,
            'sub_type':     0,
            'type':         10,
            'type_name':    'text'},
        {
            'aggregate':    'first_value',
            'delimiter':    '',
            'input':        '"Buchungsart"',
            'length':       0,
            'name':         'Buchungsart',
            'precision':    0,
            'sub_type':     0,
            'type':         10,
            'type_name':    'text'},
        # {
           # 'aggregate':    'concatenate',
           # 'delimiter':    ', ',
           # 'input':        '"Nachname"',
           # 'length':       0,
           # 'name':         'Nachname',
           # 'precision':    0,
           # 'sub_type':     0,
           # 'type':         10,
           # 'type_name':    'text'},
        # {
           # 'aggregate':    'concatenate',
           # 'delimiter':    ', ',
           # 'input':        '"Vorname"',
           # 'length':       0,
           # 'name':         'Vorname',
           # 'precision':    0,
           # 'sub_type':     0,
           # 'type':         10,
           # 'type_name':    'text'},
        {
            'aggregate':    'concatenate_unique',
            'delimiter':    '',
            'input':        "CASE WHEN \"Buchungsart\" ILIKE '%erbbaurecht%' THEN NULL ELSE \"Typ\" END",
            'length':       0,
            'name':         'Typ',
            'precision':    0,
            'sub_type':     0,
            'type':         10,
            'type_name':    'text'},
        {
            'aggregate':    'first_value',
            'delimiter':    ',',
            'input':        '"Eigentümer_Gruppe_ID"',
            'length':       0,
            'name':         'Eigentümer_Gruppe_ID',
            'precision':    0,
            'sub_type':     0,
            'type':         2,
            'type_name':    'integer'},
        {
            'aggregate':    'first_value',
            'delimiter':    '',
            'input':        '"Anzahl_Eigentümer_pro_Flurstück"',
            'length':       0,
            'name':         'Anzahl_Eigentümer_pro_Flurstück',
            'precision':    0,
            'sub_type':     0,
            'type':         2,
            'type_name':    'integer'},
        {
            'aggregate':    'mean',
            'delimiter':    '',
            'input':        '"Anzahl_Flurstücke_pro_Eigentümer"',
            'length':       0,
            'name':         'Anzahl_Flurstücke_pro_Eigentümer',
            'precision':    2,
            'sub_type':     0,
            'type':         6,
            'type_name':    'double precision'},
        {
            'aggregate':    'mean',
            'delimiter':    '',
            'input':        '"Alter"',
            'length':       0,
            'name':         'Alter',
            'precision':    2,
            'sub_type':     0,
            'type':         6,
            'type_name':    'double precision'}],
    'OUTPUT':   f"ogr:dbname='{p3_Aggregate_ParzellenEigentum_Flurstueck}' table=\"parcels_aggregated\" (geom)"
    })

# 3. Reduktion auf den direkten Siedlungskörper / die Ortslage
processing.run("native:clip", {
    'INPUT':   f"{p3_Aggregate_ParzellenEigentum_Flurstueck}|layername=parcels_aggregated",
    'OVERLAY': dlm_ortslage,
    'OUTPUT':  f"ogr:dbname='{p4_Clip_ParzellenEigentum_Ortslage}' table=\"eigentum_ortslage\" (geom)"
    })
