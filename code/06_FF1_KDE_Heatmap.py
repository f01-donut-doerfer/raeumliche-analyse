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
ripleyl_dir = os.path.join(workflow_dir, "5_FF1_RipleyL")
kde_dir     = os.path.join(workflow_dir, "6_FF1_KDE_Heatmap")

for d in [kde_dir]:
    os.makedirs(d, exist_ok=True)

# --- DATEIPFADE: Inputs ---
p0_point_leerstand      = os.path.join(ripleyl_dir, "1_punkte_leerstand.gpkg")
p0_point_bauluecke      = os.path.join(ripleyl_dir, "2_punkte_bauluecke.gpkg")
p0_point_bauvorhaben    = os.path.join(ripleyl_dir, "3_punkte_bauvorhaben.gpkg")


# --- DATEIPFADE: Outputs ---
p0_KDE_Heatmap_Leerstand        = os.path.join(kde_dir, "0_KDE_Heatmap_Leerstand.tif")
p1_KDE_Heatmap_Bauluecke        = os.path.join(kde_dir, "1_KDE_Heatmap_Bauluecke.tif")
p2_KDE_Heatmap_Bauvorhaben      = os.path.join(kde_dir, "2_KDE_Heatmap_Bauvorhaben.tif")

# Parameter aus der Ripley-L-Funktion
mikros  = 110 # mikrostrukturell
mesos   = 218 # mesostrukturell
makros  = 260 # makrostrukturell

# --- HAUPTPROZESSIERUNG ---

# Leerstaende
processing.run("qgis:heatmapkerneldensityestimation", {
    'INPUT': f"{p0_point_leerstand}|layername=point_leerstand",
    'RADIUS': mesos,
    'RADIUS_FIELD': '',
    'PIXEL_SIZE': 1,
    'WEIGHT_FIELD': '',
    'KERNEL': 0,
    'DECAY': 0,
    'OUTPUT_VALUE': 0,
    'OUTPUT': p0_KDE_Heatmap_Leerstand
})

# Bauluecken
processing.run("qgis:heatmapkerneldensityestimation", {
    'INPUT': f"{p0_point_bauluecke}|layername=point_bauluecke",
    'RADIUS': mesos,
    'RADIUS_FIELD': '',
    'PIXEL_SIZE': 1,
    'WEIGHT_FIELD': '',
    'KERNEL': 0,
    'DECAY': 0,
    'OUTPUT_VALUE': 0,
    'OUTPUT': p1_KDE_Heatmap_Bauluecke
})

# Aktive Bauvorhaben
processing.run("qgis:heatmapkerneldensityestimation", {
    'INPUT': f"{p0_point_bauvorhaben}|layername=point_bauvorhaben",
    'RADIUS': mesos,
    'RADIUS_FIELD': '',
    'PIXEL_SIZE': 1,
    'WEIGHT_FIELD': '',
    'KERNEL': 0,
    'DECAY': 0,
    'OUTPUT_VALUE': 0,
    'OUTPUT': p2_KDE_Heatmap_Bauvorhaben
})
