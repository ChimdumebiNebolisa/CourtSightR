# analyze_player.R --- Player-level split analysis
# CourtSightR: NBA analytics tool

VALID_SPLITS <- c("overall", "home_away", "win_loss", "opponent", "last_n")

#' Run player analysis for a given entity and split.
#' @param clean_df Cleaned game data (player-game rows)
#' @param entity Player name (must match player_name after cleaning)
#' @param split One of overall, home_away, win_loss, opponent, last_n
#' @param last_n Integer; number of recent games when split is last_n
#' @return List with summary tibble (split_label, metrics) and optional games_df for trend
analyze_player <- function(clean_df, entity, split, last_n = 10L) {
  if (!split %in% VALID_SPLITS) {
    stop("Unsupported split: ", split, call. = FALSE)
  }
  player_df <- clean_df[trimws(as.character(clean_df[["player_name"]])) == trimws(entity), , drop = FALSE]
  if (nrow(player_df) == 0) {
    stop("No games found for player: ", entity, call. = FALSE)
  }
  player_df <- player_df[order(player_df[["game_date"]], decreasing = TRUE), , drop = FALSE]

  if (split == "last_n") {
    n <- min(as.integer(last_n), nrow(player_df))
    player_df <- player_df[seq_len(n), , drop = FALSE]
    summary_tbl <- compute_metrics(player_df)
    summary_tbl[["split_label"]] <- paste0("last_", n)
    summary_tbl <- summary_tbl[, c("split_label", names(summary_tbl)[names(summary_tbl) != "split_label"])]
    return(list(
      summary = summary_tbl,
      games_df = player_df,
      split = split,
      entity = entity
    ))
  }

  if (split == "overall") {
    summary_tbl <- compute_metrics(player_df)
    summary_tbl[["split_label"]] <- "overall"
    summary_tbl <- summary_tbl[, c("split_label", names(summary_tbl)[names(summary_tbl) != "split_label"])]
    return(list(summary = summary_tbl, games_df = NULL, split = split, entity = entity))
  }

  group_col <- switch(split,
    home_away = "home_away",
    win_loss = "win_loss",
    opponent = "opponent",
    "overall"
  )
  grouped <- dplyr::group_by(player_df, .data[[group_col]])
  summary_tbl <- dplyr::group_map(grouped, function(g, key) {
    out <- compute_metrics(g)
    out[["split_label"]] <- as.character(key[[1]])
    out
  })
  summary_tbl <- dplyr::bind_rows(summary_tbl)
  summary_tbl <- summary_tbl[, c("split_label", names(summary_tbl)[names(summary_tbl) != "split_label"])]
  list(summary = summary_tbl, games_df = NULL, split = split, entity = entity)
}
