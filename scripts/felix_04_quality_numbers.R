# felix_04_quality_numbers.R
# Computes data-quality metrics from existing files and saves
# outputs/tables/quality_numbers.csv
# Run from project root: Rscript scripts/felix_04_quality_numbers.R

suppressMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(lubridate)
})

PENDING <- function(owner) paste0("PENDING: ", owner)
out_dir  <- "outputs/tables"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

rows <- list()
add <- function(metric, value, note = "") {
  rows[[length(rows) + 1]] <<- data.frame(
    metric = metric, value = as.character(value), note = note,
    stringsAsFactors = FALSE
  )
}

cat("=======================================================\n")
cat("  QUALITY NUMBERS — felix_04_quality_numbers.R\n")
cat("=======================================================\n\n")

# ═══════════════════════════════════════════════════════════════════════════
# 1. NVD – missing CVSS % and scorer share, by publication year
# ═══════════════════════════════════════════════════════════════════════════
cat("── 1. NVD ───────────────────────────────────────────────\n")
nvd_path <- "data/interim/nvd_cves.rds"

if (file.exists(nvd_path)) {
  nvd <- readRDS(nvd_path)

  # publication year
  nvd <- nvd |>
    mutate(pub_year = year(as.Date(published)))

  # --- 1a. Missing CVSS (no v3 score) % by year ---
  cat("  1a. Missing CVSS v3 % by publication year\n")
  missing_by_year <- nvd |>
    mutate(missing_v3 = is.na(cvss_score) | !grepl("^3", cvss_version)) |>
    group_by(pub_year) |>
    summarise(
      total    = n(),
      missing  = sum(missing_v3),
      pct_miss = round(100 * missing / total, 1),
      .groups  = "drop"
    ) |>
    arrange(pub_year)

  for (i in seq_len(nrow(missing_by_year))) {
    r <- missing_by_year[i, ]
    add(
      metric = sprintf("nvd_pct_missing_cvss_v3_%d", r$pub_year),
      value  = r$pct_miss,
      note   = sprintf("%d of %d CVEs lack CVSS v3 in %d",
                       r$missing, r$total, r$pub_year)
    )
    cat(sprintf("    %d: %.1f%% missing (%d/%d)\n",
                r$pub_year, r$pct_miss, r$missing, r$total))
  }

  # Overall missing rate
  overall_miss_pct <- round(100 * mean(is.na(nvd$cvss_score) |
                                         !grepl("^3", nvd$cvss_version)), 1)
  add("nvd_pct_missing_cvss_v3_overall", overall_miss_pct,
      sprintf("%d of %d CVEs lack CVSS v3", sum(is.na(nvd$cvss_score) |
                !grepl("^3", nvd$cvss_version)), nrow(nvd)))
  cat(sprintf("    Overall: %.1f%% missing CVSS v3\n", overall_miss_pct))

  # --- 1b. CVSS scorer share (reporter vs NVD) by year ---
  cat("  1b. CVSS scorer share by year\n")
  scorer_by_year <- nvd |>
    filter(!is.na(cvss_scored_by)) |>
    mutate(is_nvd = grepl("(?i)^nvd$|nist|nvd", cvss_scored_by)) |>
    group_by(pub_year) |>
    summarise(
      n_scored = n(),
      n_nvd    = sum(is_nvd),
      n_rep    = sum(!is_nvd),
      pct_nvd  = round(100 * n_nvd / n_scored, 1),
      pct_rep  = round(100 * n_rep / n_scored, 1),
      .groups  = "drop"
    ) |>
    arrange(pub_year)

  for (i in seq_len(nrow(scorer_by_year))) {
    r <- scorer_by_year[i, ]
    add(sprintf("nvd_pct_scored_by_nvd_%d", r$pub_year),  r$pct_nvd,
        sprintf("Year %d: %d scored, %.1f%% by NVD, %.1f%% by reporter",
                r$pub_year, r$n_scored, r$pct_nvd, r$pct_rep))
    add(sprintf("nvd_pct_scored_by_reporter_%d", r$pub_year), r$pct_rep, "")
    cat(sprintf("    %d: NVD=%.1f%%, Reporter=%.1f%% (n=%d)\n",
                r$pub_year, r$pct_nvd, r$pct_rep, r$n_scored))
  }

  # Store IDs for KEV match
  nvd_v3_ids <- nvd |>
    filter(grepl("^3", cvss_version) & !is.na(cvss_score)) |>
    pull(cve_id)

} else {
  cat("  NVD file not found.\n")
  add("nvd_pct_missing_cvss_v3_overall", PENDING("Nathan"), "nvd_cves.rds missing")
  add("nvd_pct_scored_by_nvd_overall",   PENDING("Nathan"), "nvd_cves.rds missing")
  nvd_v3_ids <- NULL
}

