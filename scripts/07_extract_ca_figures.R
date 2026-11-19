# 07_extract_ca_figures.R
# Reads the KE-CIRT/CC figures for the quarters that were not typed in by hand
# (April 2022 to June 2026) straight from the report PDFs.
#
# - Reports from October 2023 onwards print a table of detected events by category.
# - The July-September 2023 report gives each category in its own section.
# - Reports from April 2022 to June 2023 only show categories in unlabelled charts,
#   so for those quarters only the printed total (and advisories) are taken.
#
# Every figure is checked: it must appear on the page recorded in source_page,
# and the categories must add up to the report's own printed total.
#
# Output: data/interim/ca_entry_extracted.csv (same columns as ca_entry_CM.csv)

library(tidyverse)
library(pdftools)

dir <- "data/raw/ca_reports"
to_num <- function(x) as.numeric(gsub(",", "", x))
fmt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
NUM <- "(\\d{1,3}(?:,\\d{3})+)"

# Kenya's financial year runs July to June: Jul-Sep is Q1, Oct-Dec Q2, Jan-Mar Q3, Apr-Jun Q4
fy_label <- function(d) {
  start <- if_else(month(d) >= 7, year(d), year(d) - 1L)
  paste0(start, "/", substr(start + 1, 3, 4))
}
fy_quarter_no <- function(d) c(3, 3, 3, 4, 4, 4, 1, 1, 1, 2, 2, 2)[month(d)]

read_report <- function(file) pdf_text(file.path(dir, file))
page_of <- function(pages, value) which(str_detect(pages, fixed(fmt(value))))[1]

# ---- Reports from October 2023 onwards: category table on the summary page ----
categories <- c("System Attacks", "Malware Attacks", "Brute Force Attacks",
                "Web Application Attacks", "Distributed Denial of Service Attacks",
                "Mobile Application Attacks")

from_table <- function(file) {
  pages <- read_report(file)
  p <- which(str_detect(pages, "Total Cyber Threats Detected"))[1]
  block <- str_extract(pages[p], "(?s)Total Cyber Threats Detected.*?Total Cyber Threat Advisories Issued")
  total <- to_num(str_extract(block, NUM))
  rows <- map_dfr(categories, \(cat) tibble(
    category_raw = cat,
    events = to_num(str_match(block, paste0(cat, "\\s{2,}", NUM))[, 2])
  )) |> filter(!is.na(events))
  # advisories: the "issued N advisories" sentence; if a report has no such sentence,
  # the first number after the "Total Cyber Threat Advisories Issued" heading
  all <- paste(pages, collapse = "\n")
  adv <- to_num(str_match(all, paste0("issued ", NUM, " advisories"))[, 2])
  if (is.na(adv)) adv <- to_num(str_match(all, paste0("(?s)Total Cyber Threat Advisories Issued.*?", NUM))[, 2])
  rows |> mutate(reported_total = total, advisories = adv, source_page = p, note = NA_character_)
}

# ---- July-September 2023: one section per category ----
from_sections_2023_07 <- function(file) {
  pages <- read_report(file)
  all <- paste(pages, collapse = "\n")
  grab <- function(rx) to_num(str_match(all, regex(rx, ignore_case = TRUE))[, 2])
  rows <- tibble(
    category_raw = c("System Attacks", "Malware Attacks", "Web Application Attacks",
                     "Brute Force Attacks", "Mobile Application Attacks"),
    events = c(grab(paste0("System Attack Trends\\s+Threats Detected\\s+Advisories Issued\\s+", NUM)),
               grab(paste0("detected ", NUM, "\\s+malware")),
               grab(paste0("detected ", NUM, "\\s+web")),
               grab(paste0("detected ", NUM, "\\s+brute force")),
               grab(paste0("detected ", NUM, "\\s+mobile")))
  )
  total <- grab(paste0("detected ", NUM, " cyber threat events"))
  adv <- grab(paste0("issued ", NUM, " advisories"))
  rows |> mutate(reported_total = total, advisories = adv,
                 source_page = map_int(events, \(v) page_of(pages, v)),
                 note = "categories from each category's own section; DDoS not reported as detected this quarter")
}

