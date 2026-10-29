# felix_03_cleaning_table.R
# Builds outputs/tables/cleaning_table.csv showing row counts at each
# cleaning step for every dataset.
# Run from project root: source("scripts/felix_03_cleaning_table.R")
# or: Rscript scripts/felix_03_cleaning_table.R

suppressMessages({
  library(readr)
  library(dplyr)
})

PENDING <- function(owner) paste0("PENDING: ask ", owner)
out_dir  <- "outputs/tables"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

rows <- list()   # collect result rows

add_row <- function(dataset, step, rows_left, rows_removed, reason) {
  rows[[length(rows) + 1]] <<- data.frame(
    dataset      = dataset,
    step         = step,
    rows_left    = as.character(rows_left),
    rows_removed = as.character(rows_removed),
    reason       = reason,
    stringsAsFactors = FALSE
  )
}

cat("=======================================================\n")
cat("  CLEANING TABLE — felix_03_cleaning_table.R\n")
cat("=======================================================\n\n")

# ── 1. NVD ────────────────────────────────────────────────────────────────────
cat("── NVD ──────────────────────────────────────────────────\n")

nvd_path <- "data/interim/nvd_cves.rds"
if (file.exists(nvd_path)) {
  nvd <- readRDS(nvd_path)
  n0  <- nrow(nvd)
  cat(sprintf("  Step 0 (raw): %d rows\n", n0))
  add_row("NVD", "0_raw", n0, 0, "All CVEs in nvd_cves.rds")

  # Step 1: rows with a CVSS v3 score
  # cvss_version holds values like "3.1", "3.0", "2.0", NA
  nvd_v3 <- nvd |> filter(grepl("^3", cvss_version, ignore.case = TRUE) &
                           !is.na(cvss_score))
  n1      <- nrow(nvd_v3)
  removed1 <- n0 - n1
  cat(sprintf("  Step 1 (with CVSS v3 score): %d rows  (removed %d)\n", n1, removed1))
  add_row("NVD", "1_has_cvss_v3", n1, removed1,
          "Keep rows where cvss_version starts with '3' and cvss_score is not NA")

  # Store CVE IDs for KEV matching
  nvd_cve_ids <- nvd_v3$cve_id
} else {
  cat("  [NVD] File not found:", nvd_path, "\n")
  add_row("NVD", "0_raw",        PENDING("Nathan"), PENDING("Nathan"), "nvd_cves.rds not found")
  add_row("NVD", "1_has_cvss_v3", PENDING("Nathan"), PENDING("Nathan"), "Depends on step 0")
  nvd_cve_ids <- NULL
}

# ── 2. KEV ────────────────────────────────────────────────────────────────────
cat("\n── KEV ──────────────────────────────────────────────────\n")

kev_files <- list.files("data/raw/kev", pattern = "\\.csv$", full.names = TRUE)
if (length(kev_files) > 0) {
  kev_files <- last(sort(kev_files))   # newest download only
  kev <- read_csv(kev_files, col_types = cols(.default = "c"),
                  show_col_types = FALSE)
  
  n0k <- nrow(kev)
  cat(sprintf("  Step 0 (raw): %d rows from %d file(s)\n", n0k, length(kev_files)))
  add_row("KEV", "0_raw", n0k, 0,
          paste0("All entries in ", paste(basename(kev_files), collapse = ", ")))

  # Step 1: rows whose cveID is in NVD (CVSS v3 subset)
  if (!is.null(nvd_cve_ids)) {
    kev_matched <- kev |> filter(cveID %in% nvd_cve_ids)
    n1k      <- nrow(kev_matched)
    removed1k <- n0k - n1k
    cat(sprintf("  Step 1 (matched to NVD CVSS v3 rows): %d rows  (removed %d)\n",
                n1k, removed1k))
    add_row("KEV", "1_matched_nvd_v3", n1k, removed1k,
            "Keep rows where cveID is present in NVD CVSS v3 subset")
  } else {
    cat("  Step 1: PENDING (NVD CVE IDs not available)\n")
    add_row("KEV", "1_matched_nvd_v3", PENDING("Nathan"), PENDING("Nathan"),
            "Cannot match without NVD v3 CVE IDs")
  }
} else {
  cat("  [KEV] No CSV files found in data/raw/kev/\n")
  add_row("KEV", "0_raw",            PENDING("Quintone"), PENDING("Quintone"), "No KEV CSV found")
  add_row("KEV", "1_matched_nvd_v3", PENDING("Quintone"), PENDING("Quintone"), "Depends on step 0")
}

