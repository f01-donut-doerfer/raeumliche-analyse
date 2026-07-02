# Pakete: sf, spdeg, dplyr
required_pkgs <- c("sf", "spdep", "dplyr")
to_install    <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install)

library(sf)
library(spdep)
library(dplyr)

# ---
# Ordnerstruktur relativ ermitteln
# ---

# Workspace
skript_verzeichnis <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  }
  of <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(of)) {
    return(dirname(normalizePath(of)))
  }
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    p <- tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) "")
    if (!is.null(p) && nzchar(p)) return(dirname(normalizePath(p)))
  }
  NA_character_
}

.sk <- skript_verzeichnis()
if (!is.na(.sk)) {
  worksp <- normalizePath(file.path(.sk, ".."))
} else {
  worksp <- "/Volumes/Untitled/M03" # fester Pfad, falls Ermittlung nicht funktioniert
}

# Directories im Workspace
input_dir    <- file.path(worksp, "input")
workflow_dir <- file.path(worksp, "workflow")
output_dir   <- file.path(worksp, "output")

aggr_dir   <- file.path(workflow_dir, "0_TF1_Aggregation")
untern_dir <- file.path(workflow_dir, "1_TF1_Unternutzung")
hotsp_dir  <- file.path(workflow_dir, "2_TF1_Hotspots")
tab_dir    <- file.path(workflow_dir, "3_TF2_Tabellen")
bauj_dir   <- file.path(workflow_dir, "4_FF1_Baujahr")
kde_dir    <- file.path(workflow_dir, "5_FF1_KDE")

if (!dir.exists(hotsp_dir)) dir.create(hotsp_dir, recursive = TRUE)

# === DATEIPFADE: Inputs ===
ortslage_pfad <- file.path(aggr_dir, "4_Clip_ParzellenEigentum_Ortslage.gpkg")

# === DATEIPFADE: Outputs ===
gpkg_anzahl <- file.path(hotsp_dir, "0_Hotspots_AnzahlFSEig_AnzahlEigFS.gpkg")
gpkg_alter  <- file.path(hotsp_dir, "1_Hotspots_Alter.gpkg")





# 2. Daten einlesen
data <- st_read(ortslage_pfad)

# 3. Zentroide & Koordinaten (für alle Felder außer Alter)
data_centroids <- st_centroid(data)
coords <- st_coordinates(data_centroids)

# 4. Kopie ohne NAs für Alter
data_alter   <- data[!is.na(data$Alter), ]
coords_alter <- st_coordinates(st_centroid(data_alter))
cat("Features für Alter-Analyse:", nrow(data_alter), "\n")


# ===
# STUFE 1 & 2: ISA + G* für Anzahl_Eigentümer_pro_Flurstück
#                        und Anzahl_Flurstücke_pro_Eigentümer
# ===

felder_main <- c("Anzahl_Eigentümer_pro_Flurstück",
                 "Anzahl_Flurstücke_pro_Eigentümer")

opt_distanzen <- c()

for (feld in felder_main) {
  cat("\n=== ISA (grob) für:", feld, "===\n")

  # Grober Durchlauf
  distanzen_grob <- seq(50, 500, by = 25)

  moran_grob <- sapply(distanzen_grob, function(d) {
    nb <- dnearneigh(coords, d1 = 0, d2 = d)
    if (any(card(nb) == 0)) return(NA)
    lw <- nb2listw(nb, style = "B", zero.policy = TRUE)
    mi <- moran.test(data[[feld]], lw, zero.policy = TRUE)
    return(mi$estimate["Moran I statistic"])
  })

  opt_grob <- distanzen_grob[which.max(moran_grob)]
  cat("Grobe optimale Distanz:", opt_grob, "m\n")

  # Feiner Durchlauf
  distanzen_fein <- seq(max(10, opt_grob - 40), opt_grob + 40, by = 10)

  moran_fein <- sapply(distanzen_fein, function(d) {
    nb <- dnearneigh(coords, d1 = 0, d2 = d)
    if (any(card(nb) == 0)) return(NA)
    lw <- nb2listw(nb, style = "B", zero.policy = TRUE)
    mi <- moran.test(data[[feld]], lw, zero.policy = TRUE)
    return(mi$estimate["Moran I statistic"])
  })

  opt_fein <- distanzen_fein[which.max(moran_fein)]
  cat("Feine optimale Distanz:", opt_fein, "m\n")
  opt_distanzen[feld] <- opt_fein

  # G* berechnen
  cat("=== G* Berechnung für:", feld, "===\n")
  nb_opt  <- dnearneigh(coords, d1 = 0, d2 = opt_fein)
  nb_self <- include.self(nb_opt)
  lw_self <- nb2listw(nb_self, style = "B", zero.policy = TRUE)

  data[[paste0("Gi_star_", feld)]] <- as.numeric(
    localG(data[[feld]], lw_self))

  data[[paste0("hotspot_", feld)]] <- cut(
    data[[paste0("Gi_star_", feld)]],
    breaks = c(-Inf, -2.58, -1.96, -1.65, 1.65, 1.96, 2.58, Inf),
    labels = c("Cold Spot 99%", "Cold Spot 95%", "Cold Spot 90%",
               "Nicht signifikant",
               "Hot Spot 90%", "Hot Spot 95%", "Hot Spot 99%"))

  cat("Klassenverteilung:\n")
  print(table(data[[paste0("hotspot_", feld)]]))
}