# ---- April 2022 to June 2023: totals only ----
totals_only <- tribble(
  ~file,                  ~total_rx,                                             ~adv_rx,                                        ~note,
  "CA_cyber_2022-04.pdf", paste0("With ", NUM, " cyber threat attempts detected"), NA,                                             "annual report; quarterly total from the Director General's statement; categories only in an unlabelled chart; quarterly advisories not given",
  "CA_cyber_2022-07.pdf", paste0(NUM, "\\s+", NUM, "\\s+TOTAL ADVISORIES"),      paste0(NUM, "\\s+", NUM, "\\s+TOTAL ADVISORIES"),  "categories only in an unlabelled chart",
  "CA_cyber_2022-10.pdf", paste0(NUM, "\\s+", NUM, "\\s+TOTAL ADVISORIES"),      paste0(NUM, "\\s+", NUM, "\\s+TOTAL ADVISORIES"),  "categories only in an unlabelled chart; the next report gives advisories as 3,553,999",
  "CA_cyber_2023-01.pdf", paste0("detected ", NUM, " cyber\\s+threat\\s+events"),   paste0("These included ", NUM, " advisories"),  "categories only in an unlabelled chart",
  "CA_cyber_2023-04.pdf", paste0("detected ", NUM, " cyber\\s+threat\\s+events"),   paste0("These included ", NUM, " advisories"),  "categories only in an unlabelled chart"
)

from_totals <- function(file, total_rx, adv_rx, note) {
  pages <- read_report(file)
  all <- paste(pages, collapse = "\n")
  total <- to_num(str_match(all, total_rx)[, 2])
  adv <- if (is.na(adv_rx)) NA_real_ else {
    m <- str_match(all, adv_rx)
    to_num(if (ncol(m) == 3) m[, 3] else m[, 2])   # "total  advisories  TOTAL ADVISORIES" layout: second number
  }
  tibble(category_raw = NA_character_, events = NA_real_, reported_total = total,
         advisories = adv, source_page = page_of(pages, total), note = note)
}

# ---- Build the table ----
table_files <- c("CA_cyber_2023-10.pdf", sprintf("CA_cyber_%s.pdf",
  c("2024-01", "2024-04", "2024-07", "2024-10", "2025-01", "2025-04", "2025-07", "2025-10", "2026-01", "2026-04")))

extracted <- bind_rows(
  pmap_dfr(totals_only, \(file, total_rx, adv_rx, note) from_totals(file, total_rx, adv_rx, note) |> mutate(file = file)),
  from_sections_2023_07("CA_cyber_2023-07.pdf") |> mutate(file = "CA_cyber_2023-07.pdf"),
  map_dfr(table_files, \(f) from_table(f) |> mutate(file = f))
) |>
  mutate(period_start = ymd(paste0(str_extract(file, "\\d{4}-\\d{2}"), "-01")),
         fy = fy_label(period_start), quarter = fy_quarter_no(period_start)) |>
  select(fy, quarter, period_start, category_raw, events, reported_total, advisories, source_page, note, file) |>
  arrange(period_start, desc(events))

# ---- Checks ----
# 1. Every figure was found
stopifnot("a total could not be read" = !anyNA(extracted$reported_total))
stopifnot("a page could not be found" = !anyNA(extracted$source_page))

# 2. Every category figure appears on its recorded page
for (i in which(!is.na(extracted$events))) {
  pages <- read_report(extracted$file[i])
  stopifnot(str_detect(pages[extracted$source_page[i]], fixed(fmt(extracted$events[i]))))
}

# 3. Categories add up to the report's printed total
totals_check <- extracted |>
  filter(!is.na(events)) |>
  group_by(period_start) |>
  summarise(sum_of_categories = sum(events), reported_total = first(reported_total), .groups = "drop") |>
  mutate(match = sum_of_categories == reported_total)
print(totals_check, n = Inf)
# Known gap in the source: the January-March 2025 report's own categories add up to
# 854,930 events (0.03%) less than its printed total. Both are kept exactly as printed.
known_gaps <- ymd("2025-01-01")
stopifnot("categories do not add up to a printed total" =
            all(totals_check$match | totals_check$period_start %in% known_gaps))
extracted <- extracted |>
  mutate(note = case_when(
    period_start == ymd("2023-10-01") ~ "DDoS not reported as a detected category this quarter (only in advisories)",
    period_start == ymd("2024-10-01") ~ "advisories: the report's text and category breakdown give 11,584,581; its headline figure says 11,584,949",
    TRUE ~ note)) |>
  mutate(note = if_else(period_start %in% known_gaps,
                        "the report's categories add up to 2,537,428,868, which is 854,930 (0.03%) less than its printed total; both kept as printed",
                        note))

extracted |> select(-file) |> write_csv("data/interim/ca_entry_extracted.csv", na = "")
cat("\nWrote data/interim/ca_entry_extracted.csv:", n_distinct(extracted$period_start), "quarters,",
    sum(!is.na(extracted$events)), "category rows\n")
