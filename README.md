# CourtSightR

A lightweight **terminal-run NBA analytics tool** built in R. CourtSightR loads a local CSV of NBA game data, cleans it, computes performance splits, prints readable summaries in the terminal, and saves CSV summaries and plots to an `outputs/` folder. 

## Why it exists

NBA box-score data is often messy and spread across many rows. CourtSightR provides a single, local-first workflow: point it at a CSV, choose a player or team and a split type, and get cleaned metrics, terminal summaries, and exportable outputs without any API, database, or cloud setup. The goal is to look and feel like a real data analytics project suitable for portfolios and technical discussions.

## Features

- **CSV ingestion** — Load a local CSV via `--input`; validates file existence and required columns.
- **Data cleaning** — Normalizes column names, dates, numeric types, and text fields (e.g. `home_away`, `win_loss`, team codes).
- **Analysis modes** — `player` and `team` (team aggregates player-game rows to one row per team per game).
- **Split analysis** — `overall`, `home_away`, `win_loss`, `opponent`, `last_n` (with optional `--last_n`).
- **Metrics** — Games played, PPG, RPG, APG, FG%, 3P%, FT%, MPG, TOV/g, plus/minus average.
- **Terminal output** — Formatted summary tables, no raw dumps.
- **File outputs** — Summary CSV and at least one bar chart plus a trend plot when recent-game data exists.
- **Error handling** — Clear messages for missing file, missing columns, missing entity, no matching data, and unsupported split.

## Folder structure

```
CourtSightR/
  README.md
  main.R
  DESCRIPTION
  .gitignore
  data/
    sample_nba_games.csv
    games_2018_19_courtsightr.csv   # analysis-ready 2018-19 season (see data/DATA.md)
    DATA.md                         # source, season choice, limitations
  data-raw/
    games_raw.csv                   # raw player-game CSV (not committed; place file here)
  scripts/
    build_clean_games_2018_19.R     # builds clean CSV from raw
    evaluate_split_usefulness.R     # split-usefulness evaluation (2018-19)
  reports/
    split_usefulness_2018_19.Rmd    # evaluation report
    tables/
      split_usefulness_summary.csv  # comparison table (after running eval script)
  R/
    load_data.R
    clean_data.R
    analyze_player.R
    analyze_team.R
    metrics.R
    plots.R
    utils.R
  outputs/
```

## Installation

1. Install [R](https://www.r-project.org/) (4.0+).
2. Install required packages (run in R or RStudio):

```r
install.packages(c("readr", "dplyr", "tidyr", "ggplot2", "optparse"))
```

3. Clone or download the project and open a terminal in the `CourtSightR` directory.

## How to run

Run from the **project root** (the directory that contains `main.R` and the `R/` folder):

```bash
Rscript main.R --input <path-to-csv> --mode <player|team> --entity "<name-or-code>" --split <split-type> [--last_n N]
```

## Example commands

```bash
# Player, home/away split
Rscript main.R --input data/sample_nba_games.csv --mode player --entity "Luka Doncic" --split home_away

# Team, win/loss split
Rscript main.R --input data/sample_nba_games.csv --mode team --entity "DAL" --split win_loss

# Player, last 10 games (with trend plot)
Rscript main.R --input data/sample_nba_games.csv --mode player --entity "Jayson Tatum" --split last_n --last_n 10
```

## Expected input schema

The CSV should contain one row per **player-game** with at least these columns:

| Column       | Description                    |
|-------------|--------------------------------|
| game_date   | Date of game (YYYY-MM-DD or similar) |
| player_name | Full player name               |
| team        | Team code (e.g. DAL, BOS)      |
| opponent    | Opponent team code             |
| home_away   | "home" or "away"               |
| win_loss    | "win" or "loss"                |
| minutes     | Minutes played                 |
| points      | Points                         |
| rebounds    | Rebounds                       |
| assists     | Assists                        |
| fg_made     | Field goals made               |
| fg_attempts | Field goal attempts            |
| fg3_made    | 3-pointers made                |
| fg3_attempts| 3-point attempts               |
| ft_made     | Free throws made               |
| ft_attempts | Free throw attempts            |
| turnovers   | Turnovers                      |
| plus_minus  | Plus/minus                     |

The repository includes `data/sample_nba_games.csv` with this schema for testing.

For a full-season analysis slice (e.g. split-usefulness evaluation), use the 2018-19 build: see **data/DATA.md** for the source dataset, why 2018-19 was chosen, and how to generate `data/games_2018_19_courtsightr.csv` from the raw file (`data-raw/games_raw.csv`).

**Split-usefulness evaluation:** To run the lightweight evaluation of which split types produce meaningful variation on the 2018-19 cleaned data (player-level, win_loss / home_away / opponent):

```bash
Rscript scripts/evaluate_split_usefulness.R
```

This writes `reports/tables/split_usefulness_summary.csv` and `reports/tables/split_usefulness_summary.md`. Then render the short report: open `reports/split_usefulness_2018_19.Rmd` in RStudio and knit, or run `rmarkdown::render("reports/split_usefulness_2018_19.Rmd")` from the project root.

## Output examples

- **Terminal**: A formatted block with entity, mode, split, and per-split metrics (games, PPG, RPG, APG, FG%, 3P%, FT%, MPG, TOV/g, +/-).
- **outputs/summary_&lt;mode&gt;_&lt;entity&gt;_&lt;split&gt;.csv** — Same metrics in CSV form.
- **outputs/bar_&lt;entity&gt;_&lt;split&gt;.png** — Bar chart comparing a key metric (e.g. PPG) across split groups.
- **outputs/trend_&lt;entity&gt;_last_n.png** — Trend of a stat (e.g. points) over the last N games when that view is available.

## Future improvements

- Additional splits (e.g. month, back-to-back).
- More metrics (e.g. usage rate, true shooting %).
- Optional HTML or PDF report generation.
- Support for multiple entities in one run (batch summaries).

---

*Built as an R-based command-line NBA analytics tool for cleaning game data, computing performance splits, and generating summary outputs for exploratory analysis.*
