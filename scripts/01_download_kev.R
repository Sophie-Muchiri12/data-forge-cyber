# scripts/01_download_kev.R
library(tidyverse)

url <- "https://www.cisa.gov/sites/default/files/csv/known_exploited_vulnerabilities.csv"

dir.create("data/raw/kev", recursive = TRUE, showWarnings = FALSE)
dest <- paste0("data/raw/kev/kev_", Sys.Date(), ".csv")

download.file(url, dest, mode = "wb")

kev <- read_csv(dest)
glimpse(kev)
nrow(kev)

# Record this download in the source log
tibble(dataset = "KEV",
       file_name = basename(dest),
       url = url,
       downloaded_on = as.character(Sys.Date()),
       downloaded_by = "Quintone",
       period_covered = paste("2021-11 to", format(Sys.Date(), "%Y-%m")),
       terms_of_use = "CISA public data",
       notes = paste(nrow(kev), "entries")) |>
  write_csv("docs/source_log.csv", append = TRUE)