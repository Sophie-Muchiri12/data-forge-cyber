# Project Decisions Log

| Date       | Decision |
|------------|----------|
| 2026-10-28 | ca.go.ke was not checked for the Q4 FY2024/25 (Apr–Jun 2025) cybersecurity report — the site was unreachable in the browser session (allowlist block). The report was sourced successfully from ke-cirt.go.ke directly (`2024-25-Q4-Cyber-Security-Report.pdf`). ca.go.ke should be checked manually when accessible. |
| 2026-10-29 | Added 40 Kenyan URLs (Safaricom, M-PESA, Airtel Kenya, Jumia, Equity, KCB, Nation Africa) to fix the telco/M-PESA gap (was 3 Telkom URLs). Safaricom and Airtel return HTTP 403 to automated fetches, so the URLs were taken from search results restricted to each organisation's own domain, not from site navigation. Each should be opened once in a browser to confirm it loads. `org.ke.m-pesa.com` and the Equity login hosts come from the organisations' own help pages. |
