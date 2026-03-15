#!/usr/bin/env python3
"""
One-off: replicate build_clean_games_2018_19.R + evaluate_split_usefulness.R
when R is not available. Generates data/games_2018_19_courtsightr.csv and
reports/tables/split_usefulness_summary.csv.
"""
import csv
import re
import os
from collections import defaultdict

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_PATHS = [
    os.path.join(REPO_ROOT, "data-raw", "games_raw.csv"),
    os.path.join(REPO_ROOT, "data", "games.csv", "games.csv"),
]
OUT_CSV = os.path.join(REPO_ROOT, "data", "games_2018_19_courtsightr.csv")
SUMMARY_CSV = os.path.join(REPO_ROOT, "reports", "tables", "split_usefulness_summary.csv")

SEASON_START = "2018-10-01"
SEASON_END = "2019-06-30"

HOME_CODE_TO_TEAM = {
    "ATL": "Atlanta Hawks", "BOS": "Boston Celtics", "BRK": "Brooklyn Nets",
    "CHI": "Chicago Bulls", "CHO": "Charlotte Hornets", "CLE": "Cleveland Cavaliers",
    "DAL": "Dallas Mavericks", "DEN": "Denver Nuggets", "DET": "Detroit Pistons",
    "GSW": "Golden State Warriors", "HOU": "Houston Rockets", "IND": "Indiana Pacers",
    "LAC": "Los Angeles Clippers", "LAL": "Los Angeles Lakers", "MEM": "Memphis Grizzlies",
    "MIA": "Miami Heat", "MIL": "Milwaukee Bucks", "MIN": "Minnesota Timberwolves",
    "NOP": "New Orleans Pelicans", "NYK": "New York Knicks", "OKC": "Oklahoma City Thunder",
    "ORL": "Orlando Magic", "PHI": "Philadelphia 76ers", "PHO": "Phoenix Suns",
    "POR": "Portland Trail Blazers", "SAC": "Sacramento Kings", "SAS": "San Antonio Spurs",
    "TOR": "Toronto Raptors", "UTA": "Utah Jazz", "WAS": "Washington Wizards",
}

PLAYER_POOL_SIZE = 30
POOL_MIN_GAMES = 45
POOL_MIN_AVG_MINUTES = 20
BINARY_MIN_GROUP = 10
OPPONENT_MIN_GROUP = 5
OPPONENT_MIN_GROUPS = 4
OPPONENT_MIN_TOTAL_ROWS = 30
BOOTSTRAP_REPS = 1000
SEED = 42

METRICS = ["points", "rebounds", "assists", "plus_minus", "fg_pct"]


def find_raw():
    for p in RAW_PATHS:
        if os.path.isfile(p):
            return p
    return None


def parse_date_from_game_id(gid):
    m = re.search(r"/boxscores/(\d{8})0([A-Z]{3})\.html", gid)
    if not m:
        return None
    d = m.group(1)
    return f"{d[:4]}-{d[4:6]}-{d[6:8]}"


def extract_home_code(gid):
    m = re.search(r"/boxscores/\d{8}0([A-Z]{3})\.html", gid)
    return m.group(1) if m else None


