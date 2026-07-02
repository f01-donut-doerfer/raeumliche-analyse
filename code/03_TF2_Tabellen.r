
# Pakete: sf, dplyr, tidyr, flextable, officer, scales
required_pkgs <- c("sf", "dplyr", "tidyr", "flextable", "officer", "scales")
to_install    <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install)

library(sf)
library(dplyr)
library(tidyr)
library(flextable)
library(officer)
library(scales)

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

if (!dir.exists(tab_dir)) dir.create(tab_dir, recursive = TRUE)

# === DATEIPFADE: Inputs ===
ortslage_pfad     <- file.path(aggr_dir,   "4_Clip_ParzellenEigentum_Ortslage.gpkg")
unternutzung_pfad <- file.path(untern_dir, "1_SpatialJoin_ParzellenEigentum_NurUnternutzung.gpkg")

# === DATEIPFADE: Output ===
word_datei <- "Tabellen_Unternutzungsanalyse.docx"


# 1. Daten einlesen
ortslage     <- st_read(ortslage_pfad,     quiet = TRUE)
unternutzung <- st_read(unternutzung_pfad, quiet = TRUE)

ol <- st_drop_geometry(ortslage)
un <- st_drop_geometry(unternutzung)

names(ol) <- trimws(names(ol))
names(un) <- trimws(names(un))

stopifnot("landnutzung" %in% names(ol))
stopifnot("Typ"         %in% names(ol))
stopifnot("typ_2"       %in% names(un))

# 2. Unternutzung filtern
un_typen <- c("Aktives Bauvorhaben", "Baulücke", "Leerstand")
un <- un %>% filter(typ_2 %in% un_typen)



# === HILFSFUNKTIONEN ===

# Globaler Zaehler und Sammlung aller Tabellen
.tab_nr   <- 0L
.tab_list <- list()


# Optik: Arial, fette Kopfzeile, keine Farben, drei horizontale Linien
#        (oben, unter Kopfzeile, unten), keine vertikalen Linien.
# Beschriftung: "Tabelle N: Titel" linksbuendig oberhalb der Tabelle (12 pt).
# Beschreibung kursiv unterhalb der Tabelle.
make_ft <- function(df, titel, untertitel = NULL,
                    pct_cols = character(0), abs_cols = character(0)) {

  .tab_nr <<- .tab_nr + 1L

  # Prozentspalten formatieren
  for (col in pct_cols) {
    df[[col]] <- paste0(formatC(df[[col]], format = "f", digits = 1), " %")
  }

  ft <- flextable(df) %>%

    # Dreistrichtabellen-Stil (booktabs)
    theme_booktabs() %>%

    # Schrift & Groesse
    font(fontname = "Arial", part = "all") %>%
    fontsize(size = 9, part = "all") %>%

    # Kopfzeile: fett, schwarz auf weiss
    bold(part = "header") %>%
    color(color = "black", part = "all") %>%
    bg(bg = "white", part = "all") %>%

    # Ausrichtung: erste Spalte links, Rest zentriert
    align(align = "center", part = "header") %>%
    align(align = "center", part = "body") %>%
    align(j = 1, align = "left", part = "body") %>%
    align(j = 1, align = "left", part = "header") %>%

    # Kompakter Innenabstand
    padding(padding.top    = 3, padding.bottom = 3,
            padding.left   = 5, padding.right  = 5, part = "all") %>%

    # Tabellenbreite: volle Seitenbreite
    set_table_properties(width = 1, layout = "autofit") %>%

    # Tabellenbeschriftung oberhalb: "Tabelle N: Titel" in 12 pt
    set_caption(
      caption = as_paragraph(
        as_chunk(paste0("Tabelle ", .tab_nr, ": ", titel),
                 props = fp_text(font.family = "Arial", font.size = 10, bold = TRUE))
      ),
      fp_p = fp_par(text.align = "left", padding.bottom = 4)
    )

  # Beschreibung als kursive Fusszeile
  if (!is.null(untertitel)) {
    ft <- ft %>%
      add_footer_lines(paste0(untertitel)) %>%
      font(fontname = "Arial", part = "footer") %>%
      fontsize(size = 8.5, part = "footer") %>%
      italic(part = "footer") %>%
      color(color = "#333333", part = "footer") %>%
      align(align = "left", part = "footer") %>%
      padding(padding.top = 3, padding.bottom = 2,
              padding.left = 0, padding.right = 0, part = "footer")
  }

  ft
}


# Tabelle zur Sammlung vormerken
sammle_tab <- function(ft) {
  .tab_list[[length(.tab_list) + 1]] <<- ft
  message("Tabelle ", length(.tab_list), " vorgemerkt.")
}


