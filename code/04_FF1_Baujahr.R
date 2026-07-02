# Pakete: sf, dplyr
required_pkgs <- c("sf", "dplyr")
to_install    <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install)

library(sf)
library(dplyr)
options(rlang_backtrace_on_error = "none")



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

aggr_dir   <- file.path(workflow_dir, "0_TF1_Aggregation")
untern_dir <- file.path(workflow_dir, "1_TF1_Unternutzung")
hotsp_dir  <- file.path(workflow_dir, "2_TF1_Hotspots")
tab_dir    <- file.path(workflow_dir, "3_TF2_Tabellen")
bauj_dir   <- file.path(workflow_dir, "4_FF1_Baujahr")
kde_dir    <- file.path(workflow_dir, "5_FF1_KDE")

if (!dir.exists(bauj_dir)) dir.create(bauj_dir, recursive = TRUE)

# === DATEIPFADE: Inputs ===
path_gebaeudealter  <- file.path(input_dir, "zensus2022_gebaeudeJZ.gpkg")
layer_gebaeudealter <- "zensus2022_baujahr_jz_100mgitter"
path_ortslage       <- file.path(input_dir, "dlm_ortslage.gpkg")

# === DATEIPFADE: Outputs ===
out_grid          <- file.path(bauj_dir, "0_Grid_zensus2022_Baujahr.gpkg")
out_grid_ortslage <- file.path(bauj_dir, "1_Grid_Ortslage.gpkg")
out_sj_gebaeude   <- file.path(bauj_dir, "2_SpatialJoin_Grid_Baujahr.gpkg")

TARGET_CRS <- 3035



# ===
# BLOCK 1: GITTERNETZ ERSTELLEN
# ===
message(">>> Block 1: Gitternetz erstellen ...")

# Gebäudealter-Punkte laden
pts_gebaeude <- st_read(path_gebaeudealter, layer = layer_gebaeudealter, quiet = TRUE) %>%
  st_transform(TARGET_CRS)

# Extent der Punkte ermitteln
bbox <- st_bbox(pts_gebaeude)

# Gitternetz so ausrichten, dass Mittelpunkte auf den Punkten liegen:
# Zensus-100m-Gitter hat Koordinaten, die auf 50m-Vielfache ausgerichtet sind
# (Mittelpunkt = Koordinate des Punktes → Zelle geht von -50 bis +50 um den Punkt)
x_min <- floor((bbox["xmin"] - 50) / 100) * 100 + 50
x_max <- ceiling((bbox["xmax"] + 50) / 100) * 100 - 50
y_min <- floor((bbox["ymin"] - 50) / 100) * 100 + 50
y_max <- ceiling((bbox["ymax"] + 50) / 100) * 100 - 50

# Gitterzellen erzeugen (cellsize = 100m)
# Koordinaten als reine numerische Werte übergeben (vermeidet NA in st_as_sfc)
grid <- st_make_grid(
  what     = "polygons",
  cellsize = 100,
  square   = TRUE,
  offset   = c(as.numeric(x_min) - 50, as.numeric(y_min) - 50),
  n        = c(
    ceiling((as.numeric(x_max) - as.numeric(x_min) + 100) / 100),
    ceiling((as.numeric(y_max) - as.numeric(y_min) + 100) / 100)
  ),
  crs      = TARGET_CRS
) %>%
  st_as_sf() %>%
  mutate(grid_id = row_number())

st_write(grid, out_grid, delete_dsn = TRUE, quiet = TRUE)
message("    Gitternetz gespeichert: ", out_grid)

# ===
# BLOCK 2: GITTERNETZ AUF ORTSLAGE UND GEBÄUDEALTER-PUNKTE ZUSCHNEIDEN
# ===
message(">>> Block 2: Gitternetz auf Ortslage + Gebäudealter-Punkte beschränken ...")

ortslage <- st_read(path_ortslage, quiet = TRUE) %>%
  st_transform(TARGET_CRS)

# Nur Zellen behalten, die BEIDE Bedingungen erfüllen:
# 1. Innerhalb der Ortslage (intersect)
# 2. Enthalten mindestens einen Gebäudealter-Punkt
in_ortslage   <- st_intersects(grid, st_union(ortslage), sparse = FALSE)[, 1]
has_gebaeude  <- lengths(st_intersects(grid, pts_gebaeude)) > 0

grid_within <- grid[in_ortslage & has_gebaeude, ]

