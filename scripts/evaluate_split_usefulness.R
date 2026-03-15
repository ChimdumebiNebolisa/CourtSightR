#!/usr/bin/env Rscript
# evaluate_split_usefulness.R --- Lightweight split-usefulness evaluation for CourtSightR
# Primary target: player-level splits on data/games_2018_19_courtsightr.csv
#
# Usage:
#   Rscript scripts/evaluate_split_usefulness.R
#   Rscript scripts/evaluate_split_usefulness.R data/games_2018_19_courtsightr.csv

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

DEFAULT_INPUT <- "data/games_2018_19_courtsightr.csv"
DEFAULT_OUT_CSV <- "reports/tables/split_usefulness_summary.csv"
DEFAULT_OUT_MD <- "reports/tables/split_usefulness_summary.md"

PLAYER_POOL_SIZE <- 30L
POOL_MIN_GAMES <- 45L
POOL_MIN_AVG_MINUTES <- 20

BINARY_MIN_GROUP <- 10L
OPPONENT_MIN_GROUP <- 5L
OPPONENT_MIN_GROUPS <- 4L
OPPONENT_MIN_TOTAL_ROWS <- 30L

BOOTSTRAP_REPS <- 1000L
SEED <- 42L

# Performance metrics: raw columns plus one derived efficiency metric
METRICS <- c("points", "rebounds", "assists", "plus_minus", "fg_pct")

cohens_d <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  x <- x[is.finite(x)]
  y <- y[is.finite(y)]
  nx <- length(x)
  ny <- length(y)
  if (nx < 2L || ny < 2L) return(NA_real_)
  sx <- stats::sd(x)
  sy <- stats::sd(y)
  if (!is.finite(sx) || !is.finite(sy)) return(NA_real_)
  pooled <- sqrt(((nx - 1L) * sx^2 + (ny - 1L) * sy^2) / (nx + ny - 2L))
  if (!is.finite(pooled) || pooled == 0) return(NA_real_)
  (mean(x) - mean(y)) / pooled
}

eta_squared_oneway <- function(values, groups) {
  d <- data.frame(values = as.numeric(values), groups = as.character(groups), stringsAsFactors = FALSE)
  d <- d[is.finite(d$values) & !is.na(d$groups) & nzchar(d$groups), , drop = FALSE]
  if (nrow(d) < 3L || dplyr::n_distinct(d$groups) < 2L) return(NA_real_)

  grand_mean <- mean(d$values)
  by_group <- d %>%
    dplyr::group_by(groups) %>%
    dplyr::summarise(n = dplyr::n(), m = mean(values), .groups = "drop")

  ss_between <- sum(by_group$n * (by_group$m - grand_mean)^2)
  ss_total <- sum((d$values - grand_mean)^2)
  if (!is.finite(ss_total) || ss_total <= 0) return(NA_real_)
  ss_between / ss_total
}

bootstrap_ci <- function(x, reps = BOOTSTRAP_REPS, conf = 0.95) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 5L) return(c(NA_real_, NA_real_))
  alpha <- (1 - conf) / 2
  stats <- replicate(reps, median(sample(x, length(x), replace = TRUE), na.rm = TRUE))
  as.numeric(stats::quantile(stats, probs = c(alpha, 1 - alpha), na.rm = TRUE))
}

binary_interpretation <- function(score) {
  if (!is.finite(score)) return("insufficient data")
  if (score < 0.20) return("trivial practical separation")
  if (score < 0.50) return("small but potentially useful separation")
  if (score < 0.80) return("moderate separation")
  "large separation"
}

multi_interpretation <- function(score) {
  if (!is.finite(score)) return("insufficient data")
  if (score < 0.01) return("trivial explained variation")
  if (score < 0.06) return("small explained variation")
  if (score < 0.14) return("moderate explained variation")
  "large explained variation"
}

write_markdown_table <- function(tbl, path) {
  lines <- c(
    "| split_type | entity_scope | entity_count | metric | min_group_size | usefulness_score | uncertainty_low | uncertainty_high | sample_notes | interpretation | failure_mode |",
    "|---|---|---:|---|---:|---:|---:|---:|---|---|---|"
  )

  for (i in seq_len(nrow(tbl))) {
    r <- tbl[i, ]
    row <- paste(
      "|",
      r$split_type,
      "|", r$entity_scope,
      "|", r$entity_count,
      "|", r$metric,
      "|", r$min_group_size,
      "|", format(round(r$usefulness_score, 4), nsmall = 4),
      "|", ifelse(is.na(r$uncertainty_low), "NA", format(round(r$uncertainty_low, 4), nsmall = 4)),
      "|", ifelse(is.na(r$uncertainty_high), "NA", format(round(r$uncertainty_high, 4), nsmall = 4)),
      "|", gsub("\\|", "/", r$sample_notes),
      "|", gsub("\\|", "/", r$interpretation),
      "|", gsub("\\|", "/", r$failure_mode),
      "|"
    )
    lines <- c(lines, row)
  }

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, con = path)
}

