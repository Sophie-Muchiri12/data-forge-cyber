# EPSS stands for Exploit Prediction Scoring System its
# a system that estimates the probability that a software vulnerability will be exploited
# by attackers

# EPSS helps security teams decide which vulnerabilities to fix first, especially when an organization has hundreds or thousands of known vulnerabilities.
# scripts/06_download_epss.R
# Downloads two EPSS files: the 1 January 2025 snapshot (for the fair test)
# and today's scores (for exploring). Records both in the source log.

library(tidyverse)
dir.create("data/raw/epss", recursive = TRUE, showWarnings = FALSE)
options(timeout = 600)

# EPSS files are published on these two sites; try each in turn
hosts <- c("https://epss.empiricalsecurity.com", "https://epss.cyentia.com")

get_epss <- function(file) {
  dest <- file.path("data/raw/epss", file)
  for (h in hosts) {
    url <- paste0(h, "/", file)
    try(suppressWarnings(download.file(url, dest, mode = "wb", quiet = TRUE)), silent = TRUE)
    if (file.exists(dest) && file.size(dest) > 100000) return(url)   # a real file is several MB
  }
  if (file.exists(dest)) file.remove(dest)
  stop("Could not download ", file, " from either site. Download it by hand from the EPSS data page.")
}

# Reads the comment line at the top: model version and score date
file_info <- function(dest) {
  first <- readLines(gzfile(dest), n = 1)
  list(model = str_extract(first, "(?<=model_version:)[^,]+"),
       date  = str_sub(str_extract(first, "(?<=score_date:)[0-9-]+"), 1, 10))
}

# 1. The 1 January 2025 snapshot
url_hist  <- get_epss("epss_scores-2025-01-01.csv.gz")
dest_hist <- "data/raw/epss/epss_scores-2025-01-01.csv.gz"
info_hist <- file_info(dest_hist)

# 2. Today's scores, renamed with their date so the file name never goes stale
url_now  <- get_epss("epss_scores-current.csv.gz")
info_now <- file_info("data/raw/epss/epss_scores-current.csv.gz")
dest_now <- file.path("data/raw/epss", paste0("epss_scores-", info_now$date, ".csv.gz"))
file.rename("data/raw/epss/epss_scores-current.csv.gz", dest_now)

# 3. Check both files read properly (the first line is a comment, so skip it)
epss_hist <- read_csv(dest_hist, skip = 1)
epss_now  <- read_csv(dest_now,  skip = 1)
glimpse(epss_hist)                      # columns: cve, epss, percentile
cat("1 Jan 2025 file:", nrow(epss_hist), "CVEs | today's file:", nrow(epss_now), "CVEs\n")

# 4. Record both downloads in the source log
tibble(dataset        = "EPSS",
       file_name      = basename(c(dest_hist, dest_now)),
       url            = c(url_hist, url_now),
       downloaded_on  = as.character(Sys.Date()),
       downloaded_by  = "Sophie",
       period_covered = paste("scores as of", c(info_hist$date, info_now$date)),
       terms_of_use   = "FIRST EPSS - free to use with attribution",
       notes          = paste0(c(nrow(epss_hist), nrow(epss_now)), " CVEs; model ",
                               c(info_hist$model, info_now$model))) |>
  write_csv("docs/source_log.csv", append = TRUE)


epss_data <- read_csv("data/raw/epss/epss_scores-2025-01-01.csv.gz", skip = 1)
View(epss_data)
