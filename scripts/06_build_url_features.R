# scripts/06_build_url_features.R
library(tidyverse)
source("R/url_features.R")

phish <- readRDS("data/processed/phishing.rds")

phish_url <- bind_cols(select(phish, is_phishing), url_features(phish$URL))

dim(phish_url)   # expect 235795 rows, 20 columns
saveRDS(phish_url, "data/processed/phishing_url_features.rds")