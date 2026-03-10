# analyze_team.R --- Team-level split analysis (aggregate player-game to team-game)
# CourtSightR: NBA analytics tool

VALID_SPLITS <- c("overall", "home_away", "win_loss", "opponent", "last_n")

#' Aggregate player-game data to one row per team per game (sum stats per game).
team_game_level <- function(clean_df) {
  grp <- dplyr::group_by(
    clean_df,
    .data[["game_date"]], .data[["team"]], .data[["opponent"]],
    .data[["home_away"]], .data[["win_loss"]]
  )
  dplyr::summarise(grp,
    minutes = sum(.data[["minutes"]], na.rm = TRUE),
    points = sum(.data[["points"]], na.rm = TRUE),
    rebounds = sum(.data[["rebounds"]], na.rm = TRUE),
    assists = sum(.data[["assists"]], na.rm = TRUE),
    fg_made = sum(.data[["fg_made"]], na.rm = TRUE),
    fg_attempts = sum(.data[["fg_attempts"]], na.rm = TRUE),
    fg3_made = sum(.data[["fg3_made"]], na.rm = TRUE),
    fg3_attempts = sum(.data[["fg3_attempts"]], na.rm = TRUE),
    ft_made = sum(.data[["ft_made"]], na.rm = TRUE),
    ft_attempts = sum(.data[["ft_attempts"]], na.rm = TRUE),
    turnovers = sum(.data[["turnovers"]], na.rm = TRUE),
    plus_minus = mean(.data[["plus_minus"]], na.rm = TRUE),
    .groups = "drop"
  )
}

#' Run team analysis for a given entity and split.
#' @param clean_df Cleaned game data (player-game rows)
#' @param entity Team code (e.g. DAL, BOS)
#' @param split One of overall, home_away, win_loss, opponent, last_n
#' @param last_n Integer; number of recent games when split is last_n
#' @return List with summary tibble and optional games_df for trend
analyze_team <- function(clean_df, entity, split, last_n = 10L) {
  if (!split %in% VALID_SPLITS) {
    stop("Unsupported split: ", split, call. = FALSE)
  }
  team_games <- team_game_level(clean_df)
  entity_upper <- toupper(trimws(entity))
  team_df <- team_games[team_games[["team"]] == entity_upper, , drop = FALSE]
  if (nrow(team_df) == 0) {
    stop("No games found for team: ", entity, call. = FALSE)
  }
  team_df <- team_df[order(team_df[["game_date"]], decreasing = TRUE), , drop = FALSE]

  if (split == "last_n") {
    n <- min(as.integer(last_n), nrow(team_df))
    team_df <- team_df[seq_len(n), , drop = FALSE]
    summary_tbl <- compute_metrics(team_df)
    summary_tbl[["split_label"]] <- paste0("last_", n)
    summary_tbl <- summary_tbl[, c("split_label", names(summary_tbl)[names(summary_tbl) != "split_label"])]
    return(list(
      summary = summary_tbl,
      games_df = team_df,
      split = split,
      entity = entity_upper
    ))
  }

  if (split == "overall") {
    summary_tbl <- compute_metrics(team_df)
    summary_tbl[["split_label"]] <- "overall"
    summary_tbl <- summary_tbl[, c("split_label", names(summary_tbl)[names(summary_tbl) != "split_label"])]
    return(list(summary = summary_tbl, games_df = NULL, split = split, entity = entity_upper))
  }

  group_col <- switch(split,
    home_away = "home_away",
    win_loss = "win_loss",
    opponent = "opponent",
    "overall"
  )
  grouped <- dplyr::group_by(team_df, .data[[group_col]])
  summary_tbl <- dplyr::group_map(grouped, function(g, key) {
    out <- compute_metrics(g)
    out[["split_label"]] <- as.character(key[[1]])
    out
  })
  summary_tbl <- dplyr::bind_rows(summary_tbl)
  summary_tbl <- summary_tbl[, c("split_label", names(summary_tbl)[names(summary_tbl) != "split_label"])]
  list(summary = summary_tbl, games_df = NULL, split = split, entity = entity_upper)
}