evaluate_binary_split <- function(df, split_col, metric, min_group_size, selected_players_n) {
  records <- list()
  players <- unique(df$player_name)

  for (p in players) {
    g <- df[df$player_name == p, , drop = FALSE]
    vals <- g[[metric]]
    spl <- as.character(g[[split_col]])

    keep <- is.finite(vals) & !is.na(spl) & nzchar(spl)
    g2 <- data.frame(values = vals[keep], split = spl[keep], stringsAsFactors = FALSE)
    if (nrow(g2) == 0L) next

    counts <- g2 %>% dplyr::count(split, name = "n") %>% dplyr::filter(n >= min_group_size)
    if (nrow(counts) != 2L) next

    g2 <- g2[g2$split %in% counts$split, , drop = FALSE]
    if (dplyr::n_distinct(g2$split) != 2L) next

    groups <- sort(unique(g2$split))
    x <- g2$values[g2$split == groups[1L]]
    y <- g2$values[g2$split == groups[2L]]
    d <- cohens_d(x, y)
    if (!is.finite(d)) next

    records[[length(records) + 1L]] <- data.frame(
      player_name = p,
      effect = d,
      abs_effect = abs(d),
      n_a = length(x),
      n_b = length(y),
      stringsAsFactors = FALSE
    )
  }

  if (length(records) == 0L) {
    return(data.frame(
      split_type = split_col,
      entity_scope = paste0("player (top ", selected_players_n, " by total minutes)"),
      entity_count = 0L,
      metric = metric,
      min_group_size = min_group_size,
      usefulness_score = NA_real_,
      uncertainty_low = NA_real_,
      uncertainty_high = NA_real_,
      sample_notes = "No players met binary group threshold",
      interpretation = "insufficient data",
      failure_mode = "Sparse groups after thresholding",
      stringsAsFactors = FALSE
    ))
  }

  rec <- dplyr::bind_rows(records)
  ci <- bootstrap_ci(rec$abs_effect)
  dropped <- selected_players_n - nrow(rec)

  data.frame(
    split_type = split_col,
    entity_scope = paste0("player (top ", selected_players_n, " by total minutes)"),
    entity_count = nrow(rec),
    metric = metric,
    min_group_size = min_group_size,
    usefulness_score = median(rec$abs_effect, na.rm = TRUE),
    uncertainty_low = ci[1L],
    uncertainty_high = ci[2L],
    sample_notes = paste0("Median |Cohen d| across qualifying players; dropped ", dropped, " of ", selected_players_n),
    interpretation = binary_interpretation(median(rec$abs_effect, na.rm = TRUE)),
    failure_mode = "Players without >=10 games in both groups excluded",
    stringsAsFactors = FALSE
  )
}

evaluate_opponent_split <- function(df, metric, min_group_size, min_groups, min_total_rows, selected_players_n) {
  records <- list()
  players <- unique(df$player_name)

  for (p in players) {
    g <- df[df$player_name == p, , drop = FALSE]
    vals <- g[[metric]]
    opp <- as.character(g$opponent)

    keep <- is.finite(vals) & !is.na(opp) & nzchar(opp)
    g2 <- data.frame(values = vals[keep], opponent = opp[keep], stringsAsFactors = FALSE)
    if (nrow(g2) == 0L) next

    counts <- g2 %>% dplyr::count(opponent, name = "n") %>% dplyr::filter(n >= min_group_size)
    if (nrow(counts) < min_groups) next

    g3 <- g2[g2$opponent %in% counts$opponent, , drop = FALSE]
    if (nrow(g3) < min_total_rows || dplyr::n_distinct(g3$opponent) < min_groups) next

    eta2 <- eta_squared_oneway(g3$values, g3$opponent)
    if (!is.finite(eta2)) next

    records[[length(records) + 1L]] <- data.frame(
      player_name = p,
      usefulness = eta2,
      groups = dplyr::n_distinct(g3$opponent),
      rows_used = nrow(g3),
      stringsAsFactors = FALSE
    )
  }

  if (length(records) == 0L) {
    return(data.frame(
      split_type = "opponent",
      entity_scope = paste0("player (top ", selected_players_n, " by total minutes)"),
      entity_count = 0L,
      metric = metric,
      min_group_size = min_group_size,
      usefulness_score = NA_real_,
      uncertainty_low = NA_real_,
      uncertainty_high = NA_real_,
      sample_notes = "No players met opponent-group thresholds",
      interpretation = "insufficient data",
      failure_mode = "Opponent groups too sparse",
      stringsAsFactors = FALSE
    ))
  }

  rec <- dplyr::bind_rows(records)
  ci <- bootstrap_ci(rec$usefulness)
  dropped <- selected_players_n - nrow(rec)

  data.frame(
    split_type = "opponent",
    entity_scope = paste0("player (top ", selected_players_n, " by total minutes)"),
    entity_count = nrow(rec),
    metric = metric,
    min_group_size = min_group_size,
    usefulness_score = median(rec$usefulness, na.rm = TRUE),
    uncertainty_low = ci[1L],
    uncertainty_high = ci[2L],
    sample_notes = paste0("Median eta^2 across qualifying players; dropped ", dropped, " of ", selected_players_n),
    interpretation = multi_interpretation(median(rec$usefulness, na.rm = TRUE)),
    failure_mode = "Opponent imbalance and schedule effects can inflate/deflate variation",
    stringsAsFactors = FALSE
  )
}

