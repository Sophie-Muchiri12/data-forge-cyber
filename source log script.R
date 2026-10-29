install.packages(c("curl", "httr", "httr2", "tidyverse", "pdftools", "gt"))

library(tidyverse)

tibble(dataset = character(), file_name = character(), url = character(),
       downloaded_on = character(), downloaded_by = character(),
       period_covered = character(), terms_of_use = character(),
       notes = character()) |>
  write_csv("docs/source_log.csv")
log <- read_csv("docs/source_log.csv")
View(log)


library(pdftools)
txt <- pdf_text("data/raw/ca_reports/CA_cyber_2025-10.pdf")
cat(txt[1:3]) # look at the first three pages

kenya_url_data <- read.csv("data/raw/kenya_urls.csv")
View(kenya_url_data)

fk_data <- read.csv("data/raw/ca_entry_FK.csv")
View(fk_data)

cm_data <- read.csv("data/raw/ca_entry_CM.csv")
View(cm_data)

f <- "data/raw/ca_entry_CM.csv"
x <- readLines(f, warn = FALSE)
x <- iconv(x, from = "windows-1252", to = "UTF-8")   # convert the old Windows characters
x <- gsub("\u201c|\u201d", "", x)                    # remove the curly quotes
writeLines(x, f)

readr::read_csv(f) |> tail()                          # check: it should now read without errors

fk_data <- readr::read_csv("data/raw/ca_entry_FK.csv")
View(fk_data)

library(tidyverse)

list.files("data/raw/kev")    # shows every KEV file in the folder

kev <- list.files("data/raw/kev", full.names = TRUE) |>
  map_dfr(read_csv)

nrow(kev)                     # total rows
n_distinct(kev$cveID)         # unique vulnerabilities
