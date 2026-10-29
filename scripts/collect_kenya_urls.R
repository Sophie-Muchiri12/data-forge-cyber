library(rvest)
library(xml2)
library(dplyr)
library(stringr)
library(readr)
library(purrr)
library(tibble)

orgs <- tribble(
  ~home,                                  ~organisation,                      ~sector,
  "https://ardhisasa.lands.go.ke/",       "Ardhisasa (Lands)",                "government",
  "https://www.hudumakenya.go.ke/",       "Huduma Kenya",                     "government",
  "https://www.sasra.go.ke/",             "SASRA",                            "government",
  "https://www.centralbank.go.ke/",       "Central Bank of Kenya",            "government",
  "https://www.nse.co.ke/",               "Nairobi Securities Exchange",      "government",
  "https://www.ict.go.ke/",               "ICT Authority",                    "government",
  "https://ke-cirt.go.ke/",               "National KE-CIRT/CC",              "government",
  "https://www.equitygroupholdings.com/", "Equity Group",                     "bank_sacco"
)
get_rows <- function(home, organisation, sector) {
  page <- tryCatch(read_html(home), error = function(e) NULL)
  if (is.null(page)) { message("Could not read: ", home); return(NULL) }

  host <- sub("^www\\.", "", url_parse(home)$server)
  links <- page |> html_elements("a") |> html_attr("href") |> na.omit() |>
          url_absolute(home) |> unique() |> na.omit() |> as.character()
  links <- links[str_starts(links, "https://") &
                 str_detect(links, fixed(host)) &
                 !str_detect(links, "#|mailto:|\\.(pdf|jpg|png|docx?|xlsx?)$")]

  is_login <- str_detect(tolower(links), "login|signin|sign-in|portal|e-?services|account|apply")
  login <- links[is_login]
  deep  <- links[!is_login & !links %in% c(home, sub("/$", "", home))]

  pick <- c(home,
            if (length(login)) login[1],
            if (length(deep))  deep[ceiling(length(deep) / 2)])
  type <- c("homepage",
            if (length(login)) "login_service",
            if (length(deep))  "deep")

  tibble(url = pick, organisation = organisation, sector = sector,
         page_type = type, collected_by = "Bradley",
         collected_on = as.character(Sys.Date()))
}

out <- pmap_dfr(orgs, \(home, organisation, sector) {
  Sys.sleep(1)
  get_rows(home, organisation, sector)
})

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
write_csv(out, "data/raw/kenya_urls_candidates.csv")
print(out, n = Inf)