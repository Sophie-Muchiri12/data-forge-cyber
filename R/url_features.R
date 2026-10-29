# R/url_features.R
library(tidyverse)

# Kenyan second-level endings: "safaricom.co.ke" is one site, not a subdomain of "co.ke"
ke_suffixes <- c("co.ke", "go.ke", "ac.ke", "or.ke", "ne.ke", "sc.ke",
                 "me.ke", "mobi.ke", "info.ke")

last_label <- function(l) vapply(l, function(x) x[length(x)], character(1))

url_features <- function(url) {
  url  <- str_trim(url)
  host <- url |> str_remove("^[a-zA-Z]+://") |> str_remove("[/?#].*$") |>
    str_remove(":\\d+$") |> str_remove("^.*@") |> str_to_lower()
  rest <- str_remove(url, "^[a-zA-Z]+://[^/?#]+")
  tld  <- last_label(str_split(host, fixed(".")))
  two_part <- str_extract(host, "[^.]+\\.[^.]+$") %in% ke_suffixes
  n_dots <- str_count(host, fixed("."))
  
  tibble(
    url_length         = str_length(url),
    domain_length      = str_length(host),
    is_ip              = as.numeric(str_detect(host, "^\\d{1,3}(\\.\\d{1,3}){3}$")),
    tld_length         = str_length(tld),
    n_subdomains_naive = pmax(n_dots - 1, 0),
    n_subdomains_fixed = pmax(n_dots - 1 - two_part, 0),
    is_https           = as.numeric(str_detect(str_to_lower(url), "^https://")),
    letter_ratio       = str_count(url, "[A-Za-z]") / str_length(url),
    n_digits           = str_count(url, "[0-9]"),
    digit_ratio        = str_count(url, "[0-9]") / str_length(url),
    n_equals           = str_count(url, fixed("=")),
    n_qmark            = str_count(url, fixed("?")),
    n_ampersand        = str_count(url, fixed("&")),
    n_hyphens_domain   = str_count(host, fixed("-")),
    n_other_special    = str_count(url, "[^A-Za-z0-9:/.?=&\\-_]"),
    has_at             = as.numeric(str_detect(url, fixed("@"))),
    has_percent_code   = as.numeric(str_detect(url, "%[0-9A-Fa-f]{2}")),
    path_length        = str_length(rest),
    n_path_parts       = str_count(rest, fixed("/"))
  )
}