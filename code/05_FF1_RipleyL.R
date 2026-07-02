# Pakete: sf, dplyr
required_pkgs <- c("sf", "dplyr", "spatstat.geom", "spatstat.explore")
to_install    <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install)

library(sf)
library(dplyr)

# ===
# Ordnerstruktur relativ ermitteln
# ===

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

aggr_dir    <- file.path(workflow_dir, "0_TF1_Aggregation")
untern_dir  <- file.path(workflow_dir, "1_TF1_Unternutzung")
hotsp_dir   <- file.path(workflow_dir, "2_TF1_Hotspots")
tab_dir     <- file.path(workflow_dir, "3_TF2_Tabellen")
bauj_dir    <- file.path(workflow_dir, "4_FF1_Baujahr")
ripleyl_dir <- file.path(workflow_dir, "5_FF1_RipleyL")
kde_dir     <- file.path(workflow_dir, "5_FF1_KDE_Heatmap")

if (!dir.exists(ripleyl_dir)) dir.create(ripleyl_dir, recursive = TRUE)



# ===
# 2. KONFIGURATION
# ===

cfg <- list(
  gpkg_unternutzungen  = file.path(untern_dir, "1_SpatialJoin_ParzellenEigentum_NurUnternutzung.gpkg"),
  layer_unternutzungen = "unternutzung",
  col_art   = "typ_2",
  art_werte = c(leerstand   = "Leerstand",
                bauluecke   = "Baulücke",
                bauvorhaben = "Aktives Bauvorhaben"),
  col_eigentuemer = "Typ",

  gpkg_gebiet  = file.path(input_dir, "dlm_ortslage.gpkg"),
  layer_gebiet = "dlm_rp_sie01f",

  crs = 25832,

  # Ripley-K über ALLE Punkte als Konsolenausgabe:
  ripley_diagnose = TRUE,
  diagnose_rmax   = 300,

  # Separate Ausgabe-GeoPackages je Punktart
  out_alle        = file.path(ripleyl_dir, "0_punkte_alle.gpkg"),
  out_leerstand   = file.path(ripleyl_dir, "1_punkte_leerstand.gpkg"),
  out_bauluecke   = file.path(ripleyl_dir, "2_punkte_bauluecke.gpkg"),
  out_bauvorhaben = file.path(ripleyl_dir, "3_punkte_bauvorhaben.gpkg")
)

# ===
# 3. HILFSFUNKTIONEN
# ===

prep_layer <- function(g) suppressWarnings(sf::st_centroid(g))

# Ripley-K-Funktion über die kombinierten Punkte (nur Konsolenausgabe)
ripley_k <- function(xy, gebiet_sf, r_max = 300) {
  if (!requireNamespace("spatstat.geom", quietly = TRUE) ||
      !requireNamespace("spatstat.explore", quietly = TRUE)) {
    message("spatstat nicht installiert, Ripley-K übersprungen.")
    return(invisible(NULL))
  }
  win <- spatstat.geom::as.owin(sf::st_geometry(sf::st_union(gebiet_sf)))
  pp  <- spatstat.geom::ppp(xy[, 1], xy[, 2], window = win)
  spatstat.explore::Kest(pp, correction = "Ripley", rmax = r_max)
}

# ===
# 4. DATEN LADEN
# ===

gebiet <- sf::st_read(cfg$gpkg_gebiet, cfg$layer_gebiet, quiet = TRUE) |>
  sf::st_transform(cfg$crs)

un <- sf::st_read(cfg$gpkg_unternutzungen, cfg$layer_unternutzungen, quiet = TRUE) |>
  sf::st_transform(cfg$crs)
stopifnot(cfg$col_art %in% names(un), cfg$col_eigentuemer %in% names(un))

# ===
# 5. TEIL-DATENSÄTZE
# ===

teil <- list(
  leerstand   = un[un[[cfg$col_art]] == cfg$art_werte["leerstand"],   ],
  bauluecke   = un[un[[cfg$col_art]] == cfg$art_werte["bauluecke"],   ],
  bauvorhaben = un[un[[cfg$col_art]] == cfg$art_werte["bauvorhaben"], ]
)
prep <- lapply(teil, prep_layer)

cat("Fallzahlen je Art:\n"); print(sapply(prep, nrow))

# ===
# 6. PUNKTLAYER BAUEN (art, eigentuemer, geometry)
# ===

mk_pts <- function(art) {
  p <- prep[[art]]
  sf::st_sf(
    art         = art,
    eigentuemer = as.character(p[[cfg$col_eigentuemer]]),
    geometry    = sf::st_geometry(p)
  )
}
pts <- lapply(setNames(names(prep), names(prep)), mk_pts)
punkte_alle <- do.call(rbind, pts)
# separate Layer je Art (zum getrennten Stylen in QGIS)
punkte_leerstand   <- pts$leerstand
punkte_bauluecke   <- pts$bauluecke
punkte_bauvorhaben <- pts$bauvorhaben