# Alle gesammelten Tabellen als Word-Dokument exportieren
speichere_word <- function(dateiname = word_datei) {

  doc <- read_docx()

  for (i in seq_along(.tab_list)) {
    # Abstandszeile zwischen den Tabellen (ausser vor der ersten)
    if (i > 1) {
      doc <- body_add_par(doc, " ", style = "Normal")
    }
    doc <- body_add_flextable(doc, .tab_list[[i]])
  }

  pfad <- file.path(tab_dir, dateiname)
  print(doc, target = pfad)
  message("\nAlle ", length(.tab_list), " Tabellen gespeichert in: ", pfad)
}


# === Tabelle 1: Uebersicht ueber den Aufbau der Kreuztabellen ===
# Zeilen: Unternutzungsdimension, Spalten: Querschnittsdimension.
# Jede Zelle verweist auf die Tabelle, in der diese Kreuzung steht.
querschnittsmatrix <- data.frame(
  dimension                   = c("Unternutzung", "Leerstände", "Baulücken", "Aktive Bauvorhaben"),
  Gesamt                      = c("Tabelle 3", "-", "-", "-"),
  `Nach Landnutzung`          = c("Tabelle 4", "Tabelle 6", "Tabelle 7", "Tabelle 8"),
  `Nach Eigentümer:innen-Typ` = c("Tabelle 5", "Tabelle 9", "Tabelle 10", "Tabelle 11"),
  check.names = FALSE
)

tab_uebersicht <- make_ft(
  querschnittsmatrix,
  titel      = "Querschnittsmatrix",
  untertitel = "Jede Zelle verweist auf eine Tabelle, in welcher die Unternutzungsart mit einem anderen Attribut gekreuzt wird."
)
tab_uebersicht <- set_header_labels(tab_uebersicht, dimension = "")
sammle_tab(tab_uebersicht)


# === BLOCK 1: Unternutzungstypen an der gesamten Unternutzung ===
n_un_gesamt <- nrow(un)

block1 <- un %>%
  count(typ_2, name = "Anzahl Flurstücke") %>%
  mutate(`Anteil an Unternutzung [%]` = round(`Anzahl Flurstücke` / n_un_gesamt * 100, 1)) %>%
  rename(`Art der Unternutzung` = typ_2)

tab1 <- make_ft(
  block1,
  titel      = "Anteile der Unternutzungstypen an der gesamten Unternutzung",
  untertitel = paste0("Gesamtzahl unternutzter Flurstücke: ", n_un_gesamt),
  pct_cols   = "Anteil an Unternutzung [%]"
)
sammle_tab(tab1)


# === BLOCK 2: Unternutzung nach LANDNUTZUNG ===
ln_gesamt    <- ol %>% count(landnutzung, name = "n_gesamt")
ln_un_gesamt <- un %>% count(landnutzung, name = "n_unternutzt")
ln_un_typ    <- un %>%
  count(landnutzung, typ_2) %>%
  pivot_wider(names_from = typ_2, values_from = n, values_fill = 0)

block2 <- ln_gesamt %>%
  left_join(ln_un_gesamt, by = "landnutzung") %>%
  left_join(ln_un_typ,    by = "landnutzung") %>%
  mutate(across(where(is.numeric) & !n_gesamt, \(x) replace(x, is.na(x), 0))) %>%
  mutate(
    `Unternutzung [%]`        = round(n_unternutzt / n_gesamt * 100, 1),
    `Aktives Bauvorhaben [%]` = round(if ("Aktives Bauvorhaben" %in% names(.)) `Aktives Bauvorhaben` / n_gesamt * 100 else 0, 1),
    `Baulücke [%]`            = round(if ("Baulücke"            %in% names(.)) `Baulücke`            / n_gesamt * 100 else 0, 1),
    `Leerstand [%]`           = round(if ("Leerstand"           %in% names(.)) `Leerstand`           / n_gesamt * 100 else 0, 1)
  ) %>%
  select(
    Landnutzung              = landnutzung,
    `Flurstücke gesamt`      = n_gesamt,
    `Davon unternutzt`       = n_unternutzt,
    `Unternutzung [%]`,
    `Aktives Bauvorhaben [%]`,
    `Baulücke [%]`,
    `Leerstand [%]`
  )

tab2 <- make_ft(
  block2,
  titel      = "Unternutzung nach Landnutzung",
  untertitel = "",
  pct_cols   = c("Unternutzung [%]", "Aktives Bauvorhaben [%]", "Baulücke [%]", "Leerstand [%]")
)
sammle_tab(tab2)


