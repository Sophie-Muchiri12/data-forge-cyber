# Data Forge: The Changing Cyber Threat Landscape in Kenya

Kenya records billions of detected cyber threat events every quarter, and tens of thousands of new software vulnerabilities are published worldwide every year. No organisation can fix everything at once.

Data Forge uses public data to show how cyber threats in Kenya are changing, which vulnerabilities attackers actually use, and which ones organisations should fix first. It also tests whether a phishing detector trained on global data works on Kenyan websites.

Everything is done in R. Every table, chart and number in our reports is computed from the files in this repository, so all results can be checked and rebuilt.

---

## Research questions

1. **Kenya trends:** How have detected cyber threat categories in Kenya changed from quarter to quarter and year to year?
2. **What gets exploited:** Which severity scores, technical characteristics and products are associated with vulnerabilities that are actually exploited?
3. **What to fix first:** Can a model rank vulnerabilities by risk better than the CVSS severity score and the EPSS exploit prediction score?
4. **Phishing:** Which URL features separate phishing from legitimate URLs, and does a globally trained detector wrongly flag legitimate Kenyan websites?

---

## Key findings so far

These come from the exploratory data analysis (Phase 2).

| Area | Finding |
| --- | --- |
| Kenya | Detected threat events grew from about 35 million a quarter (January to March 2020) to 3.4 billion (January to March 2026). Malware fell from 97% of events to 47% by early 2022. |
| Volume | 85,802 new CVEs had been published in 2026 by late October, almost twice the 2025 total. |
| Exploitation | Only 0.49% of all CVEs, and 1.38% of Critical CVEs, are known to be exploited. |
| Signals | CVEs whose description mentions remote code execution are four times as likely to be exploited. Microsoft accounts for 22% of exploited CVEs. |
| Prioritisation | Fixing the top 5% of open CVEs ranked by EPSS would have caught 31% of those exploited after 1 January 2025, against 10% when ranked by CVSS severity. |
| Data quality | Until 2023 the NVD scored over 90% of CVEs itself; in 2026 it scored 16%. Most new scores now come from the reporting company. |
| Phishing | One PhiUSIIL feature (URLSimilarityIndex) separates the classes almost perfectly and is treated as a leak. All legitimate URLs in the dataset are bare homepages, while 75% of Kenyan login pages have a path, so a global detector may wrongly flag them. |

---

## Data sources

