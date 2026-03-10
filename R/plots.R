# plots.R --- Generate bar and trend plots for CourtSightR
# CourtSightR: NBA analytics tool

#' Save a bar chart comparing a metric across split groups.
#' @param analysis_result List with 'summary' tibble (split_label + metric columns)
#' @param entity Label for title
#' @param split Split type (for title)
#' @param metric Metric column name (e.g. "ppg", "fg_pct")
#' @param out_dir Directory to save PNG (e.g. "outputs")
#' @return Invisible path to saved file, or NULL
plot_split_bars <- function(analysis_result, entity, split, metric = "ppg", out_dir = "outputs") {
  summary_tbl <- analysis_result[["summary"]]
  if (is.null(summary_tbl) || nrow(summary_tbl) == 0 || !metric %in% names(summary_tbl)) {
    return(invisible(NULL))
  }
  safe_entity <- sanitize_entity(entity)
  summary_tbl[["split_label"]] <- factor(summary_tbl[["split_label"]], levels = unique(summary_tbl[["split_label"]]))
  metric_label <- switch(metric,
    ppg = "Points per game",
    rpg = "Rebounds per game",
    apg = "Assists per game",
    fg_pct = "FG%",
    fg3_pct = "3P%",
    ft_pct = "FT%",
    mpg = "Minutes per game",
    tov_pg = "Turnovers per game",
    plus_minus_avg = "Plus/Minus (avg)",
    metric
  )
  p <- ggplot2::ggplot(summary_tbl, ggplot2::aes(x = .data[["split_label"]], y = .data[[metric]], fill = .data[["split_label"]])) +
    ggplot2::geom_col(show.legend = FALSE) +
    ggplot2::labs(
      title = paste0(entity, " by ", split),
      x = split,
      y = metric_label
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45L, hjust = 1))
  fname <- file.path(out_dir, paste0("bar_", safe_entity, "_", split, ".png"))
  ggplot2::ggsave(fname, plot = p, width = 6, height = 4, dpi = 150)
  invisible(fname)
}

#' Save a trend plot (e.g. points over last N games).
#' @param games_df Data frame with game_date (or row order) and a numeric series (e.g. points)
#' @param entity Label for title
#' @param y_var Column name for y-axis (e.g. "points")
#' @param out_dir Directory to save PNG
#' @return Invisible path to saved file, or NULL
plot_trend <- function(games_df, entity, y_var = "points", out_dir = "outputs") {
  if (is.null(games_df) || nrow(games_df) < 2L || !y_var %in% names(games_df)) {
    return(invisible(NULL))
  }
  safe_entity <- sanitize_entity(entity)
  df <- games_df
  df[["game_index"]] <- seq_len(nrow(df))
  if ("game_date" %in% names(df)) {
    df[["game_date"]] <- as.Date(df[["game_date"]])
  }
  y_label <- switch(y_var,
    points = "Points",
    rebounds = "Rebounds",
    assists = "Assists",
    minutes = "Minutes",
    y_var
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data[["game_index"]], y = .data[[y_var]])) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_point(size = 2) +
    ggplot2::labs(
      title = paste0(entity, " — ", y_label, " (last ", nrow(df), " games)"),
      x = "Game (most recent first)",
      y = y_label
    ) +
    ggplot2::theme_minimal()
  fname <- file.path(out_dir, paste0("trend_", safe_entity, "_last_n.png"))
  ggplot2::ggsave(fname, plot = p, width = 6, height = 4, dpi = 150)
  invisible(fname)
}
