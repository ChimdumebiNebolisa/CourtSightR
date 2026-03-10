#!/usr/bin/env Rscript
# main.R --- CourtSightR entry point: CLI and orchestration
# Usage: Rscript main.R --input data/sample_nba_games.csv --mode player --entity "Luka Doncic" --split home_away

suppressPackageStartupMessages({
  library(optparse)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Parse command-line arguments
option_list <- list(
  make_option(c("-i", "--input"), type = "character", default = "data/sample_nba_games.csv",
              help = "Path to NBA games CSV", metavar = "FILE"),
  make_option(c("-m", "--mode"), type = "character", default = "player",
              help = "Analysis mode: player or team"),
  make_option(c("-e", "--entity"), type = "character", default = "",
              help = "Player name or team code (e.g. 'Luka Doncic' or 'DAL')"),
  make_option(c("-s", "--split"), type = "character", default = "overall",
              help = "Split: overall, home_away, win_loss, opponent, last_n"),
  make_option(c("-n", "--last_n"), type = "integer", default = 10L,
              help = "Number of recent games when split is last_n [default %default]", metavar = "N")
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

# Source R modules: find project root (directory containing main.R or R/)
get_project_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)]
  if (length(file_arg) > 0) {
    root <- dirname(sub("^--file=", "", file_arg))
    if (file.exists(file.path(root, "R", "utils.R"))) return(root)
  }
  if (file.exists("R/utils.R")) return(".")
  stop("Cannot find R/ scripts. Run from CourtSightR project root.", call. = FALSE)
}
project_root <- get_project_root()
source(file.path(project_root, "R", "utils.R"), local = FALSE)
source(file.path(project_root, "R", "load_data.R"), local = FALSE)
source(file.path(project_root, "R", "clean_data.R"), local = FALSE)
source(file.path(project_root, "R", "metrics.R"), local = FALSE)
source(file.path(project_root, "R", "analyze_player.R"), local = FALSE)
source(file.path(project_root, "R", "analyze_team.R"), local = FALSE)
source(file.path(project_root, "R", "plots.R"), local = FALSE)

VALID_MODES <- c("player", "team")
VALID_SPLITS <- c("overall", "home_away", "win_loss", "opponent", "last_n")

# Validate mode and split
if (!opts$mode %in% VALID_MODES) {
  stop("Invalid mode: ", opts$mode, ". Use player or team.", call. = FALSE)
}
if (!opts$split %in% VALID_SPLITS) {
  stop("Unsupported split: ", opts$split, call. = FALSE)
}
if (!nzchar(trimws(opts$entity))) {
  stop("Please provide --entity for mode ", opts$mode, ".", call. = FALSE)
}

# Paths: use project root for relative paths
input_path <- if (grepl("^[/\\\\]|[A-Za-z]:", opts$input)) opts$input else file.path(project_root, opts$input)
out_dir <- file.path(project_root, "outputs")
ensure_output_dir(out_dir)

# Load and clean data
raw <- load_nba_csv(input_path)
clean_df <- clean_nba_data(raw)

# Run analysis
if (opts$mode == "player") {
  result <- analyze_player(clean_df, opts$entity, opts$split, opts$last_n)
} else {
  result <- analyze_team(clean_df, opts$entity, opts$split, opts$last_n)
}

# Print summary to terminal
print_summary(result, opts$mode, opts$entity, opts$split)

# Write summary CSV
safe_entity <- sanitize_entity(opts$entity)
csv_path <- file.path(out_dir, paste0("summary_", opts$mode, "_", safe_entity, "_", opts$split, ".csv"))
write_csv(result$summary, csv_path)
message("Summary written to ", csv_path)

# Bar chart (for any split with multiple groups or single group)
plot_split_bars(result, opts$entity, opts$split, metric = "ppg", out_dir = out_dir)
message("Bar chart saved to ", out_dir, "/")

# Trend plot when we have game-level data (e.g. last_n)
if (!is.null(result$games_df) && nrow(result$games_df) >= 2L) {
  plot_trend(result$games_df, opts$entity, y_var = "points", out_dir = out_dir)
  message("Trend plot saved to ", out_dir, "/")
}