| Source | What it provides | Size | Format |
| --- | --- | --- | --- |
| [KE-CIRT/CC quarterly reports](https://ke-cirt.go.ke/quarterly-reports/), Communications Authority of Kenya | Detected cyber threat events in Kenya by category, per quarter | 26 reports, 2020 to 2026 | PDF, typed in by hand |
| [National Vulnerability Database (NVD)](https://nvd.nist.gov/), via [fkie-cad/nvd-json-data-feeds](https://github.com/fkie-cad/nvd-json-data-feeds) | Every published vulnerability (CVE) with its severity score, weakness type and affected product | 315,909 CVEs, 2016 to 2026 | JSON, one file per year |
| [CISA Known Exploited Vulnerabilities (KEV)](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) | CVEs confirmed as exploited in real attacks | 1,758 CVEs | CSV |
| [FIRST EPSS](https://www.first.org/epss/data_stats) | Daily predicted probability that each CVE is exploited in the next 30 days | 271,765 scores (1 January 2025) | CSV (gzip) |
| [PhiUSIIL Phishing URL Dataset](https://archive.ics.uci.edu/dataset/967/phiusiil+phishing+url+dataset), UCI | Labelled phishing and legitimate URLs | 235,795 URLs | CSV |
| Kenyan URL list (built for this project) | Real, legitimate Kenyan website addresses across 7 sectors | 348 URLs, 124 organisations | CSV |

Every download is recorded in `docs/source_log.csv` with its link, date, who downloaded it and its terms of use.

This project uses data from the NVD API but is not endorsed or certified by the NVD.

---

## Folder structure

```text
data-forge-cyber/
├── data/
│   ├── raw/                 Original files exactly as downloaded (never edited)
│   │   ├── ca_reports/      KE-CIRT/CC quarterly report PDFs (CA_cyber_YYYY-MM.pdf)
│   │   ├── epss/            EPSS score files
│   │   ├── kev/             KEV catalog downloads
│   │   ├── nvd/             NVD yearly JSON files (not in Git, too large)
│   │   ├── phishing/        PhiUSIIL CSV (not in Git, too large)
│   │   ├── ca_entry_CM.csv  Kenyan report figures, first entry
│   │   ├── ca_entry_FK.csv  Kenyan report figures, second entry
│   │   └── kenya_urls.csv   Kenyan URL list
│   ├── interim/             Half-cleaned files made by scripts (safe to delete and rebuild)
│   └── processed/           Final analysis tables: vulns.rds, phishing.rds, phishing_url_features.rds
├── R/                       Reusable functions: parse_nvd.R, url_features.R, theme_dataforge.R
├── scripts/                 Numbered steps that download and clean the data
├── analysis/                Quarto notebooks for exploratory analysis (eda_*.qmd)
├── outputs/
│   ├── figures/             Charts saved as PNG
│   └── tables/              Result tables saved as CSV
├── report/                  Presentation slides and written submissions (Quarto)
├── dashboard/               Optional dashboard (later phase)
├── docs/                    source_log.csv, decisions.md, data_quality.md
├── data-forge-cyber.Rproj
└── README.md
```

### Folder rules

| Folder | Rule |
| --- | --- |
| `data/raw/` | Never edit. All changes happen in code. |
| `data/interim/` | Only written by scripts. Safe to delete and rebuild. |
| `data/processed/` | Only written by scripts in `scripts/`. Every notebook reads from here. |
| `R/` | Functions only, no code that runs on its own. |
| `docs/` | Update as you work, not at the end. |

---

## Scripts and what they do

Run them in this order. Each step reads the output of the step before it.

| Step | Script | What it does | Output |
| --- | --- | --- | --- |
| Download | `download_ca_reports.R` | Downloads the KE-CIRT/CC reports (live site or Wayback Machine) | `data/raw/ca_reports/` |
| Download | `00_ca_manifest.R` | Checks every report opens and records its quarter and pages | `data/interim/ca_report_manifest.csv` |
| Download | `01_download_kev.R` | Downloads the KEV catalog and logs it | `data/raw/kev/` |
| Download | `02_download_nvd.R` | Downloads the NVD yearly files from the fkie-cad release | `data/raw/nvd/` |
| Download | `06_download_epss.R` | Downloads the EPSS scores for 1 January 2025 | `data/raw/epss/` |
| Download | `collect_kenya_urls.R` | Collects Kenyan URLs sector by sector | `data/raw/kenya_urls.csv` |
| Clean | `03_build_nvd.R` | Turns the NVD JSON into one row per CVE (takes about 25 minutes) | `data/interim/nvd_cves.rds` |
| Clean | `04_build_vulns.R` | Joins NVD, KEV and EPSS and adds derived columns | `data/processed/vulns.rds` |
| Clean | `05_build_phishing.R` | Names the phishing labels | `data/processed/phishing.rds` |
| Clean | `06_build_url_features.R` | Computes 19 features from the URL text only | `data/processed/phishing_url_features.rds` |
| Check | `felix_01_check_source_log.R`, `felix_03_cleaning_table.R`, `felix_04_quality_numbers.R` | Source log checks, cleaning table and data quality numbers | `outputs/tables/`, `docs/data_quality.md` |

The Kenyan report figures are typed in by hand twice (`ca_entry_CM.csv` and `ca_entry_FK.csv`). Code compares the two copies cell by cell and checks that each quarter's categories add up to the report's own total.

---

## Getting started

### 1. Install the tools

- R 4.4 or newer: <https://cran.r-project.org>
- RStudio Desktop: <https://posit.co/download/rstudio-desktop/>
- Git: <https://git-scm.com>

**Linux only:** install these system libraries first, or some R packages will fail to install:

```bash
sudo apt update
sudo apt install -y libcurl4-openssl-dev libssl-dev libxml2-dev libpoppler-cpp-dev \
  libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev \
  libpng-dev libjpeg-dev libtiff-dev
```

### 2. Clone the repository

In RStudio: **File > New Project > Version Control > Git**, then paste:

```text
https://github.com/Sophie-Muchiri12/data-forge-cyber
```

GitHub asks for a personal access token, not your password. Create one at <https://github.com/settings/tokens> (classic token, with `repo` ticked).

### 3. Install the R packages

Run once in the RStudio Console:

```r
install.packages(c("tidyverse", "jsonlite", "pdftools", "rvest", "xml2",
                   "here", "scales", "yardstick", "knitr", "rmarkdown"))
```

### 4. Get the large files

The NVD and PhiUSIIL raw files are too large for GitHub. Copy the `nvd` and `phishing` folders from the shared Drive into `data/raw/`, or run `02_download_nvd.R` and download PhiUSIIL from UCI. The processed tables in `data/processed/` are already in the repository, so the analysis notebooks and slides work without the raw files.

---

## Viewing the results

| File | What it shows |
| --- | --- |
| `analysis/eda_phishing.qmd` | Phishing dataset exploration and the Kenyan URL comparison |
| `analysis/eda_kev.qmd` | Exploited vulnerabilities: per year and top vendors |
| `analysis/eda_kenya_urls.qmd` | The Kenyan URL list by sector and page type |
| `report/phase2_slides.qmd` | Phase 2 presentation, with speaker notes (press S when presenting) |
| `report/phase2_submission.qmd` | Full Phase 2 write-up rendered to PDF |

Open any of them in RStudio and click **Render**. To see a single chart, run the `setup` chunk first and then the chart's chunk.

---

## How the team works with Git

1. **Pull** before you start, so you have everyone's latest work.
2. Work on your own branch, named after the task, for example `kev-cleaning`.
3. Commit often with clear messages: "Add KEV download script", not "update".
4. Open a pull request into `dev`. A teammate reviews it before it is merged.
5. `dev` is merged into `main` at each milestone.
6. Never commit passwords, API keys or tokens. Keep them in `.Renviron`, which is in `.gitignore`.

---

## Ethics and limitations

- All data used is public. No personal information is collected.
- KE-CIRT/CC figures count **detected** threat events, mostly blocked scans and attempts. They are not confirmed breaches.
- Category names change between KE-CIRT/CC reports, so a category map is used before comparing quarters.
- KEV mainly covers products used by US government agencies, so it shows **known** exploitation, not all exploitation.
- Our NVD download starts at CVE-2016 IDs.
- PhiUSIIL is a global dataset. The Kenyan URL list contains only legitimate public pages, and no phishing pages were visited at any point.
- The project does not claim that any vulnerability caused a specific attack in Kenya.

---

## Acknowledgements

Data is provided by the National KE-CIRT/CC under the Communications Authority of Kenya, the US National Institute of Standards and Technology (NVD), the Cybersecurity and Infrastructure Security Agency (KEV), FIRST (EPSS), and Prasad and Chandra (PhiUSIIL, UCI Machine Learning Repository, CC BY 4.0).
