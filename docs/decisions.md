# Project Decisions Log

| Date       | Decision |
|------------|----------|
| 2026-10-28 | ca.go.ke was not checked for the Q4 FY2024/25 (Apr–Jun 2025) cybersecurity report — the site was unreachable in the browser session (allowlist block). The report was sourced successfully from ke-cirt.go.ke directly (`2024-25-Q4-Cyber-Security-Report.pdf`). ca.go.ke should be checked manually when accessible. |
| 2026-10-29 | vulns.rds and eda_kev.qmd use kev_2026-10-27.csv (1,758 entries), the newest KEV download, to match Felix's quality scripts, which read the newest file. |
| 2026-10-29 | 204 of 1,758 KEV entries have no match in nvd_cves.rds. All 204 are CVEs from before 2016, which is outside our NVD download (2016 onwards). So vulns.rds counts 1,554 exploited CVEs, not 1,758. |