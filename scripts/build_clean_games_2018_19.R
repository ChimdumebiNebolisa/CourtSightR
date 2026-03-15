#!/usr/bin/env Rscript
# build_clean_games_2018_19.R --- Build CourtSightR-ready CSV from raw NBA player-game data
# Reads raw CSV, filters to 2018-19 season, maps to CourtSightR schema, writes clean CSV.
# Run from project root: Rscript scripts/build_clean_games_2018_19.R [path_to_raw_csv]

# --- Configuration ---
# Default: raw file in data-raw/ (not committed; place your downloaded file there)
RAW_PATH_DEFAULT <- "data-raw/games_raw.csv"
OUT_PATH         <- "data/games_2018_19_courtsightr.csv"

# 2018-19 NBA season: full season, pre-COVID, clean. Oct 2018 - June 2019.
SEASON_START <- as.Date("2018-10-01")
SEASON_END   <- as.Date("2019-06-30")

# Optional: to later expand to 2017-18 + 2018-19, use e.g.:
# SEASON_START <- as.Date("2017-10-01")
# SEASON_END   <- as.Date("2019-06-30")
# and set OUT_PATH <- "data/games_2017_19_courtsightr.csv" (and adjust script name/logic)

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

# --- Raw → CourtSightR column mapping ---
# Raw columns used:
#   GAME_ID     → game_date (parsed from path, e.g. /boxscores/201812250LAL.html → 2018-12-25)
#   PLAYER      → player_name
#   TEAM        → team (full name, e.g. "Phoenix Suns"; CourtSightR normalizes to uppercase)
#   OPPT        → opponent (full name)
#   RESULT      → win_loss ("W"→"win", "L"→"loss")
#   MP          → minutes
#   PTS         → points
#   TRB         → rebounds
#   AST         → assists
#   FG          → fg_made
#   FGA         → fg_attempts
#   FG3         → fg3_made
#   FG3A        → fg3_attempts
#   FT          → ft_made
#   FTA         → ft_attempts
#   TOV         → turnovers
#   PLUS_MINUS  → plus_minus
# home_away is derived from GAME_ID home-team code (YYYYMMDD0XXX; XXX=home team).

raw_path <- if (length(commandArgs(trailingOnly = TRUE)) > 0L) {
  commandArgs(trailingOnly = TRUE)[1L]
} else {
  RAW_PATH_DEFAULT
}

if (!file.exists(raw_path)) {
  stop("Raw CSV not found: ", raw_path,
       ". Place the downloaded file at data-raw/games_raw.csv or pass path as argument.",
       call. = FALSE)
}

message("Reading raw CSV: ", raw_path)
raw <- read_csv(raw_path, show_col_types = FALSE, progress = TRUE)

# Parse game_date from GAME_ID (e.g. /boxscores/201812250LAL.html → 2018-12-25)
parse_game_date_from_id <- function(x) {
  # Basketball Reference-style id is YYYYMMDD0XXX where XXX is home team code.
  # Extract YYYYMMDD from first 8 chars after last "/".
  s <- sub(".*/", "", x)
  s <- sub("\\.html$", "", s)
  date_str <- substr(s, 1L, 8L)
  as.Date(date_str, format = "%Y%m%d")
}

raw[["game_date"]] <- parse_game_date_from_id(raw[["GAME_ID"]])
# Drop rows where date parsing failed
raw <- raw[!is.na(raw[["game_date"]]), , drop = FALSE]

# Filter to 2018-19 season
n_before <- nrow(raw)
raw <- raw[raw[["game_date"]] >= SEASON_START & raw[["game_date"]] <= SEASON_END, , drop = FALSE]
n_after <- nrow(raw)
message("Filtered to 2018-19 season: ", n_after, " rows (from ", n_before, ")")

