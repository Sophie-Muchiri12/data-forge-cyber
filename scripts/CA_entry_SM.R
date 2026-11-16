library(tidyverse)
tibble(fy = character(), quarter = integer(), period_start = character(),
       category_raw = character(), events = numeric(), reported_total = numeric(),
       advisories = numeric(), source_page = integer(), note = character()) |>
  write_csv("data/raw/ca_entry_SM.csv")