# ── 3. CA Reports ─────────────────────────────────────────────────────────────
cat("\n── CA Reports ───────────────────────────────────────────\n")

ca_dir <- "data/raw/ca_reports"
if (dir.exists(ca_dir)) {
  # Canonical files: CA_cyber_YYYY-MM.pdf  (exclude _new suffix, Quarter- prefix)
  all_pdfs       <- list.files(ca_dir, pattern = "^CA_cyber_\\d{4}-\\d{2}\\.pdf$")
  n_canonical    <- length(all_pdfs)
  cat(sprintf("  Step 0 (canonical PDFs on disk): %d files\n", n_canonical))
  add_row("CA reports", "0_canonical_pdfs", n_canonical, 0,
          "CA_cyber_YYYY-MM.pdf files in data/raw/ca_reports/")

  # Step 1: usable (pdf_info does not error)
  suppressMessages(library(pdftools))
  usable <- sapply(file.path(ca_dir, all_pdfs), function(p) {
    tryCatch({ pdf_info(p); TRUE }, error = function(e) FALSE)
  })
  n_usable   <- sum(usable)
  n_broken   <- n_canonical - n_usable
  broken_files <- basename(file.path(ca_dir, all_pdfs))[!usable]
  cat(sprintf("  Step 1 (pdf_info passes): %d usable  (removed %d)\n", n_usable, n_broken))
  if (n_broken > 0) cat("  Broken/truncated:", paste(broken_files, collapse = ", "), "\n")
  add_row("CA reports", "1_pdf_info_ok", n_usable, n_broken,
          if (n_broken > 0)
            paste0("Remove truncated/broken PDFs: ", paste(broken_files, collapse = ", "))
          else
            "All PDFs pass pdf_info()")
} else {
  cat("  [CA] Directory not found:", ca_dir, "\n")
  add_row("CA reports", "0_canonical_pdfs", PENDING("Sophie"), PENDING("Sophie"), "Directory missing")
  add_row("CA reports", "1_pdf_info_ok",    PENDING("Sophie"), PENDING("Sophie"), "Depends on step 0")
}

# ── 4. EPSS ───────────────────────────────────────────────────────────────────
cat("\n── EPSS ─────────────────────────────────────────────────\n")
epss_files <- list.files("data/raw", pattern = "(?i)epss", recursive = TRUE)
if (length(epss_files) == 0) {
  cat("  [EPSS] No files found.\n")
  add_row("EPSS", "0_raw",       PENDING("team member"), PENDING("team member"), "No EPSS data found in data/raw/")
  add_row("EPSS", "1_with_score", PENDING("team member"), PENDING("team member"), "Depends on step 0")
} else {
  cat("  Found:", paste(epss_files, collapse = ", "), "\n")
}

# ── 5. Phishing ──────────────────────────────────────────────────────────────
cat("\n── Phishing ─────────────────────────────────────────────\n")
phish_files <- list.files("data/raw", pattern = "(?i)phish|PhiUSIIL", recursive = TRUE)
if (length(phish_files) == 0) {
  cat("  [Phishing] No files found.\n")
  add_row("Phishing", "0_raw",     PENDING("team member"), PENDING("team member"), "No phishing data found in data/raw/")
  add_row("Phishing", "1_cleaned", PENDING("team member"), PENDING("team member"), "Depends on step 0")
} else {
  cat("  Found:", paste(phish_files, collapse = ", "), "\n")
}

# ── 6. Kenya URLs ─────────────────────────────────────────────────────────────
cat("\n── Kenya URLs ───────────────────────────────────────────\n")
ku_files <- list.files("data/raw", pattern = "(?i)kenya|kenyan", recursive = TRUE)
if (length(ku_files) == 0) {
  cat("  [Kenya URLs] No files found.\n")
  add_row("Kenya URLs", "0_raw",     PENDING("team member"), PENDING("team member"), "No Kenya URL data found in data/raw/")
  add_row("Kenya URLs", "1_cleaned", PENDING("team member"), PENDING("team member"), "Depends on step 0")
} else {
  cat("  Found:", paste(ku_files, collapse = ", "), "\n")
}

# ── Write output ─────────────────────────────────────────────────────────────
cat("\n── Writing output ───────────────────────────────────────\n")
result <- bind_rows(rows)
out_path <- file.path(out_dir, "cleaning_table.csv")
write_csv(result, out_path)
cat("  Saved:", out_path, "\n")

cat("\n── Summary ──────────────────────────────────────────────\n")
print(as.data.frame(result), row.names = FALSE)

cat("\n=======================================================\n")
cat("  DONE\n")
cat("=======================================================\n")
