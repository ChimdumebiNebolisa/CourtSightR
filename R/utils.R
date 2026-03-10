# utils.R --- Helpers and terminal output for CourtSightR
# CourtSightR: NBA analytics tool

#' Ensure outputs directory exists.
ensure_output_dir <- function(path = "outputs") {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(path)
}

#' Sanitize entity string for use in filenames (no spaces or special chars).
sanitize_entity <- function(entity) {
  gsub("[^A-Za-z0-9_-]", "_", trimws(entity))
}

#' Print a formatted summary table to the terminal.
#' @param analysis_result List from analyze_player or analyze_team (has 'summary' tibble)
#' @param mode "player" or "team"
#' @param entity Entity name/code
#' @param split Split type used
print_summary <- function(analysis_result, mode, entity, split) {
  summary_tbl <- analysis_result[["summary"]]
  if (is.null(summary_tbl) || nrow(summary_tbl) == 0) return(invisible(NULL))

  title <- paste0("CourtSightR | ", mode, ": ", entity, " | split: ", split)
  cat("\n")
  cat(strrep("=", 60), "\n")
  cat(title, "\n")
  cat(strrep("=", 60), "\n\n")

  for (i in seq_len(nrow(summary_tbl))) {
    row <- summary_tbl[i, ]
    split_lab <- row[["split_label"]]
    cat("--- ", split_lab, " ---\n", sep = "")
    cat("  Games:    ", row[["games_played"]], "\n", sep = "")
    cat("  PPG:      ", format(row[["ppg"]], digits = 2, nsmall = 2), "\n", sep = "")
    cat("  RPG:      ", format(row[["rpg"]], digits = 2, nsmall = 2), "\n", sep = "")
    cat("  APG:      ", format(row[["apg"]], digits = 2, nsmall = 2), "\n", sep = "")
    fg  <- if (is.na(row[["fg_pct"]])) "N/A" else paste0(round(100 * row[["fg_pct"]], 1), "%")
    fg3 <- if (is.na(row[["fg3_pct"]])) "N/A" else paste0(round(100 * row[["fg3_pct"]], 1), "%")
    ft  <- if (is.na(row[["ft_pct"]])) "N/A" else paste0(round(100 * row[["ft_pct"]], 1), "%")
    cat("  FG%:      ", fg, "\n", sep = "")
    cat("  3P%:      ", fg3, "\n", sep = "")
    cat("  FT%:      ", ft, "\n", sep = "")
    cat("  MPG:      ", format(row[["mpg"]], digits = 2, nsmall = 2), "\n", sep = "")
    cat("  TOV/g:    ", format(row[["tov_pg"]], digits = 2, nsmall = 2), "\n", sep = "")
    pm <- row[["plus_minus_avg"]]
    pm_str <- if (is.na(pm)) "N/A" else format(pm, digits = 2, nsmall = 2)
    cat("  +/- avg:  ", pm_str, "\n", sep = "")
    cat("\n")
  }
  cat(strrep("=", 60), "\n\n")
  invisible(NULL)
}
