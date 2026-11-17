# 08_build_ca_quarterly.R
# Builds the two clean Kenya tables used by Part 1 (analysis/part1_kenya_trends.qmd):
#
#   data/processed/ca_quarterly.csv  one row per category per quarter, with the
#                                    standard category name from docs/ca_category_map.csv
#   data/processed/ca_totals.csv     one row per quarter: total detected events, advisories,
#                                    and whether the quarter has a category breakdown
#
# Sources:
#   data/raw/ca_entry_CM.csv              typed in by hand (double entry, checked against ca_entry_FK.csv)
#   data/interim/ca_entry_extracted.csv   read from the PDF text by scripts/07_extract_ca_figures.R
# Where a quarter is in both, the hand-typed figures are used and the two are compared.

library(tidyverse)

typed <- read_csv("data/raw/ca_entry_CM.csv", show_col_types = FALSE,
                  col_types = cols(period_start = col_date(), .default = col_guess())) |>
  mutate(source = "typed by hand (double entry)")
extracted <- read_csv("data/interim/ca_entry_extracted.csv", show_col_types = FALSE,
                      col_types = cols(period_start = col_date(), category_raw = col_character(),
                                       note = col_character(), .default = col_guess())) |>
  mutate(source = "read from report text by script")

# ---- Check: quarters in both sources must agree ----
both <- inner_join(typed, extracted, by = c("period_start", "category_raw"), suffix = c("_typed", "_extracted"))
if (nrow(both) > 0) {
  disagree <- both |> filter(events_typed != events_extracted | reported_total_typed != reported_total_extracted)
  cat("Quarters in both sources:", n_distinct(both$period_start), "| rows that disagree:", nrow(disagree), "\n")
  stopifnot("typed and extracted figures disagree" = nrow(disagree) == 0)
}

combined <- bind_rows(
  typed,
  extracted |> filter(!period_start %in% typed$period_start)
) |>
  mutate(quarter = as.integer(quarter))

# ---- Standard category names ----
cat_map <- read_csv("docs/ca_category_map.csv", show_col_types = FALSE)
ca_quarterly <- combined |>
  filter(!is.na(category_raw)) |>
  left_join(cat_map, by = "category_raw")
unmapped <- ca_quarterly |> filter(is.na(category_std)) |> distinct(category_raw)
stopifnot("add these names to docs/ca_category_map.csv" = nrow(unmapped) == 0)

ca_quarterly <- ca_quarterly |>
  select(fy, quarter, period_start, category_raw, category_std, events,
         reported_total, advisories, source_page, source, note) |>
  arrange(period_start, desc(events))

# ---- One row per quarter ----
ca_totals <- combined |>
  group_by(fy, quarter, period_start) |>
  summarise(reported_total = first(reported_total),
            advisories = first(advisories),
            has_categories = any(!is.na(events)),
            sum_of_categories = if (any(!is.na(events))) sum(events, na.rm = TRUE) else NA_real_,
            source = first(source),
            .groups = "drop") |>
  mutate(gap_pct = round(100 * (reported_total - sum_of_categories) / reported_total, 3)) |>
  arrange(period_start)

# Every quarter from January 2020 to June 2026 should be present exactly once
expected <- seq(ymd("2020-01-01"), ymd("2026-04-01"), by = "3 months")
missing_q <- setdiff(expected, ca_totals$period_start)
cat("Quarters:", nrow(ca_totals), "of", length(expected), "| with categories:", sum(ca_totals$has_categories), "\n")
if (length(missing_q) > 0) cat("Missing quarters:", format(as_date(missing_q)), "\n")

print(ca_totals |> select(period_start, reported_total, sum_of_categories, gap_pct, has_categories), n = Inf)

write_csv(ca_quarterly, "data/processed/ca_quarterly.csv", na = "")
write_csv(ca_totals, "data/processed/ca_totals.csv", na = "")
cat("Wrote data/processed/ca_quarterly.csv and data/processed/ca_totals.csv\n")
