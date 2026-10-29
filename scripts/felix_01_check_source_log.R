# felix_01_check_source_log.R
# Audits docs/source_log.csv without editing it.
# Run from the project root: source("scripts/felix_01_check_source_log.R")

library(readr)
library(dplyr)
library(stringr)

cat("=======================================================\n")
cat("  SOURCE LOG AUDIT — felix_01_check_source_log.R\n")
cat("=======================================================\n\n")

# ── 0. Paths ──────────────────────────────────────────────────────────────────
log_path   <- "docs/source_log.csv"
raw_root   <- "data/raw"

# Dataset name → subfolder mapping (extend as new datasets arrive)
dataset_dirs <- list(
  "CA report" = file.path(raw_root, "ca_reports"),
  "NVD"       = file.path(raw_root, "nvd"),
  "KEV"       = file.path(raw_root, "kev"),
  "EPSS"      = file.path(raw_root, "epss"),
  "PhiUSIIL"  = file.path(raw_root, "phiusiil"),
  "Kenyan URL"= file.path(raw_root, "kenyan_url")
)

# ── 1. Read the log ───────────────────────────────────────────────────────────
required_cols <- c("dataset", "file_name", "url", "downloaded_on",
                   "downloaded_by", "period_covered", "terms_of_use", "notes")

log <- read_csv(log_path, col_types = cols(.default = "c"), trim_ws = FALSE)

# 1a. Column check
cat("── 1. COLUMN CHECK ──────────────────────────────────────\n")
missing_cols <- setdiff(required_cols, names(log))
extra_cols   <- setdiff(names(log), required_cols)
if (length(missing_cols) == 0 && length(extra_cols) == 0) {
  cat("   ✓ All required columns present, no extras.\n\n")
} else {
  if (length(missing_cols) > 0)
    cat("   ✗ Missing columns :", paste(missing_cols, collapse = ", "), "\n")
  if (length(extra_cols) > 0)
    cat("   ✗ Extra columns   :", paste(extra_cols, collapse = ", "), "\n")
  cat("\n")
}

# Drop completely empty rows (e.g. trailing blank line)
log <- log |> filter(if_any(everything(), ~ !is.na(.)))

# ── 2. Rows per dataset ───────────────────────────────────────────────────────
cat("── 2. ROWS PER DATASET ──────────────────────────────────\n")
rows_per_dataset <- log |>
  count(dataset, name = "n_rows") |>
  arrange(dataset)
print(as.data.frame(rows_per_dataset), row.names = FALSE)
cat("\n")

# ── 3. Date format check (downloaded_on must be YYYY-MM-DD) ──────────────────
cat("── 3. DATE FORMAT CHECK (downloaded_on) ─────────────────\n")
bad_dates <- log |>
  filter(!str_detect(downloaded_on, "^\\d{4}-\\d{2}-\\d{2}$")) |>
  select(row = file_name, downloaded_on)
if (nrow(bad_dates) == 0) {
  cat("   ✓ All dates are in YYYY-MM-DD format.\n\n")
} else {
  cat("   ✗ Rows with bad date format:\n")
  print(as.data.frame(bad_dates), row.names = FALSE)
  cat("\n")
}

# ── 4. Stray commas inside field values ──────────────────────────────────────
cat("── 4. STRAY COMMAS IN FIELD VALUES ──────────────────────\n")
stray_comma_rows <- log |>
  rowwise() |>
  filter(any(str_detect(c_across(everything()), ","), na.rm = TRUE)) |>
  ungroup() |>
  select(dataset, file_name)
if (nrow(stray_comma_rows) == 0) {
  cat("   ✓ No stray commas found.\n\n")
} else {
  cat("   ✗ Rows with stray commas:\n")
  print(as.data.frame(stray_comma_rows), row.names = FALSE)
  cat("\n")
}

# ── 5. Duplicate URLs ─────────────────────────────────────────────────────────
cat("── 5. DUPLICATE URLs ────────────────────────────────────\n")
dup_urls <- log |>
  filter(!is.na(url)) |>
  group_by(url) |>
  filter(n() > 1) |>
  ungroup() |>
  arrange(url) |>
  select(dataset, file_name, url)
if (nrow(dup_urls) == 0) {
  cat("   ✓ No duplicate URLs.\n\n")
} else {
  cat("   ✗ Duplicate URLs:\n")
  print(as.data.frame(dup_urls), row.names = FALSE)
  cat("\n")
}

# ── 6. Duplicate file names ───────────────────────────────────────────────────
cat("── 6. DUPLICATE FILE NAMES ──────────────────────────────\n")
dup_files <- log |>
  filter(!is.na(file_name)) |>
  group_by(file_name) |>
  filter(n() > 1) |>
  ungroup() |>
  arrange(file_name) |>
  select(dataset, file_name)
if (nrow(dup_files) == 0) {
  cat("   ✓ No duplicate file names.\n\n")
} else {
  cat("   ✗ Duplicate file names:\n")
  print(as.data.frame(dup_files), row.names = FALSE)
  cat("\n")
}

# ── 7. Disk ↔ Log reconciliation ─────────────────────────────────────────────
cat("── 7. DISK ↔ LOG RECONCILIATION ─────────────────────────\n")

for (ds in names(dataset_dirs)) {
  dir_path <- dataset_dirs[[ds]]
  log_files <- log |>
    filter(dataset == ds) |>
    pull(file_name) |>
    na.omit()

  if (length(log_files) == 0) {
    # Dataset expected but has no rows in the log at all
    cat(sprintf("   [%s] — 0 rows in log (dataset owned by another member; skip disk check)\n", ds))
    next
  }

  if (!dir.exists(dir_path)) {
    cat(sprintf("   [%s] ✗ Folder does not exist: %s\n", ds, dir_path))
    cat(sprintf("          %d file(s) in log have nowhere to live on disk.\n\n", length(log_files)))
    next
  }

  disk_files <- list.files(dir_path, recursive = FALSE)

  in_log_not_disk <- setdiff(log_files, disk_files)
  on_disk_not_log <- setdiff(disk_files, log_files)

  if (length(in_log_not_disk) == 0 && length(on_disk_not_log) == 0) {
    cat(sprintf("   [%s] ✓ Log and disk match perfectly (%d files).\n\n", ds, length(log_files)))
  } else {
    if (length(in_log_not_disk) > 0) {
      cat(sprintf("   [%s] ✗ In log but MISSING on disk (%d):\n", ds, length(in_log_not_disk)))
      cat(paste0("          ", in_log_not_disk, collapse = "\n"), "\n")
    }
    if (length(on_disk_not_log) > 0) {
      cat(sprintf("   [%s] ✗ On disk but NOT in log (%d):\n", ds, length(on_disk_not_log)))
      cat(paste0("          ", on_disk_not_log, collapse = "\n"), "\n")
    }
    cat("\n")
  }
}

cat("=======================================================\n")
cat("  AUDIT COMPLETE  — no changes made to source_log.csv\n")
cat("=======================================================\n")
