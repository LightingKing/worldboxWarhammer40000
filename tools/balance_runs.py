"""Run several unattended 40KBox balance games and summarise them.

Usage: python -I tools/balance_runs.py OUT_DIR [--runs 4] [--minutes 5] [--speed x10]

Each run launches WorldBox with the probe on and a different start rotation
(40KBOX_PROBE_ROTATE), so over four runs every civ starts in every band of
the map. The probe closes the menu, spawns the civs and speeds the world up;
no window focus is needed. After the time is up the game is killed, its
Player.log is copied to OUT_DIR/run_<k>.log, and the last report of every run
is printed as a table.
"""
import argparse
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

GAME = Path(r"H:\SteamLibrary\steamapps\common\worldbox\worldbox.exe")
LOG = Path(os.environ["USERPROFILE"]) / r"AppData\LocalLow\mkarpenko\WorldBox\Player.log"
REPORT = re.compile(r"Probe: year\+(\d+) (\w+) units=(\d+) babies=(\d+) kingdoms=(\d+) cities=(\d+) buildings=(\d+)")


def kill_game():
    subprocess.run(["taskkill", "/IM", "worldbox.exe", "/F"], capture_output=True)
    for _ in range(30):
        result = subprocess.run(["tasklist", "/FI", "IMAGENAME eq worldbox.exe"], capture_output=True, text=True)
        if "worldbox.exe" not in result.stdout:
            return
        time.sleep(1)


def last_reports(log_text):
    latest = {}
    for match in REPORT.finditer(log_text):
        year, civ, units, babies, kingdoms, cities, buildings = match.groups()
        latest[civ] = (int(year), int(units), int(babies), int(kingdoms), int(cities), int(buildings))
    return latest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("out")
    parser.add_argument("--runs", type=int, default=4)
    parser.add_argument("--minutes", type=float, default=5)
    parser.add_argument("--speed", default="x10")
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    summary = []
    for run in range(args.runs):
        kill_game()
        env = dict(os.environ, **{"40KBOX_PROBE": "1", "40KBOX_PROBE_ROTATE": str(run), "40KBOX_PROBE_SPEED": args.speed})
        subprocess.Popen([str(GAME)], cwd=str(GAME.parent), env=env,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(args.minutes * 60 + 40)  # ~40 s of loading before the probe starts
        kill_game()
        log_copy = out / f"run_{run}.log"
        shutil.copyfile(LOG, log_copy)
        text = log_copy.read_text(encoding="utf-8", errors="replace")
        errors = len(re.findall(r"NullReferenceException|IndexOutOfRangeException|ArgumentException|Probe failed", text))
        summary.append((run, last_reports(text), errors))
        print(f"run {run} done: {errors} exception lines", flush=True)

    print()
    print(f"{'run':>3} {'civ':<14} {'years':>5} {'units':>5} {'babies':>6} {'kingd':>5} {'cities':>6} {'bldgs':>5}")
    for run, reports, errors in summary:
        for civ, (year, units, babies, kingdoms, cities, buildings) in sorted(reports.items()):
            print(f"{run:>3} {civ:<14} {year:>5} {units:>5} {babies:>6} {kingdoms:>5} {cities:>6} {buildings:>5}")
        print(f"{run:>3} exceptions: {errors}")


if __name__ == "__main__":
    main()