# ═══════════════════════════════════════════════════════════════════════════
# 2. KEV – unmatched entries (not in NVD CVSS v3 set) and their CVE-ID years
# ═══════════════════════════════════════════════════════════════════════════
cat("\n── 2. KEV ───────────────────────────────────────────────\n")
kev_files <- list.files("data/raw/kev", pattern = "\\.csv$", full.names = TRUE)

if (length(kev_files) > 0 && !is.null(nvd_v3_ids)) {
  kev <- read_csv(last(sort(kev_files)), col_types = cols(.default = "c"),
                  show_col_types = FALSE)
  
  unmatched <- kev |> filter(!cveID %in% nvd_v3_ids)
  n_total   <- nrow(kev)
  n_unmat   <- nrow(unmatched)
  pct_unmat <- round(100 * n_unmat / n_total, 1)

  add("kev_total_rows",        n_total,   "Raw KEV entries")
  add("kev_unmatched_n",       n_unmat,   "KEV rows with no CVSS v3 NVD match")
  add("kev_unmatched_pct",     pct_unmat, "% of KEV rows unmatched to NVD v3")
  cat(sprintf("  Total: %d  Unmatched: %d (%.1f%%)\n", n_total, n_unmat, pct_unmat))

  # Year breakdown of unmatched CVE-IDs
  unmatched_years <- unmatched |>
    mutate(cve_year = as.integer(sub("CVE-(\\d{4})-.*", "\\1", cveID))) |>
    count(cve_year, name = "n_unmatched") |>
    arrange(cve_year)

  cat("  Unmatched by CVE-ID year:\n")
  for (i in seq_len(nrow(unmatched_years))) {
    r <- unmatched_years[i, ]
    add(sprintf("kev_unmatched_n_cve_year_%s", r$cve_year),
        r$n_unmatched,
        sprintf("%d unmatched KEV entries with CVE year %s", r$n_unmatched, r$cve_year))
    cat(sprintf("    CVE-%s: %d unmatched\n", r$cve_year, r$n_unmatched))
  }

} else if (length(kev_files) == 0) {
  add("kev_unmatched_n",   PENDING("Quintone"), "No KEV file found")
  add("kev_unmatched_pct", PENDING("Quintone"), "No KEV file found")
} else {
  add("kev_unmatched_n",   PENDING("Nathan"),   "Need NVD v3 IDs first")
  add("kev_unmatched_pct", PENDING("Nathan"),   "Need NVD v3 IDs first")
}

# ═══════════════════════════════════════════════════════════════════════════
# 3. CA Reports – quarters with sum ≠ reported_total, total usable quarters
# ═══════════════════════════════════════════════════════════════════════════
cat("\n── 3. CA Reports ────────────────────────────────────────\n")
ca_entry_path <- "data/raw/ca_entry_FK.csv"