# Derive home_away from GAME_ID home team code:
# GAME_ID basename format: YYYYMMDD0XXX.html
# - XXX is home team code in Basketball Reference notation.
extract_home_code <- function(x) {
  s <- sub(".*/", "", x)
  s <- sub("\\.html$", "", s)
  out <- rep(NA_character_, length(s))
  ok <- nchar(s) >= 12L & substr(s, 9L, 9L) == "0"
  out[ok] <- substr(s[ok], 10L, 12L)
  out
}

home_code_to_team <- c(
  ATL = "Atlanta Hawks",
  BOS = "Boston Celtics",
  BRK = "Brooklyn Nets",
  CHI = "Chicago Bulls",
  CHO = "Charlotte Hornets",
  CLE = "Cleveland Cavaliers",
  DAL = "Dallas Mavericks",
  DEN = "Denver Nuggets",
  DET = "Detroit Pistons",
  GSW = "Golden State Warriors",
  HOU = "Houston Rockets",
  IND = "Indiana Pacers",
  LAC = "Los Angeles Clippers",
  LAL = "Los Angeles Lakers",
  MEM = "Memphis Grizzlies",
  MIA = "Miami Heat",
  MIL = "Milwaukee Bucks",
  MIN = "Minnesota Timberwolves",
  NOP = "New Orleans Pelicans",
  NYK = "New York Knicks",
  OKC = "Oklahoma City Thunder",
  ORL = "Orlando Magic",
  PHI = "Philadelphia 76ers",
  PHO = "Phoenix Suns",
  POR = "Portland Trail Blazers",
  SAC = "Sacramento Kings",
  SAS = "San Antonio Spurs",
  TOR = "Toronto Raptors",
  UTA = "Utah Jazz",
  WAS = "Washington Wizards"
)

home_code <- extract_home_code(raw[["GAME_ID"]])
home_team_from_code <- unname(home_code_to_team[home_code])
team_name <- as.character(raw[["TEAM"]])
oppt_name <- as.character(raw[["OPPT"]])

# Resolve only when we can confirm the parsed home team against TEAM/OPPT:
# - TEAM == parsed home team   -> home
# - OPPT == parsed home team   -> away
# - otherwise                  -> NA (unresolved)
home_away <- ifelse(
  is.na(home_team_from_code) | is.na(team_name) | !nzchar(team_name),
  NA_character_,
  ifelse(
    team_name == home_team_from_code,
    "home",
    ifelse(oppt_name == home_team_from_code, "away", NA_character_)
  )
)
n_home_away_na <- sum(is.na(home_away))
message("Derived home_away from GAME_ID: unresolved rows = ", n_home_away_na, " / ", nrow(raw))

# Map and rename to CourtSightR schema
win_loss_map <- c("W" = "win", "L" = "loss")
clean <- raw %>%
  transmute(
    game_date   = game_date,
    player_name = PLAYER,
    team        = TEAM,
    opponent    = OPPT,
    home_away   = home_away,
    win_loss    = unname(win_loss_map[RESULT]),
    minutes     = as.numeric(MP),
    points      = as.numeric(PTS),
    rebounds    = as.numeric(TRB),
    assists     = as.numeric(AST),
    fg_made     = as.numeric(FG),
    fg_attempts = as.numeric(FGA),
    fg3_made    = as.numeric(FG3),
    fg3_attempts = as.numeric(FG3A),
    ft_made     = as.numeric(FT),
    ft_attempts = as.numeric(FTA),
    turnovers   = as.numeric(TOV),
    plus_minus  = as.numeric(PLUS_MINUS)
  )

# Coerce NAs to 0 only for counting stats where CourtSightR expects numeric (clean_data.R does this)
count_cols <- c("minutes", "points", "rebounds", "assists",
                "fg_made", "fg_attempts", "fg3_made", "fg3_attempts",
                "ft_made", "ft_attempts", "turnovers")
for (col in count_cols) {
  clean[[col]][is.na(clean[[col]])] <- 0
}

dir.create(dirname(OUT_PATH), recursive = TRUE, showWarnings = FALSE)
write_csv(clean, OUT_PATH, na = "")
message("Wrote ", nrow(clean), " rows to ", OUT_PATH)
