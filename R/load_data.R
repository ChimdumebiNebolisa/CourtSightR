# load_data.R --- Load and validate NBA game CSV
# CourtSightR: NBA analytics tool

REQUIRED_COLUMNS <- c(
  "game_date", "player_name", "team", "opponent", "home_away", "win_loss",
  "minutes", "points", "rebounds", "assists",
  "fg_made", "fg_attempts", "fg3_made", "fg3_attempts",
  "ft_made", "ft_attempts", "turnovers", "plus_minus"
)

#' Load NBA game data from a local CSV file.
#' Validates file existence and required columns.
#' @param path Character; path to CSV file
#' @return A data frame (tibble) of raw game data
#' @export
load_nba_csv <- function(path) {
  if (!file.exists(path)) {
    stop("Input file not found: ", path, call. = FALSE)
  }
  raw <- readr::read_csv(path, show_col_types = FALSE)
  raw_names <- names(raw)
  missing <- setdiff(REQUIRED_COLUMNS, raw_names)
  if (length(missing) > 0) {
    stop("Missing required columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  raw
}