run_split_usefulness_eval <- function(input_path = DEFAULT_INPUT,
                                      out_csv = DEFAULT_OUT_CSV,
                                      out_md = DEFAULT_OUT_MD) {
  if (!file.exists(input_path)) {
    stop("Input clean CSV not found: ", input_path,
         ". Generate it first (e.g., Rscript scripts/build_clean_games_2018_19.R).",
         call. = FALSE)
  }

  set.seed(SEED)

  d <- readr::read_csv(input_path, show_col_types = FALSE)

  required <- c("player_name", "minutes", "points", "rebounds", "assists", "plus_minus",
                "home_away", "win_loss", "opponent", "fg_made", "fg_attempts")
  missing <- setdiff(required, names(d))
  if (length(missing) > 0L) {
    stop("Missing required columns for evaluation: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  d <- d %>%
    dplyr::mutate(
      player_name = as.character(player_name),
      home_away = as.character(home_away),
      win_loss = as.character(win_loss),
      opponent = as.character(opponent),
      minutes = as.numeric(minutes),
      fg_made = as.numeric(fg_made),
      fg_attempts = as.numeric(fg_attempts),
      fg_pct = dplyr::if_else(fg_attempts > 0, fg_made / fg_attempts, NA_real_)
    )

  player_pool <- d %>%
    dplyr::group_by(player_name) %>%
    dplyr::summarise(
      games = dplyr::n(),
      avg_minutes = mean(minutes, na.rm = TRUE),
      total_minutes = sum(minutes, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::filter(games >= POOL_MIN_GAMES, avg_minutes >= POOL_MIN_AVG_MINUTES) %>%
    dplyr::arrange(dplyr::desc(total_minutes)) %>%
    dplyr::slice_head(n = PLAYER_POOL_SIZE)

  if (nrow(player_pool) == 0L) {
    stop("No players met selection thresholds. Consider lowering POOL_MIN_GAMES or POOL_MIN_AVG_MINUTES.",
         call. = FALSE)
  }

  selected <- d %>% dplyr::filter(player_name %in% player_pool$player_name)

  out_rows <- list()
  idx <- 1L
  for (metric in METRICS) {
    out_rows[[idx]] <- evaluate_binary_split(selected, "win_loss", metric, BINARY_MIN_GROUP, nrow(player_pool)); idx <- idx + 1L
    out_rows[[idx]] <- evaluate_binary_split(selected, "home_away", metric, BINARY_MIN_GROUP, nrow(player_pool)); idx <- idx + 1L
    out_rows[[idx]] <- evaluate_opponent_split(selected, metric, OPPONENT_MIN_GROUP,
                                               OPPONENT_MIN_GROUPS, OPPONENT_MIN_TOTAL_ROWS,
                                               nrow(player_pool)); idx <- idx + 1L
  }

  summary_tbl <- dplyr::bind_rows(out_rows) %>%
    dplyr::arrange(metric, split_type)

  dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(summary_tbl, out_csv, na = "")
  write_markdown_table(summary_tbl, out_md)

  message("Selected players: ", nrow(player_pool),
          " (games >= ", POOL_MIN_GAMES,
          ", avg_minutes >= ", POOL_MIN_AVG_MINUTES, ")")
  message("Wrote split usefulness summary to: ", out_csv)
  message("Wrote markdown table to: ", out_md)

  invisible(summary_tbl)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  input <- if (length(args) >= 1L) args[1L] else DEFAULT_INPUT
  run_split_usefulness_eval(input_path = input)
}