if (file.exists(ca_entry_path)) {
  ca <- read_csv(ca_entry_path, col_types = cols(.default = "c"),
                 show_col_types = FALSE) |>
    filter(!is.na(fy)) |>
    mutate(events        = as.numeric(events),
           reported_total = as.numeric(reported_total))

  # Quarters encoded in file
  quarters_in_file <- ca |>
    distinct(fy, quarter, period_start, reported_total)
  n_quarters_encoded <- nrow(quarters_in_file)
  add("ca_quarters_in_entry_file", n_quarters_encoded, "Distinct quarters in ca_entry_FK.csv")
  cat(sprintf("  Quarters encoded so far: %d\n", n_quarters_encoded))

  # Sum check per quarter
  sum_check <- ca |>
    group_by(fy, quarter, period_start, reported_total) |>
    summarise(cat_sum = sum(events, na.rm = TRUE), .groups = "drop") |>
    mutate(discrepancy = cat_sum - reported_total,
           ok          = discrepancy == 0)

  n_bad  <- sum(!sum_check$ok)
  n_good <- sum( sum_check$ok)
  add("ca_quarters_sum_matches", n_good, "Quarters where category sum = reported_total")
  add("ca_quarters_sum_mismatch", n_bad, "Quarters where category sum ≠ reported_total")
  cat(sprintf("  Sum matches: %d  Mismatches: %d\n", n_good, n_bad))

  if (n_bad > 0) {
    bad_rows <- sum_check |> filter(!ok) |>
      mutate(note = sprintf("%s %s: sum=%d total=%d diff=%d",
                            fy, quarter, cat_sum, reported_total, discrepancy))
    for (r in bad_rows$note) {
      add("ca_sum_mismatch_detail", r, "")
      cat("  MISMATCH:", r, "\n")
    }
  }

  # Usable quarters = canonical PDFs that pass pdf_info
  suppressMessages(library(pdftools))
  ca_dir      <- "data/raw/ca_reports"
  all_pdfs    <- list.files(ca_dir, pattern = "^CA_cyber_\\d{4}-\\d{2}\\.pdf$")
  n_canonical <- length(all_pdfs)
  usable_flags <- sapply(file.path(ca_dir, all_pdfs), function(p)
    tryCatch({ pdf_info(p); TRUE }, error = function(e) FALSE))
  n_usable <- sum(usable_flags)
  add("ca_total_canonical_pdfs", n_canonical, "CA_cyber_YYYY-MM.pdf files on disk")
  add("ca_total_usable_quarters", n_usable,   "Quarters with readable PDFs (pdf_info passes)")
  cat(sprintf("  Canonical PDFs: %d  Usable: %d\n", n_canonical, n_usable))

} else {
  cat("  ca_entry_FK.csv not found.\n")
  add("ca_quarters_in_entry_file",  PENDING("Felix"),  "ca_entry_FK.csv not yet built")
  add("ca_quarters_sum_mismatch",   PENDING("Felix"),  "ca_entry_FK.csv not yet built")
  add("ca_total_usable_quarters",   PENDING("Felix"),  "ca_entry_FK.csv not yet built")
}

# ═══════════════════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════════════════
# 4. EPSS, phishing and Kenyan URLs
# ═══════════════════════════════════════════════════════════════════════════
cat("\n── 4. EPSS, phishing, Kenyan URLs ───────────────────────\n")

# EPSS: one row count per file (first line of each file is a comment, so skip it)
epss_files <- list.files("data/raw/epss", pattern = "\\.csv\\.gz$", full.names = TRUE)
if (length(epss_files) > 0) {
  for (f in epss_files) {
    e <- read_csv(f, skip = 1, show_col_types = FALSE)
    snap <- sub("^epss_scores-(.*)\\.csv\\.gz$", "\\1", basename(f))
    add(paste0("epss_rows_", snap), nrow(e), paste("CVEs scored in", basename(f)))
    add(paste0("epss_missing_scores_", snap), sum(is.na(e$epss)), "Rows with no EPSS value")
    cat(sprintf("  %s: %d CVEs, %d missing scores\n", basename(f), nrow(e), sum(is.na(e$epss))))
  }
} else {
  add("epss_total_rows", PENDING("Sophie"), "No EPSS files in data/raw/epss/")
}

# Phishing: the processed table (the raw CSV is not on GitHub)
phish_path <- "data/processed/phishing.rds"
if (file.exists(phish_path)) {
  phish <- readRDS(phish_path)
  add("phishing_total_rows", nrow(phish), "URLs in data/processed/phishing.rds")
  add("phishing_n_legitimate", sum(phish$is_phishing == "legitimate"), "Expected 134,850")
  add("phishing_n_phishing", sum(phish$is_phishing == "phishing"), "Expected 100,945")
  add("phishing_missing_cells", sum(is.na(phish)), "Empty cells across all columns")
  cat(sprintf("  Phishing: %d URLs (%d legitimate, %d phishing), %d empty cells\n",
              nrow(phish), sum(phish$is_phishing == "legitimate"),
              sum(phish$is_phishing == "phishing"), sum(is.na(phish))))
} else {
  add("phishing_total_rows", PENDING("Quintone"), "data/processed/phishing.rds not found")
}

# Kenyan URL list
urls_path <- "data/raw/kenya_urls.csv"
if (file.exists(urls_path)) {
  urls <- read_csv(urls_path, show_col_types = FALSE)
  add("kenya_urls_total_rows", nrow(urls), "URLs in data/raw/kenya_urls.csv")
  add("kenya_urls_organisations", n_distinct(urls$organisation), "Distinct organisations")
  add("kenya_urls_duplicates", sum(duplicated(urls$url)), "Repeated URLs")
  add("kenya_urls_not_https", sum(!startsWith(urls$url, "https://")), "URLs not using https")
  cat(sprintf("  Kenyan URLs: %d links from %d organisations, %d duplicates\n",
              nrow(urls), n_distinct(urls$organisation), sum(duplicated(urls$url))))
} else {
  add("kenya_urls_total_rows", PENDING("Bradley"), "data/raw/kenya_urls.csv not found")
}