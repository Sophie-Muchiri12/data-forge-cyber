library(tidyverse)
library(pdftools)

files <- list.files("data/raw/ca_reports", pattern = "^CA_cyber_.*\\.pdf$",
                    full.names = TRUE)

safe_len  <- possibly(pdf_length, otherwise = NA_integer_)
safe_text <- possibly(\(p) nchar(paste(pdf_text(p), collapse = "")) > 500,
                      otherwise = NA)

manifest <- tibble(path = files, file = basename(files)) |>
  mutate(
    period_start = ymd(paste0(str_extract(file, "\\d{4}-\\d{2}"), "-01")),
    m = month(period_start),
    quarter = match(m, c(7, 10, 1, 4)),
    start_yr = if_else(m >= 7, year(period_start), year(period_start) - 1),
    fy = paste0(start_yr, "/", str_sub(start_yr + 1, 3, 4)),
    size_kb = round(file.size(path) / 1024),
    pages = map_int(path, safe_len),
    has_text = map_lgl(path, safe_text)
  ) |>
  select(file, fy, quarter, period_start, size_kb, pages, has_text)

print(manifest, n = Inf)

# Which quarters are missing? Expect only 2025-04-01
tibble(period_start = seq(as.Date("2020-01-01"), as.Date("2026-01-01"), by = "quarter")) |>
  anti_join(manifest, by = "period_start")

dir.create("data/interim", recursive = TRUE, showWarnings = FALSE)
write_csv(manifest, "data/interim/ca_report_manifest.csv")