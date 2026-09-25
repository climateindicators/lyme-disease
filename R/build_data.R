# Build tidy long-format data for the Lyme Disease indicator.
#
#   Rscript R/build_data.R
#
# Reads EPA's published figure CSVs in data-raw/ and writes data/*.csv plus
# data/meta.yml. Rerunning with unchanged inputs produces byte-identical output.
# Nothing here touches the network.
#
# TO UPDATE THE DATA: drop replacement CSVs into data-raw/ and rerun. Headers
# are asserted, not assumed, so a renamed or reordered column stops the build.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(tibble)
})

root <- here::here()
source(file.path(root, "R/utils/epa_csv.R"))
source(file.path(root, "R/utils/write_stable.R"))

raw_dir <- file.path(root, "data-raw")
out_dir <- file.path(root, "data")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Shared reshape helper ----------------------------------------------------

# Pivot a figure's series columns into long format and attach each series' key
# and label by joining a lookup table on the source header string, never on
# column position. A blank cell means that series has no observation for that
# row (e.g. a year outside its case-definition era), not a suppressed value,
# so it is dropped before the flag split rather than becoming a spurious
# empty-value row. What survives is split into `value` and a suppression
# `flag`.
tidy_series <- function(df, id_cols, lookup) {
  out <- df |>
    tidyr::pivot_longer(
      cols      = -dplyr::all_of(id_cols),
      names_to  = "source_header",
      values_to = "raw_value"
    ) |>
    dplyr::filter(trimws(raw_value) != "") |>
    dplyr::inner_join(lookup, by = "source_header")

  split <- split_value_flag(out$raw_value)
  out$value <- split$value
  out$flag  <- split$flag
  out
}

# ---- Indicator constants -----------------------------------------------------

INDICATOR <- list(
  name                    = "Lyme Disease",
  slug                    = "lyme-disease",
  publisher               = "U.S. Environmental Protection Agency",
  source_page             = "https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-lyme-disease/index.html",
  technical_documentation = "https://19january2025snapshot.epa.gov/system/files/documents/2024-12/lyme_td.pdf",
  rights                  = "Public domain, work of the U.S. Government (17 U.S.C. 105)"
)

# ---- Figure 1: Reported Cases of Lyme Disease in the United States, 1992-2022 ----

# EPA's surveillance case definition changed in 1996, 2008, and 2022, so the
# national series arrives as four columns, each populated only for the years
# under that definition. No year has two populated columns, so the pivot
# conserves exactly one output row per year.
f1_path <- file.path(raw_dir, "lyme_fig-1.csv")
f1_meta <- read_epa_preamble(f1_path)
f1_raw  <- read_epa_csv(f1_path)

FIG1_SERIES <- tibble::tribble(
  ~source_header,          ~definition_key, ~definition_label,
  "1990 case definition",  "def_1990",      "1990 case definition",
  "1996 case definition",  "def_1996",      "1996 case definition",
  "2008 case definition",  "def_2008",      "2008 case definition",
  "2022 case definition",  "def_2022",      "2022 case definition"
)

assert_headers(
  f1_raw,
  id_cols          = "Year",
  expected_headers = FIG1_SERIES$source_header,
  what             = "lyme_fig-1.csv"
)

f1 <- tidy_series(f1_raw, "Year", FIG1_SERIES)
stopifnot("figure 1: no suppression flags expected" = all(f1$flag == ""))

f1 <- f1 |>
  dplyr::rename(year = Year) |>
  dplyr::arrange(match(year, f1_raw$Year), match(definition_key, FIG1_SERIES$definition_key)) |>
  dplyr::select(year, definition_key, definition_label, value)

assert_conservation(f1_raw, FIG1_SERIES$source_header, nrow(f1), "lyme_fig-1.csv")

write_csv_stable(f1, file.path(out_dir, "lyme_incidence_national.csv"))

# ---- Figure 2: Reported Annual Lyme Disease Incidence in the United States, 2022 ----

# Already one row per jurisdiction: no pivot needed, just a rename and a
# suppression-flag split. A jurisdiction that filed no report for 2022 reaches
# this file with an empty `value` and a non-empty `flag`, not a zero.
f2_path <- file.path(raw_dir, "lyme_fig-2.csv")
f2_meta <- read_epa_preamble(f2_path)
f2_raw  <- read_epa_csv(f2_path)

assert_headers(
  f2_raw,
  id_cols          = character(),
  expected_headers = c("Jurisdiction", "Incidence (per 100,000 people)"),
  what             = "lyme_fig-2.csv"
)

f2_split <- split_value_flag(f2_raw[["Incidence (per 100,000 people)"]])

f2 <- tibble::tibble(
  jurisdiction = f2_raw$Jurisdiction,
  value        = f2_split$value,
  flag         = f2_split$flag
)

write_csv_stable(f2, file.path(out_dir, "lyme_incidence_by_jurisdiction.csv"))

# ---- Data dictionary ---------------------------------------------------------

col <- function(name, type, description) {
  list(name = name, type = type, description = description)
}

meta <- list(
  indicator = INDICATOR,
  datasets = list(
    list(
      file            = "lyme_incidence_national.csv",
      figure          = "Figure 1",
      figure_title    = f1_meta$title,
      source_file     = "lyme_fig-1.csv",
      source_sha256   = file_sha256(f1_path),
      source_encoding = f1_meta$encoding,
      data_source     = f1_meta$data_source,
      web_update      = f1_meta$web_update,
      unit            = f1_meta$units,
      rows            = nrow(f1),
      columns         = list(
        col("year", "integer", "Calendar year, as published."),
        col("definition_key", "string", "Machine-readable case-definition era: def_1990, def_1996, def_2008, or def_2022. Exactly one is populated per year; CDC's surveillance case definition changed in 1996, 2008, and 2022."),
        col("definition_label", "string", "Display label for definition_key, EPA's own column heading."),
        col("value", "number", "Reported Lyme disease cases per 100,000 people for that year, verbatim from the source file.")
      )
    ),
    list(
      file            = "lyme_incidence_by_jurisdiction.csv",
      figure          = "Figure 2",
      figure_title    = f2_meta$title,
      source_file     = "lyme_fig-2.csv",
      source_sha256   = file_sha256(f2_path),
      source_encoding = f2_meta$encoding,
      data_source     = f2_meta$data_source,
      web_update      = f2_meta$web_update,
      unit            = f2_meta$units,
      rows            = nrow(f2),
      columns         = list(
        col("jurisdiction", "string", "U.S. state or the District of Columbia."),
        col("value", "number", "Reported Lyme disease cases per 100,000 people in 2022. Blank where flag is set."),
        col("flag", "string", "Suppression marker from the source file (not_reported where a jurisdiction filed no report for 2022). Empty string when value is present.")
      )
    )
  )
)

write_yaml_stable(meta, file.path(out_dir, "meta.yml"))

# ---- Verify what was written -------------------------------------------------

written <- list.files(out_dir, pattern = "[.](csv|yml)$", full.names = TRUE)
invisible(lapply(written, assert_clean_output))

cat("\nWrote:\n")
for (p in written) {
  cat(sprintf("  %-34s %8d bytes  %s\n", basename(p), file.size(p), substr(file_sha256(p), 1, 12)))
}
