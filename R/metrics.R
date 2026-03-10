# metrics.R --- Compute performance metrics from game-level data
# CourtSightR: NBA analytics tool

#' Compute aggregate metrics for a set of game rows.
#' Expects columns: minutes, points, rebounds, assists, fg_made, fg_attempts,
#' fg3_made, fg3_attempts, ft_made, ft_attempts, turnovers, plus_minus.
#' @param games_df Data frame with one row per game (player or team level)
#' @return One-row tibble with games_played, ppg, rpg, apg, fg_pct, fg3_pct, ft_pct,
#'   mpg, tov_pg, plus_minus_avg
compute_metrics <- function(games_df) {
  if (!is.data.frame(games_df) || nrow(games_df) == 0) {
    return(dplyr::tibble(
      games_played = 0L, ppg = NA_real_, rpg = NA_real_, apg = NA_real_,
      fg_pct = NA_real_, fg3_pct = NA_real_, ft_pct = NA_real_, mpg = NA_real_,
      tov_pg = NA_real_, plus_minus_avg = NA_real_
    ))
  }
  n <- nrow(games_df)
  total_fga <- sum(games_df[["fg_attempts"]], na.rm = TRUE)
  total_fg3a <- sum(games_df[["fg3_attempts"]], na.rm = TRUE)
  total_fta <- sum(games_df[["ft_attempts"]], na.rm = TRUE)
  fg_pct <- if (total_fga > 0) sum(games_df[["fg_made"]], na.rm = TRUE) / total_fga else NA_real_
  fg3_pct <- if (total_fg3a > 0) sum(games_df[["fg3_made"]], na.rm = TRUE) / total_fg3a else NA_real_
  ft_pct <- if (total_fta > 0) sum(games_df[["ft_made"]], na.rm = TRUE) / total_fta else NA_real_
  plus_minus_avg <- NA_real_
  if ("plus_minus" %in% names(games_df)) {
    pm <- games_df[["plus_minus"]]
    if (any(!is.na(pm))) plus_minus_avg <- mean(pm, na.rm = TRUE)
  }
  dplyr::tibble(
    games_played = n,
    ppg = mean(games_df[["points"]], na.rm = TRUE),
    rpg = mean(games_df[["rebounds"]], na.rm = TRUE),
    apg = mean(games_df[["assists"]], na.rm = TRUE),
    fg_pct = fg_pct,
    fg3_pct = fg3_pct,
    ft_pct = ft_pct,
    mpg = mean(games_df[["minutes"]], na.rm = TRUE),
    tov_pg = mean(games_df[["turnovers"]], na.rm = TRUE),
    plus_minus_avg = plus_minus_avg
  )
}
