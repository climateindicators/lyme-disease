# Provenance

Every file in this directory is reproduced unmodified from EPA's published
indicator page and its per-figure data downloads. To update the data, replace the
file and rerun `Rscript R/build_data.R`.

## Indicator page

- `source-page.html`  \
  <https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-lyme-disease/index.html>  \
  sha256 `c900afa936df9d611f1c8d5b185fcf90eec1dafd1748c1dd516210e1c03c9f85`

Technical documentation: <https://19january2025snapshot.epa.gov/system/files/documents/2024-12/lyme_td.pdf>

## Figure data

- `lyme_fig-1.csv`  \
  <https://19january2025snapshot.epa.gov/system/files/other-files/2024-12/lyme_fig-1.csv>  \
  sha256 `f8f50029b8168514c3e11e098d9ae8626b44049bcb7b95dc4ce7f3d7e101a541`  \
  encoding windows-1252, 31 data rows, columns: `Year`, `1990 case definition`, `1996 case definition`, `2008 case definition`, `2022 case definition`  \
  title: Figure 1. Reported Cases of Lyme Disease in the United States, 1992–2022  \
  data source: Centers for Disease Control and Prevention, 2024; web update: December 2024; units: cases per 100,000 people

- `lyme_fig-2.csv`  \
  <https://19january2025snapshot.epa.gov/system/files/other-files/2024-12/lyme_fig-2.csv>  \
  sha256 `3b769a32c041ba8107389077881930de7d5ea43c243c2a2fa5be2568bdfe84a3`  \
  encoding UTF-8-BOM, 51 data rows, columns: `Jurisdiction`, `Incidence (per 100,000 people)`  \
  title: Figure 2. Reported Annual Lyme Disease Incidence in the United States, 2022  \
  data source: Centers for Disease Control and Prevention, 2024; web update: December 2024; units: cases per 100,000 people

- **Figure 3** has no data download on EPA's page. The narrative carries the caption; there is nothing to build.
