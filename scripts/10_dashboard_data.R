# Saves the small tables the dashboard needs, so dashboard/index.qmd loads in
# seconds instead of reading the 37 MB vulns.rds every time.
# Re-run this after vulns.rds or the Kenyan URL list changes.
#
# Outputs (data/processed/):
#   p2_rate_by_severity.rds   exploit rate by CVSS severity (Part 2)
#   p4_path_share.rds         share of URLs with a path: Kenya vs PhiUSIIL (Part 4)

library(tidyverse)
source("R/url_features.R")

# Part 2: same scope and filters as analysis/part2_exploited.qmd
v <- readRDS("data/processed/vulns.rds") |>
  filter(pub_year >= 2016, !is.na(cvss_score))

rate_by_severity <- v |>
  filter(severity != "NONE") |>
  mutate(severity = factor(severity, levels = c("LOW", "MEDIUM", "HIGH", "CRITICAL"))) |>
  group_by(severity) |>
  summarise(n = n(), n_exploited = sum(exploited),
            rate_pct = 100 * mean(exploited), .groups = "drop") |>
  arrange(severity)

overall <- tibble(n = nrow(v), n_exploited = sum(v$exploited),
                  rate_pct = 100 * mean(v$exploited))

saveRDS(list(by_severity = rate_by_severity, overall = overall),
        "data/processed/p2_rate_by_severity.rds")

# Part 4: Kenyan URLs against the phishing dataset, same function on both
phish_url <- readRDS("data/processed/phishing_url_features.rds")
ke <- read_csv("data/raw/kenya_urls.csv", show_col_types = FALSE)

path_share <- bind_rows(
  phish_url |> transmute(group = if_else(is_phishing == "phishing",
                                         "Dataset: phishing", "Dataset: legitimate"),
                         has_path = path_length > 1),
  url_features(ke$url) |> transmute(group = "Our Kenyan list", has_path = path_length > 1)
) |>
  group_by(group) |>
  summarise(n = n(), share_pct = 100 * mean(has_path), .groups = "drop")

saveRDS(path_share, "data/processed/p4_path_share.rds")

print(rate_by_severity)
print(overall)
print(path_share)
