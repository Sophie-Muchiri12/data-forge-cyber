# scripts/04_build_vulns.R
library(tidyverse)

nvd <- readRDS("data/interim/nvd_cves.rds")

# Part 1: Load the three tables
kev <- read_csv("data/raw/kev/kev_2026-10-27.csv") |>
  transmute(cve_id = cveID,
            kev_date_added = as_date(dateAdded),
            ransomware = knownRansomwareCampaignUse == "Known")

epss <- read_csv("data/raw/epss/epss_scores-2025-01-01.csv.gz", skip = 1) |>
  transmute(cve_id = cve, epss_2025_01_01 = epss)

# Part 2: Joining the three tables and adding new columns.
vulns <- nvd |>
  left_join(kev, by = "cve_id") |>
  left_join(epss, by = "cve_id") |>
  mutate(
    exploited = !is.na(kev_date_added),
    pub_year = year(published),
    vendor = na_if(vendor, "n/a"),
    cwe_group = fct_lump_n(replace_na(cwe, "Unknown"), n = 15),
    vendor_group = fct_lump_n(replace_na(vendor, "unknown"), n = 20),
    says_rce = str_detect(description, regex("remote code execution|execute arbitrary code", ignore_case = TRUE)),
    says_auth_bypass = str_detect(description, regex("authentication bypass|bypass authentication", ignore_case = TRUE)),
    says_sqli = str_detect(description, regex("sql injection", ignore_case = TRUE)),
    desc_length = str_length(description)
  )

# Part 3: Count KEV entries with no NVD match. Expected: CVEs from before 2016,
# which we didn't download. Write this number in docs/decisions.md.
anti_join(kev, nvd, by = "cve_id") |> nrow()

saveRDS(vulns, "data/processed/vulns.rds")