# ===
# STUFE 1 & 2: ISA + G* für Alter (mit NA-bereinigten Daten)
# ===

cat("\n=== ISA (grob) für: Alter ===\n")

# Grober Durchlauf mit coords_alter
distanzen_grob <- seq(50, 500, by = 25)

moran_grob_alter <- sapply(distanzen_grob, function(d) {
  nb <- dnearneigh(coords_alter, d1 = 0, d2 = d)
  if (any(card(nb) == 0)) return(NA)
  lw <- nb2listw(nb, style = "B", zero.policy = TRUE)
  mi <- moran.test(data_alter$Alter, lw, zero.policy = TRUE)
  return(mi$estimate["Moran I statistic"])
})

opt_grob_alter <- distanzen_grob[which.max(moran_grob_alter)]
cat("Grobe optimale Distanz Alter:", opt_grob_alter, "m\n")

# Feiner Durchlauf
distanzen_fein_alter <- seq(max(10, opt_grob_alter - 40), opt_grob_alter + 40, by = 10)

moran_fein_alter <- sapply(distanzen_fein_alter, function(d) {
  nb <- dnearneigh(coords_alter, d1 = 0, d2 = d)
  if (any(card(nb) == 0)) return(NA)
  lw <- nb2listw(nb, style = "B", zero.policy = TRUE)
  mi <- moran.test(data_alter$Alter, lw, zero.policy = TRUE)
  return(mi$estimate["Moran I statistic"])
})

opt_fein_alter <- distanzen_fein_alter[which.max(moran_fein_alter)]
cat("Feine optimale Distanz Alter:", opt_fein_alter, "m\n")
opt_distanzen["Alter"] <- opt_fein_alter

# G* für Alter berechnen
cat("=== G* Berechnung für: Alter ===\n")
nb_opt_alter  <- dnearneigh(coords_alter, d1 = 0, d2 = opt_fein_alter)
nb_self_alter <- include.self(nb_opt_alter)
lw_self_alter <- nb2listw(nb_self_alter, style = "B", zero.policy = TRUE)

data_alter$Gi_star_Alter <- as.numeric(
  localG(data_alter$Alter, lw_self_alter))

data_alter$hotspot_Alter <- cut(
  data_alter$Gi_star_Alter,
  breaks = c(-Inf, -2.58, -1.96, -1.65, 1.65, 1.96, 2.58, Inf),
  labels = c("Cold Spot 99%", "Cold Spot 95%", "Cold Spot 90%",
             "Nicht signifikant",
             "Hot Spot 90%", "Hot Spot 95%", "Hot Spot 99%"))

cat("Klassenverteilung Alter:\n")
print(table(data_alter$hotspot_Alter))


# ===
# STUFE 3: Ergebnisse als GeoPackage speichern
# ===

# Hauptdaten (ohne Alter)
st_write(data,
         gpkg_anzahl,
         driver = "GPKG",
         delete_dsn = TRUE)

# Alter separat
st_write(data_alter,
         gpkg_alter,
         driver = "GPKG",
         delete_dsn = TRUE)

# Übersicht optimale Distanzen
cat("\n=== Übersicht optimale Distanzen ===\n")
print(opt_distanzen)
cat("\nFertig. Alle Ergebnisse gespeichert.\n")
