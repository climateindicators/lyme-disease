# Regression checks on the generated data for the Lyme Disease indicator.
#
#   Rscript tests/test-data.R
#
# The checks below are shape-independent: they hold whatever the reshape in
# R/build_data.R turns each figure into. Value snapshots, which pin the actual
# numbers so a data update fails loudly instead of passing silently, are the
# TODO at the bottom.

setwd(here::here())
source("R/utils/write_stable.R")

# Keeps the dictionary check readable when a meta.yml field is absent altogether.
`%||%` <- function(a, b) if (is.null(a)) b else a

failures <- character()
check <- function(label, ok) {
  ok <- isTRUE(ok)
  cat(sprintf("  [%s] %s\n", if (ok) "PASS" else "FAIL", label))
  if (!ok) failures <<- c(failures, label)
  invisible(ok)
}

rd <- function(f) {
  readr::read_csv(file.path("data", f),
                  col_types = readr::cols(.default = readr::col_character()),
                  na = character(), progress = FALSE)
}

meta <- yaml::read_yaml("data/meta.yml")

cat("\nData dictionary\n")
check("meta.yml documents 2 dataset(s)", length(meta$datasets) == 2L)
check("meta.yml has no timestamp",
      !any(grepl("\\d{4}-\\d{2}-\\d{2}T|Sys\\.time|generated_at",
                 readLines("data/meta.yml", warn = FALSE))))

for (ds in meta$datasets) {
  df   <- rd(ds$file)
  cols <- vapply(ds$columns, function(x) x$name, character(1))
  check(sprintf("%s: meta.yml lists the columns the file actually has", ds$file),
        identical(cols, names(df)))
  check(sprintf("%s: meta.yml row count matches the file", ds$file),
        identical(as.integer(ds$rows), nrow(df)))
  check(sprintf("%s: every column has a type and a description", ds$file),
        all(vapply(ds$columns, function(x) nzchar(x$type %||% "") && nzchar(x$description %||% ""), logical(1))))
  check(sprintf("%s: source file is still present and unchanged", ds$file),
        identical(file_sha256(file.path("data-raw", ds$source_file)), ds$source_sha256))
  check(sprintf("%s: no blank rows", ds$file), nrow(df) > 0L)
}

cat("\nFile hygiene\n")
for (f in list.files("data", pattern = "[.](csv|yml)$", full.names = TRUE)) {
  check(sprintf("%s is UTF-8, LF, no BOM, no mojibake", basename(f)),
        tryCatch({ assert_clean_output(f); TRUE },
                 error = function(e) { cat("      ", conditionMessage(e), "\n"); FALSE }))
}

cat("\nValue snapshots\n")

national <- rd("lyme_incidence_national.csv")
national$year  <- as.integer(national$year)
national$value <- as.numeric(national$value)

check("national: 31 rows, 1992-2022", nrow(national) == 31L &&
        min(national$year) == 1992L && max(national$year) == 2022L)
check("national: first row is 1992, def_1990, 3.862553836",
      identical(national$year[1], 1992L) &&
        identical(national$definition_key[1], "def_1990") &&
        identical(national$value[1], 3.862553836))
check("national: last row is 2022, def_2022, 18.76878662",
      identical(national$year[nrow(national)], 2022L) &&
        identical(national$definition_key[nrow(national)], "def_2022") &&
        identical(national$value[nrow(national)], 18.76878662))
check("national: minimum incidence is 3.176763949 in 1993 (EPA: 3.2 per 100,000)",
      identical(national$value[which.min(national$value)], 3.176763949) &&
        identical(national$year[which.min(national$value)], 1993L))
check("national: maximum incidence is 18.76878662 in 2022 (EPA: 18.8 per 100,000)",
      identical(national$value[which.max(national$value)], 18.76878662) &&
        identical(national$year[which.max(national$value)], 2022L))
check("national: each case-definition era has exactly one row per year, no gaps",
      identical(
        sort(national$year),
        sort(c(1992:1995, 1996:2007, 2008:2021, 2022L))
      ))
check("national: era boundaries are def_1990 1992-1995, def_1996 1996-2007, def_2008 2008-2021, def_2022 2022",
      identical(range(national$year[national$definition_key == "def_1990"]), c(1992L, 1995L)) &&
        identical(range(national$year[national$definition_key == "def_1996"]), c(1996L, 2007L)) &&
        identical(range(national$year[national$definition_key == "def_2008"]), c(2008L, 2021L)) &&
        identical(range(national$year[national$definition_key == "def_2022"]), c(2022L, 2022L)))

jurisdiction <- rd("lyme_incidence_by_jurisdiction.csv")
jurisdiction$value <- suppressWarnings(as.numeric(jurisdiction$value))

check("jurisdiction: 51 rows (50 states + DC)", nrow(jurisdiction) == 51L)
check("jurisdiction: Hawaii filed no report (value NA, flag not_reported)",
      is.na(jurisdiction$value[jurisdiction$jurisdiction == "Hawaii"]) &&
        identical(jurisdiction$flag[jurisdiction$jurisdiction == "Hawaii"], "not_reported"))
check("jurisdiction: Oklahoma reported a genuine zero, not suppressed",
      identical(jurisdiction$value[jurisdiction$jurisdiction == "Oklahoma"], 0) &&
        identical(jurisdiction$flag[jurisdiction$jurisdiction == "Oklahoma"], ""))
check("jurisdiction: maximum is Rhode Island at 212.6449707",
      identical(jurisdiction$jurisdiction[which.max(jurisdiction$value)], "Rhode Island") &&
        identical(jurisdiction$value[which.max(jurisdiction$value)], 212.6449707))
check("jurisdiction: only one jurisdiction is missing a value (Hawaii)",
      sum(is.na(jurisdiction$value)) == 1L)

cat("\n")
if (length(failures)) {
  cat(sprintf("%d FAILED:\n", length(failures)))
  for (f in failures) cat("  -", f, "\n")
  quit(status = 1L)
}
cat("All data checks passed.\n")