def build_clean_csv(raw_path):
    rows = []
    with open(raw_path, newline="", encoding="utf-8") as f:
        r = csv.DictReader(f)
        for row in r:
            game_date = parse_date_from_game_id(row["GAME_ID"])
            if not game_date or not (SEASON_START <= game_date <= SEASON_END):
                continue
            home_team = HOME_CODE_TO_TEAM.get(extract_home_code(row["GAME_ID"]))
            team = row["TEAM"]
            oppt = row["OPPT"]
            if home_team and team == home_team:
                home_away = "home"
            elif home_team and oppt == home_team:
                home_away = "away"
            else:
                home_away = ""
            try:
                fga = float(row["FGA"]) if row.get("FGA") else 0
                fgm = float(row["FG"]) if row.get("FG") else 0
                fg_pct = fgm / fga if fga > 0 else None
            except (ValueError, TypeError):
                fg_pct = None
            rows.append({
                "game_date": game_date,
                "player_name": row["PLAYER"],
                "team": team,
                "opponent": oppt,
                "home_away": home_away,
                "win_loss": "win" if row.get("RESULT") == "W" else "loss",
                "minutes": float(row["MP"]) if row.get("MP") else 0,
                "points": float(row["PTS"]) if row.get("PTS") else 0,
                "rebounds": float(row["TRB"]) if row.get("TRB") else 0,
                "assists": float(row["AST"]) if row.get("AST") else 0,
                "fg_made": float(row["FG"]) if row.get("FG") else 0,
                "fg_attempts": fga,
                "fg3_made": float(row["FG3"]) if row.get("FG3") else 0,
                "fg3_attempts": float(row["FG3A"]) if row.get("FG3A") else 0,
                "ft_made": float(row["FT"]) if row.get("FT") else 0,
                "ft_attempts": float(row["FTA"]) if row.get("FTA") else 0,
                "turnovers": float(row["TOV"]) if row.get("TOV") else 0,
                "plus_minus": float(row["PLUS_MINUS"]) if row.get("PLUS_MINUS") else None,
                "fg_pct": fg_pct,
            })
    os.makedirs(os.path.dirname(OUT_CSV), exist_ok=True)
    fieldnames = ["game_date", "player_name", "team", "opponent", "home_away", "win_loss",
                  "minutes", "points", "rebounds", "assists", "fg_made", "fg_attempts",
                  "fg3_made", "fg3_attempts", "ft_made", "ft_attempts", "turnovers", "plus_minus"]
    with open(OUT_CSV, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            out = {k: r.get(k) for k in fieldnames}
            if r.get("fg_pct") is not None:
                pass  # fg_pct not in CourtSightR schema for CSV; we use it only in eval
            w.writerow(out)
    return len(rows), rows


def cohens_d(x, y):
    import statistics
    x = [float(v) for v in x if v is not None and str(v).strip() != ""]
    y = [float(v) for v in y if v is not None and str(v).strip() != ""]
    if len(x) < 2 or len(y) < 2:
        return None
    mx, my = statistics.mean(x), statistics.mean(y)
    sx = statistics.stdev(x)
    sy = statistics.stdev(y)
    if sx == 0 and sy == 0:
        return None
    n = len(x) + len(y) - 2
    pooled = ((len(x) - 1) * sx * sx + (len(y) - 1) * sy * sy) / n
    if pooled <= 0:
        return None
    return (mx - my) / (pooled ** 0.5)


def eta_squared(values, groups):
    import statistics
    data = [(float(v), str(g)) for v, g in zip(values, groups) if v is not None and str(g).strip()]
    if len(data) < 3:
        return None
    vals = [x[0] for x in data]
    grps = [x[1] for x in data]
    if len(set(grps)) < 2:
        return None
    grand = statistics.mean(vals)
    by_grp = defaultdict(list)
    for v, g in data:
        by_grp[g].append(v)
    ss_between = sum(len(arr) * (statistics.mean(arr) - grand) ** 2 for arr in by_grp.values())
    ss_total = sum((v - grand) ** 2 for v in vals)
    if ss_total <= 0:
        return None
    return ss_between / ss_total


def bootstrap_ci(values, reps=BOOTSTRAP_REPS, conf=0.95):
    import random
    random.seed(SEED)
    vals = [float(x) for x in values if x is not None]
    if len(vals) < 5:
        return None, None
    alphas = (1 - conf) / 2, 1 - (1 - conf) / 2
    medians = []
    for _ in range(reps):
        s = random.choices(vals, k=len(vals))
        s.sort()
        medians.append(s[len(s) // 2])
    medians.sort()
    return medians[int(reps * alphas[0])], medians[int(reps * alphas[1])]


def run_evaluation(rows):
    # Player pool: top 30 by total minutes, >= 45 games, >= 20 avg minutes
    by_player = defaultdict(list)
    for r in rows:
        by_player[r["player_name"]].append(r)
    pool = []
    for name, games in by_player.items():
        if len(games) < POOL_MIN_GAMES:
            continue
        avg_min = sum(g["minutes"] for g in games) / len(games)
        if avg_min < POOL_MIN_AVG_MINUTES:
            continue
        total_min = sum(g["minutes"] for g in games)
        pool.append((name, total_min, games))
    pool.sort(key=lambda x: -x[1])
    pool = pool[:PLAYER_POOL_SIZE]
    if not pool:
        return []
    selected_names = {p[0] for p in pool}
    selected_rows = [r for r in rows if r["player_name"] in selected_names]

    summary_rows = []
    scope = f"player (top {len(pool)} by total minutes)"

    for metric in METRICS:
        # win_loss binary
        effects = []
        for name, _, games in pool:
            g = [x for x in games if x.get("home_away") and x.get("win_loss")]
            by_wl = defaultdict(list)
            for x in g:
                by_wl[x["win_loss"]].append(x.get(metric))
            by_wl = {k: [v for v in vs if v is not None] for k, vs in by_wl.items()}
            if len(by_wl) != 2:
                continue
            keys = list(by_wl.keys())
            if len(by_wl[keys[0]]) < BINARY_MIN_GROUP or len(by_wl[keys[1]]) < BINARY_MIN_GROUP:
                continue
            d = cohens_d(by_wl[keys[0]], by_wl[keys[1]])
            if d is not None:
                effects.append(abs(d))
        if effects:
            med = sorted(effects)[len(effects) // 2]
            lo, hi = bootstrap_ci(effects)
            interp = "large separation" if med >= 0.80 else "moderate separation" if med >= 0.50 else "small but potentially useful separation" if med >= 0.20 else "trivial practical separation"
            summary_rows.append({
                "split_type": "win_loss", "entity_scope": scope, "entity_count": len(effects),
                "metric": metric, "min_group_size": BINARY_MIN_GROUP, "usefulness_score": round(med, 4),
                "uncertainty_low": round(lo, 4) if lo is not None else "", "uncertainty_high": round(hi, 4) if hi is not None else "",
                "sample_notes": f"Median |Cohen d| across qualifying players",
                "interpretation": interp, "failure_mode": "Players without >=10 games in both groups excluded"
            })
        else:
            summary_rows.append({
                "split_type": "win_loss", "entity_scope": scope, "entity_count": 0, "metric": metric,
                "min_group_size": BINARY_MIN_GROUP, "usefulness_score": "", "uncertainty_low": "", "uncertainty_high": "",
                "sample_notes": "No players met binary group threshold", "interpretation": "insufficient data",
                "failure_mode": "Sparse groups after thresholding"
            })

        # home_away binary
        effects = []
        for name, _, games in pool:
            g = [x for x in games if x.get("home_away") in ("home", "away") and x.get(metric) is not None]
            by_ha = defaultdict(list)
            for x in g:
                by_ha[x["home_away"]].append(x.get(metric))
            if len(by_ha) != 2:
                continue
            keys = list(by_ha.keys())
            if len(by_ha[keys[0]]) < BINARY_MIN_GROUP or len(by_ha[keys[1]]) < BINARY_MIN_GROUP:
                continue
            d = cohens_d(by_ha[keys[0]], by_ha[keys[1]])
            if d is not None:
                effects.append(abs(d))
        if effects:
            med = sorted(effects)[len(effects) // 2]
            lo, hi = bootstrap_ci(effects)
            interp = "large separation" if med >= 0.80 else "moderate separation" if med >= 0.50 else "small but potentially useful separation" if med >= 0.20 else "trivial practical separation"
            summary_rows.append({
                "split_type": "home_away", "entity_scope": scope, "entity_count": len(effects),
                "metric": metric, "min_group_size": BINARY_MIN_GROUP, "usefulness_score": round(med, 4),
                "uncertainty_low": round(lo, 4) if lo is not None else "", "uncertainty_high": round(hi, 4) if hi is not None else "",
                "sample_notes": f"Median |Cohen d| across qualifying players",
                "interpretation": interp, "failure_mode": "Players without >=10 games in both groups excluded"
            })
        else:
            summary_rows.append({
                "split_type": "home_away", "entity_scope": scope, "entity_count": 0, "metric": metric,
                "min_group_size": BINARY_MIN_GROUP, "usefulness_score": "", "uncertainty_low": "", "uncertainty_high": "",
                "sample_notes": "No players met binary group threshold", "interpretation": "insufficient data",
                "failure_mode": "Sparse groups after thresholding"
            })

        # opponent multi-group
        eta2s = []
        for name, _, games in pool:
            g = [x for x in games if x.get("opponent") and x.get(metric) is not None]
            by_opp = defaultdict(list)
            for x in g:
                by_opp[x["opponent"]].append(x.get(metric))
            by_opp = {k: v for k, v in by_opp.items() if len(v) >= OPPONENT_MIN_GROUP}
            if len(by_opp) < OPPONENT_MIN_GROUPS:
                continue
            flat_vals = []
            flat_grps = []
            for k, v in by_opp.items():
                flat_vals.extend(v)
                flat_grps.extend([k] * len(v))
            if len(flat_vals) < OPPONENT_MIN_TOTAL_ROWS:
                continue
            eta2 = eta_squared(flat_vals, flat_grps)
            if eta2 is not None:
                eta2s.append(eta2)
        if eta2s:
            med = sorted(eta2s)[len(eta2s) // 2]
            lo, hi = bootstrap_ci(eta2s)
            interp = "large explained variation" if med >= 0.14 else "moderate explained variation" if med >= 0.06 else "small explained variation" if med >= 0.01 else "trivial explained variation"
            summary_rows.append({
                "split_type": "opponent", "entity_scope": scope, "entity_count": len(eta2s),
                "metric": metric, "min_group_size": OPPONENT_MIN_GROUP, "usefulness_score": round(med, 4),
                "uncertainty_low": round(lo, 4) if lo is not None else "", "uncertainty_high": round(hi, 4) if hi is not None else "",
                "sample_notes": "Median eta^2 across qualifying players",
                "interpretation": interp, "failure_mode": "Opponent imbalance and schedule effects can inflate/deflate variation"
            })
        else:
            summary_rows.append({
                "split_type": "opponent", "entity_scope": scope, "entity_count": 0, "metric": metric,
                "min_group_size": OPPONENT_MIN_GROUP, "usefulness_score": "", "uncertainty_low": "", "uncertainty_high": "",
                "sample_notes": "No players met opponent-group thresholds", "interpretation": "insufficient data",
                "failure_mode": "Opponent groups too sparse"
            })

    return summary_rows


def main():
    raw_path = find_raw()
    if not raw_path:
        print("ERROR: No raw CSV found at data-raw/games_raw.csv or data/games.csv/games.csv")
        return 1
    print("Raw CSV:", raw_path)
    n, rows = build_clean_csv(raw_path)
    print("Wrote", n, "rows to", OUT_CSV)

    # Eval needs fg_pct on rows (we have it in memory from build; re-add for eval)
    for r in rows:
        if r.get("fg_attempts", 0) > 0 and "fg_pct" not in r:
            r["fg_pct"] = r["fg_made"] / r["fg_attempts"]
        elif "fg_pct" not in r:
            r["fg_pct"] = None

    summary_rows = run_evaluation(rows)
    os.makedirs(os.path.dirname(SUMMARY_CSV), exist_ok=True)
    fieldnames = ["split_type", "entity_scope", "entity_count", "metric", "min_group_size",
                  "usefulness_score", "uncertainty_low", "uncertainty_high", "sample_notes",
                  "interpretation", "failure_mode"]
    with open(SUMMARY_CSV, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(summary_rows)
    print("Wrote", len(summary_rows), "summary rows to", SUMMARY_CSV)
    return 0


if __name__ == "__main__":
    exit(main())