st_write(grid_within, out_grid_ortslage, delete_dsn = TRUE, quiet = TRUE)
message("    Gitternetz gespeichert: ", out_grid_ortslage,
        " (", nrow(grid_within), " Zellen)")

# ===
# BLOCK 3: GEBÄUDEALTER-PUNKTE AUFBEREITEN & SPATIAL JOIN INS GITTERNETZ
# ===
message(">>> Block 3: Gebäudealter aufbereiten ...")

# Alterskategorien-Felder
alter_felder <- c("Vor1919", "a1919bis1949", "a1950bis1959",
                  "a1960bis1969", "a1970bis1979", "a1980bis1989",
                  "a1990bis1999", "a2000bis2009", "a2010bis2015",
                  "a2016undspaeter")

# Dummy-Codes (ordinale Zahlen) für jede Alterskategorie
# Diese werden als separate Felder angelegt: z.B. Vor1919_code = 1
alter_codes <- c(
  Vor1919          = 1,
  a1919bis1949     = 2,
  a1950bis1959     = 3,
  a1960bis1969     = 4,
  a1970bis1979     = 5,
  a1980bis1989     = 6,
  a1990bis1999     = 7,
  a2000bis2009     = 8,
  a2010bis2015     = 9,
  a2016undspaeter  = 10
)

pts_clean <- pts_gebaeude %>%
  # Schritt 1: '–' durch 0 ersetzen und in Integer umwandeln
  mutate(across(
    all_of(alter_felder),
    ~ as.integer(ifelse(. == "\u2013" | . == "-" | is.na(.), 0L, as.integer(.)))
  )) %>%
  # Schritt 2: Ordinale Dummy-Code-Felder anlegen
  mutate(
    Vor1919_code          = ifelse(Vor1919          > 0, alter_codes["Vor1919"],          0L),
    a1919bis1949_code     = ifelse(a1919bis1949     > 0, alter_codes["a1919bis1949"],     0L),
    a1950bis1959_code     = ifelse(a1950bis1959     > 0, alter_codes["a1950bis1959"],     0L),
    a1960bis1969_code     = ifelse(a1960bis1969     > 0, alter_codes["a1960bis1969"],     0L),
    a1970bis1979_code     = ifelse(a1970bis1979     > 0, alter_codes["a1970bis1979"],     0L),
    a1980bis1989_code     = ifelse(a1980bis1989     > 0, alter_codes["a1980bis1989"],     0L),
    a1990bis1999_code     = ifelse(a1990bis1999     > 0, alter_codes["a1990bis1999"],     0L),
    a2000bis2009_code     = ifelse(a2000bis2009     > 0, alter_codes["a2000bis2009"],     0L),
    a2010bis2015_code     = ifelse(a2010bis2015     > 0, alter_codes["a2010bis2015"],     0L),
    a2016undspaeter_code  = ifelse(a2016undspaeter  > 0, alter_codes["a2016undspaeter"],  0L)
  )

# Schritt 3: Spatial Join Punkte -> Gitternetz (1:1, kein join_count nötig)
# st_join mit largest = FALSE nimmt das erste/einzige matchende Polygon
sj_gebaeude <- st_join(
  grid_within,
  pts_clean %>% select(-any_of("grid_id")),  # grid_id nicht doppelt
  join    = st_intersects,
  left    = TRUE,
  suffix  = c("", "_pt")
)

# Schritt 4: Dominante Epoche je Zelle (Epoche mit den meisten Gebäuden, Code 1 bis 10)
sj_gebaeude <- sj_gebaeude %>%
  mutate(
    dom_epoche = apply(
      cbind(Vor1919, a1919bis1949, a1950bis1959, a1960bis1969, a1970bis1979,
            a1980bis1989, a1990bis1999, a2000bis2009, a2010bis2015, a2016undspaeter),
      1,
      function(x) {
        if (all(is.na(x)) || all(x == 0, na.rm = TRUE)) NA_integer_
        else which.max(replace(x, is.na(x), 0L))
      }
    ),
    dom_epoche = as.integer(dom_epoche)
  )

st_write(sj_gebaeude, out_sj_gebaeude, delete_dsn = TRUE, quiet = TRUE)
message("    Gebäudealter-Join gespeichert: ", out_sj_gebaeude)

# ===
# ZUSAMMENFASSUNG
# ===
message("Alle Outputs gespeichert in: ", bauj_dir)
message("  0_Grid_zensus2022_gebaeudealter.gpkg")
message("  1_Grid_Ortslage.gpkg")
message("  2_SpatialJoin_Grid_gebaeudealter.gpkg")