# === BLOCK 3: Unternutzung nach Eigentümer:innen-Typ ===
et_gesamt    <- ol %>% count(Typ, name = "n_gesamt")
et_un_gesamt <- un %>% count(Typ, name = "n_unternutzt")
et_un_typ    <- un %>%
  count(Typ, typ_2) %>%
  pivot_wider(names_from = typ_2, values_from = n, values_fill = 0)

block3 <- et_gesamt %>%
  left_join(et_un_gesamt, by = "Typ") %>%
  left_join(et_un_typ,    by = "Typ") %>%
  mutate(across(where(is.numeric) & !n_gesamt, \(x) replace(x, is.na(x), 0))) %>%
  mutate(
    `Unternutzung [%]`        = round(n_unternutzt / n_gesamt * 100, 1),
    `Aktives Bauvorhaben [%]` = round(if ("Aktives Bauvorhaben" %in% names(.)) `Aktives Bauvorhaben` / n_gesamt * 100 else 0, 1),
    `Baulücke [%]`            = round(if ("Baulücke"            %in% names(.)) `Baulücke`            / n_gesamt * 100 else 0, 1),
    `Leerstand [%]`           = round(if ("Leerstand"           %in% names(.)) `Leerstand`           / n_gesamt * 100 else 0, 1)
  ) %>%
  select(
    `Eigentümer:innen-Typ`           = Typ,
    `Flurstücke gesamt`       = n_gesamt,
    `Davon unternutzt`        = n_unternutzt,
    `Unternutzung [%]`,
    `Aktives Bauvorhaben [%]`,
    `Baulücke [%]`,
    `Leerstand [%]`
  )

tab3 <- make_ft(
  block3,
  titel      = "Unternutzung nach Eigentümer:innen-Typ",
  untertitel = "",
  pct_cols   = c("Unternutzung [%]", "Aktives Bauvorhaben [%]", "Baulücke [%]", "Leerstand [%]")
)
sammle_tab(tab3)


# === BLOCK 4-6: Unternutzungstypen nach LANDNUTZUNG ===
make_kreuztab_ln <- function(typ_filter, titel) {
  df <- un %>%
    filter(typ_2 == typ_filter) %>%
    count(landnutzung, name = "Anzahl Flurstücke") %>%
    mutate(`Anteil an Unternutzungstyp [%]` = round(`Anzahl Flurstücke` / sum(`Anzahl Flurstücke`) * 100, 1)) %>%
    arrange(desc(`Anzahl Flurstücke`)) %>%
    rename(Landnutzung = landnutzung)

  ft <- make_ft(
    df,
    titel      = titel,
    untertitel = paste0("Gesamtzahl: ", sum(df$`Anzahl Flurstücke`), " Flurstücke"),
    pct_cols   = "Anteil an Unternutzungstyp [%]",
    abs_cols   = "Anzahl Flurstücke"
  )
  sammle_tab(ft)
}

make_kreuztab_ln("Leerstand",          "Leerstände nach Landnutzung")
make_kreuztab_ln("Baulücke",           "Baulücken nach Landnutzung")
make_kreuztab_ln("Aktives Bauvorhaben","Aktive Bauvorhaben nach Landnutzung")


# === BLOCK 7-9: Unternutzungstypen nach Eigentümer:innen-Typ ===
make_kreuztab_et <- function(typ_filter, titel) {
  df <- un %>%
    filter(typ_2 == typ_filter) %>%
    count(Typ, name = "Anzahl Flurstücke") %>%
    mutate(`Anteil an Unternutzungstyp [%]` = round(`Anzahl Flurstücke` / sum(`Anzahl Flurstücke`) * 100, 1)) %>%
    arrange(desc(`Anzahl Flurstücke`)) %>%
    rename(`Eigentümer:innen-Typ` = Typ)

  ft <- make_ft(
    df,
    titel      = titel,
    untertitel = paste0("Gesamtzahl: ", sum(df$`Anzahl Flurstücke`), " Flurstücke"),
    pct_cols   = "Anteil an Unternutzungstyp [%]",
    abs_cols   = "Anzahl Flurstücke"
  )
  sammle_tab(ft)
}

make_kreuztab_et("Leerstand",          "Leerstände nach Eigentümer:innen-Typ")
make_kreuztab_et("Baulücke",           "Baulücken nach Eigentümer:innen-Typ")
make_kreuztab_et("Aktives Bauvorhaben","Aktive Bauvorhaben nach Eigentümer:innen-Typ")


# === Alle Tabellen als Word-Dokument speichern ===
speichere_word(word_datei)
