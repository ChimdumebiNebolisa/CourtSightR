# clean_data.R --- Clean and normalize NBA game data
# CourtSightR: NBA analytics tool

#' Clean column names to snake_case and trim whitespace.
clean_names_snake <- function(x) {
  nms <- tolower(gsub("\\s+", "_", trimws(names(x))))
  nms <- gsub("[^a-z0-9_]", "", nms)
  names(x) <- nms
  x
}

#' Standardize home_away to "home" or "away".
normalize_home_away <- function(x) {
  if (is.null(x)) return(x)
  x <- trimws(tolower(as.character(x)))
  x[grepl("^h|1|true|yes", x, ignore.case = TRUE)] <- "home"
  x[grepl("^a|0|false|no", x, ignore.case = TRUE)] <- "away"
  x[!x %in% c("home", "away")] <- NA_character_
  x
}

#' Standardize win_loss to "win" or "loss".
normalize_win_loss <- function(x) {
  if (is.null(x)) return(x)
  x <- trimws(tolower(as.character(x)))
  x[grepl("^w|1|true|yes|won", x, ignore.case = TRUE)] <- "win"
  x[grepl("^l|0|false|no|lost", x, ignore.case = TRUE)] <- "loss"
  x[!x %in% c("win", "loss")] <- NA_character_
  x
}

#' Parse game_date; accepts ISO and common formats.
parse_game_date <- function(x) {
  if (is.null(x)) return(x)
  out <- suppressWarnings(as.Date(x, tryFormats = c("%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y")))
  if (all(is.na(out))) out <- readr::parse_date(x, format = "%Y-%m-%d")
  out
}

#' Clean and normalize NBA game data.
#' @param raw Data frame from load_nba_csv
#' @return Cleaned tibble with normalized types and text
clean_nba_data <- function(raw) {
  # Ensure we have the required names (may already be snake_case from CSV)
  if (!"player_name" %in% names(raw)) {
    nms <- clean_names_snake(raw)
  } else {
    nms <- raw
  }
  d <- dplyr::as_tibble(nms)

  # Normalize numeric columns; treat NA as 0 for counting stats where appropriate
  num_cols <- c("minutes", "points", "rebounds", "assists",
                "fg_made", "fg_attempts", "fg3_made", "fg3_attempts",
                "ft_made", "ft_attempts", "turnovers")
  for (col in num_cols) {
    if (col %in% names(d)) {
      d[[col]] <- as.numeric(d[[col]])
      d[[col]][is.na(d[[col]])] <- 0
    }
  }
  if ("plus_minus" %in% names(d)) {
    d[["plus_minus"]] <- as.numeric(d[["plus_minus"]])
    # leave NA as NA for plus_minus
  }

  # Date
  if ("game_date" %in% names(d)) {
    d[["game_date"]] <- parse_game_date(d[["game_date"]])
  }

  # Text fields
  if ("player_name" %in% names(d)) d[["player_name"]] <- trimws(as.character(d[["player_name"]]))
  if ("team" %in% names(d)) d[["team"]] <- toupper(trimws(as.character(d[["team"]])))
  if ("opponent" %in% names(d)) d[["opponent"]] <- toupper(trimws(as.character(d[["opponent"]])))
  if ("home_away" %in% names(d)) d[["home_away"]] <- normalize_home_away(d[["home_away"]])
  if ("win_loss" %in% names(d)) d[["win_loss"]] <- normalize_win_loss(d[["win_loss"]])

  d
}