# ===
# 7. RIPLEY-L: Distanzen der stärksten Clusterung (mehrere Peaks)
# ===

if (cfg$ripley_diagnose &&
    requireNamespace("spatstat.geom", quietly = TRUE) &&
    requireNamespace("spatstat.explore", quietly = TRUE)) {
  
  win <- spatstat.geom::as.owin(sf::st_geometry(sf::st_union(gebiet)))
  xy  <- sf::st_coordinates(punkte_alle)
  pp  <- spatstat.geom::ppp(xy[, 1], xy[, 2], window = win)
  L   <- spatstat.explore::Lest(pp, correction = "Ripley", rmax = cfg$diagnose_rmax)
  
  r      <- L$r
  exzess <- L$iso - r            # L(r) - r ; > 0 bedeutet Clusterung
  dr     <- mean(diff(r))
  
  # Stellschrauben
  glaett_m <- 8     # Glättungsfenster gegen das Rauschen (m)
  such_m   <- 25    # Suchfenster + Mindestabstand zwischen Peaks (m)
  anteil   <- 0.50  # Peak muss mind. 50 % des stärksten Peaks erreichen
  
  # leichte Glättung
  fb       <- max(1, round(glaett_m / dr))
  exzess_g <- as.numeric(stats::filter(exzess, rep(1 / (2 * fb + 1), 2 * fb + 1)))
  exzess_g[is.na(exzess_g)] <- exzess[is.na(exzess_g)]
  
  # lokale Maxima im Fenster +/- such_m finden
  w     <- max(1, round(such_m / dr))
  peaks <- which(vapply(seq_along(exzess_g), function(k) {
    lo <- max(1, k - w); hi <- min(length(exzess_g), k + w)
    exzess_g[k] == max(exzess_g[lo:hi]) && exzess_g[k] > 0
  }, logical(1)))
  
  # nur deutliche Peaks, dicht beieinanderliegende zusammenfassen
  if (length(peaks) > 0) {
    peaks <- peaks[exzess_g[peaks] >= anteil * max(exzess_g[peaks])]
    behalten <- integer(0)
    for (p in peaks[order(-exzess_g[peaks])])
      if (all(abs(r[p] - r[behalten]) > such_m)) behalten <- c(behalten, p)
    peaks <- sort(behalten)
  }
  
  cat("\nClusterungs-Distanzen (lokale Maxima von L(r) - r):\n")
  for (p in peaks)
    cat(sprintf("  r = %3.0f m   L(r) - r = %.1f\n", r[p], exzess[p]))
  
  # Grafik mit etwas Kopfraum für die Beschriftungen
  yr <- range(exzess)
  plot(r, exzess, type = "l",
       ylim = c(yr[1], yr[2] + 0.18 * diff(yr)),
       xlab = "Distanz r (m)", ylab = "L(r) - r",
       main = "Ripley-L: Clusterung über Distanz")
  abline(h = 0, lty = 2)
  for (p in peaks) {
    abline(v = r[p], col = "red", lty = 3)
    points(r[p], exzess[p], col = "red", pch = 19)
    text(r[p], exzess[p],
         labels = sprintf("%.0f m\nL-r = %.0f", r[p], exzess[p]),
         pos = 3, col = "red", cex = 0.85, xpd = NA)
  }
}



# ===
# 8. GEOPACKAGES SCHREIBEN (je Punktart eine eigene Datei)
# ===

schreibe_gpkg <- function(layer, pfad, name) {
  if (file.exists(pfad)) file.remove(pfad)
  sf::st_write(layer, pfad, name, delete_layer = TRUE, quiet = TRUE)
}

schreibe_gpkg(punkte_alle,        cfg$out_alle,        "point_alle")
schreibe_gpkg(punkte_leerstand,   cfg$out_leerstand,   "point_leerstand")
schreibe_gpkg(punkte_bauluecke,   cfg$out_bauluecke,   "point_bauluecke")
schreibe_gpkg(punkte_bauvorhaben, cfg$out_bauvorhaben, "point_bauvorhaben")

cat("\nFertig. Punkt-GeoPackages in:", normalizePath(kde_dir), "\n")
cat("  0_Point_Unternutzung.gpkg\n")
cat("  1_Point_leerstand.gpkg\n")
cat("  2_Point_bauluecke.gpkg\n")
cat("  3_Point_bauvorhaben.gpkg\n")
